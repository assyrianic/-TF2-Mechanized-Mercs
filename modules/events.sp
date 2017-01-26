

public Action Resupply(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	//int client = GetClientOfUserId( event.GetInt("userid") );
	BaseVehicle player = BaseVehicle(event.GetInt("userid"), true);
	if ( player and IsClientInGame(player.index) ) {
		int client = player.index;
		SetVariantString(""); AcceptEntityInput(client, "SetCustomModel");
		SetClientOverlay(client, "0");

		if ( IsBlueBlocked(client) or IsRedBlocked(client) )
			return Plugin_Continue;

		bool free = AllowFreeClasses.BoolValue;
		int team = player.iTeam;
		//bool unlocked = IsClassUnlocked(player);
		switch (GamePlayMode.IntValue) {
			case Normal: {
				switch ( player.Class ) {
					case TFClass_Scout: {
						if ( (GarageFlags[team-2] & SUPPORTBUILT) or free ) {
							player.iType = ArmoredCar;
							player.bSetOnSpawn = true;
						}
						else {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}Armored Car is currently locked, you need a Support Mainframe online to Unlock it.");
							player.Class = GetRandomClass(team);
							TF2_RegeneratePlayer(client);
							//player.bSetOnSpawn = false;
						}
					}
					case TFClass_Sniper: {
						if ( (GarageFlags[team-2] & HEAVYBUILT) or free ) {
							player.iType = Destroyer;
							player.bSetOnSpawn = true;
						}
						else {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}Marder 2 is currently locked, you need a Heavy Support Mainframe online to Unlock it.");
							player.Class = GetRandomClass(team);
							TF2_RegeneratePlayer(client);
							//player.bSetOnSpawn = false;
						}
					}
					case TFClass_DemoMan: {
						if ( (GarageFlags[team-2] & OFFENSIVEBUILT) or free ) {
							player.iType = Tank;
							player.bSetOnSpawn = true;
						}
						else {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}Panzer IV is currently locked, you need an Offensive Mainframe online to Unlock it.");
							player.Class = GetRandomClass(team);
							TF2_RegeneratePlayer(client);
							//player.bSetOnSpawn = false;
						}
					}
					case TFClass_Medic: {
						if ( (GarageFlags[team-2] & SUPPORTBUILT) or free ) {
							player.iType = Ambulance;
							player.bSetOnSpawn = true;
						}
						else {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}Ambulance is currently locked, you need a Support Mainframe online to Unlock it.");
							player.Class = GetRandomClass(team);
							TF2_RegeneratePlayer(client);
							//player.bSetOnSpawn = false;
						}
					}
					case TFClass_Heavy: {
						if ( (GarageFlags[team-2] & HEAVYBUILT) or free ) {
							player.iType = KingPanzer;
							player.bSetOnSpawn = true;
						}
						else {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}Tiger II is currently locked, you need a Heavy Support Mainframe online to Unlock it.");
							player.Class = GetRandomClass(team);
							TF2_RegeneratePlayer(client);
							//player.bSetOnSpawn = false;
						}
					}
					case TFClass_Pyro: {
						if ( (GarageFlags[team-2] & OFFENSIVEBUILT) or free ) {
							player.iType = PanzerIII;
							player.bSetOnSpawn = true;
						}
						else {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}Panzer II is currently locked, you need an Offensive Mainframe online to Unlock it.");
							player.Class = GetRandomClass(team);
							TF2_RegeneratePlayer(client);
							//player.bSetOnSpawn = false;
						}
					}
					
					case TFClass_Soldier: {
						player.bSetOnSpawn = false;
						//if (!player.iSecWep or !IsValidEntity(player.iSecWep))
						player.iSecWep = player.SpawnWeapon("tf_weapon_smg", 16, 1, 0, "4 ; 1.28 ; 78 ; 6.0 ; 106 ; 0.2");
						int weprl = GetPlayerWeaponSlot(client, 0);
						if ( weprl > MaxClients and IsValidEntity(weprl) ) {
							int wepindex = GetEntProp(weprl, Prop_Send, "m_iItemDefinitionIndex");
							//	Removed beggars bazooka, jumper, and cow mangler in order. Too game breaking.
							if ( wepindex == 730 or wepindex == 237 or wepindex == 441 )
							{
								TF2_RemoveWeaponSlot(client, 0);
								player.SpawnWeapon("tf_weapon_rocketlauncher", 18, 1, 0, "3 ; 0.2 ; 77 ; 0.5 ; 96 ; 2.0 ; 2 ; 1.5 ; 411 ; 3.0");
							}
						}
					}
					case TFClass_Spy: {
						player.bSetOnSpawn = false;
						TF2_RemoveAllWeapons(client);
						player.SpawnWeapon("tf_weapon_revolver", 460, 1, 0, "106 ; 0.5 ; 26 ; 35");
						player.SpawnWeapon("tf_weapon_pistol", 773, 1, 0, "78 ; 7.5");
						player.SpawnWeapon("tf_weapon_shovel", 447, 1, 0, "1 ; 0.75 ; 251 ; 1.0 ; 264 ; 1.7 ; 263 ; 1.55 ; 68 ; 2.0");

						SetVariantString(OfficerModel);
						AcceptEntityInput(client, "SetCustomModel");
						SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
						SetPawnTimer(_SetOfficerModel, 1.0, client);
					}
					case TFClass_Engineer: {
						player.bSetOnSpawn = false;
						//TF2_RemoveWeaponSlot(client, 1);
						//if (!player.iSecWep or !IsValidEntity(player.iSecWep))
						player.iSecWep = player.SpawnWeapon("tf_weapon_pipebomblauncher", 130, 1, 10, "1 ; 0.5 ; 89 ; -4.0 ; 120 ; 0.1 ; 4 ; 0.5 ; 727 ; 2.0 ; 121 ; 1.0 ; 119 ; 1.0 ; 670 ; 0.1");
						//SpawnVehicleGarageMenu( client, -1 ) ;
					}
				}
				player.HelpPanel();
			}
			case Powerup: {
				player.iType = -1;
				player.bSetOnSpawn = false;
				CPrintToChat(client, "{red}[Mechanized Mercs] {white}Engies can build Vehicles (!vehicle), press RELOAD, when they're done building, to drive them!");
			}
			case GunGame: {
				if (player.iVehicleKills < 5)
					player.iType = ArmoredCar;
				switch ( player.Class ) {
					case TFClass_Engineer, TFClass_Spy, TFClass_Soldier, TFClass_Medic, TFClass_Scout: {
						if (player.iVehicleKills >= 5) {
							int VehType = player.iVehicleKills/5;
							switch (VehType) {	// make the player become the strongest available tank
								case 1: player.iType = PanzerIII;
								case 2: player.iType = Tank;
								case 3: player.iType = Destroyer;
								case 4: player.iType = KingPanzer;
							}
						}
					}
					case TFClass_Heavy: {
						if (player.iVehicleKills >= 20)
							player.iType = KingPanzer;
					}
					case TFClass_Pyro: {
						if (player.iVehicleKills >= 5)
							player.iType = PanzerIII;
					}
					case TFClass_DemoMan: {
						if (player.iVehicleKills >= 10)
							player.iType = Tank;
					}
					case TFClass_Sniper: {
						if (player.iVehicleKills >= 15)
							player.iType = Tank;
					}
				}
				player.bSetOnSpawn = true;
				if (player.iVehicleKills >= 5)
					SpawnVehicleGarageMenu(client, -1);
			}
		}
		player.bIsVehicle = player.bSetOnSpawn;
		if ( player.bIsVehicle )
			player.ConvertToVehicle();
	}
	return Plugin_Continue;
}

