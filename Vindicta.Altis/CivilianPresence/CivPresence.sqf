#include "common.h"

/*
Civilian presense module for a specific small area (hundreds of meters, but can be different)
Authors: Jeroen Notenbomer, Billw, Sparker
Some BI civilian presence code is used
*/

#define pr private

// Variable which controls population density
if (isNil "vin_CivPresence_multiplierUser") then {
	vin_CivPresence_multiplierUser = 1;
	vin_CivPresence_multiplierSystem = 1;
};

#define OOP_CLASS_NAME CivPresence
CLASS("CivPresence", "")

	// Area
	// [center, a, b, angle, isRectangle, c]
	VARIABLE("area");

	// Center position
	VARIABLE("pos");

	// Amount of houses in this area, used for calculation of civ count
	VARIABLE("nHouses");

	// Counters and state
	VARIABLE("enabled");

	// Target amount of civilians this object will try to keep
	// Based on values above (0 if disabled, mult*cap if enabled)
	VARIABLE("targetAmount");

	// Current amount of created civilians
	VARIABLE("currentAmount");

	// Periodic processing of this object is active
	VARIABLE("processingEnabled");

	// Array of positions
	VARIABLE("buildingPosAGL");
	VARIABLE("waypointsAGL");
	VARIABLE("spawnPointsAGL");

	// Array of Civilian-derived OOP objects
	VARIABLE("civilians");

	// Marker for debug
	VARIABLE("debugMarkerArea");
	VARIABLE("debugMarkerText");

	// 
	/* private */ METHOD(new)
		params [P_THISOBJECT, P_POSITION("_pos"), P_NUMBER("_halfWidthx"), P_NUMBER("_halfWidthy"), P_ARRAY("_buildingPositions"), P_ARRAY("_waypoints")];

		pr _area = [_pos, _halfWidthx, _halfWidthy, 0, true]; // pos, a, b, angle, rectangle
		T_SETV("area", _area);
		T_SETV("pos", _pos);

		#ifdef DEBUG_CIV_PRESENCE

		// Rectangular marker for area
		_pos params ["_x", "_y"];
		pr _mrkName = format ["%1_debug_%2_%3", _thisObject, floor _x, floor _y];
		pr _mrk = createMarkerLocal [_mrkName, _pos];
		_mrk setMarkerShapeLocal "RECTANGLE";
		_mrk setMarkerBrushLocal "SolidFull";
		_mrk setMarkerSizeLocal [_halfWidthx, _halfWidthy];
		_mrk setMarkerColorLocal "ColorBlue";
		_mrk setMarkerAlphaLocal 0.2;
		T_SETV("debugMarkerArea", _mrk);

		// Marker with text
		_mrkName = format ["%1_debugText_%2_%3", _thisObject, floor _x, floor _y];
		pr _mrk = createMarkerLocal [_mrkName, _pos];
		_mrk setMarkerShapeLocal "ICON";
		_mrk setMarkerBrushLocal "SolidFull";
		_mrk setMarkerColorLocal "ColorBlue";
		_mrk setMarkerAlphaLocal 1.0;
		_mrk setMarkerTypeLocal "mil_dot";
		_mrk setMarkerSizeLocal [0.3, 0.3];
		_mrk setMarkerText "idle";
		T_SETV("debugMarkerText", _mrk);

		{
			private _markerName = createMarker [format["%1_wypnt_%2_%3", _thisObject, round (_x#0), round (_x#1)], _x];
			_markerName setMarkerShape "ICON";
			_markerName setMarkerType "hd_dot";
			_markerName setMarkerColor "ColorBlue";
		} forEach _waypoints;

		{
			private _markerName = createMarker [format["%1_bpos_%2_%3_%4", _thisObject, round (_x#0), round (_x#1), round(_x#2)], _x];
			_markerName setMarkerShape "ICON";
			_markerName setMarkerType "hd_dot";
			_markerName setMarkerColor "ColorRed";
		} forEach _buildingPositions;

		#endif

		// Calculate amount of houses
		pr _nHouses = {count (_x buildingPos -1) > 0} count (_pos nearObjects ["House", _radius]);
		T_SETV("nHouses", _nHouses);

		T_SETV("enabled", false);
		T_SETV("targetAmount", 0);
		T_SETV("currentAmount", 0);
		T_SETV("processingEnabled", false);
		T_SETV("buildingPosAGL", _buildingPositions);
		T_SETV("waypointsAGL", _waypoints);
		T_SETV("spawnPointsAGL", _buildingPositions + _waypoints);
		T_SETV("civilians", []);

	ENDMETHOD;

	METHOD(delete)
		params [P_THISOBJECT];

		
		#ifdef DEBUG_CIV_PRESENCE
		deleteMarkerLocal T_GETV("debugMarkerArea");
		deleteMarkerLocal T_GETV("debugMarkerText");
		#endif
	ENDMETHOD;

	#ifdef DEBUG_CIV_PRESENCE
	METHOD(_updateDebugMarkers)
		params [P_THISOBJECT];

		pr _mrkArea = T_GETV("debugMarkerArea");
		pr _mrkText = T_GETV("debugMarkerText");
		if (_enabled) then {
			_mrkArea setMarkerAlphaLocal 0.6;
		} else {
			_mrkArea setMarkerAlphaLocal 0.2;
		};

		pr _currentAmount = T_GETV("currentAmount");
		pr _targetAmount = T_GETV("targetAmount");
		if (_targetAmount == 0 && _currentAmount == 0) then {
			_mrkText setMarkerTextLocal "";
		} else {
			_mrkText setMarkerTextLocal (format ["%1 / %2", _currentAmount, _targetAmount]);
		};


	ENDMETHOD;
	#endif

	// Creates an object here, returns object or nULL_OBJECT if it cant't be created here
	METHOD(tryCreateInstance)
		params [P_THISOBJECT, P_POSITION("_pos"), P_NUMBER("_halfWidthx"), P_NUMBER("_halfWidthy")];

		OOP_INFO_1("tryCreateInstance: %1", _this);

		pr _pos = +_pos;
		_pos set [2, 0]; // Snap to ground

		//loop through the border
		private _waypoints = [];	//road segments and spawnpoints
		private _buildingPositions = [];	//locations in buildings

		// in meters, average distance between spawn/way points
		private _area = [_pos, _halfWidthx, _halfWidthy, 0, true]; // pos, a, b, angle, rectangle
		_area params ["_pos", "_a", "_b"];
		private _res = 20; // (_a max _b) / 2; // Resolution of the scan
		private _nCellsXHalf = ceil(_a/_res); // Amount of cells - one dimension
		private _nCellsYHalf = ceil(_b/_res);

		private _radius = sqrt (_a^2 + _b^2);

		// Traverse a grid covering the entire area specified
		for "_idx" from -_nCellsXHalf to _nCellsXHalf do {
			for "_idy" from -_nCellsYHalf to _nCellsYHalf do{
				//calculate position reletive to whole map
				private _posSubarea = [_idx*_res + (_pos#0), _idy*_res + (_pos#1), 0];

				//skipping the ones out side the area
				if(_posSubarea inArea _area) then {

					//paint markers for debugging
					/*
					#ifdef DEBUG_CIV_PRESENCE
					private _markerName = createMarker [format["%1_subarea_%2_%3", _thisObject, _idx, _idy], _posSubarea];
					_markerName setMarkerShape "ICON";
					_markerName setMarkerType "hd_dot";
					_markerName setMarkerColor "ColorBlack";
					_markerName setMarkerText (format ["(%1, %2)", _idx, _idy]); 
					#endif
					*/

					private _building = nearestObject [_posSubarea, "House"]; // (nearestBuilding doesn't return objects placed in editor)
					private _buildingPositionsThisHouse = (_building buildingPos -1);
					if ((_building distance2D _posSubarea < _res/2) && {count _buildingPositionsThisHouse > 0}) then {
						//_buildingPositionsThisHouse = (_buildingPositionsThisHouse call BIS_fnc_arrayShuffle);
						_buildingPositions append _buildingPositionsThisHouse;
					};
					
					private _nearRoad = selectRandom ((_posSubarea nearRoads _res/2) apply { [_x, roadsConnectedTo _x] } select { count (_x#1) > 0 });
					if(!isnil "_nearRoad") then {
						_nearRoad params ["_road", "_rct"];
						private _dir = _road getDir _rct#0;
						// Move to the edge
						private _width = [_road, 1, 8] call misc_fnc_getRoadWidth;
						private _pos = [getPos _road, _width - 4, _dir + (selectRandom [90, 270]) ] call BIS_Fnc_relPos;
						// Move up and down the street a bit
						_pos = [_pos, _width * 0.5, _dir + (selectRandom [0, 180]) ] call BIS_Fnc_relPos;

						_waypoints pushBack _pos;
					};
				};
			};//for loop _y
		};

		OOP_INFO_2("  building positions: %1, waypoints: %2", count _buildingPositions, count _waypoints);

		// Does it make sense to create it here?
		pr _success = ((count _buildingPositions) > 0) && ((count _waypoints) > 1);
		pr _instance = NULL_OBJECT;
		if (_success) then {			

			pr _args = [_pos, _halfWidthX, _halfWidthY, _buildingPositions, _waypoints];
			_instance = NEW("CivPresence", _args);
		};

		_instance
	ENDMETHOD;

	METHOD(enable)
		params [P_THISOBJECT, P_BOOL("_enabled")];

		OOP_INFO_1("enable: %1", _enabled);

		T_SETV("enabled", _enabled);
		//T_CALLM0("_updateTargetAmount");

		#ifdef DEBUG_CIV_PRESENCE
		T_CALLM0("_updateDebugMarkers");
		#endif
	ENDMETHOD;

	/*
	METHOD(setCapacity)
		params [P_THISOBJECT, P_NUMBER("_value")];

		T_SETV("capacity", _value);
		//T_CALLM0("_updateTargetAmount");

		#ifdef DEBUG_CIV_PRESENCE
		T_CALLM0("_updateDebugMarkers");
		#endif
	ENDMETHOD;
	*/

	/*
	METHOD(setCapacityMultiplier)
		params [P_THISOBJECT, P_NUMBER("_value")];
		T_SETV("capacityMult", _value);
		//T_CALLM0("_updateTargetAmount");

		#ifdef DEBUG_CIV_PRESENCE
		T_CALLM0("_updateDebugMarkers");
		#endif
	ENDMETHOD;
	*/

	STATIC_METHOD(setMultiplierUser)
		params [P_THISCLASS, P_NUMBER("_value")];
		vin_CivPresence_multiplierUser = _value;
	ENDMETHOD

	STATIC_METHOD(setMultiplierSystem)
		params [P_THISCLASS, P_NUMBER("_value")];
		vin_CivPresence_multiplierSystem = _value;
	ENDMETHOD

	// updates target amount of civilians - based on different rules
	/* private */ METHOD(commitSettings)

		params [P_THISOBJECT];
		pr _val = 0;
		if (T_GETV("enabled")) then {
			pr _area = T_GETV("area");
			pr _area_m2 = 4*(_area#1)*(_area#2);
			pr _capHouses = N_CIVS_PER_HOUSE*T_GETV("nHouses");
			pr _capArea = MAX_DENSITY*_area_m2;
			pr _val =  ceil ( vin_CivPresence_multiplierUser*vin_CivPresence_multiplierSystem* (_capHouses min _capArea) );
		};
		T_SETV("targetAmount", _val);

		// If we must change the amount of created bots, enable processing
		if (_val != T_GETV("currentAmount")) then {
			T_CALLM0("_addToProcessCategory");
		};

		#ifdef DEBUG_CIV_PRESENCE
		T_CALLM0("_updateDebugMarkers");
		#endif
	ENDMETHOD;

	// "process" method of this object will be called periodically
	/* private */ METHOD(_addToProcessCategory)
		params [P_THISOBJECT];
		
		// Bail if already added
		if (T_GETV("processingEnabled")) exitWith {};

		CALLM2(gMessageLoopUnscheduled, "addProcessCategoryObject", "MiscLowPriority", _thisObject);
		T_SETV("processingEnabled", true);
	ENDMETHOD;

	// "process" method of this object will not be called any more
	/* private */ METHOD(_removeFromProcessCategory)
		params [P_THISOBJECT];
		CALLM1(gMessageLoopUnscheduled, "deleteProcessCategoryObject", _thisObject);
		T_SETV("processingEnabled", false);
	ENDMETHOD;

	// Called periodically
	// It might create a civilian at each call, so don't call too often
	METHOD(process)
		params [P_THISOBJECT];

		pr _currentAmount = T_GETV("currentAmount");
		pr _targetAmount = T_GETV("targetAmount");
 
		if (_targetAmount == _currentAmount) then {
			if (_targetAmount == 0) then {
				// If we don't need any more civilians, disable processing of this
				T_CALLM0("_removeFromProcessCategory");
			};
		} else {
			if (_targetAmount > _currentAmount) then {
				// Try to create one civilian
				pr _created = T_CALLM0("_tryCreateUnit");
			} else {
				// Try to remove one civilian
				pr _removed = T_CALLM0("_tryDeleteUnit");
				if (_removed) then {
					if (T_GETV("currentAmount") == 0 && _targetAmount == 0) then {
						T_CALLM0("_removeFromProcessCategory");
					};
				};
			};
		};

		#ifdef DEBUG_CIV_PRESENCE
		T_CALLM0("_updateDebugMarkers");
		#endif
	ENDMETHOD;

	// Creates an ambient civ
	// Returns a ref to OOP Civilian object
	METHOD(_createAmbientCivilian)
		params [P_THISOBJECT, P_POSITION("_pos"), P_STRING("_className")];

		createAgent [_className, _pos, [], 0, "CAN_COLLIDE"];
		_ho setVariable ["vin_isagent", true];
		pr _oop_civ = NEW("Civilian", [_hO]);	// Create OOP object associated with it
		
		_oop_civ // Return
	ENDMETHOD;

	// Tries to create a civilian at random spot
	// returns bool
	METHOD(_tryCreateUnit)
		params [P_THISOBJECT];

		private _pos = selectRandom T_GETV("spawnPointsAGL");
		private _posASL = (AGLToASL _pos) vectorAdd [0,0,1.5];

		//check if any player can see the point of creation
		private _seenBy = allPlayers findIf {_x distance _pos < 35 || {(_x distance _pos < 150 && {([_x,"VIEW"] checkVisibility [eyePos _x, _posASL]) > 0.5})}};
		if (_seenBy != -1) exitWith {false};

		pr _className = "C_Man_3_enoch_F";
		pr _oop_civ = T_CALLM2("_createAmbientCivilian", _pos, _className);

		// Register it here, increase counters
		pr _createdObjects = T_GETV("civilians");
		_createdObjects pushBack _oop_civ;
		T_SETV("currentAmount", count _createdObjects);

		true
	ENDMETHOD;

	// Tries to delete a civlian
	// returns bool
	METHOD(_tryDeleteUnit)
		params [P_THISOBJECT];

		pr _createdObjects = T_GETV("civilians");
		if (count _createdObjects == 0) exitWith {false};

		private _civ = selectRandom _createdObjects;
		private _hO = CALLM0(_civ, "getObjectHandle");
		
		// Check if it can be deleted
		private _seenBy = allPlayers findIf {_x distance _hO < 50 || {(_x distance _hO < 150 && {([_x,"VIEW",_hO] checkVisibility [eyePos _x, eyePos _hO]) > 0.5})}};
		if (_seenBy != -1) exitWith {false};

		DELETE(_civ); // Will also delete him from the game world
		pr _createdObjects = T_GETV("civilians");
		_createdObjects deleteAt (_createdObjects find _civ);

		T_SETV("currentAmount", count _createdObjects);

		true
	ENDMETHOD;

	METHOD(_getNearestSafeSpot)
		params [P_THISOBJECT];

	ENDMETHOD;

	METHOD(_getSafeSpot)
		params [P_THISOBJECT];
		/*

		private _core = _unit getVariable ["#core",objNull]; if (isNull _core) exitWith {objNull};
		private _safespots = _core getVariable ["#modulesSafeSpots",[]];
		private _units = _core getVariable ["#units",[]];


		_safespots = _safespots select {_x getVariable ["#type",-1] != [2,0] select _mode};

		_safespots = _safespots select
		{
			_safespot = _x;
			_capacity = _safespot getVariable ["#capacity",100];
			_inhabitantCount = {_x getVariable ["#safespot",objNull] == _safespot} count _units;



			_inhabitantCount < _capacity
		};

		if (count _safespots == 0) then {_safespots = _core getVariable ["#modulesSafeSpots",[objNull]]};
		switch (_mode) do
		{
			case 0:
			{
				([_safespots,[_unit],{_x distance _input0},"ASCEND"] call bis_fnc_sortBy) param [0,objNull]
			};
			case 1:
			{
				selectRandom _safespots
			};
			default
			{
				objNull
			};
		};}
		*/
	ENDMETHOD;

ENDCLASS;