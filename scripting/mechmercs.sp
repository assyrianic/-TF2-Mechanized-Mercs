#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <tf2items>
#include <sdkhooks>
#include <morecolors>

#define UPDATE_URL		"https://raw.githubusercontent.com/assyrianic/-TF2-Mechanized-Mercs/master/updater.txt"

#undef REQUIRE_EXTENSIONS
#tryinclude <steamtools>
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN

#pragma semicolon		1
#pragma newdecls		required

#define PLUGIN_VERSION		"1.6.5"
#define CODEFRAMETIME		(1.0/30.0)	/* 30 frames per second means 0.03333 seconds pass each frame */

#define IsClientValid(%1)	( (%1) && (%1) <= MaxClients && IsClientInGame((%1)) )
#define PLYR			MAXPLAYERS+1

#define RESPAWNER

#define and			&&
#define or			||


public Plugin myinfo = {
	name 			= "Mechanized Mercs",
	author 			= "Nergal / Assyrian / Ashurian, Koishi, Chdata",
	description 		= "gameplay mod that utilizes vehicles with some RTS elements",
	version 		= PLUGIN_VERSION,
	url 			= "hue" //will fill later
};

//cvar handles
ConVar
	bEnabled = null,
	bGasPowered = null,

	AllowBlu = null,
	AllowRed = null,

	HealthFromMetal = null,
	HealthFromMetalMult = null,
	HealthFromEngies = null,
	CrushDmg = null,

	HUDX = null,
	HUDY = null,

	StartingFuel = null,
	AdminFlagByPass = null,
	bSelfDamage = null,
	AllowVehicleTele = null,
	AllowFreeClasses = null
;

enum {
	SupportBuildTime,
	OffensiveBuildTime,
	HeavySupportBuildTime,
	OnEngieHitBuildTime,
	OnOfficerHitBuildTime,
	ArmoredCarGunDmg,
	MaxSMGAmmo,
	MaxRocketAmmo,
	MaxGunnerAmmo,
	RocketSpeed,
	AdvertTime,
	ReplacePowerups,
	VehicleConstructHP,
	BuildSetUpTime,
	ConstructMetalAdd,
	AmbulanceMetal,
	ArmoredCarMetal,
	KingPanzerMetal,
	Marder3Metal,
	LitePanzerMetal,
	PanzerMetal,
	SupportHP,
	OffensiveHP,
	HeavySupportHP,
	AmbulanceHP,
	ArmoredCarHP,
	KingPanzerHP,
	Marder3HP,
	LightPanzerHP,
	Panzer4HP
};

ConVar MMCvars[Panzer4HP+1];

enum /*GamePlayStyles*/ {
	Normal = 0,
	GunGame = 1,
	Powerup = 2
};

Handle
	hHudText
;

char szCurrMap[100];

methodmap TF2Item < Handle {
	/* [*C*O*N*S*T*R*U*C*T*O*R*] */

	public TF2Item(int iFlags) {
		return view_as<TF2Item>( TF2Items_CreateItem(iFlags) );
	}
	/////////////////////////////// 

	/* [ P R O P E R T I E S ] */

	property int iFlags {
		public get()			{ return TF2Items_GetFlags(this); }
		public set( int iVal )		{ TF2Items_SetFlags(this, iVal); }
	}

	property int iItemIndex {
		public get()			{return TF2Items_GetItemIndex(this);}
		public set( int iVal )		{TF2Items_SetItemIndex(this, iVal);}
	}

	property int iQuality {
		public get()			{return TF2Items_GetQuality(this);}
		public set( int iVal )		{TF2Items_SetQuality(this, iVal);}
	}

	property int iLevel {
		public get()			{return TF2Items_GetLevel(this);}
		public set( int iVal )		{TF2Items_SetLevel(this, iVal);}
	}

	property int iNumAttribs {
		public get()			{return TF2Items_GetNumAttributes(this);}
		public set( int iVal )		{TF2Items_SetNumAttributes(this, iVal);}
	}
	///////////////////////////////

	/* [ M E T H O D S ] */

	public int GiveNamedItem(int iClient) {
		return TF2Items_GiveNamedItem(iClient, this);
	}

	public void SetClassname(char[] strClassName) {
		TF2Items_SetClassname(this, strClassName);
	}

	public void GetClassname(char[] strDest, int iDestSize) {
		TF2Items_GetClassname(this, strDest, iDestSize);
	}

	public void SetAttribute(int iSlotIndex, int iAttribDefIndex, float flValue) {
		TF2Items_SetAttribute(this, iSlotIndex, iAttribDefIndex, flValue);
	}

	public int GetAttribID(int iSlotIndex) {
		return TF2Items_GetAttributeId(this, iSlotIndex);
	}

	public float GetAttribValue(int iSlotIndex) {
		return TF2Items_GetAttributeValue(this, iSlotIndex);
	}
	/**************************************************************/
};

#include "modules/handler.sp"
#include "modules/gamemode.sp"
GameModeManager manager;

#include "modules/events.sp"