public Action PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	BaseVehicle player = BaseVehicle(event.GetInt("userid"), true);

	if (player.bIsVehicle) { // if victim is a vehicle, kill him off and remove overlay
		CreateTimer(0.1, Timer_VehicleDeath, player.userid);
		ManageVehicleDeath(player);
	}

	BaseVehicle fighter = BaseVehicle(event.GetInt("attacker"), true);
	if (fighter.bIsVehicle and !player.bIsVehicle) //if vehicle is killer and victim is not a vehicle, check if player was crushed
		ManageVehicleKillPlayer(fighter, player, event);
	if (player.bIsVehicle) {
		fighter.iVehicleKills++;
		player.iVehicleKills = 0;
	}
	//if (fighter.bIsVehicle and player.bIsVehicle) //clash of the titans - when both killer and victim are Vehicles

	return Plugin_Continue;
}

public Action PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	BaseVehicle player = BaseVehicle(event.GetInt("userid"), true);
	BaseVehicle attacker = BaseVehicle( event.GetInt("attacker"), true );

	if ( player == attacker and !bSelfDamage.BoolValue )
		return Plugin_Continue;

	if ( player.bIsVehicle )
		player.iHealth -= event.GetInt("damageamount");

	return Plugin_Continue;
}

public Action ObjectBuilt(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	BaseVehicle engie = BaseVehicle(event.GetInt("userid"), true);
	if (engie.Class == TFClass_Spy)
		return Plugin_Continue;

	int building = event.GetInt("index");
	int flags = manager.GaragesBuilt(engie.iTeam);
	int health=0;
	switch (flags) {
		//case 2, 4, 8: health=2;
		case 6, 10, 12: health=300;
		case 14: health=400;
	}
	if (health)
		SetEntProp(building, Prop_Send, "m_iMaxHealth", health);

	return Plugin_Continue;
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (GamePlayMode.IntValue)
		return Plugin_Continue;

	for (int team=0; team<2; ++team) {
		for (int offset=0 ; offset<3 ; offset++) {
			if (GarageRefs[team][offset] and IsValidEntity(EntRefToEntIndex(GarageRefs[team][offset])))
				CreateTimer( 0.1, RemoveEnt, GarageRefs[team][offset] );
			GarageRefs[team][offset] = 0;
			manager.DeleteGarage(team, OffsetToFlag(offset));
		}
	}
	return Plugin_Continue;
}

void _SetOfficerModel(const int x)
{
	SetVariantString(OfficerModel);
	AcceptEntityInput(x, "SetCustomModel");
	SetEntProp(x, Prop_Send, "m_bUseClassAnimations", 1);
}
