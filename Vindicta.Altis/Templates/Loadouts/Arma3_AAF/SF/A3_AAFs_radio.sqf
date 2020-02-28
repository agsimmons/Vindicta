removeAllWeapons this;
removeAllItems this;
removeAllAssignedItems this;
removeUniform this;
removeVest this;
removeBackpack this;
removeHeadgear this;
removeGoggles this;

_RandomHeadgear = selectRandom ["H_HelmetB_light_black", "H_Bandanna_khk", "H_Watchcap_khk", "H_Cap_blk_Raven"];
this addHeadgear _RandomHeadgear;
this forceAddUniform "U_I_CombatUniform";
this addVest "V_SmershVest_01_F", "V_SmershVest_01_radio_F";
this addBackpack "B_RadioBag_01_digi_F";

this addWeapon "arifle_SPAR_01_snd_F";
this addPrimaryWeaponItem "muzzle_snds_m_khk_F";
this addPrimaryWeaponItem "ACE_acc_pointer_green";
this addPrimaryWeaponItem "optic_ERCO_khk_F";
this addPrimaryWeaponItem "30Rnd_556x45_Stanag_Sand";
this addPrimaryWeaponItem "bipod_03_F_oli";
this addWeapon "hgun_ACPC2_F";
this addHandgunItem "muzzle_snds_acp";
this addHandgunItem "acc_flashlight_pistol";
this addHandgunItem "9Rnd_45ACP_Mag";


for "_i" from 1 to 2 do {this addItemToUniform "FirstAidKit";};
for "_i" from 3 to 5 do {this addItemToVest "30Rnd_556x45_Stanag_Sand";};
for "_i" from 2 to 3 do {this addItemToVest "9Rnd_45ACP_Mag";};
for "_i" from 1 to 2 do {this addItemToVest "SmokeShell";};
for "_i" from 1 to 2 do {this addItemToVest "HandGrenade";};
for "_i" from 1 to 2 do {this addItemToVest "MiniGrenade";};
for "_i" from 1 to 2 do {this addItemToUniform "Chemlight_green";};


this linkItem "ItemMap";
this linkItem "ItemGPS";
this linkItem "ItemRadio";
this linkItem "ItemCompass";
this linkItem "ItemWatch";
this linkItem "NVGoggles_INDEP";
this linkItem "Rangefinder";
