public Action Resupply(Event event, const char[] name, bool dontBroadcast)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	//int client = GetClientOfUserId( event.GetInt("userid") );
	BaseVehicle player = BaseVehicle(event.GetInt("userid"), true);
	if( player and IsClientInGame(player.index) ) {
		int client = player.index;
		SetVariantString(""); AcceptEntityInput(client, "SetCustomModel");
		SetClientOverlay(client, "0");
		//SetVariantString("0");
		//AcceptEntityInput(client, "SetForcedTauntCam");

		if( IsBlueBlocked(client) or IsRedBlocked(client) )
			return Plugin_Continue;

		bool free = AllowFreeClasses.BoolValue;
		int team = player.iTeam;
		//bool unlocked = IsClassUnlocked(player);
		if( player.Class == TFClass_Engineer )
			CPrintToChat(client, "{red}[MechMercs] {white}You can build Vehicles Garages (!garage). Once the Garages are done building, you and your team can build vehicles (!vehicle)");

		switch( player.iType ) {
			case -1: { player.bSetOnSpawn = false; }
			case ArmoredCar, Ambulance: {
				if( (GarageFlags[team-2] & SUPPORTBUILT) or free ) {
					player.bSetOnSpawn = true;
				}
				else {
					CPrintToChat(client, "{red}[Mechanized Mercs] {white}Armored Cars & Ambulances are currently locked, Please Build a Support Garage to Unlock them.");
					player.iType = -1;
					player.bSetOnSpawn = false;
				}
			}
			case Tank, PanzerIII: {
				if( (GarageFlags[team-2] & OFFENSIVEBUILT) or free ) {
					player.bSetOnSpawn = true;
				}
				else {
					CPrintToChat(client, "{red}[Mechanized Mercs] {white}Panzer 4s and Panzer 2s are currently locked, Please Build an Offensive Garage to Unlock them.");
					player.iType = -1;
					player.bSetOnSpawn = false;
				}
			}
			case KingPanzer, Destroyer: {
				if( (GarageFlags[team-2] & HEAVYBUILT) or free ) {
					player.bSetOnSpawn = true;
				}
				else {
					CPrintToChat(client, "{red}[Mechanized Mercs] {white}King Tigers & Marder 2 Tank Destroyers are currently locked, Please Build a Heavy Support Garage to Unlock them.");
					player.iType = -1;
					player.bSetOnSpawn = false;
				}
			}
		}
		player.bIsVehicle = player.bSetOnSpawn;
		if( player.bIsVehicle )
			player.ConvertToVehicle();
	}
	return Plugin_Continue;
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	//int client = GetClientOfUserId( event.GetInt("userid") );
	BaseVehicle player = BaseVehicle(event.GetInt("userid"), true);
	if( player and IsClientInGame(player.index) ) {
		if( player.bIsVehicle ) {
			int team = player.iTeam;
			int garage;
			switch( player.iType ) {
				case -1: {}
				case ArmoredCar, Ambulance: {
					// tele to support garage
					garage = manager.GetGarage(team, SUPPORTGARAGE);
				}
				case Tank, PanzerIII: {
					// tele to offensive
					garage = manager.GetGarage(team, OFFENSEGARAGE);
				}
				case KingPanzer, Destroyer: {
					// tele to heavy
					garage = manager.GetGarage(team, HEAVYGARAGE);
				}
			}
			if( garage != 0 ) {
				float vec_GarageLoc[3]; vec_GarageLoc = Vec_GetEntPropVector(garage, Prop_Data, "m_vecAbsOrigin");
				vec_GarageLoc[2] += 5.0;
				TeleportEntity(player.index, vec_GarageLoc, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	return Plugin_Continue;
}

public Action PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	BaseVehicle player = BaseVehicle(event.GetInt("userid"), true);
	BaseVehicle fighter = BaseVehicle(event.GetInt("attacker"), true);

	if( player.bIsVehicle ) { // if victim is a vehicle, kill him off and remove overlay
		if( player.bHasGunner ) {
			SDKHooks_TakeDamage(player.hGunner.index, event.GetInt("inflictor_entindex"), fighter.index, GetClientHealth(player.hGunner.index)+1.0, event.GetInt("damagebits"));
			//PrintToConsole
			player.RemoveGunner();
		}
		CreateTimer(0.1, Timer_VehicleDeath, player.userid);
		ManageVehicleDeath(player);
	}

	if( fighter.bIsVehicle and !player.bIsVehicle ) //if vehicle is killer and victim is not a vehicle, check if player was crushed
		ManageVehicleKillPlayer(fighter, player, event);

	//if (fighter.bIsVehicle and player.bIsVehicle) //clash of the titans - when both killer and victim are Vehicles

	return Plugin_Continue;
}

public Action PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if( !bEnabled.BoolValue )
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
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	BaseVehicle engie = BaseVehicle(event.GetInt("userid"), true);
	if (engie.Class == TFClass_Spy)
		return Plugin_Continue;

	return Plugin_Continue;
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
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
/*
void _SetOfficerModel(const int i)
{
	SetVariantString(OfficerModel);
	AcceptEntityInput(i, "SetCustomModel");
	SetEntProp(i, Prop_Send, "m_bUseClassAnimations", 1);
}
*/
public Action ObjectDeflected(Event event, const char[] name, bool dontBroadcast)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	//BaseVehicle airblaster = BaseVehicle( event.GetInt("userid"), true );
	BaseVehicle airblasted = BaseVehicle( event.GetInt("ownerid"), true );
	int weaponid = GetEventInt(event, "weaponid");
	if( weaponid )		// number lower or higher than 0 is considered "true", learned that in C programming lol
		return Plugin_Continue;

	if( airblasted.bIsVehicle ) {
		float Vel[3];
		TeleportEntity(airblasted.index, NULL_VECTOR, NULL_VECTOR, Vel); // Stops knockback
		TF2_RemoveCondition(airblasted.index, TFCond_Dazed); // Stops slowdown
		SetEntPropVector(airblasted.index, Prop_Send, "m_vecPunchAngle", Vel);
		SetEntPropVector(airblasted.index, Prop_Send, "m_vecPunchAngleVel", Vel); // Stops screen shake  
	}

	return Plugin_Continue;
}