public void OnPluginStart()
{
	RegConsoleCmd("sm_garages",		SpawnVehicleGarageMenu);
	RegConsoleCmd("sm_garage",		SpawnVehicleGarageMenu);
	RegConsoleCmd("sm_bases",		SpawnVehicleGarageMenu);
	RegConsoleCmd("sm_base",		SpawnVehicleGarageMenu);
	RegConsoleCmd("sm_vehicle",		SpawnVehicleGarageMenu);
	RegConsoleCmd("sm_build",		SpawnVehicleGarageMenu);

	RegConsoleCmd("sm_mmclasshelp",		ClassInfoCmd);
	RegConsoleCmd("sm_mmclassinfo",		ClassInfoCmd);
	
	RegConsoleCmd("sm_mmhelp",		GameInfoCmd);
	RegConsoleCmd("sm_mminfo",		GameInfoCmd);

	RegAdminCmd("sm_forcevehicle",		ForcePlayerVehicle, ADMFLAG_KICK);
	RegAdminCmd("sm_reloadvehiclecfg",	CmdReloadCFG, ADMFLAG_GENERIC);

#if defined RESPAWNER
	RegAdminCmd("sm_spawnveh", ForcePlayerRespawn, ADMFLAG_ROOT);
#endif
	bEnabled = CreateConVar("mechmercs_enabled", "1", "Enable Player-Vehicles plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	
	bGasPowered = CreateConVar("mechmercs_gaspowered", "0", "Enable Vehicles to be powered via 'gas' which is replenishable by dispensers+mediguns", FCVAR_NONE, true, 0.0, true, 1.0);

	AllowBlu = CreateConVar("mechmercs_blu", "1", "(Dis)Allow Vehicles to be playable for BLU team", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	AllowRed = CreateConVar("mechmercs_red", "1", "(Dis)Allow Vehicles to be playable for RED team", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	HealthFromMetal = CreateConVar("mechmercs_healthfrommetal", "25", "how much metal to heal/arm Vehicles by Engineers", FCVAR_NONE, true, 0.0, true, 999.0);

	HealthFromMetalMult = CreateConVar("mechmercs_healthfrommetal_mult", "4", "how much metal to heal/arm Vehicles by Engineers mult", FCVAR_NONE, true, 0.0, true, 999.0);

	HealthFromEngies = CreateConVar("mechmercs_hpfromengies", "1", "(Dis)Allow Engies to be able to repair+arm Vehicles via wrench", FCVAR_NONE, true, 0.0, true, 1.0);

	bSelfDamage = CreateConVar("mechmercs_selfdamage", "0", "(Dis)Allow Vehicles to damage their health when they hurt themselves", FCVAR_NONE, true, 0.0, true, 1.0);

	CrushDmg = CreateConVar("mechmercs_crushdamage", "5.0", "Crush Damage (ignores uber) done by Vehicles while they're moving", FCVAR_NONE, true, 0.0, true, 9999.0);

	HUDX = CreateConVar("mechmercs_hudx", "1.0", "x coordinate for the Gas Meter HUD", FCVAR_NONE);

	HUDY = CreateConVar("mechmercs_hudy", "1.0", "y coordinate for the Gas Meter HUD", FCVAR_NONE);

	StartingFuel = CreateConVar("mechmercs_startingfuel", "200.0", "If Vehicles are gas powered, how much gas they will start with?", FCVAR_NONE, true, 0.0, true, 9999.0);

	AdminFlagByPass = CreateConVar("mechmercs_adminflag_bypass", "b", "what flag admins need to bypass the vehicle class limit", FCVAR_NONE);

	AllowVehicleTele = CreateConVar("mechmercs_allowtele", "1", "(Dis)allow vehicles to be able to use Engineer teleporters", FCVAR_NONE, true, 0.0, true, 1.0);
	
	AllowFreeClasses = CreateConVar("mechmercs_allowfreevehicles", "0", "(Dis)allow vehicles to be used without requiring each team to build Garages", FCVAR_NONE, true, 0.0, true, 1.0);
	
	MMCvars[SupportBuildTime] = CreateConVar("mechmercs_support_buildtime", "60.0", "how long it takes in seconds for the Support Garage to build unsupported.", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[OffensiveBuildTime] = CreateConVar("mechmercs_offensive_buildtime", "120.0", "how long it takes in seconds for the Offensive Garage to build unsupported.", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[HeavySupportBuildTime] = CreateConVar("mechmercs_heavysupport_buildtime", "240.0", "how long it takes in seconds for the Heavy Support Garage to build unsupported.", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[OnEngieHitBuildTime] = CreateConVar("mechmercs_engiehit_buildtime", "2.0", "when an engie wrench hits a Garage, how many seconds should it take off build time?", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[OnOfficerHitBuildTime] = CreateConVar("mechmercs_officerhit_buildtime", "1.0", "when an officer melees a Garage, how many seconds should it take off build time?", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[ArmoredCarGunDmg] = CreateConVar("mechmercs_armoredcar_cannondmg", "40.0", "how much damage the Armored Car's 20mm cannon deals.", FCVAR_NONE, true, 0.0, true, 99999.0);
	
	MMCvars[MaxSMGAmmo] = CreateConVar("mechmercs_sidearm_ammo", "1000", "how much ammo each vehicle's sidearm (SMG or other) gets.", FCVAR_NONE, true, 0.0, true, 99999.0);
	
	MMCvars[MaxRocketAmmo] = CreateConVar("mechmercs_maingun_ammo", "50", "how much ammo each vehicle's rocket turret gets.", FCVAR_NONE, true, 0.0, true, 99999.0);
	
	MMCvars[MaxGunnerAmmo] = CreateConVar("mechmercs_secgunner_ammo", "1000", "how much ammo each vehicle's secondary gunner gets.", FCVAR_NONE, true, 0.0, true, 99999.0);
	
	MMCvars[VehicleConstructHP] = CreateConVar("mechmercs_constructhp", "500", "how much max health vehicle constructs get", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[BuildSetUpTime] = CreateConVar("mechmercs_allowbuild_setup", "0", "allows engineers to build Garages or constructs during setup time", FCVAR_NONE, true, 0.0, true, 1.0);
	
	MMCvars[SupportHP] = CreateConVar("mechmercs_supporthp", "1000", "how much max health the Support Garages get", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[OffensiveHP] = CreateConVar("mechmercs_offensivehp", "1500", "how much max health the Offensive Garages get", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[HeavySupportHP] = CreateConVar("mechmercs_heavysupporthp", "2500", "how much max health the Heavy Support Garages get", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[AmbulanceHP] = CreateConVar("mechmercs_ambulancehp", "400", "how much max health the Ambulance vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[ArmoredCarHP] = CreateConVar("mechmercs_armoredcarhp", "600", "how much max health the Armored Car vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[KingPanzerHP] = CreateConVar("mechmercs_kingtigerhp", "2000", "how much max health the King Tiger Panzer vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[Marder3HP] = CreateConVar("mechmercs_marderhp", "500", "how much max health the Marder 3 vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[LightPanzerHP] = CreateConVar("mechmercs_lighttankhp", "750", "how much max health the Panzer 3 Light tank vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[Panzer4HP] = CreateConVar("mechmercs_panzer4hp", "1000", "how much max health the Panzer 4 tank vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[AmbulanceMetal] = CreateConVar("mechmercs_ambulancemetal", "800", "how much metal the Ambulance construct requires to use.", FCVAR_NONE, true, 0.0, true, 999999.0);
	MMCvars[ArmoredCarMetal] = CreateConVar("mechmercs_armoredcarmetal", "2000", "how much metal the Armored Car construct requires to use.", FCVAR_NONE, true, 0.0, true, 999999.0);
	MMCvars[KingPanzerMetal] = CreateConVar("mechmercs_kingtigermetal", "5000", "how much metal the King Tiger tank construct requires to use.", FCVAR_NONE, true, 0.0, true, 999999.0);
	MMCvars[Marder3Metal] = CreateConVar("mechmercs_marder2metal", "3000", "how much metal the Marder 2 AT vehicle construct requires to use.", FCVAR_NONE, true, 0.0, true, 999999.0);
	MMCvars[LitePanzerMetal] = CreateConVar("mechmercs_panzer2metal", "3000", "how much metal the Panzer 2 tank construct requires to use.", FCVAR_NONE, true, 0.0, true, 999999.0);
	MMCvars[PanzerMetal] = CreateConVar("mechmercs_panzer4metal", "4000", "how much metal the Panzer 4 tank construct requires to use.", FCVAR_NONE, true, 0.0, true, 999999.0);
	
	MMCvars[ConstructMetalAdd] = CreateConVar("mechmercs_construct_metaladd", "25", "how much metal each wrench hit adds to tank constructs.", FCVAR_NONE, true, 1.0, true, 999999.0);
	
	MMCvars[RocketSpeed] = CreateConVar("mechmercs_tankrocket_speed", "4000.0", "how fast the mouse2 rockets travel.", FCVAR_NONE, true, 1.0, true, 999999.0);
	
	MMCvars[AdvertTime] = CreateConVar("mechmercs_advert_time", "120.0", "how much time in seconds the advertisement will message.", FCVAR_NONE, true, 1.0, true, 999999.0);
	
	MMCvars[ReplacePowerups] = CreateConVar("mechmercs_replace_powerups", "1", "replaces mannpower powerups with ready-to-use tank constructs.", FCVAR_NONE, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "Mechanized-Mercenaries");
	
	hHudText = CreateHudSynchronizer();
	manager = GameModeManager();		// In gamemodemanager.sp
	
	HookEvent("player_death", PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", PlayerHurt, EventHookMode_Pre);
	//HookEvent("player_spawn", PlayerSpawn);
	HookEvent("post_inventory_application", Resupply);
	//HookEvent("player_changeclass", ChangeClass, EventHookMode_Pre);
	//HookEvent("player_builtobject", ObjectBuilt);
	HookEvent("player_upgradedobject", ObjectBuilt);
	//HookEvent("teamplay_round_start", RoundStart);
	HookEvent("teamplay_round_win", RoundEnd);
	HookEvent("object_deflected", ObjectDeflected);

	ManageDownloads();			// in handler.sp

	for( int i=MaxClients ; i ; --i ) {
		if( !IsValidClient(i) )
			continue;
		OnClientPutInServer(i);
	}
	hFields[0] = new StringMap();

#if defined _steamtools_included
	manager.bSteam = LibraryExists("SteamTools");
#endif
}

public void OnLibraryAdded(const char[] name)
{
#if defined _steamtools_included
	if( !strcmp(name, "SteamTools", false) )
		manager.bSteam = true;
#endif
#if defined _updater_included
	if( !strcmp(name, "updater") )
		Updater_AddPlugin(UPDATE_URL);
#endif
}
public void OnLibraryRemoved(const char[] name)
{
#if defined _steamtools_included
	if( !strcmp(name, "SteamTools", false) )
		manager.bSteam = false;
#endif
}

public void OnConfigsExecuted()
{
	if( bEnabled.BoolValue ) {
#if defined _steamtools_included
		if( manager.bSteam ) {
			char gameDesc[64];
			//Format(gameDesc, sizeof(gameDesc), "Mechanized Mercs (%s)", PLUGIN_VERSION);
			Steam_SetGameDescription(gameDesc);
		}
#endif
	}
}

//	UPDATER Stuff
public void OnAllPluginsLoaded() 
{
#if defined _updater_included
	if( LibraryExists("updater") )
		Updater_AddPlugin(UPDATE_URL);
#endif
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_TraceAttack, TraceAttack);
	SDKHook(client, SDKHook_Touch, OnTouch);
	SDKHook(client, SDKHook_PreThink, OnPreThink);
	
	if( hFields[client] )
		delete hFields[client];
	
	hFields[client] = new StringMap();
	// The backing fields are all from the StringMap
	BaseVehicle user = BaseVehicle(client);
	user.bIsVehicle = false;
	user.bSetOnSpawn = false;
	user.iType = -1;
	user.bIsGunner = false;
	user.iHealth = 0;
	user.bHonkedHorn=false;
	user.flGas=0.0;
	user.flSpeed=0.0;
	user.flSoundDelay=0.0;
	user.flIdleSound=0.0;
	user.bHasGunner = false;
	user.hGunner = view_as< BaseFighter >(0);
	ManageConnect(client);	// in handler.sp
}

public Action OnTouch(int client, int other)	// simulate "crush, roadkill" damage
{
	if( 0 < other <= MaxClients ) {
		BaseVehicle player = BaseVehicle(client), victim = BaseVehicle(other);

		// make sure noot to damage players just because enemies stand on them.
		if( player.bIsVehicle and !victim.bIsVehicle ) {
			ManageOnTouchPlayer(player, victim); // in handler.sp
		}
	}
	else if( other > MaxClients ) {	// damage buildings too. Teles aren't strong enough to lift enemy vehicles
		BaseVehicle player = BaseVehicle(client);
		if( IsValidEntity(other) and player.bIsVehicle ) {
			char ent[5];
			if( GetEntityClassname(other, ent, sizeof(ent)), StrContains(ent, "obj_") == 0 ) {
				if( GetEntProp(other, Prop_Send, "m_iTeamNum") != GetClientTeam(client) )
					ManageOnTouchBuilding(player, other); // in handler.sp
			}
		}
	}
	return Plugin_Continue;
}
stock void CheckDownload(const char[] dlpath)
{
	if( FileExists(dlpath) )
		AddFileToDownloadsTable(dlpath);
}

public void OnMapStart()
{
	ManageDownloads(); // in handler.sp
	CreateTimer(0.1, Timer_VehicleThink, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, Timer_GarageThink, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(5.0, MakeModelTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(MMCvars[AdvertTime].FloatValue, Timer_Announce, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	GetCurrentMap(szCurrMap, sizeof(szCurrMap));
	
	// Mann vs. Machine compatibility
	if( StrContains(szCurrMap, "mvm_") != -1 ) {
		AllowBlu.IntValue = 0;
		AllowRed.IntValue = 1;
		manager.bisMVM = true;
	}
	// mediocre VSH game mode compatibility
	else if( StrContains(szCurrMap, "vsh_") != -1 or StrContains(szCurrMap, "arena_") != -1 ) {
		AllowBlu.IntValue = 0;
		AllowRed.IntValue = 1;
		AllowFreeClasses.BoolValue = true;
		manager.bisVSH = true;
	}
}
public Action Timer_Announce(Handle timer)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	CPrintToChatAll("{red}[Mechanized Mercs] {default}For Gameplay Help and Information, type '{green}!mmhelp{default}' or '{green}!mminfo{default}'; for Class help, type '{green}!mmclasshelp{default}' or '{green}!mmclassinfo{default}'.");
	
	CPrintToChatAll("{red}[Mechanized Mercs]{default} created by {green}Nergal the Ashurian{default} AKA {green}Assyrian{default} or {green}Nergal{default}. Join the Mechanized Mercs Steam Group @ {green}'http://steamcommunity.com/groups/mechmercs'{default}.");
	return Plugin_Continue;
}

public Action Timer_MakePlayerVehicle(Handle timer, any userid)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	int client = GetClientOfUserId(userid);
	if( client and IsClientInGame(client) ) {
		BaseVehicle player = BaseVehicle(client);
		ManageHealth(player);			// in handler.sp
		ManageVehicleTransition(player);	// in handler.sp
		//SetEntPropEnt(player.index, Prop_Send, "m_hVehicle", player.index);
		if( bGasPowered.BoolValue )
			player.flGas = StartingFuel.FloatValue;
		
		//SetVariantString("1");
		//AcceptEntityInput(client, "SetForcedTauntCam");
	}
	return Plugin_Continue;
}

public Action Timer_VehicleDeath(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if( IsValidClient(client, false) ) {
		BaseVehicle player = BaseVehicle(client);
		if( player.iHealth <= 0 )
			player.iHealth = 0; // ded, k!big soup rice
		ManageVehicleDeath(player); // in handler.sp Powerup
	}
	return Plugin_Continue;
}
public Action MakeModelTimer(Handle hTimer)
{
	BaseVehicle player;
	for( int client=MaxClients ; client ; --client ) {
		if( !IsValidClient(client, false) )
			continue;

		player = BaseVehicle(client);
		if( player.bIsVehicle ) {
			if( !IsPlayerAlive(client) )
				continue;
			ManageVehicleModels(player); // in handler.sp
		}
	}
	return Plugin_Continue;
}

public Action Timer_VehicleThink(Handle hTimer) //the main 'mechanics' of vehicles
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;
	
	BaseVehicle player;
	for( int i=MaxClients ; i ; --i ) {
		if( !IsValidClient(i, false) )
			continue;
		else if( !IsPlayerAlive(i) )
			continue;

		player = BaseVehicle(i);
		if( player.bIsVehicle ) {
			ManageVehicleThink(player); // in handler.sp
			SetEntityHealth(i, player.iHealth);
			if( !(GetClientButtons(i) & IN_SCORE) ) {
				SetHudTextParams(0.93, 0.80, 0.1, 0, 255, 255, 255);
				if( player.iType==ArmoredCar )
					ShowSyncHudText(player.index, hHudText, "Cannon: %i | Rockets: %i | Gas: %i", ToCArmCar(player).iCannonClipsize, ToCArmCar(player).iRockets, ( bGasPowered.BoolValue ) ? RoundFloat( player.flGas ) : 999);
				else if( player.iType==Tank or player.iType==PanzerIII or player.iType==KingPanzer )
					ShowSyncHudText(player.index, hHudText, "Rockets: %i | Gas: %i", ToCTank(player).iRockets, ( bGasPowered.BoolValue ) ? RoundFloat( player.flGas ) : 999);
			}
		}
	}
	return Plugin_Continue;
}

/*
float lastFrameTime = 0.0;
public void OnGameFrame()
{
	if( !bEnabled.BoolValue )
		return;

	float curtime = GetGameTime();
	float deltatime = curtime - lastFrameTime;
	if( deltatime > CODEFRAMETIME ) {
		BaseVehicle player;
		for( int i=MaxClients ; i ; --i ) {
			if( !IsValidClient(i, false) )
				continue;
			else if( !IsPlayerAlive(i) or IsClientObserver(i) )
				continue;

			player = BaseVehicle(i);
			if( player.bIsVehicle ) {
				ManageVehicleThink(player); // in handler.sp
				SetEntProp(player.index, Prop_Send, "m_iHealth", player.iHealth);
			}
		}
		lastFrameTime = curtime;
	}
}
*/

public bool IsImmune(const int client)
{
	if( !IsValidClient(client, false) )
		return false;
	
	char sFlags[32]; AdminFlagByPass.GetString(sFlags, sizeof(sFlags));
	// If flags are specified and client has generic or root flag, client is immune
	return ( !StrEqual(sFlags, "") and (GetUserFlagBits(client) & (ReadFlagString(sFlags)|ADMFLAG_ROOT)) );
}

public Action ClassInfoCmd (int client, int args)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;
		
	else if( IsClientObserver(client) or !IsPlayerAlive(client) )
		return Plugin_Handled;

	BaseFighter(client).HelpPanel();
	return Plugin_Handled;
}

public Action GameInfoCmd(int client, int args)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;
	
	else if( IsVoteInProgress() )
		return Plugin_Handled;

	Panel panel = new Panel();
	char helpstr[] = "Welcome to Mechanized Mercs, TF2's Combat Vehicles Mod!\n\nMechanized Mercs is a gameplay mod that adds combat vehicles to the game.\nThe Available Vehicles: the Armored Car, Ambulance, Panzer II, Panzer IV, Tiger II, and Marder 2 Tank Hunter\nEngineers can build Garages using !base to unlock the Vehicle classes. When Garages are built, any class can build vehicles.\nTo build vehicles, use !base near any of the garages, you must be near the garages to build vehicles.\nVehicles require building, hit with any melee them to build!";
	panel.SetTitle(helpstr);
	panel.DrawItem( "Exit" );
	panel.Send(client, HintPanel, 99);
	delete ( panel );
	
	return Plugin_Handled;
}

public Action SpawnVehicleGarageMenu (int client, int args)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	else if( IsClientObserver(client) or !IsPlayerAlive(client) ) {
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}You Need to be Alive to become Vehicles, build Vehicles, or build Vehicle Garages.");
		return Plugin_Handled;
	}
	else if( !MMCvars[BuildSetUpTime].BoolValue and (GameRules_GetRoundState() == RoundState_Preround or GameRules_GetProp("m_bInSetup")) ) {
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build Vehicles or Vehicle Garages yet...");
		return Plugin_Handled;
	}
	int team = GetClientTeam(client);
	bool free = AllowFreeClasses.BoolValue;
	if( BaseFighter(client).Class == TFClass_Engineer ) {
		Menu bases = new Menu( MenuHandler_BuildGarage );
		
		if( !(GarageFlags[team-2] & SUPPORTBUILT) and !free )
			bases.AddItem("2", "Support Vehicle Garage: Unlocks the Scout Car and Ambulance vehicles");
		else {
			bases.AddItem("11", "Armored Car: Machinegun & 20mm Cannon");
			bases.AddItem("12", "Ambulance: Self Defense Machinegun");
		}
		if( !(GarageFlags[team-2] & OFFENSIVEBUILT) and !free )
			bases.AddItem("4", "Offensive Vehicle Garage: Unlocks the Panzer II and Panzer IV vehicles");
		else {
			bases.AddItem("13", "Panzer 2: Machinegun & Arcing, HE Rockets");
			bases.AddItem("10", "Panzer 4: Machinegun & Rockets");
		}
		if( !(GarageFlags[team-2] & HEAVYBUILT) and !free )
			bases.AddItem("8", "Heavy Support Vehicle Garage: Unlocks the King Panzer and Tank Destroyer vehicles");
		else {
			bases.AddItem("14", "Tiger 2 King Panzer: Machinegun, Rockets, Lotsa Health");
			bases.AddItem("15", "Marder 2 AT: Armor Piercing Rockets");
		}
		bases.Display(client, MENU_TIME_FOREVER);
	}
	else {
		Menu bases = new Menu( MenuHandler_BuildGarage );
		if( (GarageFlags[team-2] & SUPPORTBUILT) or free ) {
			bases.AddItem("11", "Armored Car: Machinegun & 20mm Cannon");
			bases.AddItem("12", "Ambulance: Self Defense Machinegun");
		}
		if( (GarageFlags[team-2] & OFFENSIVEBUILT) or free ) {
			bases.AddItem("13", "Panzer 2: Machinegun & Arcing, HE Rockets");
			bases.AddItem("10", "Panzer 4: Machinegun & Rockets");
		}
		if( (GarageFlags[team-2] & HEAVYBUILT) or free ) {
			bases.AddItem("14", "Tiger 2 King Panzer: Machinegun, Rockets, Lotsa Health");
			bases.AddItem("15", "Marder 2 AT: Armor Piercing Rockets");
		}
		bases.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}
public int MenuHandler_GoTank(Menu menu, MenuAction action, int client, int select)
{
	if( IsClientObserver(client) )
		return;
	
	char info1[16]; menu.GetItem(select, info1, sizeof(info1));
	if( action == MenuAction_Select ) {
		BaseVehicle player = BaseVehicle(client);
		player.iType = StringToInt(info1);
	}
	else if( action == MenuAction_End )
		delete menu;
}
public bool TraceFilterIgnorePlayers(int entity, int contentsMask, any client)
{
	return( !(entity and entity <= MaxClients) );
}
public int MenuHandler_MakeTankPowUp(Menu menu, MenuAction action, int client, int select)
{
	if( !IsValidClient(client) )
		return;
	else if( IsClientObserver(client) or !IsPlayerAlive(client) )
		return;
	
	else if( manager.IsPowerupFull(GetClientTeam(client)) ) {
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}Your team has too many built vehicles!");
		return;
	}
	else if( BaseVehicle(client).bIsVehicle ) {
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build Vehicles as a Vehicle!");
		return;
	}
	
	char info1[16]; menu.GetItem(select, info1, sizeof(info1));
	if( action == MenuAction_Select ) {
		//BaseVehicle player = BaseVehicle(client);
		int construct = CreateEntityByName("prop_dynamic_override");
		if( construct <= 0 or !IsValidEdict(construct) )
			return ;
			
		int vehicletype = StringToInt(info1);
		int team = GetClientTeam(client);
		
		char tName[32]; tName[0] = '\0';
		char szModelPath[PLATFORM_MAX_PATH];
		
		float flEyePos[3], flAng[3];
		GetClientEyePosition(client, flEyePos);
		GetClientEyeAngles(client, flAng);

		int metal;
		switch( vehicletype ) {
			case Tank: {
				szModelPath = TankModel;
				Format(tName, sizeof(tName), "mechmercs_construct_panzer4%i", GetRandomInt(0, 9999999));
				metal = MMCvars[PanzerMetal].IntValue;
			}
			case ArmoredCar: {
				szModelPath = ArmCarModel;
				Format(tName, sizeof(tName), "mechmercs_construct_armoredcar%i", GetRandomInt(0, 9999999));
				metal = MMCvars[ArmoredCarMetal].IntValue;
			}
			case Ambulance: {
				szModelPath = AmbModel;
				Format(tName, sizeof(tName), "mechmercs_construct_ambulance%i", GetRandomInt(0, 9999999));
				metal = MMCvars[AmbulanceMetal].IntValue;
			}
			case PanzerIII: {
				szModelPath = LightTankModel;
				Format(tName, sizeof(tName), "mechmercs_construct_lighttank%i", GetRandomInt(0, 9999999));
				metal = MMCvars[LitePanzerMetal].IntValue;
			}
			case KingPanzer: {
				szModelPath = KingTankModel;
				Format(tName, sizeof(tName), "mechmercs_construct_tiger%i", GetRandomInt(0, 9999999));
				metal = MMCvars[KingPanzerMetal].IntValue;
			}
			case Destroyer: {
				szModelPath = DestroyerModel;
				Format(tName, sizeof(tName), "mechmercs_construct_marder%i", GetRandomInt(0, 9999999));
				metal = MMCvars[Marder3Metal].IntValue;
			}
		}
		
		DispatchKeyValue(construct, "targetname", tName);
		SetEntProp( construct, Prop_Send, "m_iTeamNum", team );
		char szskin[32]; Format(szskin, sizeof(szskin), "%d", team-2);
		DispatchKeyValue(construct, "skin", szskin);
		
		SetEntityModel(construct, szModelPath);
		SetEntPropFloat(construct, Prop_Send, "m_flModelScale", 1.25);
		
		float mins[3], maxs[3];
		mins = Vec_GetEntPropVector(construct, Prop_Send, "m_vecMins");
		maxs = Vec_GetEntPropVector(construct, Prop_Send, "m_vecMaxs");
		
		float flEndPos[3];
		if( IsPlacementPosValid(client, mins, maxs, flEndPos) ) {
			//float flEndPos[3]; TR_GetEndPosition(flEndPos);
			{
				float spawnPos[3];
				int iEnt = -1;
				while( (iEnt = FindEntityByClassname(iEnt, "info_player_teamspawn")) != -1 ) {
					if( GetEntProp(iEnt, Prop_Send, "m_iTeamNum") != team )
						continue;

					spawnPos = Vec_GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin");
					if( GetVectorDistance(flEndPos, spawnPos) <= 650.0 ) {
						CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Vehicle near Spawn!");
						SpawnVehicleGarageMenu(client, -1);
						return;
					}
				}
				if( TR_PointOutsideWorld(flEndPos) ) {
					CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Vehicle outside the Playable Area!");
					SpawnVehicleGarageMenu(client, -1);
					return;
				}
			}
			DispatchSpawn(construct);
			SetEntProp( construct, Prop_Send, "m_nSolidType", 6 );
			TeleportEntity(construct, flEndPos, NULL_VECTOR, NULL_VECTOR);

			int beamcolor[4] = {0, 255, 90, 255};

			float vecMins[3], vecMaxs[3];
			vecMins = Vec_AddVectors(flEndPos, mins); //AddVectors(flEndPos, mins, vecMins);
			vecMaxs = Vec_AddVectors(flEndPos, maxs); //AddVectors(flEndPos, maxs, vecMaxs);

			int laser = PrecacheModel("sprites/laser.vmt", true);
			TE_SendBeamBoxToAll( vecMaxs, vecMins, laser, laser, 1, 1, 5.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );

			SetEntProp(construct, Prop_Data, "m_takedamage", 2, 1);
			SDKHook(construct, SDKHook_OnTakeDamage,	OnConstructTakeDamage);
			SDKHook(construct, SDKHook_Touch,		OnConstructTouch);
			
			SetEntProp(construct, Prop_Data, "m_iHealth", MMCvars[VehicleConstructHP].IntValue);
			if( IsValidEntity(construct) and IsValidEdict(construct) ) {
				int index = manager.GetNextEmptyPowerUpSlot(team);
				if (index == -1) {
					CPrintToChat(client, "{red}[Mechanized Mercs] {white}SpawnTankConstruct::Logic Error.");
					CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(construct) );
					return;
				}
				TankConstruct[team-2][index][ENTREF] = EntIndexToEntRef(construct);
				TankConstruct[team-2][index][VEHTYPE] = vehicletype;
				TankConstruct[team-2][index][BUILDER] = GetClientUserId(client);
				TankConstruct[team-2][index][METAL] = 0;
				TankConstruct[team-2][index][AMMO] = 0;
				TankConstruct[team-2][index][HEALTH] = 0;
				//TankConstruct[team-2][index][PLYRHP] = 0;
				TankConstruct[team-2][index][MAXMETAL] = metal;
			}
		}
		else {
			CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build that Vehicle there.");
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(construct) );
			SpawnVehicleGarageMenu(client, -1);
		}
	}
	else if( action == MenuAction_End )
		delete menu;
}

public Action OnConstructTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if( !IsValidClient(attacker) )
		return Plugin_Continue;
	
	int team = GetClientTeam(attacker);
	if( team == GetEntProp(victim, Prop_Data, "m_iTeamNum") ) {
		damage = 0.0;
		
		char tName[64]; GetEntPropString(victim, Prop_Data, "m_iName", tName, sizeof(tName));
		char classname[64];
		
		if( IsValidEdict(weapon) )
			GetEdictClassname(weapon, classname, sizeof(classname));
		
		int index = manager.FindEntityPowerUpIndex(team, victim);
		if( index == -1 ) {
			//CPrintToChat(attacker, "{red}[Mechanized Mercs] {white}OnConstructTakeDamage::Logic Error.");
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(victim) );
			return Plugin_Continue;
		}
		
		if( !strcmp(classname, "tf_weapon_wrench", false) or !strcmp(classname, "tf_weapon_robot_arm", false) ) {
			int iCurrentMetal = GetEntProp(attacker, Prop_Data, "m_iAmmo", 4, 3);
			int FixAdd = MMCvars[ConstructMetalAdd].IntValue;
			if( iCurrentMetal > 0 and TankConstruct[team-2][index][METAL] < TankConstruct[team-2][index][MAXMETAL] ) {
				if( iCurrentMetal < FixAdd )
					FixAdd = iCurrentMetal;
				
				TankConstruct[team-2][index][METAL] += FixAdd;	// Takes 7 seconds with Jag to put in 200 metal
				SetEntProp(attacker, Prop_Data, "m_iAmmo", iCurrentMetal-FixAdd, 4, 3);
				if( FixAdd > 0 )
					EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
			}
			// if the engie has no metal, fall back to universal metal speed of half.
			else if( iCurrentMetal == 0 and TankConstruct[team-2][index][METAL] < TankConstruct[team-2][index][MAXMETAL] ) {
				TankConstruct[team-2][index][METAL] += FixAdd >> 1;
				EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
			}
			else EmitSoundToClient(attacker, "weapons/wrench_hit_build_fail.wav");
		}
		else if( weapon == GetPlayerWeaponSlot(attacker, 2) and (damagetype & DMG_CLUB) ) {
			int FixAdd = MMCvars[ConstructMetalAdd].IntValue;
			if( TankConstruct[team-2][index][METAL] < TankConstruct[team-2][index][MAXMETAL] ) {
				TankConstruct[team-2][index][METAL] += FixAdd >> 1;	// Takes 7 seconds with Jag to put in 200 metal
				EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
			}
			else EmitSoundToClient(attacker, "weapons/wrench_hit_build_fail.wav");
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
public Action OnConstructTouch(int item, int other)
{
	if( 0 < other <= MaxClients ) {
		if( IsBlueBlocked(other) or IsRedBlocked(other) )
			return Plugin_Continue;
		
		int team;
		int index = manager.FindEntityPowerUpIndex(3, item);
		if( index == -1 ) {
			index = manager.FindEntityPowerUpIndex(2, item);
			if( index == -1 ) {
				//CPrintToChat(other, "{red}[Mechanized Mercs] {white}OnConstructTouch::Logic Error.");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(item) );
				return Plugin_Continue;
			}
			else team = 2;
		}
		else team = 3;

		if( !BaseVehicle(other).bIsVehicle and TankConstruct[team-2][index][METAL] >= TankConstruct[team-2][index][MAXMETAL] ) {
			SetHudTextParams(0.93, -1.0, 0.1, 0, 255, 0, 255);
			ShowHudText(other, -1, "Press RELOAD to Enter the Vehicle! JUMP to Exit Vehicle");
			if( GetClientButtons(other) & IN_RELOAD ) {
				if( GetClientTeam(other)==team )
					TankConstruct[team-2][index][PLYRHP] = GetClientHealth(other);
				BaseVehicle toucher = BaseVehicle(other);
				toucher.iType = TankConstruct[team-2][index][VEHTYPE];
				toucher.bIsVehicle = true;
				toucher.ConvertToVehicle();
				toucher.VehHelpPanel();
				SetPawnTimer(SetConstructAttribs, 0.1, toucher, team, index);
				float VehLoc[3]; VehLoc = Vec_GetEntPropVector(item, Prop_Data, "m_vecAbsOrigin");
				TeleportEntity(other, VehLoc, NULL_VECTOR, NULL_VECTOR);
				
				CreateTimer( 0.1, RemoveEnt, TankConstruct[team-2][index][ENTREF] );
				TankConstruct[team-2][index][ENTREF] = 0;
			}
		}
	}
	return Plugin_Continue;
}

public void SetConstructAttribs(const BaseVehicle veh, const int team, const int index)
{
	int Turret = GetEntPropEnt(veh.index, Prop_Send, "m_hActiveWeapon");
	if( TankConstruct[team-2][index][AMMO] > 0 )
		SetWeaponClip(Turret, TankConstruct[team-2][index][AMMO]);

	if( TankConstruct[team-2][index][HEALTH] > 0 )
		veh.iHealth = TankConstruct[team-2][index][HEALTH];
	
	switch( veh.iType ) {
		case Tank, ArmoredCar, KingPanzer, PanzerIII:
			ToCTank(veh).iRockets = TankConstruct[team-2][index][ROCKETS];
	}
	if( bGasPowered.BoolValue )
		veh.flGas = 0.0 + TankConstruct[team-2][index][GASLEFT];
}

public int MenuHandler_BuildGarage(Menu menu, MenuAction action, int client, int select)
{
	if( client <= 0 )
		return;
	else if( IsClientObserver(client) or !IsPlayerAlive(client) or GetClientTeam(client) < 2 )
		return;
	
	char info1[16]; menu.GetItem(select, info1, sizeof(info1));
	int buildId = StringToInt(info1);
	if( action == MenuAction_Select ) {
		if( buildId < 10 ) {
			if( GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3) < 200 ) {
				CPrintToChat(client, "{red}[Mechanized Mercs] {white}You need 200 Metal to build a Garage.");
				SpawnVehicleGarageMenu(client, -1);
				return;
			}
			int garageflag = buildId;
			int team = GetClientTeam(client);
			int offset = FlagtoOffset(garageflag);	// in gamemodemanager.sp

			if( GarageRefs[team-2][offset] and IsValidEntity(EntRefToEntIndex(GarageRefs[team-2][offset])) ) {
				CPrintToChat(client, "{red}[Mechanized Mercs] {white}The Garage you've selected has already been built.");
				SpawnVehicleGarageMenu(client, -1);
				return;
			}

			float flEyePos[3], flAng[3];
			GetClientEyePosition(client, flEyePos);
			GetClientEyeAngles(client, flAng);
			/*
			TR_TraceRayFilter( flEyePos, flAng, MASK_PLAYERSOLID, RayType_Infinite, TraceFilterIgnorePlayers, client );

			if( TR_GetFraction() < 1.0 ) {
				float flEndPos[3]; TR_GetEndPosition(flEndPos);
			*/
			GetClientAbsAngles(client, flAng); //flAng[1] += 90.0;

			int pStruct = CreateEntityByName("prop_dynamic_override");
			if( pStruct <= 0 or !IsValidEdict(pStruct) )
				return;
		
			char tName[32]; tName[0] = '\0';
			
			char szModelPath[PLATFORM_MAX_PATH];
			switch( garageflag ) {
				case SUPPORTBUILT: {
					szModelPath = "models/structures/combine/barracks.mdl";
					Format(tName, sizeof(tName), "mechmercs_garage_support%i", GetRandomInt(0, 9999999));
				}
				case OFFENSIVEBUILT: {
					szModelPath = "models/structures/combine/armory.mdl";
					Format(tName, sizeof(tName), "mechmercs_garage_offense%i", GetRandomInt(0, 9999999));
				}
				case HEAVYBUILT: {
					szModelPath = "models/structures/combine/synthfac.mdl";
					Format(tName, sizeof(tName), "mechmercs_garage_heavy%i", GetRandomInt(0, 9999999));
				}
			}
			DispatchKeyValue(pStruct, "targetname", tName);
			SetEntProp( pStruct, Prop_Send, "m_iTeamNum", team );
			//SetEntPropEnt( pStruct, Prop_Send, "m_hOwnerEntity", client );

			PrecacheModel(szModelPath, true);
			SetEntityModel(pStruct, szModelPath);
			//SetEntPropFloat(pStruct, Prop_Send, "m_flModelScale", 0.5);

			float mins[3], maxs[3];
			mins = Vec_GetEntPropVector(pStruct, Prop_Send, "m_vecMins");
			maxs = Vec_GetEntPropVector(pStruct, Prop_Send, "m_vecMaxs");

			//if ( CanBuildHere(flEndPos, mins, maxs) ) {
			float flEndPos[3];
			if( IsPlacementPosValid(client, mins, maxs, flEndPos) ) {
				if( TR_PointOutsideWorld(flEndPos) ) {
					CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Garage outside the Playable Area!");
					SpawnVehicleGarageMenu(client, -1);
					CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(pStruct) );
					return;
				}
				
				{
					float spawnPos[3];
					int iEnt = -1;
					while( (iEnt = FindEntityByClassname(iEnt, "info_player_teamspawn")) != -1 ) {
						if( GetEntProp(iEnt, Prop_Send, "m_iTeamNum") != team )
							continue;

						spawnPos = Vec_GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin");
						if( GetVectorDistance(flEndPos, spawnPos) <= 650.0 ) {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Garage near Spawn!");
							SpawnVehicleGarageMenu(client, -1);
							CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(pStruct) );
							return;
						}
					}
				}
				DispatchSpawn(pStruct);
				SetEntProp( pStruct, Prop_Send, "m_nSolidType", 6 );
				GetClientAbsAngles(client, flAng);	// set the building straight up
				TeleportEntity(pStruct, flEndPos, flAng, NULL_VECTOR);
				
				int beamcolor[4] = {0, 255, 90, 255};
				float vecMins[3], vecMaxs[3];
				
				vecMins = Vec_AddVectors(flEndPos, mins); //AddVectors(flEndPos, mins, vecMins);
				vecMaxs = Vec_AddVectors(flEndPos, maxs); //AddVectors(flEndPos, maxs, vecMaxs);
				
				int laser = PrecacheModel("sprites/laser.vmt", true);
				TE_SendBeamBoxToAll( vecMaxs, vecMins, laser, laser, 1, 1, 5.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );
				
				SetEntProp(pStruct, Prop_Data, "m_takedamage", 2, 1);
				SDKHook(pStruct, SDKHook_OnTakeDamage, OnGarageTakeDamage);
				//SDKHook(pStruct, SDKHook_ShouldCollide, OnGarageCollide);
				int _collision_projectile_flag = 13;
				//int _collision_weapon_flag = 11;
				SetEntProp(pStruct, Prop_Data, "m_CollisionGroup", _collision_projectile_flag);
				SetEntProp(pStruct, Prop_Send, "m_CollisionGroup", _collision_projectile_flag);
			
				int iGlow = CreateEntityByName("tf_taunt_prop");
				if( iGlow != -1 ) {
					GarageGlowRefs[team-2][offset] = EntIndexToEntRef(iGlow);
					SetEntityModel(iGlow, szModelPath);
					SetEntProp( iGlow, Prop_Send, "m_iTeamNum", team );

					DispatchSpawn(iGlow);
					ActivateEntity(iGlow);
					SetEntityRenderMode(iGlow, RENDER_TRANSCOLOR);
					SetEntityRenderColor(iGlow, 0, 0, 0, 0);
					SetEntProp(iGlow, Prop_Send, "m_bGlowEnabled", 1);
					float flModelScale = GetEntPropFloat(pStruct, Prop_Send, "m_flModelScale");
					SetEntPropFloat(iGlow, Prop_Send, "m_flModelScale", flModelScale);

					int iFlags = GetEntProp(iGlow, Prop_Send, "m_fEffects");
					SetEntProp(iGlow, Prop_Send, "m_fEffects", iFlags|(1 << 0));

					SetVariantString("!activator");
					AcceptEntityInput(iGlow, "SetParent", pStruct);

					SDKHook(iGlow, SDKHook_SetTransmit, OnEffectTransmit);
				}

				SetEntProp(pStruct, Prop_Data, "m_iHealth", 500);
				SetEntityRenderMode(pStruct, RENDER_TRANSCOLOR);
			
				switch( team ) {
					case 2:	SetEntityRenderColor(pStruct, 255, 30, 30, 255);	// RED
					case 3:	SetEntityRenderColor(pStruct, 30, 150, 255, 255);	// BLU
				}

				if( IsValidEntity(pStruct) and IsValidEdict(pStruct) ) {
					int baseid = EntIndexToEntRef(pStruct);
					switch( garageflag ) {
						case SUPPORTBUILT:	GarageBuildTime[team-2][offset] = MMCvars[SupportBuildTime].FloatValue;
						case OFFENSIVEBUILT:	GarageBuildTime[team-2][offset] = MMCvars[OffensiveBuildTime].FloatValue;
						case HEAVYBUILT:	GarageBuildTime[team-2][offset] = MMCvars[HeavySupportBuildTime].FloatValue;
					}
					GarageRefs[team-2][offset] = baseid;
					for( int i=MaxClients ; i ; --i ) {
						if( !IsValidClient(i) )
							continue;
						else if( GetClientTeam(i) != team )
							continue;

						switch( garageflag ) {
							case SUPPORTBUILT:	CPrintToChat(i, "{red}[Mechanized Mercs] {white}Support Garage Built, Will activate in 1 Minute.");
							case OFFENSIVEBUILT:	CPrintToChat(i, "{red}[Mechanized Mercs] {white}Offense Garage Built, Will activate in 2 Minutes.");
							case HEAVYBUILT:	CPrintToChat(i, "{red}[Mechanized Mercs] {white}Heavy Support Garage Built, Will activate in 4 Minutes");
						}
					}
					SetEntProp(client, Prop_Data, "m_iAmmo", 0, 4, 3);
				}
			}
			else {
				CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build that Vehicle Garage there.");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(pStruct) );
				SpawnVehicleGarageMenu(client, -1);
			}
		}
		else {
			if( manager.IsPowerupFull(GetClientTeam(client)) ) {
				CPrintToChat(client, "{red}[Mechanized Mercs] {white}Your team has too many built vehicles!");
				return;
			}
			else if( BaseVehicle(client).bIsVehicle ) {
				CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build Vehicles as a Vehicle!");
				return;
			}
			int construct = CreateEntityByName("prop_dynamic_override");
			if( construct <= 0 or !IsValidEdict(construct) )
				return ;
			
			int vehicletype = buildId - 10;
			int team = GetClientTeam(client);
		
			char tName[32]; tName[0] = '\0';
			char szModelPath[PLATFORM_MAX_PATH];
		
			float flEyePos[3], flAng[3];
			GetClientEyePosition(client, flEyePos);
			GetClientEyeAngles(client, flAng);
			
			int metal;
			int garage;
			switch( vehicletype ) {
				case Tank: {
					szModelPath = TankModel;
					Format(tName, sizeof(tName), "mechmercs_construct_panzer4%i", GetRandomInt(0, 9999999));
					metal = MMCvars[PanzerMetal].IntValue;
					garage = manager.GetGarage(team-2, OFFENSEGARAGE);
				}
				case ArmoredCar: {
					szModelPath = ArmCarModel;
					Format(tName, sizeof(tName), "mechmercs_construct_armoredcar%i", GetRandomInt(0, 9999999));
					metal = MMCvars[ArmoredCarMetal].IntValue;
					garage = manager.GetGarage(team-2, SUPPORTGARAGE);
				}
				case Ambulance: {
					szModelPath = AmbModel;
					Format(tName, sizeof(tName), "mechmercs_construct_ambulance%i", GetRandomInt(0, 9999999));
					metal = MMCvars[AmbulanceMetal].IntValue;
					garage = manager.GetGarage(team-2, SUPPORTGARAGE);
				}
				case PanzerIII: {
					szModelPath = LightTankModel;
					Format(tName, sizeof(tName), "mechmercs_construct_lighttank%i", GetRandomInt(0, 9999999));
					metal = MMCvars[LitePanzerMetal].IntValue;
					garage = manager.GetGarage(team-2, OFFENSEGARAGE);
				}
				case KingPanzer: {
					szModelPath = KingTankModel;
					Format(tName, sizeof(tName), "mechmercs_construct_tiger%i", GetRandomInt(0, 9999999));
					metal = MMCvars[KingPanzerMetal].IntValue;
					garage = manager.GetGarage(team-2, HEAVYGARAGE);
				}
				case Destroyer: {
					szModelPath = DestroyerModel;
					Format(tName, sizeof(tName), "mechmercs_construct_marder%i", GetRandomInt(0, 9999999));
					metal = MMCvars[Marder3Metal].IntValue;
					garage = manager.GetGarage(team-2, HEAVYGARAGE);
				}
			}
			
			DispatchKeyValue(construct, "targetname", tName);
			SetEntProp( construct, Prop_Send, "m_iTeamNum", team );
			char szskin[32]; Format(szskin, sizeof(szskin), "%d", team-2);
			DispatchKeyValue(construct, "skin", szskin);
			
			SetEntityModel(construct, szModelPath);
			SetEntPropFloat(construct, Prop_Send, "m_flModelScale", 1.25);
			
			float mins[3], maxs[3];
			mins = Vec_GetEntPropVector(construct, Prop_Send, "m_vecMins");
			maxs = Vec_GetEntPropVector(construct, Prop_Send, "m_vecMaxs");
			
			float flEndPos[3];
			if( IsPlacementPosValid(client, mins, maxs, flEndPos) ) {
				//float flEndPos[3]; TR_GetEndPosition(flEndPos);
				{
					float spawnPos[3], garagePos[3];
					int iEnt = -1;
					while( (iEnt = FindEntityByClassname(iEnt, "info_player_teamspawn")) != -1 ) {
						if( GetEntProp(iEnt, Prop_Send, "m_iTeamNum") != team )
							continue;

						spawnPos = Vec_GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin");
						if( GetVectorDistance(flEndPos, spawnPos) <= 650.0 ) {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Vehicle near Spawn!");
							SpawnVehicleGarageMenu(client, -1);
							CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(construct) );
							return;
						}
					}
					if( TR_PointOutsideWorld(flEndPos) ) {
						CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Vehicle outside the Playable Area!");
						SpawnVehicleGarageMenu(client, -1);
						CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(construct) );
						return;
					}
					if( garage != 0 ) {
						garagePos = Vec_GetEntPropVector(garage, Prop_Send, "m_vecOrigin");
						if( GetVectorDistance(flEndPos, garagePos) > 400.0 ) {
							CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can only build a vehicle near its appropriate garage!");
							SpawnVehicleGarageMenu(client, -1);
							CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(construct) );
							return;
						}
					}
				}
				DispatchSpawn(construct);
				SetEntProp( construct, Prop_Send, "m_nSolidType", 6 );
				TeleportEntity(construct, flEndPos, NULL_VECTOR, NULL_VECTOR);

				int beamcolor[4] = {0, 255, 90, 255};

				float vecMins[3], vecMaxs[3];
				vecMins = Vec_AddVectors(flEndPos, mins); //AddVectors(flEndPos, mins, vecMins);
				vecMaxs = Vec_AddVectors(flEndPos, maxs); //AddVectors(flEndPos, maxs, vecMaxs);

				int laser = PrecacheModel("sprites/laser.vmt", true);
				TE_SendBeamBoxToAll( vecMaxs, vecMins, laser, laser, 1, 1, 5.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );

				SetEntProp(construct, Prop_Data, "m_takedamage", 2, 1);
				SDKHook(construct, SDKHook_OnTakeDamage,	OnConstructTakeDamage);
				SDKHook(construct, SDKHook_Touch,		OnConstructTouch);
		
				SetEntProp(construct, Prop_Data, "m_iHealth", MMCvars[VehicleConstructHP].IntValue);
				if( IsValidEntity(construct) and IsValidEdict(construct) ) {
					int index = manager.GetNextEmptyPowerUpSlot(team);
					if( index == -1 ) {
						CPrintToChat(client, "{red}[Mechanized Mercs] {white}SpawnTankConstruct::Logic Error.");
						CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(construct) );
						return;
					}
					TankConstruct[team-2][index][ENTREF] = EntIndexToEntRef(construct);
					TankConstruct[team-2][index][VEHTYPE] = vehicletype;
					TankConstruct[team-2][index][BUILDER] = GetClientUserId(client);
					TankConstruct[team-2][index][METAL] = 0;
					TankConstruct[team-2][index][AMMO] = 0;
					TankConstruct[team-2][index][HEALTH] = 0;
					//TankConstruct[team-2][index][PLYRHP] = 0;
					TankConstruct[team-2][index][MAXMETAL] = metal;
					TankConstruct[team-2][index][ROCKETS] = 0;
					switch( vehicletype ) {
						case Tank, PanzerIII, KingPanzer:	TankConstruct[team-2][index][ROCKETS] = MMCvars[MaxRocketAmmo].IntValue;
						case ArmoredCar:			TankConstruct[team-2][index][ROCKETS] = MMCvars[MaxRocketAmmo].IntValue * 2;
					}
					if( bGasPowered.BoolValue )
						TankConstruct[team-2][index][GASLEFT] = RoundFloat( StartingFuel.FloatValue );
				}
			}
			else {
				CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build that Vehicle there.");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(construct) );
				SpawnVehicleGarageMenu(client, -1);
			}
		}
	}
	else if( action == MenuAction_End )
		delete menu;
}


#define CONTENTS_REDTEAM			0x800
#define CONTENTS_BLUTEAM			0x1000
#define COLLISION_GROUP_PLAYER_MOVEMENT		8

public bool OnGarageCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	if( entity and IsValidEntity(entity) ) {
		int ent_team = GetEntProp( entity, Prop_Send, "m_iTeamNum" );
		for( int i=MaxClients ; i ; i-- )
			if( IsValidClient(i) )
				PrintToConsole(i, "collide ent == %i", entity);
		
		if( collisiongroup == COLLISION_GROUP_PLAYER_MOVEMENT
			and (entity == manager.GetGarage(ent_team-2, SUPPORTGARAGE)
			or entity == manager.GetGarage(ent_team-2, OFFENSEGARAGE)
			or entity == manager.GetGarage(ent_team-2, HEAVYGARAGE)) ) {
			switch( ent_team ) {	// Do collisions by team
				case 2: {
					if( !(contentsmask & CONTENTS_REDTEAM) )
						return false;
				}
				case 3: {
					if( !(contentsmask & CONTENTS_BLUTEAM) )
						return false;
				}
			}
			return true;
		}
	}
	return true;
}
public Action OnEffectTransmit(int entity, int client)
{
	if (!IsClientValid(client))
		return Plugin_Continue;

	int team = GetEntProp(entity, Prop_Data, "m_iTeamNum");
	if (GetClientTeam(client) != team)
		return Plugin_Handled;

	return Plugin_Continue;
}


public Action ForcePlayerRespawn(int client, int args)
{
	if (bEnabled.BoolValue) {
		if (args < 1) {
			ReplyToCommand(client, "[TF2Vehicles] Usage: sm_forcevehicle <player/target> <vehicle id>");
			return Plugin_Handled;
		}
		char name[PLATFORM_MAX_PATH]; GetCmdArg( 1, name, sizeof(name) );

		char target_name[MAX_TARGET_LENGTH];
		int target_list[PLYR], target_count;
		bool tn_is_ml;
		if ((target_count = ProcessTargetString(name, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
			/* This function replies to the admin with a failure message */
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		for( int i=0 ; i < target_count ; i++ )
			if( IsValidClient(target_list[i], false) )
				TF2_RespawnPlayer(target_list[i]);

	} return Plugin_Continue;
}
public Action CmdReloadCFG(int client, int iAction)
{
	ServerCommand("sm_rcon exec sourcemod/Mechanized-Mercenaries.cfg");
	ReplyToCommand(client, "**** Reloading Mechanized Mercenaries Config ****");
	return Plugin_Handled;
}
public void OnPreThink(int client)
{
	if( IsClientObserver(client) )
		return;
	
	int entity = GetClientAimTarget(client, false);
	if (entity > MaxClients) {
		int index = manager.FindEntityPowerUpIndex(2, entity);
		int team ;
		if (index == -1) {
			index = manager.FindEntityPowerUpIndex(3, entity);
			if (index == -1)
				return;
			else team = 3;
		}
		else team = 2;

		SetHudTextParams(0.93, -1.0, 0.1, 0, 255, 0, 255);
		if (TankConstruct[team-2][index][METAL] < TankConstruct[team-2][index][MAXMETAL])
			ShowHudText(client, -1, "Metal Progress for Vehicle: %i / %i\nVehicle Health: %i", TankConstruct[team-2][index][METAL], TankConstruct[team-2][index][MAXMETAL], GetEntProp(entity, Prop_Data, "m_iHealth"));
		else ShowHudText(client, -1, "Vehicle is Ready to Board!");
	}

	BaseVehicle player = BaseVehicle(client);
	if( player.bIsVehicle ) {
		int team = GetClientTeam(client);
		if( (GetClientButtons(client) & IN_JUMP) and (GetEntityFlags(client) & FL_ONGROUND) ) {
			// record vehicle info so we can recreate our vehicle construct as ready to use
			float vec_origin[3]; GetClientAbsOrigin(client, vec_origin);
			//vec_origin[2] += 10.0;
			if( BringClientToSide(client, vec_origin) ) {	// found safe place for player to be
				if( player.bHasGunner )
					player.RemoveGunner();

				int index = manager.SpawnTankConstruct(client, vec_origin, team, player.iType, false);
				if( index != -1 ) {
					TankConstruct[team-2][index][METAL] = 999999999;
					int Turret = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					TankConstruct[team-2][index][AMMO] = GetWeaponClip(Turret);
					TankConstruct[team-2][index][HEALTH] = player.iHealth;
					switch( player.iType ) {
						case Tank, ArmoredCar, KingPanzer, PanzerIII:
							TankConstruct[team-2][index][ROCKETS] = ToCTank(player).iRockets;
					}
					// we got our info, let's get out of the vehicle.
					player.bIsVehicle = false;
					player.iType = -1;
					player.Reset();
					SetEntityHealth(client, 5);
					TF2_RegeneratePlayer(client);
					if( TankConstruct[team-2][index][PLYRHP] > 0 ) {
						SetEntityHealth(client, TankConstruct[team-2][index][PLYRHP]);
						TankConstruct[team-2][index][PLYRHP] = 0;
					}
					return;
				}
			}
			else CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't exit the vehicle in this area.");
		}
		if( player.bHasGunner )
			player.UpdateGunner();
		
		if( IsNearSpencer(client) )
			ManageVehicleNearDispenser(player); // in handler.sp
		
		for( int i=MaxClients ; i ; --i ) {
			if( !IsClientValid(i) )
				continue;

			else if( client == GetHealingTarget(i) )
				ManageVehicleMedigunHeal(player, BaseVehicle(i)); // in handler.sp
		}
	}
	else {
		// self isn't taken yet!
		BaseVehicle vehicle;
		for( int i=MaxClients ; i ; --i ) {
			if( !IsClientValid(i) )
				continue;
			else if( !IsPlayerAlive(i) )
				continue;
			else if( i==client or GetClientTeam(i) != GetClientTeam(client) )
				continue;
			
			vehicle = BaseVehicle(i);
			if( !vehicle.bIsVehicle )
				continue;
			
			if( (vehicle.iType==Tank or vehicle.iType==ArmoredCar or vehicle.iType==PanzerIII or vehicle.iType==KingPanzer)
			and IsInRange(client, vehicle.index, 100.0) ) {
				SetHudTextParams(0.93, 0.80, 0.1, 0, 255, 255, 255);
				if( !player.bIsGunner ) {
					ShowSyncHudText(client, hHudText, "press RELOAD to become a mounted gunner!");
					if( GetClientButtons(client) & IN_RELOAD )
						vehicle.SetUpGunner(player);
				}
				else ShowSyncHudText(client, hHudText, "press JUMP to get off.");
			}
		}
	}
}
public Action TraceAttack(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	if( IsClientValid(attacker) and IsClientValid(victim) ) {
		/* this is basically the same code from my Advanced armor plugin but with the difference of making it work for the vehicle classes */
		if( GetClientTeam(attacker) == GetClientTeam(victim) ) {
			if( TF2_GetPlayerClass(attacker) == TFClass_Engineer
				and HealthFromEngies.BoolValue
				and BaseVehicle(victim).bIsVehicle ) {
				//BaseVehicle fixer	= BaseVehicle(attacker);
				//BaseVehicle player	= BaseVehicle(victim);
				ManageVehicleEngieHit( BaseVehicle(victim), BaseVehicle(attacker) ); // in handler.sp
			}
		}
	}
	return Plugin_Continue;
}
public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;
	else if( !IsValidClient(victim, false) )
		return Plugin_Continue;

	BaseVehicle vehVictim = BaseVehicle(victim);
	BaseVehicle vehAttacker = BaseVehicle(attacker);

	if (vehVictim.bIsVehicle)	// in handler.sp
		return ManageOnVehicleTakeDamage(vehVictim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
	
	if (damagetype & DMG_CRIT)
		return Plugin_Continue; //this prevents damage fall off applying to crits
	
	if (attacker < 1)
		return Plugin_Continue;
	
	if (vehAttacker.bIsVehicle)	// in handler.sp
		return ManageOnVehicleDealDamage(vehVictim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);

	return Plugin_Continue;
}
public Action OnGarageTakeDamage(int victim, int& attacker, int& inflictor, float &damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if( !IsValidClient(attacker) )
		return Plugin_Continue;
	
	int team = GetClientTeam(attacker);
	if( team == GetEntProp(victim, Prop_Data, "m_iTeamNum") and IsClientValid(attacker) ) {
		damage = 0.0;
		int maxhp, offset;
		char tName[64]; GetEntPropString(victim, Prop_Data, "m_iName", tName, sizeof(tName));
		
		if( StrContains(tName, "mechmercs_garage_support") != -1 ) {
			maxhp = 1000; offset = SUPPORTGARAGE;
		}
		else if( StrContains(tName, "mechmercs_garage_offense") != -1 ) {
			maxhp = 1500; offset = OFFENSEGARAGE;
		}
		else if( StrContains(tName, "mechmercs_garage_heavy") != -1 ) {
			maxhp = 2500; offset = HEAVYGARAGE;
		}

		int iCurrentMetal = GetEntProp(attacker, Prop_Data, "m_iAmmo", 4, 3);
		int repairamount = HealthFromMetal.IntValue;	//default 10
		int mult = HealthFromMetalMult.IntValue;	//default 10
		int flag = OffsetToFlag(offset);	// in gamemodemanager.sp

		char classname[64];
		if( IsValidEdict(weapon) )
			GetEdictClassname(weapon, classname, sizeof(classname));

		if( !strcmp(classname, "tf_weapon_wrench", false) or !strcmp(classname, "tf_weapon_robot_arm", false) ) {
			int health = GetEntProp(victim, Prop_Data, "m_iHealth");
			// PATCH: only be able to fix Garages that are fully built.
			if( (GarageFlags[team-2] & flag) and health < maxhp and iCurrentMetal > 0 ) {
				if( iCurrentMetal < repairamount )
					repairamount = iCurrentMetal;

				if( maxhp-health < repairamount*mult )
					repairamount = RoundToCeil( float((maxhp - health)/mult) );

				if( repairamount < 1 and iCurrentMetal )
					repairamount = 1;

				health += repairamount*mult;

				if( health > maxhp )
					health = maxhp;

				iCurrentMetal -= repairamount;
				SetEntProp(attacker, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
				SetEntProp(victim, Prop_Data, "m_iHealth", health);
				if( repairamount )
					EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
				else EmitSoundToClient(attacker, "weapons/wrench_hit_build_fail.wav");
				//EmitSoundToClient(attacker, "ui/item_store_add_to_cart.wav");
			}
			if( GarageBuildTime[team-2][offset] > 0.0 ) {
				GarageBuildTime[team-2][offset] -= MMCvars[OnEngieHitBuildTime].FloatValue;
				EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
				//EmitSoundToClient(attacker, "ui/item_store_add_to_cart.wav", _, SNDCHAN_AUTO, _, _, _, 80);
			}
		}
		/*		DIDN'T WORK
		else if (TF2_GetPlayerClass(attacker) == TFClass_Engineer and !strcmp(classname, "tf_weapon_shotgun_building_rescue", false))
		{
			int health = GetEntProp(victim, Prop_Data, "m_iHealth");
			if ( (GarageFlags[team-2] & flag) and health and health < maxhp) {
				health += 100;
				if (health > maxhp)
					health = maxhp;

				SetEntProp(victim, Prop_Data, "m_iHealth", health);
				EmitSoundToClient(attacker, "ui/item_store_add_to_cart.wav");
			}
		}
		
		else if (TF2_GetPlayerClass(attacker) == TFClass_Spy and weapon == GetPlayerWeaponSlot(attacker, 2)) {
			if (GarageBuildTime[team-2][offset] > 0.0) {
				GarageBuildTime[team-2][offset] -= MMCvars[OnOfficerHitBuildTime].FloatValue;
				EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
				//EmitSoundToClient(attacker, "ui/item_store_add_to_cart.wav", _, SNDCHAN_AUTO, _, _, _, 80);
			}
		}*/
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action RemoveEnt(Handle timer, any entid)
{
	int ent = EntRefToEntIndex(entid);
	if( ent and IsValidEntity(ent) )
		AcceptEntityInput(ent, "Kill");
	return Plugin_Continue;
}
/*
	When using intended garage models, have going inside the garages heal and rearm the respective vehicle.
*/
public Action Timer_GarageThink(Handle timer)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;

	int garage, /*owner,*/ health[2][3], buildinghp[3];
	for( int team=0 ; team<2 ; ++team ) {
		for( int offset=0 ; offset<3 ; ++offset ) {
			garage = manager.GetGarage(team, offset);
			if( !GarageRefs[team][offset] ) {
				if (GarageGlowRefs[team][offset])
					CreateTimer( 0.1, RemoveEnt, GarageGlowRefs[team][offset] );
				GarageGlowRefs[team][offset] = 0;
				manager.DeleteGarage(team, OffsetToFlag(offset));
				continue;
			}
			else if( !IsValidEntity(garage) or !IsValidEdict(garage) ) {
				if( GarageRefs[team][offset] )
					GarageRefs[team][offset] = 0;	// If the index has a true entry but still invalid, set to 0

				if( GarageGlowRefs[team][offset] )
					CreateTimer( 0.1, RemoveEnt, GarageGlowRefs[team][offset] );
				GarageGlowRefs[team][offset] = 0;
				manager.DeleteGarage(team, OffsetToFlag(offset));
				continue;
			}

			// If the owner engineer disconnects OR changes team, kill the garage
			/*
			owner = GetOwner(garage);
			if( owner <= 0 ) {
				CreateTimer( 0.1, RemoveEnt, GarageGlowRefs[team][offset] );
				GarageGlowRefs[team][offset] = 0;

				CreateTimer( 0.1, RemoveEnt, GarageRefs[team][offset] );
				GarageRefs[team][offset] = 0;
				manager.DeleteGarage(team, OffsetToFlag(offset));
				continue;
			}
			else if( GetClientTeam(owner) != GetEntProp(garage, Prop_Data, "m_iTeamNum") ) {
				CreateTimer( 0.1, RemoveEnt, GarageRefs[team][offset] );
				GarageRefs[team][offset] = 0;
				manager.DeleteGarage(team, OffsetToFlag(offset));
				continue;
			}
			*/
			health[team][offset] = GetEntProp(garage, Prop_Data, "m_iHealth");
			
			if( GarageBuildTime[team][offset] <= 0.0 ) {
				int flag = OffsetToFlag(offset);
				if( !(GarageFlags[team] & flag) ) {
					GarageFlags[team] |= flag;
					switch( flag ) {
						case SUPPORTBUILT:	SetEntProp(garage, Prop_Data, "m_iHealth", MMCvars[SupportHP].IntValue);
						case OFFENSIVEBUILT:	SetEntProp(garage, Prop_Data, "m_iHealth", MMCvars[OffensiveHP].IntValue);
						case HEAVYBUILT:	SetEntProp(garage, Prop_Data, "m_iHealth", MMCvars[HeavySupportHP].IntValue);
					}
				}
				GarageBuildTime[team][offset] = 0.0;
			}
			else GarageBuildTime[team][offset] -= 0.1;
		}
	}
	int team, supporttime, offensetime, heavytime, buildingflag;
	for( int i=MaxClients ; i ; --i ) {
		if( !IsValidClient(i, false) )
			continue;
		else if( GetClientButtons(i) & IN_SCORE )
			continue;
		else if( GetClientTeam(i) < 2 )
			continue;

		team = GetClientTeam(i)-2;
		
		switch( team ) {
			case 0: { buildinghp[0] = health[team][0]; buildinghp[1] = health[team][1]; buildinghp[2] = health[team][2]; }
			case 1: { buildinghp[0] = health[team][0]; buildinghp[1] = health[team][1]; buildinghp[2] = health[team][2]; }
		}
		buildingflag = manager.GetGarageRefFlags(team);
		supporttime = RoundFloat(GarageBuildTime[team][SUPPORTGARAGE]);
		offensetime = RoundFloat(GarageBuildTime[team][OFFENSEGARAGE]);
		heavytime = RoundFloat(GarageBuildTime[team][HEAVYGARAGE]);

		//SetHudTextParams(0.93, 0.80, 0.13, 0, 255, 0, 255);
		SetHudTextParams(0.93, 0.10, 0.13, 0, 255, 0, 255);
		switch( GarageFlags[team] ) {
			case 14: ShowHudText(i, -1, "Support Garage Online: Health %i\nOffensive Garage Online: Health %i\nHeavy Support Garage Online: Health %i", buildinghp[0], buildinghp[1], buildinghp[2]);
			case 12: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Garage Online in %i Seconds\nOffensive Garage Online: Health %i\nHeavy Support Garage Online: Health %i", supporttime, buildinghp[1], buildinghp[2]);
					continue;
				}
				ShowHudText(i, -1, "Offensive Garage Online: Health %i\nHeavy Support Garage Online: Health %i", buildinghp[1], buildinghp[2]);
			}
			case 10: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Garage Online: Health %i\nOffensive Garage Online in %i Seconds\nHeavy Support Garage Online: Health %i", buildinghp[0], offensetime, buildinghp[2]);
					continue;
				}
				ShowHudText(i, -1, "Support Garage Online: Health %i\nHeavy Support Garage Online: Health %i", buildinghp[0], buildinghp[2]);
			}
			case 8: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Garage Online in %i Seconds\nOffensive Garage Online in %i Seconds\nHeavy Support Garage Online: Health %i", supporttime, offensetime, buildinghp[2]);
					continue;
				}
				else if (buildingflag == 12) {
					ShowHudText(i, -1, "Offensive Garage Online in %i Seconds\nHeavy Support Garage Online: Health %i", offensetime, buildinghp[2]);
					continue;
				}
				else if (buildingflag == 10) {
					ShowHudText(i, -1, "Support Garage Online in %i Seconds\nHeavy Support Garage Online: Health %i", supporttime, buildinghp[2]);
					continue;
				}
				ShowHudText(i, -1, "Heavy Support Garage Online: Health %i", buildinghp[2]);
			}
			case 6: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Garage Online: Health %i\nOffensive Garage Online: Health %i\nHeavy Support Garage Online in %i Seconds", buildinghp[0], buildinghp[1], heavytime);
					continue;
				}
				ShowHudText(i, -1, "Support Garage Online: Health %i\nOffensive Garage Online: Health %i", buildinghp[0], buildinghp[1]);
			}
			case 4: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Garage Online in %i Seconds\nOffensive Garage Online: Health %i\nHeavy Support Garage Online in %i Seconds", supporttime, buildinghp[1], heavytime);
					continue;
				}
				else if (buildingflag == 12) {
					ShowHudText(i, -1, "Offensive Garage Online: Health %i\nHeavy Support Garage Online in %i Seconds", buildinghp[1], heavytime);
					continue;
				}
				else if (buildingflag == 6) {
					ShowHudText(i, -1, "Support Garage Online in %i Seconds\nOffensive Garage Online: Health %i", supporttime, buildinghp[1]);
					continue;
				}
				ShowHudText(i, -1, "Offensive Garage Online: Health %i", buildinghp[1]);
			}
			case 2: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Garage Online: Health %i\nOffensive Garage Online in %i Seconds\nHeavy Support Garage Online in %i Seconds", buildinghp[0], offensetime, heavytime);
					continue;
				}
				else if (buildingflag == 10) {
					ShowHudText(i, -1, "Support Garage Online: Health %i\nHeavy Support Garage Online in %i Seconds", buildinghp[0], heavytime);
					continue;
				}
				else if (buildingflag == 6) {
					ShowHudText(i, -1, "Support Garage Online: Health %i\nOffensive Garage Online in %i Seconds", buildinghp[0], offensetime);
					continue;
				}
				ShowHudText(i, -1, "Support Garage Online: Health %i", buildinghp[0]);
			}
			case 0: {
				switch (buildingflag) {
					case 2: ShowHudText(i, -1, "Support Garage Online in %i Seconds", supporttime);
					case 4: ShowHudText(i, -1, "Offensive Garage Online in %i Seconds", offensetime);
					case 6: ShowHudText(i, -1, "Support Garage Online in %i Seconds\nOffensive Garage Online in %i Seconds", supporttime, offensetime);
					case 8: ShowHudText(i, -1, "Heavy Support Garage Online in %i Seconds", heavytime);
					case 10: ShowHudText(i, -1, "Support Garage Online in %i Seconds\nHeavy Support Garage Online in %i Seconds", supporttime, heavytime);
					case 12: ShowHudText(i, -1, "Offensive Garage Online in %i Seconds\nHeavy Support Garage Online in %i Seconds", offensetime, heavytime);
					case 14: ShowHudText(i, -1, "Support Garage Online in %i Seconds\nOffensive Garage Online in %i Seconds\nHeavy Support Garage Online in %i Seconds", supporttime, offensetime, heavytime);
				}
			}
		}
	}
	return Plugin_Continue;
}
public Action OnPowUpTouch(int item, int player)
{
	if (0 < player <= MaxClients) {
		char tName[64]; GetEntPropString(item, Prop_Data, "m_iName", tName, sizeof(tName));
		int vehtype;
		if ( StrContains(tName, "panzer4", false) != -1 )
			vehtype = Tank;
		else if ( StrContains(tName, "armoredcar", false) != -1 )
			vehtype = ArmoredCar;
		else if ( StrContains(tName, "ambulance", false) != -1 )
			vehtype = Ambulance;
		else if ( StrContains(tName, "tiger", false) != -1 )
			vehtype = KingPanzer;
		else if ( StrContains(tName, "lighttank", false) != -1 )
			vehtype = PanzerIII;
		else if ( StrContains(tName, "marder", false) != -1 )
			vehtype = Destroyer;
		
		SetHudTextParams(0.93, -1.0, 0.1, 0, 255, 0, 255);
		ShowHudText(player, -1, "Press RELOAD to Enter the Vehicle!");
		if (GetClientButtons(player) & IN_RELOAD) {
			BaseVehicle toucher = BaseVehicle(player);
			toucher.iType = vehtype;
			toucher.bIsVehicle = true;
			toucher.ConvertToVehicle();
			toucher.VehHelpPanel();
			float VehLoc[3]; VehLoc = Vec_GetEntPropVector(item, Prop_Data, "m_vecAbsOrigin");
			TeleportEntity(player, VehLoc, NULL_VECTOR, NULL_VECTOR);
			
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(item) );
			
			DataPack thinkpack = new DataPack();
			thinkpack.WriteCell(vehtype);
			thinkpack.WriteFloat(VehLoc[0]);
			thinkpack.WriteFloat(VehLoc[1]);
			thinkpack.WriteFloat(VehLoc[2]);
		
			float respawntime;
			switch (vehtype) {
				case Tank:		respawntime = 15.0;
				case ArmoredCar:	respawntime = 11.0;
				case Ambulance:		respawntime = 9.0;
				case KingPanzer:	respawntime = 35.0;
				case PanzerIII:		respawntime = 15.0;
				case Destroyer:		respawntime = 25.0;
			}
			CreateTimer( respawntime, RespawnPowup, thinkpack, TIMER_DATA_HNDL_CLOSE );
		}
	}
	return Plugin_Continue;
}
public Action RespawnPowup(Handle timer, DataPack paco)
{
	paco.Reset();

	int vehtype = paco.ReadCell();
	float origin[3];
	origin[0] = paco.ReadFloat();
	origin[1] = paco.ReadFloat();
	origin[2] = paco.ReadFloat();
	manager.SpawnTankPowerup(origin, vehtype);
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( !bEnabled.BoolValue or !IsValidEntity(entity) )
		return;

	if( MMCvars[ReplacePowerups].BoolValue and StrContains(classname, "rune") != -1 )
		SDKHook(entity, SDKHook_SpawnPost, HookPowerup);
		
	if( StrEqual(classname, "tf_dropped_weapon") )
		SDKHook(entity, SDKHook_SpawnPost, OnDroppedWeaponSpawn);
}

public void HookPowerup(int entity)
{
	float vecOrigin[3]; vecOrigin = Vec_GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin");
	CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(entity) );
	//vecOrigin[2] += 5.0;
	manager.SpawnTankPowerup(vecOrigin, GetRandomInt(Tank, Destroyer));
}
public void OnDroppedWeaponSpawn(int entity)
{
	//int client = AccountIDToClient( GetEntProp(entity, Prop_Send, "m_iAccountID") );
	//if( client != -1 )
	AcceptEntityInput(entity, "kill");
} 


/*************************************************/
/******************* STOCKS **********************/
/*************************************************/
stock int AccountIDToClient(const int iAccountID)
{
	for( int i=MaxClients ; i ; --i ) {
		if( !IsClientValid(i) )
			continue;
			
		if( GetSteamAccountID(i) == iAccountID )
			return i;
	}
	return -1;

}  
stock int GetHealingTarget(const int client)
{
	int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if( !IsValidEdict(medigun) or !IsValidEntity(medigun) )
		return -1;

	char s[32]; GetEdictClassname(medigun, s, sizeof(s));
	if( !strcmp(s, "tf_weapon_medigun", false) ) {
		if( GetEntProp(medigun, Prop_Send, "m_bHealing") )
			return GetEntPropEnt( medigun, Prop_Send, "m_hHealingTarget" );
	}
	return -1;
}
stock bool IsNearSpencer(const int client)
{
	int medics=0;
	for( int i=MaxClients ; i ; --i ) {
		if( !IsValidClient(i) )
			continue;
		else if( GetHealingTarget(i) == client )
			++medics;
	}
	return (GetEntProp(client, Prop_Send, "m_nNumHealers") > medics);
}
public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return (entity != data);
}
stock bool IsInRange(const int entity, const int target, const float dist, bool pTrace=false)
{
	float entitypos[3]; GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", entitypos);
	float targetpos[3]; GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", targetpos);

	if ( GetVectorDistance(entitypos, targetpos) <= dist ) {
		if (!pTrace)
			return true;
		else {
			TR_TraceRayFilter( entitypos, targetpos, MASK_SHOT, RayType_EndPoint, TraceRayDontHitSelf, entity );
			if ( TR_GetFraction() > 0.98 )
				return true;
		}
	}
	return false;
}
stock int AttachParticle(const int ent, const char[] particleType, float offset = 0.0, bool battach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	char tName[128];
	float pos[3]; GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
	pos[2] += offset;
	TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	Format(tName, sizeof(tName), "target%i", ent);
	DispatchKeyValue(ent, "targetname", tName);
	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", tName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(tName);
	if (battach) {
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", ent);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(3.0, RemoveEnt, EntIndexToEntRef(particle));
	return particle;
}
stock void CreateParticles(const char[] particlename, float Pos[3] = NULL_VECTOR, const float time)
{
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle)) {
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		TeleportEntity(particle, Pos, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(time, RemoveEnt, EntIndexToEntRef(particle));
	}
	else LogError("CreateParticles: **** Couldn't Create 'info_particle_system Entity' ****");
}
stock int SetWeaponAmmo(const int weapon, const int ammo)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner <= 0)
		return 0;

	if (IsValidEntity(weapon)) {
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(owner, iAmmoTable+iOffset, ammo, 4, true);
	}
	return 0;
}
stock int GetWeaponClip(const int weapon)
{
	if (IsValidEntity(weapon)) {
		int AmmoClipTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
		return GetEntData(weapon, AmmoClipTable);
	}
	return 0;
}
stock int SetWeaponClip(const int weapon, const int ammo)
{
	if (IsValidEntity(weapon)) {
		int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
		SetEntData(weapon, iAmmoTable, ammo, 4, true);
	}
	return 0;
}
stock int ShootRocket(const int client, bool bCrit=false, float vPosition[3], float vAngles[3], const float flSpeed, const float dmg, const char[] model, bool arc=false)
{
//new String:strEntname[45] = "tf_projectile_spellfireball";
/*
switch (spell)
	{
		case FIREBALL: 		strEntname = "tf_projectile_spellfireball";
		case LIGHTNING: 	strEntname = "tf_projectile_lightningorb";
		case PUMPKIN: 		strEntname = "tf_projectile_spellmirv";
		case PUMPKIN2: 		strEntname = "tf_projectile_spellpumpkin";
		case BATS: 			strEntname = "tf_projectile_spellbats";
		case METEOR: 		strEntname = "tf_projectile_spellmeteorshower";
		case TELE: 			strEntname = "tf_projectile_spelltransposeteleport";
		case BOSS:			strEntname = "tf_projectile_spellspawnboss";
		case ZOMBIEH:		strEntname = "tf_projectile_spellspawnhorde";
		case ZOMBIE:		strEntname = "tf_projectile_spellspawnzombie";
	}
	switch(spell)
	{
		//These spells have arcs.
		case BATS, METEOR, TELE:
		{
			vVelocity[2] += 32.0;
		}
	}

CTFGrenadePipebombProjectile m_bCritical
CTFProjectile_Rocket m_bCritical
CTFProjectile_SentryRocket m_bCritical
CTFWeaponBaseGrenadeProj m_bCritical
CTFMinigun m_bCritShot
CTFFlameThrower m_bCritFire
CTFProjectile_Syringe
CTFPlayer m_iCritMult
SetEntPropFloat(iProjectile, Prop_Send, "m_flDamage", dmg);
	}
*/
	int iProjectile = CreateEntityByName("tf_projectile_rocket");	
	if (!IsValidEdict(iProjectile))
		return 0;

	float vVelocity[3];
	vVelocity = Vec_GetAngleVecForward(vAngles); //GetAngleVectors(vAngles, vVelocity, NULL_VECTOR, NULL_VECTOR);

	if (!arc)
		vVelocity = Vec_NormalizeVector(vVelocity);
	else vVelocity[2] -= 0.025;

	ScaleVector(vVelocity, flSpeed);
	SetEntPropEnt(iProjectile,	Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(iProjectile,		Prop_Send, "m_bCritical", (bCrit ? 1 : 0));
	
	int iTeam = GetClientTeam(client);
	SetEntProp(iProjectile,		Prop_Send, "m_iTeamNum", iTeam, 1);
	SetEntProp(iProjectile,		Prop_Send, "m_nSkin", (iTeam-2));

	SetVariantInt(iTeam);
	AcceptEntityInput(iProjectile, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iProjectile, "SetTeam", -1, -1, 0);
	SetEntDataFloat(iProjectile, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected")+4, dmg, true);

	TeleportEntity(iProjectile, vPosition, vAngles, vVelocity); 
	DispatchSpawn(iProjectile);
	if (arc)
		SetEntityMoveType(iProjectile, MOVETYPE_FLYGRAVITY);
	if ( model[0] != '\0' )
		SetEntityModel(iProjectile, model);
	return iProjectile;
}

stock void SetClientOverlay(const int client, const char[] strOverlay)
{
	int iFlags = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlags);
	ClientCommand(client, "r_screenoverlay \"%s\"", strOverlay);
}

stock bool IsValidClient(const int client, bool replaycheck = true)
{
	if (client <= 0 or client > MaxClients)
		return false;
	if (!IsClientInGame(client))
		return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;
	if (replaycheck)
		if (IsClientSourceTV(client) or IsClientReplay(client))
			return false;
	return true;
}

stock bool IsBlueBlocked(const int client)
{
	if( !AllowBlu.BoolValue and GetClientTeam(client) == 3 )
		return true;
	return false;
}

stock bool IsRedBlocked(const int client)
{
	if( !AllowRed.BoolValue and GetClientTeam(client) == 2 )
		return true;
	return false;
}
stock int GetOwner(const int ent)
{
	if( IsValidEdict(ent) and IsValidEntity(ent) )
		return GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	return -1;
}
stock void DoExplosion(const int owner, const int damage, const int radius, const float pos[3])
{
	int explode = CreateEntityByName("env_explosion");
	if( !IsValidEntity(explode) )
		return;

	DispatchKeyValue(explode, "targetname", "exploder");
	DispatchKeyValue(explode, "spawnflags", "4");
	DispatchKeyValue(explode, "rendermode", "5");

	SetEntPropEnt(explode, Prop_Data, "m_hOwnerEntity", owner);
	SetEntProp(explode, Prop_Data, "m_iMagnitude", damage);
	SetEntProp(explode, Prop_Data, "m_iRadiusOverride", radius);

	int team = GetClientTeam(owner);
	SetVariantInt(team); AcceptEntityInput(explode, "TeamNum");
	SetVariantInt(team); AcceptEntityInput(explode, "SetTeam");

	TeleportEntity(explode, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(explode);
	ActivateEntity(explode);
	AcceptEntityInput(explode, "Explode");
	AcceptEntityInput(explode, "Kill");
}

stock float fmax(float a, float b)
{
	return (a > b) ? a : b ;
}

stock float Vec2DLength(float v[2])
{
	float length = 0.0;
	for (int i=0 ; i<2 ; ++i)
		length += v[i]*v[i];
	
	length = SquareRoot (length);
	return length;
}

stock bool CalcBuildPos(const int builder, const float flMins[3], const float flMaxs[3], float flBuildBuffer[3])
{
	if (builder <= 0)
		return false ;
	
	float vec_forward[3];
	float vec_angles[3], vec_objangles[3];
	GetClientEyeAngles(builder, vec_angles);
	// we only need the y-angle
	vec_angles[0] = 0.0, vec_angles[2] = 0.0;
	vec_objangles = vec_angles;
	GetAngleVectors(vec_angles, vec_forward, NULL_VECTOR, NULL_VECTOR);
	
	float vec_objradius[2];
	vec_objradius[0] = fmax( flMins[0], flMaxs[0] );
	vec_objradius[1] = fmax( flMins[1], flMaxs[1] );
	
	float vec_playerRadius[2];
	float vecPlayerMins[3], vecPlayerMaxs[3];
	
	GetClientMaxs(builder, vecPlayerMaxs);
	GetClientMins(builder, vecPlayerMins);
	vec_playerRadius[0] = fmax( vecPlayerMins[0], vecPlayerMaxs[0] );
	vec_playerRadius[1] = fmax( vecPlayerMins[1], vecPlayerMaxs[1] );
	
	float fldist = Vec2DLength(vec_objradius) + Vec2DLength(vec_playerRadius) + 4.0;
	
	float vecBuildOrigin[3];
	float vec_playerorigin[3];
	GetClientAbsOrigin(builder, vec_playerorigin);
	
	ScaleVector(vec_forward, fldist);
	AddVectors(vec_playerorigin, vec_forward, vecBuildOrigin);
	
	flBuildBuffer = vecBuildOrigin;
	
	float vBuildDims[3];
	SubtractVectors(flMaxs, flMins, vBuildDims);
	
	float vHalfBuildDims[3];
	vHalfBuildDims = vBuildDims;
	ScaleVector(vHalfBuildDims, 0.5);
	
	
	//Vector vErrorOrigin = vecBuildOrigin - (m_vecBuildMaxs - m_vecBuildMins) * 0.5f - m_vecBuildMins;
	float vErrorOrigin[3];
	{
		SubtractVectors(vecBuildOrigin, vHalfBuildDims, vErrorOrigin);
		SubtractVectors(vErrorOrigin, flMins, vErrorOrigin);
	}
	
	float vHalfPlayerDims[3];
	{
		float mins[3]; GetClientMins(builder, mins);
		float maxs[3]; GetClientMaxs(builder, maxs);
		SubtractVectors(maxs, mins, vHalfPlayerDims);
		ScaleVector(vHalfPlayerDims, 0.5);
	}
	float flBoxTopZ = vec_playerorigin[2] + vHalfPlayerDims[2] + vBuildDims[2];
	float flBoxBottomZ = vec_playerorigin[2] - vHalfPlayerDims[2] - vBuildDims[2];
	
	float bottomZ = 0.0;
	int nIterations = 8;
	float topZ = flBoxTopZ;
	float topZInc = (flBoxBottomZ - flBoxTopZ) / (nIterations-1);
	int iIteration;
	
	float checkOriginTop[3];
	checkOriginTop = vecBuildOrigin;
	float checkOriginBottom[3];
	checkOriginBottom = vecBuildOrigin;
	
	float endpos[3];
	for (iIteration=0 ; iIteration<nIterations ; ++iIteration) {
		//checkOriginTop[2] = topZ;
		//checkOriginBottom[2] = flBoxBottomZ;
		
		TR_TraceHull( vecBuildOrigin, vecBuildOrigin, flMins, flMaxs, MASK_SOLID );
		TR_GetEndPosition(endpos);
		bottomZ = endpos[2];
		
		if (TR_GetFraction() == 1.0 /*or TR_PointOutsideWorld(endpos)*/) {	// no ground, can't build here!
			flBuildBuffer = vErrorOrigin;
			return false;
		}
		
		// if we found enough space to fit our object, place here
		if ( topZ - bottomZ > vBuildDims[2]
			and !(TR_GetPointContents(vecBuildOrigin) & MASK_SOLID)
			and !(TR_GetPointContents(vecBuildOrigin) & MASK_SOLID) )
			break;
		
		++vecBuildOrigin[2];
		topZ += topZInc;
	}
	if ( iIteration == nIterations ) {
		flBuildBuffer = vErrorOrigin;
		return false;
	}
		
	// Now see if the range we've got leaves us room for our box.
	if ( topZ-bottomZ < vBuildDims[2] ) {
		flBuildBuffer = vErrorOrigin;
		return false;
	}
	
	// Ok, now we know the Z range where this box can fit.
	float vBottomLeft[3];
	SubtractVectors(vecBuildOrigin, vHalfBuildDims, vBottomLeft);
	vBottomLeft[2] = bottomZ;
	
	SubtractVectors(vBottomLeft, flMins, vecBuildOrigin);
	flBuildBuffer = vecBuildOrigin;
	return true;
	
	/*
	bool bSuccess;
	for ( int i=301 ; i ; --i ) {
		TR_TraceHull( vecBuildOrigin, vecBuildOrigin, flMins, flMaxs, MASK_SOLID );
		if (bSuccess)
			break;
		
		if (TR_GetFraction() == 0.99 or TR_GetFraction() == 0.98)
			bSuccess = true; //PrintToConsole(builder, "tr.fraction");
		else if (TR_DidHit())
			vecBuildOrigin[2] += 0.1;
	}
	flBuildBuffer = vecBuildOrigin;
	PrintToConsole(builder, "%i", (bSuccess == true));
	return bSuccess;
	*/
}


stock bool IsPlacementPosValid(const int builder, const float flMins[3], const float flMaxs[3], float flBuildBuffer[3])
{
	bool bValid = CalcBuildPos(builder, flMins, flMaxs, flBuildBuffer);

	if ( !bValid )
		return false;
	
	if ( builder <= 0 )
		return false;
	
	// Make sure we can see the final position
	float EyePos[3]; GetClientEyePosition(builder, EyePos);
	float BuildOriginSum[3];
	{
		float tempvec[3];
		tempvec[0] = 0.0, tempvec[1] = 0.0, tempvec[2] = flMaxs[2] * 0.5;
		AddVectors(flBuildBuffer, tempvec, BuildOriginSum);
	}
	TR_TraceRayFilter( EyePos, BuildOriginSum, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, TraceRayDontHitSelf, builder );
	if ( TR_GetFraction() < 1.0 )
		return false;

	return true;
}
/*
bool CBaseObject::EstimateValidBuildPos( void )
{
	CTFPlayer *pPlayer = GetOwner();

	if ( !pPlayer )
		return false;

	// Calculate build angles
	Vector forward;
	QAngle vecAngles = vec3_angle;
	vecAngles.y = pPlayer->EyeAngles().y;

	QAngle objAngles = vecAngles;

	//SetAbsAngles( objAngles );
	//SetLocalAngles( objAngles );
	AngleVectors(vecAngles, &forward );

	// Adjust build distance based upon object size
	Vector2D vecObjectRadius;
	vecObjectRadius.x = max( fabs( m_vecBuildMins.m_Value.x ), fabs( m_vecBuildMaxs.m_Value.x ) );
	vecObjectRadius.y = max( fabs( m_vecBuildMins.m_Value.y ), fabs( m_vecBuildMaxs.m_Value.y ) );

	Vector2D vecPlayerRadius;
	Vector vecPlayerMins = pPlayer->WorldAlignMins();
	Vector vecPlayerMaxs = pPlayer->WorldAlignMaxs();
	vecPlayerRadius.x = max( fabs( vecPlayerMins.x ), fabs( vecPlayerMaxs.x ) );
	vecPlayerRadius.y = max( fabs( vecPlayerMins.y ), fabs( vecPlayerMaxs.y ) );

	float flDistance = vecObjectRadius.Length() + vecPlayerRadius.Length() + 4; // small safety buffer
	Vector vecBuildOrigin = pPlayer->WorldSpaceCenter() + forward * flDistance;

	// Cannot build inside a nobuild brush
	if ( PointInNoBuild( vecBuildOrigin, this ) )
		return false;

	if ( PointInRespawnRoom( NULL, vecBuildOrigin ) )
		return false;

	Vector vecBuildFarEdge = vecBuildOrigin + forward * ( flDistance + 8.0f );
	if ( TestAgainstRespawnRoomVisualizer( pPlayer, vecBuildFarEdge ) )
		return false;

	return true;
}
*/
stock bool CanBuildHere(float flPos[3], const float flMins[3], const float flMaxs[3])
{
	bool bSuccess;
	for ( int i=0 ; i<60 ; ++i ) {
		TR_TraceHull( flPos, flPos, flMins, flMaxs, MASK_SOLID );
		if ( TR_GetFraction() > 0.98 ) {
			bSuccess = true;
			break;
		}
		else flPos[2] += 1.0;
	}
	return bSuccess;
/*
//-----------------------------------------------------------------------------
// Purpose: Check that the selected position is buildable
//-----------------------------------------------------------------------------
bool CBaseObject::IsPlacementPosValid( void )
{
	bool bValid = CalculatePlacementPos();

	if ( !bValid )
	{
		return false;
	}

	CTFPlayer *pPlayer = GetOwner();

	if ( !pPlayer )
	{
		return false;
	}

#ifndef CLIENT_DLL
	if ( !EstimateValidBuildPos() )
		return false;
#endif

	// Verify that the entire object can fit here
	// Important! here we want to collide with players and other buildings, but not dropped weapons
	trace_t tr;
	UTIL_TraceEntity( this, m_vecBuildOrigin, m_vecBuildOrigin, MASK_SOLID, NULL, COLLISION_GROUP_PLAYER, &tr );

	if ( tr.fraction < 1.0f )
		return false;

	// Make sure we can see the final position
	UTIL_TraceLine( pPlayer->EyePosition(), m_vecBuildOrigin + Vector(0,0,m_vecBuildMaxs[2] * 0.5), MASK_PLAYERSOLID_BRUSHONLY, pPlayer, COLLISION_GROUP_NONE, &tr );
	if ( tr.fraction < 1.0 )
	{
		return false;
	}

	return true;
}
//-----------------------------------------------------------------------------
// Purpose: 
//-----------------------------------------------------------------------------
bool CBaseObject::TestAgainstRespawnRoomVisualizer( CTFPlayer *pPlayer, const Vector &vecEnd )
{
	// Setup the ray.
	Ray_t ray;
	ray.Init( pPlayer->WorldSpaceCenter(), vecEnd );

	CBaseEntity *pEntity = NULL;
	while ( ( pEntity = gEntList.FindEntityByClassnameWithin( pEntity, "func_respawnroomvisualizer", pPlayer->WorldSpaceCenter(), ray.m_Delta.Length() ) ) != NULL )
	{
		trace_t trace;
		enginetrace->ClipRayToEntity( ray, MASK_ALL, pEntity, &trace );
		if ( trace.fraction < 1.0f )
			return true;
	}

	return false;
}
*/
}
stock int GetWeaponAmmo(const int weapon)
{
	int owner = GetOwner(weapon);
	if (owner == -1)
		return 0;
	if (IsValidEntity(weapon)) {
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		return GetEntData(owner, iAmmoTable+iOffset, 4);
	}
	return 0;
}
stock void TE_SendBeamBoxToAll (const float upc[3], const float btc[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, const float Life, const float Width, const float EndWidth, int FadeLength, const float Amplitude, const int Color[4], const int Speed)
{
	// Create the additional corners of the box
	float tc1[] = {0.0, 0.0, 0.0};
	float tc2[] = {0.0, 0.0, 0.0};
	float tc3[] = {0.0, 0.0, 0.0};
	float tc4[] = {0.0, 0.0, 0.0};
	float tc5[] = {0.0, 0.0, 0.0};
	float tc6[] = {0.0, 0.0, 0.0};

	tc1 = Vec_AddVectors(tc1, upc); //AddVectors(tc1, upc, tc1);
	tc2 = Vec_AddVectors(tc2, upc); //AddVectors(tc2, upc, tc2);
	tc3 = Vec_AddVectors(tc3, upc); //AddVectors(tc3, upc, tc3);
	tc4 = Vec_AddVectors(tc4, btc); //AddVectors(tc4, btc, tc4);
	tc5 = Vec_AddVectors(tc5, btc); //AddVectors(tc5, btc, tc5);
	tc6 = Vec_AddVectors(tc6, btc); //AddVectors(tc6, btc, tc6);

	tc1[0] = btc[0];
	tc2[1] = btc[1];
	tc3[2] = btc[2];
	tc4[0] = upc[0];
	tc5[1] = upc[1];
	tc6[2] = upc[2];

	// Draw all the edges
	TE_SetupBeamPoints(upc, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(upc, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(upc, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
}
/*
stock int SpawnWeapon(int client, char[] name, int index, int level, int qual, char[] att)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == null) return -1;
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2 = 0;
		for (int i = 0; i < count; i += 2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else TF2Items_SetNumAttributes(hWeapon, 0);

	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}
*/
stock void SetWeaponInvis(const int client, const int alpha)
{
	int transparent = alpha;
	for (int i=0; i<5; i++) {
		int entity = GetPlayerWeaponSlot(client, i);
		if ( IsValidEdict(entity) and IsValidEntity(entity) )
		{
			if (transparent > 255)
				transparent = 255;
			if (transparent < 0)
				transparent = 0;
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR); 
			SetEntityRenderColor(entity, 150, 150, 150, transparent); 
		}
	}
}
stock TF2Item PrepareItemHandle(TF2Item hItem, char[] name = "", int index = -1, const char[] att = "", bool dontpreserve = false)
{
	static TF2Item hWeapon = null;
	int addattribs = 0;

	char weaponAttribsArray[32][32];
	int attribCount = ExplodeString(att, " ; ", weaponAttribsArray, 32, 32);

	int flags = OVERRIDE_ATTRIBUTES;
	if (!dontpreserve)
		flags |= PRESERVE_ATTRIBUTES;

	if ( !hWeapon )
		hWeapon = new TF2Item(flags);
	else hWeapon.iFlags = flags;
//	Handle hWeapon = TF2Items_CreateItem(flags);	//null;

	if (hItem != null) {
		addattribs = hItem.iNumAttribs;
		if (addattribs) {
			for (int i=0; i < 2*addattribs; i+=2) {
				bool dontAdd = false;
				int attribIndex = hItem.GetAttribID(i);
				for (int z=0; z < attribCount+i; z += 2) {
					if (StringToInt(weaponAttribsArray[z]) == attribIndex)
					{
						dontAdd = true;
						break;
					}
				}
				if (!dontAdd) {
					IntToString(attribIndex, weaponAttribsArray[i+attribCount], 32);
					FloatToString(hItem.GetAttribValue(i), weaponAttribsArray[i+1+attribCount], 32);
				}
			}
			attribCount += 2*addattribs;
		}
		delete hItem;
	}

	if (name[0] != '\0') {
		flags |= OVERRIDE_CLASSNAME;
		hWeapon.SetClassname(name);
	}
	if (index != -1) {
		flags |= OVERRIDE_ITEM_DEF;
		hWeapon.iItemIndex = index;
	}
	if (attribCount > 1) {
		hWeapon.iNumAttribs = (attribCount/2);
		int i2 = 0;
		for (int i=0; i<attribCount and i<32; i += 2)
		{
			hWeapon.SetAttribute(i2, StringToInt(weaponAttribsArray[i]), StringToFloat(weaponAttribsArray[i+1]));
			i2++;
		}
	}
	else hWeapon.iNumAttribs = 0;
	hWeapon.iFlags = flags;
	return hWeapon;
}
/**
 * Wrapper function for easily setting up non-repeating timers
 *
 * @param func			Function pointer to call desired function when time elapses
 * @param thinktime		time in seconds when timer function will be called
 * @param param1		1st param for the call back function
 * @param param2		2nd param for the call back function
 *
 * @noreturn
 */

/*
If you need to use this and your function uses 3 parameters, modify it if necessary.
BUG/GLITCH: For some strange reason, SetPawnTimer doesn't work when u attempt to callback stock functions, interesting...
*/
stock void SetPawnTimer(Function func, float thinktime = 0.1, any param1 = -999, any param2 = -999, any param3 = -999)
{
	DataPack thinkpack = new DataPack();
	thinkpack.WriteFunction(func);
	thinkpack.WriteCell(param1);
	thinkpack.WriteCell(param2);
	thinkpack.WriteCell(param3);
	CreateTimer(thinktime, DoThink, thinkpack, TIMER_DATA_HNDL_CLOSE);
}

public Action DoThink(Handle hTimer, DataPack hndl)
{
	hndl.Reset();
	Function pFunc = hndl.ReadFunction();
	Call_StartFunction( null, pFunc );

	any param1 = hndl.ReadCell();
	if ( param1 != -999 )
		Call_PushCell(param1);

	any param2 = hndl.ReadCell();
	if ( param2 != -999 )
		Call_PushCell(param2);
		
	any param3 = hndl.ReadCell();
	if ( param3 != -999 )
		Call_PushCell(param3);

	Call_Finish();
	return Plugin_Continue;
}

stock int TF2_CreateGlow(const int iEnt, const int team)	// props to Pelipoika
{
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);
	
	char strGlowColor[18];
	switch (team) {
		case 2: Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", 255, 30, 30, 255);
		case 3: Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", 30, 30, 255, 255);
	}
	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "RainbowGlow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchKeyValue(ent, "GlowColor", strGlowColor);
	DispatchSpawn(ent);
	
	AcceptEntityInput(ent, "Enable");

	return ent;
}
stock float[] Vec_SubtractVectors(const float vec1[3], const float vec2[3])
{
	float result[3]; SubtractVectors(vec1, vec2, result);
	return result;
}
stock float[] Vec_AddVectors(const float vec1[3], const float vec2[3])
{
	float result[3]; AddVectors(vec1, vec2, result);
	return result;
}
stock float[] Vec_ScaleVector(const float vec[3], const float scale)
{
	float result[3];
	result[0] = vec[0] * scale;
	result[1] = vec[1] * scale;
	result[2] = vec[2] * scale;
	return result;
}
stock float[] Vec_NegateVector(const float vec[3])
{
	float result[3];
	result[0] = -vec[0];
	result[1] = -vec[1];
	result[2] = -vec[2];
	return result;
}
stock float[] Vec_GetVectorAngles(const float vec[3])
{
	float angResult[3]; GetVectorAngles(vec, angResult);
	return angResult;
}
stock float[] Vec_GetVectorCrossProduct(const float vec1[3], const float vec2[3])
{
	float result[3]; GetVectorCrossProduct(vec1, vec2, result);
	return result;
}
stock float[] Vec_MakeVectorFromPoints(const float pt1[3], const float pt2[3])
{
	float output[3]; MakeVectorFromPoints(pt1, pt2, output);
	return output;
}
stock float[] Vec_GetEntPropVector(const int entity, const PropType type, const char[] prop, int element=0)
{
	float output[3]; GetEntPropVector(entity, type, prop, output, element);
	return output;
}
stock float[] Vec_NormalizeVector(const float vec[3])
{
	float output[3]; NormalizeVector(vec, output);
	return output;
}
stock float[] Vec_GetAngleVecForward(const float angle[3])
{
	float output[3]; GetAngleVectors(angle, output, NULL_VECTOR, NULL_VECTOR);
	return output;
}
stock float[] Vec_GetAngleVecRight(const float angle[3])
{
	float output[3]; GetAngleVectors(angle, NULL_VECTOR, output, NULL_VECTOR);
	return output;
}
stock float[] Vec_GetAngleVecUp(const float angle[3])
{
	float output[3]; GetAngleVectors(angle, NULL_VECTOR, NULL_VECTOR, output);
	return output;
}

stock int QueryEntities(const float origin[3], const float radius, int[] array, const int size)
{
	array = new int[size];
	int count = 0;
	float xyz[3];
	for (int l=1 ; l<2048 ; ++l) {
		if ( !IsValidEdict(l) or !IsValidEntity(l) ) 
			continue;
		else if (count >= size)
			break;

		xyz = Vec_GetEntPropVector(l, Prop_Data, "m_vecAbsOrigin");
		if (GetVectorDistance(xyz, origin) <= radius)
			array[count++] = l;
	}
	return count;
}

stock int QueryPlayers(const float origin[3], const float radius, int[] array, const int size, const int team)
{
	array = new int[size];
	int count = 0;
	float xyz[3];
	for (int l=MaxClients ; l ; l--) {
		if ( !IsClientInGame(l) ) 
			continue;
		else if ( !IsPlayerAlive(l) or GetClientTeam(l) != team )
			continue;
		else if (count >= size)
			break;

		GetClientAbsOrigin(l, xyz);
		if (GetVectorDistance(xyz, origin) <= radius)
			array[count++] = GetClientUserId(l);
	}
	return count;
}
stock bool IsClientStuck(const int iEntity, const float flOrigin[3])
{
	//float flOrigin[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flOrigin);
	float flMins[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecMins", flMins);
	float flMaxs[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", flMaxs);

	TR_TraceHullFilter(flOrigin, flOrigin, flMins, flMaxs, MASK_PLAYERSOLID, TraceFilterNotSelf, iEntity);
	return TR_DidHit();
}
public bool TraceFilterNotSelf(int entity, int contentsMask, any client)
{
	if( entity == client )
		return false;
	return true;
}
stock bool BringClientToSide(const int client, const float flOrigin[3])
{
	float vec_modifier[3];
	const float flMove = 85.0;
	/*
	vec_modifier = flOrigin; vec_modifier[0] += flMove;	// check x-axis
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[0] -= flMove;
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[1] += flMove;	// check y-axis
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[1] -= flMove;
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	*/
	vec_modifier = flOrigin; vec_modifier[2] += flMove;	// check z-axis
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[2] -= flMove;
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	return false;
}

/*
//-----------------------------------------------------------------------------
// Purpose: Find a place in the world where we should try to build this object
//-----------------------------------------------------------------------------
bool CBaseObject::CalculatePlacementPos( void )
{
	CTFPlayer *pPlayer = GetOwner();

	if ( !pPlayer )
		return false;

	// Calculate build angles
	Vector forward;
	QAngle vecAngles = vec3_angle;
	vecAngles.y = pPlayer->EyeAngles().y;

	QAngle objAngles = vecAngles;

	SetAbsAngles( objAngles );

	UpdateDesiredBuildRotation( gpGlobals->frametime );

	objAngles.y = objAngles.y + m_flCurrentBuildRotation;

	SetLocalAngles( objAngles );
	AngleVectors(vecAngles, &forward );

	// Adjust build distance based upon object size
	Vector2D vecObjectRadius;
	vecObjectRadius.x = max( fabs( m_vecBuildMins.m_Value.x ), fabs( m_vecBuildMaxs.m_Value.x ) );
	vecObjectRadius.y = max( fabs( m_vecBuildMins.m_Value.y ), fabs( m_vecBuildMaxs.m_Value.y ) );

	Vector2D vecPlayerRadius;
	Vector vecPlayerMins = pPlayer->WorldAlignMins();
	Vector vecPlayerMaxs = pPlayer->WorldAlignMaxs();
	vecPlayerRadius.x = max( fabs( vecPlayerMins.x ), fabs( vecPlayerMaxs.x ) );
	vecPlayerRadius.y = max( fabs( vecPlayerMins.y ), fabs( vecPlayerMaxs.y ) );

	float flDistance = vecObjectRadius.Length() + vecPlayerRadius.Length() + 4; // small safety buffer
	Vector vecBuildOrigin = pPlayer->WorldSpaceCenter() + forward * flDistance;

	m_vecBuildOrigin = vecBuildOrigin;
	Vector vErrorOrigin = vecBuildOrigin - (m_vecBuildMaxs - m_vecBuildMins) * 0.5f - m_vecBuildMins;

	Vector vBuildDims = m_vecBuildMaxs - m_vecBuildMins;
	Vector vHalfBuildDims = vBuildDims * 0.5;
	Vector vHalfBuildDimsXY( vHalfBuildDims.x, vHalfBuildDims.y, 0 );

	// Here, we start at the highest Z we'll allow for the top of the object. Then
	// we sweep an XY cross section downwards until it hits the ground.
	//
	// The rule is that the top of to box can't go lower than the player's feet, and the bottom of the
	// box can't go higher than the player's head.
	//
	// To simplify things in here, we treat the box as though it's symmetrical about all axes
	// (so mins = -maxs), then reoffset the box at the very end.
	Vector vHalfPlayerDims = (pPlayer->WorldAlignMaxs() - pPlayer->WorldAlignMins()) * 0.5f;
	float flBoxTopZ = pPlayer->WorldSpaceCenter().z + vHalfPlayerDims.z + vBuildDims.z;
	float flBoxBottomZ = pPlayer->WorldSpaceCenter().z - vHalfPlayerDims.z - vBuildDims.z;

	// First, find the ground (ie: where the bottom of the box goes).
	trace_t tr;
	float bottomZ = 0;
	int nIterations = 8;
	float topZ = flBoxTopZ;
	float topZInc = (flBoxBottomZ - flBoxTopZ) / (nIterations-1);
	int iIteration;
	for ( iIteration = 0; iIteration < nIterations; iIteration++ )
	{
		UTIL_TraceHull( 
			Vector( m_vecBuildOrigin.x, m_vecBuildOrigin.y, topZ ), 
			Vector( m_vecBuildOrigin.x, m_vecBuildOrigin.y, flBoxBottomZ ), 
			-vHalfBuildDimsXY, vHalfBuildDimsXY, MASK_PLAYERSOLID_BRUSHONLY, this, COLLISION_GROUP_PLAYER_MOVEMENT, &tr );
		bottomZ = tr.endpos.z;

		// If there is no ground, then we can't place here.
		if ( tr.fraction == 1 )
		{
			m_vecBuildOrigin = vErrorOrigin;
			return false;
		}

		// if we found enough space to fit our object, place here
		if ( topZ - bottomZ > vBuildDims.z && !tr.startsolid )
		{
			break;
		}

		topZ += topZInc;
	}

	if ( iIteration == nIterations )
	{
		m_vecBuildOrigin = vErrorOrigin;
		return false;
	}

	// Now see if the range we've got leaves us room for our box.
	if ( topZ - bottomZ < vBuildDims.z )
	{
		m_vecBuildOrigin = vErrorOrigin;
		return false;
	}

	// Verify that it's not on too much of a slope by seeing how far the corners are from the ground.
	Vector vBottomCenter( m_vecBuildOrigin.x, m_vecBuildOrigin.y, bottomZ );
	if ( !VerifyCorner( vBottomCenter, -vHalfBuildDims.x, -vHalfBuildDims.y ) ||
		!VerifyCorner( vBottomCenter, +vHalfBuildDims.x, +vHalfBuildDims.y ) ||
		!VerifyCorner( vBottomCenter, +vHalfBuildDims.x, -vHalfBuildDims.y ) ||
		!VerifyCorner( vBottomCenter, -vHalfBuildDims.x, +vHalfBuildDims.y ) )
	{
		m_vecBuildOrigin = vErrorOrigin;
		return false;
	}

	// Ok, now we know the Z range where this box can fit.
	Vector vBottomLeft = m_vecBuildOrigin - vHalfBuildDims;
	vBottomLeft.z = bottomZ;
	m_vecBuildOrigin = vBottomLeft - m_vecBuildMins;

	return true;
}

//-----------------------------------------------------------------------------
// Purpose: Checks a position to make sure a corner of a building can live there
//-----------------------------------------------------------------------------
bool CBaseObject::VerifyCorner( const Vector &vBottomCenter, float xOffset, float yOffset )
{
	// Start slightly above the surface
	Vector vStart( vBottomCenter.x + xOffset, vBottomCenter.y + yOffset, vBottomCenter.z + 0.1 );

	trace_t tr;
	UTIL_TraceLine( 
		vStart, 
		vStart - Vector( 0, 0, TF_OBJ_GROUND_CLEARANCE ), 
		MASK_PLAYERSOLID_BRUSHONLY, this, COLLISION_GROUP_PLAYER_MOVEMENT, &tr );

	// Cannot build on very steep slopes ( > 45 degrees )
	if ( tr.fraction < 1.0f )
	{
		Vector vecUp(0,0,1);
		tr.plane.normal.NormalizeInPlace();
		float flDot = DotProduct( tr.plane.normal, vecUp );

		if ( flDot < 0.65 )
		{
			// Too steep
			return false;
		}
	}

	return !tr.startsolid && tr.fraction < 1;
}
*/

public Action ForcePlayerVehicle(int client, int args)
{
	if( !bEnabled.BoolValue )
		return Plugin_Continue;
	
	if( args < 2 ) {
		ReplyToCommand(client, "[TF2Vehicles] Usage: sm_forcevehicle <player/target> <vehicle id>");
		return Plugin_Handled;
	}
	char name[PLATFORM_MAX_PATH]; GetCmdArg( 1, name, sizeof(name) );

	char number[4]; GetCmdArg( 2, number, sizeof(number) );
	int type = StringToInt(number);

	if( type < 0 or type > 255 )
		type = -1;

	char target_name[MAX_TARGET_LENGTH];
	int target_list[PLYR], target_count;
	bool tn_is_ml;
	if( (target_count = ProcessTargetString(name, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0 ) {
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	BaseVehicle veh;
	for( int i=0 ; i<target_count ; ++i ) {
		if( !IsValidClient(target_list[i], false) )
			continue;
		
		veh = BaseVehicle(target_list[i]);
		veh.bSetOnSpawn = false;
		veh.bIsVehicle = true;
		veh.iType = type;
		veh.ConvertToVehicle();
		veh.VehHelpPanel();
				
		PrintToChat(veh.index, "[MechMercs] An Admin has forced you on a Vehicle");
		PrintToChat(client, "[MechMercs] You've force %N onto a Vehicle", target_list[i]);
	}
	return Plugin_Handled;
}
