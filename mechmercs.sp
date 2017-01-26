#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <tf2items>
#include <sdkhooks>
#include <morecolors>

#undef REQUIRE_EXTENSIONS
#tryinclude <steamtools>
#define REQUIRE_EXTENSIONS

#pragma semicolon		1
#pragma newdecls		required

#define PLUGIN_VERSION		"1.4.5 BETA"
#define CODEFRAMETIME		(1.0/30.0)	/* 30 frames per second means 0.03333 seconds pass each frame */

#define IsClientValid(%1)	( (%1) and (%1) <= MaxClients and IsClientInGame((%1)) )
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
	AllowFreeClasses = null,
	GamePlayMode = null	// Let's you change up the gamemode of the MechMercs mod
;

enum {
	SupportBuildTime,
	OffensiveBuildTime,
	HeavySupportBuildTime,
	OnEngieHitBuildTime,
	OnOfficerHitBuildTime,
	ArmoredCarGunDmg,
	MaxSMGAmmo,
	VehicleConstructHP,
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

methodmap TF2Item < Handle
{
	/* [*C*O*N*S*T*R*U*C*T*O*R*] */

	public TF2Item(int iFlags)
	{
		return view_as<TF2Item>( TF2Items_CreateItem(iFlags) );
	}
	/////////////////////////////// 

	/* [ P R O P E R T I E S ] */

	property int iFlags
	{
		public get()			{ return TF2Items_GetFlags(this); }
		public set( int iVal )		{ TF2Items_SetFlags(this, iVal); }
	}

	property int iItemIndex
	{
		public get()			{return TF2Items_GetItemIndex(this);}
		public set( int iVal )		{TF2Items_SetItemIndex(this, iVal);}
	}

	property int iQuality
	{
		public get()			{return TF2Items_GetQuality(this);}
		public set( int iVal )		{TF2Items_SetQuality(this, iVal);}
	}

	property int iLevel
	{
		public get()			{return TF2Items_GetLevel(this);}
		public set( int iVal )		{TF2Items_SetLevel(this, iVal);}
	}

	property int iNumAttribs
	{
		public get()			{return TF2Items_GetNumAttributes(this);}
		public set( int iVal )		{TF2Items_SetNumAttributes(this, iVal);}
	}
	///////////////////////////////

	/* [ M E T H O D S ] */

	public int GiveNamedItem(int iClient)
	{
		return TF2Items_GiveNamedItem(iClient, this);
	}

	public void SetClassname(char[] strClassName)
	{
		TF2Items_SetClassname(this, strClassName);
	}

	public void GetClassname(char[] strDest, int iDestSize)
	{
		TF2Items_GetClassname(this, strDest, iDestSize);
	}

	public void SetAttribute(int iSlotIndex, int iAttribDefIndex, float flValue)
	{
		TF2Items_SetAttribute(this, iSlotIndex, iAttribDefIndex, flValue);
	}

	public int GetAttribID(int iSlotIndex)
	{
		return TF2Items_GetAttributeId(this, iSlotIndex);
	}

	public float GetAttribValue(int iSlotIndex)
	{
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

	//RegAdminCmd("sm_forcevehicle",	ForcePlayerVehicle, ADMFLAG_ROOT);
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
	
	AllowFreeClasses = CreateConVar("mechmercs_allowfreevehicles", "0", "(Dis)allow vehicles to be used without requiring each team to build mainframes", FCVAR_NONE, true, 0.0, true, 1.0);
	
	GamePlayMode = CreateConVar("mechmercs_gamemode", "0", "0 - build up mode that replaces 6 other classes with unlockable vehicles, 1-gungame, 2-normal with vehicles as powerups", FCVAR_NONE, true, 0.0, true, 2.0);
	
	MMCvars[SupportBuildTime] = CreateConVar("mechmercs_support_buildtime", "60.0", "how long it takes in seconds for the Support mainframe to build unsupported.", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[OffensiveBuildTime] = CreateConVar("mechmercs_offensive_buildtime", "120.0", "how long it takes in seconds for the Offensive mainframe to build unsupported.", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[HeavySupportBuildTime] = CreateConVar("mechmercs_heavysupport_buildtime", "240.0", "how long it takes in seconds for the Heavy Support mainframe to build unsupported.", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[OnEngieHitBuildTime] = CreateConVar("mechmercs_engiehit_buildtime", "2.0", "when an engie wrench hits a mainframe, how many seconds should it take off build time?", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[OnOfficerHitBuildTime] = CreateConVar("mechmercs_officerhit_buildtime", "1.0", "when an officer melees a mainframe, how many seconds should it take off build time?", FCVAR_NONE, true, 1.0, true, 1200.0);
	
	MMCvars[ArmoredCarGunDmg] = CreateConVar("mechmercs_armoredcar_cannondmg", "40.0", "how much damage the Armored Car's 20mm cannon deals.", FCVAR_NONE, true, 0.0, true, 99999.0);
	
	MMCvars[MaxSMGAmmo] = CreateConVar("mechmercs_sidearm_ammo", "1000", "how much ammo each vehicle's sidearm (SMG or other) gets.", FCVAR_NONE, true, 0.0, true, 99999.0);
	
	MMCvars[VehicleConstructHP] = CreateConVar("mechmercs_constructhp", "500", "how much max health vehicle constructs get", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[SupportHP] = CreateConVar("mechmercs_supporthp", "1000", "how much max health the Support mainframes get", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[OffensiveHP] = CreateConVar("mechmercs_offensivehp", "1500", "how much max health the Offensive mainframes get", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[HeavySupportHP] = CreateConVar("mechmercs_heavysupporthp", "2500", "how much max health the Heavy Support mainframes get", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[AmbulanceHP] = CreateConVar("mechmercs_ambulancehp", "400", "how much max health the Ambulance vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[ArmoredCarHP] = CreateConVar("mechmercs_armoredcarhp", "600", "how much max health the Armored Car vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[KingPanzerHP] = CreateConVar("mechmercs_kingtigerhp", "2000", "how much max health the King Tiger Panzer vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[Marder3HP] = CreateConVar("mechmercs_marderhp", "500", "how much max health the Marder 3 vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[LightPanzerHP] = CreateConVar("mechmercs_lighttankhp", "750", "how much max health the Panzer 3 Light tank vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	MMCvars[Panzer4HP] = CreateConVar("mechmercs_panzer4hp", "1000", "how much max health the Panzer 4 tank vehicle gets", FCVAR_NONE, true, 1.0, true, 99999.0);
	
	AutoExecConfig(true, "Mechanized-Mercenaries");
	
	hHudText = CreateHudSynchronizer();
	manager = GameModeManager(); // In gamemodemanager.sp
	
	HookEvent("player_death", PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", PlayerHurt, EventHookMode_Pre);
	//HookEvent("player_spawn", PlayerSpawn, EventHookMode_Pre);
	HookEvent("post_inventory_application", Resupply);
	//HookEvent("player_changeclass", ChangeClass, EventHookMode_Pre);
	HookEvent("player_builtobject", ObjectBuilt);
	HookEvent("player_upgradedobject", ObjectBuilt);
	//HookEvent("teamplay_round_start", RoundStart);
	HookEvent("teamplay_round_win", RoundEnd); // 773-865-9121

	ManageDownloads(); // in handler.sp

	for (int i=MaxClients ; i ; --i) {
		if ( !IsValidClient(i) )
			continue;
		OnClientPutInServer(i);
	}
	hFields[0]=new StringMap();

#if defined _steamtools_included
	manager.bSteam = LibraryExists("SteamTools");
#endif
}

public void OnLibraryAdded(const char[] name)
{
#if defined _steamtools_included
	if (!strcmp(name, "SteamTools", false))
		manager.bSteam = true;
#endif
}
public void OnLibraryRemoved(const char[] name)
{
#if defined _steamtools_included
	if (!strcmp(name, "SteamTools", false))
		manager.bSteam = false;
#endif
}

public void OnConfigsExecuted()
{
	if ( bEnabled.BoolValue ) {
#if defined _steamtools_included
		if (manager.bSteam) {
			char gameDesc[64];
			Format(gameDesc, sizeof(gameDesc), "Mechanized Mercs (%s)", PLUGIN_VERSION);
			Steam_SetGameDescription(gameDesc);
		}
#endif
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_TraceAttack, TraceAttack);
	SDKHook(client, SDKHook_Touch, OnTouch);
	SDKHook(client, SDKHook_PreThink, OnPreThink);
	
	if (hFields[client])
		delete hFields[client];
	
	hFields[client] = new StringMap();
	// The backing fields are all from the StringMap
	BaseVehicle user = BaseVehicle(client);
	user.bIsVehicle = false;
	user.bSetOnSpawn = false;
	user.iType = -1;
	user.iSecWep = 0;
	user.iVehicleKills = 0;
	user.bNearOfficer = false;
	user.iHealth = 0;
	user.bHonkedHorn=false;
	user.flGas=0.0;
	user.flSpeed=0.0;
	user.flSoundDelay=0.0;
	user.flIdleSound=0.0;

	ManageConnect(client); // in handler.sp
}

public Action OnTouch(int client, int other) //simulate "crush, roadkill" damage
{
	if (0 < other <= MaxClients) {
		BaseVehicle player = BaseVehicle(client), victim = BaseVehicle(other);

		// make sure noot to damage players just because enemies stand on them.
		if ( player.bIsVehicle and !victim.bIsVehicle ) {
			ManageOnTouchPlayer(player, victim); // in handler.sp
		}
	}
	else if (other > MaxClients) {	// damage buildings too. Teles aren't strong enough to lift enemy vehicles
		BaseVehicle player = BaseVehicle(client);
		if (IsValidEntity(other) and player.bIsVehicle) {
			char ent[5];
			if (GetEntityClassname(other, ent, sizeof(ent)), StrContains(ent, "obj_") == 0)
			{
				if (GetEntProp(other, Prop_Send, "m_iTeamNum") != GetClientTeam(client))
					ManageOnTouchBuilding(player, other); // in handler.sp
			}
		}
	}
	return Plugin_Continue;
}
stock void CheckDownload(const char[] dlpath)
{
	if ( FileExists(dlpath) )
		AddFileToDownloadsTable(dlpath);
}

public void OnMapStart()
{
	ManageDownloads(); // in handler.sp
	CreateTimer(0.1, Timer_VehicleThink, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, Timer_GarageThink, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(5.0, MakeModelTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(120.0, Timer_Announce, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	GetCurrentMap(szCurrMap, sizeof(szCurrMap));
	// Mann vs. Machine compatibility
	if (StrContains(szCurrMap, "mvm_") != -1) {
		AllowBlu.IntValue = 0;
		AllowRed.IntValue = 1;
		manager.bisMVM = true;
	}
	// VSH game mode compatibility!
	else if (StrContains(szCurrMap, "vsh_") != -1 or StrContains(szCurrMap, "arena_") != -1)
	{
		AllowBlu.IntValue = 0;
		AllowRed.IntValue = 1;
		AllowFreeClasses.BoolValue = true;
		manager.bisVSH = true;
	}
	// Mannpower compatibility!
	if ( !strcmp(szCurrMap, "ctf_foundry", false) or !strcmp(szCurrMap, "ctf_gorge", false) or !strcmp(szCurrMap, "ctf_hellfire", false) or !strcmp(szCurrMap, "ctf_thundermountain", false) )
	{
		GamePlayMode.IntValue = 2;
	}
}
public Action Timer_Announce(Handle timer)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	CPrintToChatAll("{red}[Mechanized Mercs] {default}For Gameplay Help and Information, type '{green}!mmhelp{default}' or '{green}!mminfo{default}'; for Class help, type '{green}!mmclasshelp{default}' or '{green}!mmclassinfo{default}'.");
	
	CPrintToChatAll("{red}[Mechanized Mercs]{default} created by {green}Nergal the Ashurian{default} AKA {green}Assyrian{default} or {green}Nergal{default}. Join the Mechanized Mercs Steam Group @ {green}'http://steamcommunity.com/groups/mechmercs'{default}.");
	return Plugin_Continue;
}

public Action Timer_MakePlayerVehicle(Handle timer, any userid)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	int client = GetClientOfUserId(userid);
	if ( client and IsClientInGame(client) ) {
		BaseVehicle player = BaseVehicle(client);
		ManageHealth(player);			// in handler.sp
		ManageVehicleTransition(player);	// in handler.sp
		//SetEntPropEnt(player.index, Prop_Send, "m_hVehicle", player.index);
		if (bGasPowered.BoolValue)
			player.flGas = StartingFuel.FloatValue;
	}
	return Plugin_Continue;
}

public Action Timer_VehicleDeath(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if ( IsValidClient(client, false) ) {
		BaseVehicle player = BaseVehicle(client);
		if (player.iHealth <= 0)
			player.iHealth = 0; // ded, k!big soup rice
		ManageVehicleDeath(player); // in handler.sp
	}
	return Plugin_Continue;
}
public Action MakeModelTimer(Handle hTimer)
{
	BaseVehicle player;
	for ( int client=MaxClients ; client ; --client ) {
		if ( !IsValidClient(client, false) )
			continue;

		player = BaseVehicle(client);
		if (player.bIsVehicle) {
			if ( !IsPlayerAlive(client) )
				continue;
			ManageVehicleModels(player); // in handler.sp
		}
	}
	return Plugin_Continue;
}

public Action Timer_VehicleThink(Handle hTimer) //the main 'mechanics' of vehicles
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;
	bool forceHp = (GamePlayMode.IntValue != GunGame); // for gungame mode, there's no engineers so allow vehicles to pick up health
	BaseVehicle player;
	for ( int i=MaxClients ; i ; --i ) {
		if ( !IsValidClient(i, false) )
			continue;
		else if ( !IsPlayerAlive(i) )
			continue;

		player = BaseVehicle(i);
		if (player.bIsVehicle) {
			ManageVehicleThink(player); // in handler.sp
			if (forceHp)
				SetEntityHealth(i, player.iHealth);
		}
		else {
			if (player.bNearOfficer) //if (IsNearOfficer[i])
				TF2_AddCondition(i, TFCond_DefenseBuffed, 0.1);
		}
	}
	return Plugin_Continue;
}

/*
float lastFrameTime = 0.0;
public void OnGameFrame()
{
	if (!bEnabled.BoolValue)
		return;

	float curtime = GetGameTime();
	float deltatime = curtime - lastFrameTime;
	if ( deltatime > CODEFRAMETIME ) {
		BaseVehicle player;
		for ( int i=MaxClients ; i ; --i ) {
			if ( !IsValidClient(i, false) )
				continue;
			else if (!IsPlayerAlive(i) or IsClientObserver(i))
				continue;

			player = BaseVehicle(i);
			if (player.bIsVehicle) {
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
	if (!IsValidClient(client, false))
		return false;
	char sFlags[32]; AdminFlagByPass.GetString(sFlags, sizeof(sFlags));
	// If flags are specified and client has generic or root flag, client is immune
	return ( !StrEqual(sFlags, "") and (GetUserFlagBits(client) & (ReadFlagString(sFlags)|ADMFLAG_ROOT)) );
}


public Action ClassInfoCmd (int client, int args)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;
		
	else if (IsClientObserver(client) or !IsPlayerAlive(client))
		return Plugin_Handled;

	BaseFighter(client).HelpPanel();
	return Plugin_Handled;
}

public Action GameInfoCmd(int client, int args)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;
	
	else if ( IsVoteInProgress() )
		return Plugin_Handled;

	Panel panel = new Panel();
	switch (GamePlayMode.IntValue) {
		case Normal: {
			char helpstr[] = "Welcome to Mechanized Mercs, TF2's Combat Vehicles Mod!\nMechanized Mercs is a gameplay mod where 6 of the 9 classes are replaced with combat vehicles.\nThe only human classes are Soldier, Engineer, and Officer (Spy).\nThe Available Vehicles are: the Armored Car, Ambulance, Panzer II, Panzer IV, Tiger II, and Marder 2 Tank Hunter\nOfficer and Engineer are for supporting roles.\nOfficers support Infantry whilst Engineers support friendly Vehicles.\nEngineers can build Mainframes using !base to unlock the Vehicle classes.";
			panel.SetTitle(helpstr);
		}
		case Powerup: {
			char helpstr[] = "Welcome to Mechanized Mercs, TF2's Combat Vehicles Mod!\nMechanized Mercs is a gameplay mod where Mannpower Powerups and Random Health or Ammo kits are replaced with Combat Vehicles!\nEngineers are also able to build vehicles using the !vehicle command.\nEach respective vehicle has a specific metal cost required for it to be actively useable.\nAll Vehicle constructs have 500 health until they're activated, build them in a safe spot!\nTo use the Combat Vehicles, simply Jump on top of them or touch them while pressing RELOAD.\nBe careful as enemies can steal any vehicle your team produces.";
			panel.SetTitle(helpstr);
		}
		case GunGame: {
			char helpstr[] = "Welcome to Mechanized Mercs, TF2's Combat Vehicles Mod!\nMechanized Mercs is a gameplay mod where you start out as an Armored Car and you must kill other Combat Vehicles to become stronger! Pretty much Gun Game but with Vehicles instead.\nArmored Car is the most useful yet weakest while the Destroyer is the most powerful!";
			panel.SetTitle(helpstr);
		}
	}
	panel.DrawItem( "Exit" );
	panel.Send(client, HintPanel, 99);
	delete (panel);
	
	return Plugin_Handled;
}

public Action SpawnVehicleGarageMenu (int client, int args)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	else if (IsClientObserver(client) or !IsPlayerAlive(client))
	{
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}You Need to be Alive to become Vehicles, build Vehicles, or Vehicle Mainframes.");
		return Plugin_Handled;
	}
	else if (GamePlayMode.IntValue != GunGame and BaseFighter(client).Class != TFClass_Engineer)
	{
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}You Need to be an Engineer to build Vehicles or Vehicle Mainframes.");
		return Plugin_Handled;
	}
	else if ( GameRules_GetRoundState() == RoundState_Preround or GameRules_GetProp("m_bInSetup") )
	{
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build Vehicles or Vehicle Mainframes yet...");
		return Plugin_Handled;
	}
	
	switch (GamePlayMode.IntValue) {
		case Normal: {
			Menu bases = new Menu( MenuHandler_BuildGarage );
			bases.AddItem("2", "Support Vehicle Mainframe: Unlocks the Scout Car and Ambulance vehicles");
			bases.AddItem("4", "Offensive Vehicle Mainframe: Unlocks the Panzer II and Panzer IV vehicles");
			bases.AddItem("8", "Heavy Support Vehicle Mainframe: Unlocks the King Panzer and Tank Destroyer vehicles");
			bases.Display(client, MENU_TIME_FOREVER);
		}
		case Powerup: {
			Menu tankers = new Menu( MenuHandler_MakeTankPowUp );
			tankers.AddItem("2", "Ambulance: Heals everybody in Area of Effect radius, 400 HP. Costs 600 Metal");
			tankers.AddItem("1", "Armored Car: Armed w/ Machinegun and 20mm Cannon, 600 HP. Costs 2,000 Metal");
			tankers.AddItem("3", "Panzer II: Armed w/ Flamethrower and HE, Arcing Rockets, 750 HP. Costs 3,000 Metal");
			tankers.AddItem("0", "Panzer IV: Armed w/ Machinegun and Mouse2 Rockets, 1000 HP. Costs 4,000 Metal");
			tankers.AddItem("4", "King Tiger II: Armed w/ Machinegun and Mouse2 Rockets, 2000 HP. Costs 5,000 Metal");
			tankers.AddItem("5", "Marder II: Armed w/ 700 DMG Anti-Tank Rockets, 500 HP. Costs 3,000 Metal");
			tankers.Display(client, MENU_TIME_FOREVER);
		}
		case GunGame: {
			Menu tankers = new Menu( MenuHandler_GoTank );
			tankers.AddItem("1", "Armored Car: Armed w/ Machinegun and 40-DMG 20mm Cannon, 600 HP. Can Capture and Self-Heal");
			int vehkills = BaseVehicle(client).iVehicleKills;
			if (vehkills >= 5)
				tankers.AddItem("3", "Panzer II: Armed w/ Flamethrower and HE, Arcing Rockets, 750 HP.");
			if (vehkills >= 10)
				tankers.AddItem("0", "Panzer IV: Armed w/ Machinegun and Mouse2 Rockets, 1000 HP.");
			if (vehkills >= 15)
				tankers.AddItem("5", "Marder II: Armed w/ 700 DMG Anti-Tank Rockets, 500 HP.");
			if (vehkills >= 20)
				tankers.AddItem("4", "King Tiger II: Armed w/ Machinegun and Mouse2 Rockets, 2000 HP.");
			tankers.Display(client, MENU_TIME_FOREVER);
		}
	}
	return Plugin_Handled;
}
public int MenuHandler_GoTank(Menu menu, MenuAction action, int client, int select)
{
	if (IsClientObserver(client))
		return;
	
	char info1[16]; menu.GetItem(select, info1, sizeof(info1));
	if (action == MenuAction_Select) {
		BaseVehicle player = BaseVehicle(client);
		player.iType = StringToInt(info1);
	}
	else if (action == MenuAction_End)
		delete menu;
}
public bool TraceFilterIgnorePlayers(int entity, int contentsMask, any client)
{
	return ( !(entity and entity <= MaxClients) );
}
public int MenuHandler_MakeTankPowUp(Menu menu, MenuAction action, int client, int select)
{
	if (BaseFighter(client).Class != TFClass_Engineer or IsClientObserver(client) or !IsPlayerAlive(client))
		return;
	
	else if (manager.IsPowerupFull(GetClientTeam(client))) {
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}Your team has too many built vehicles!");
		return;
	}
	else if (BaseVehicle(client).bIsVehicle) {
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build Vehicles as a Vehicle!");
		return;
	}
	
	char info1[16]; menu.GetItem(select, info1, sizeof(info1));
	if (action == MenuAction_Select) {
		//BaseVehicle player = BaseVehicle(client);
		int vehicletype = StringToInt(info1);
		int team = GetClientTeam(client);
		
		float flEyePos[3], flAng[3];
		GetClientEyePosition(client, flEyePos);
		GetClientEyeAngles(client, flAng);

		TR_TraceRayFilter( flEyePos, flAng, MASK_SOLID, RayType_Infinite, TraceFilterIgnorePlayers, client );

		if ( TR_GetFraction() < 1.0 ) {
			float flEndPos[3]; TR_GetEndPosition(flEndPos);
			{
				float spawnPos[3];
				int iEnt = -1;
				while ( (iEnt = FindEntityByClassname(iEnt, "info_player_teamspawn")) != -1 )
				{
					if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") != team)
						continue;

					spawnPos = Vec_GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin");
					if ( GetVectorDistance(flEndPos, spawnPos) <= 650.0 ) {
						CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Vehicle near Spawn!");
						SpawnVehicleGarageMenu(client, -1);
						return;
					}
				}
				if (TR_PointOutsideWorld(flEndPos)) {
					CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Vehicle Mainframe outside the Playable Area!");
					SpawnVehicleGarageMenu(client, -1);
					return;
				}
			}
			GetClientAbsAngles(client, flAng); flAng[1] += 90.0;
			manager.SpawnTankConstruct(client, flEndPos, team, vehicletype);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}

public Action OnConstructTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsValidClient(attacker))
		return Plugin_Continue;
	
	int team = GetClientTeam(attacker);
	if ( team == GetEntProp(victim, Prop_Data, "m_iTeamNum") ) {
		damage = 0.0;
		
		char tName[64]; GetEntPropString(victim, Prop_Data, "m_iName", tName, sizeof(tName));

		char classname[64];
		if ( IsValidEdict(weapon) )
			GetEdictClassname(weapon, classname, sizeof(classname));
		
		int index = manager.FindEntityPowerUpIndex(team, victim);
		if (index == -1) {
			//CPrintToChat(attacker, "{red}[Mechanized Mercs] {white}OnConstructTakeDamage::Logic Error.");
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(victim) );
			return Plugin_Continue;
		}

		if ( !strcmp(classname, "tf_weapon_wrench", false) or !strcmp(classname, "tf_weapon_robot_arm", false) )
		{
			int iCurrentMetal = GetEntProp(attacker, Prop_Data, "m_iAmmo", 4, 3);
			int FixAdd = 25;
			if ( iCurrentMetal ) {
				if (iCurrentMetal < FixAdd)
					FixAdd = iCurrentMetal;

				TankConstruct[team-2][index][3] += FixAdd;	// Takes 7 seconds with Jag to put in 200 metal
				SetEntProp(attacker, Prop_Data, "m_iAmmo", iCurrentMetal-FixAdd, 4, 3);
				EmitSoundToClient(attacker, "ui/item_store_add_to_cart.wav");
			}
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
public Action OnConstructTouch(int item, int other)
{
	if (0 < other <= MaxClients) {
		int team;
		int index = manager.FindEntityPowerUpIndex(3, item);
		if (index == -1) {
			index = manager.FindEntityPowerUpIndex(2, item);
			if (index == -1) {
				//CPrintToChat(other, "{red}[Mechanized Mercs] {white}OnConstructTouch::Logic Error.");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(item) );
				return Plugin_Continue;
			}
			else team = 2;
		}
		else team = 3;
		
		int metalcost;
		switch ( TankConstruct[team-2][index][1] ) {
			case Tank:			metalcost = 4000;
			case ArmoredCar:		metalcost = 2000;
			case Ambulance:			metalcost = 600;
			case KingPanzer:		metalcost = 5000;
			case PanzerIII, Destroyer:	metalcost = 3000;
		}
		if (TankConstruct[team-2][index][3] >= metalcost) {
			SetHudTextParams(0.93, -1.0, 0.1, 0, 255, 0, 255);
			ShowHudText(other, -1, "Press RELOAD to Enter the Vehicle!");
			if (GetClientButtons(other) & IN_RELOAD) {
				BaseVehicle toucher = BaseVehicle(other);
				toucher.iType = TankConstruct[team-2][index][1];
				toucher.bIsVehicle = true;
				toucher.ConvertToVehicle();
				toucher.VehHelpPanel();
				float VehLoc[3]; VehLoc = Vec_GetEntPropVector(item, Prop_Data, "m_vecAbsOrigin");
				TeleportEntity(other, VehLoc, NULL_VECTOR, NULL_VECTOR);
				
				CreateTimer( 0.1, RemoveEnt, TankConstruct[team-2][index][0] );
				TankConstruct[team-2][index][0] = 0;
			}
		}
	}
	return Plugin_Continue;
}

public int MenuHandler_BuildGarage(Menu menu, MenuAction action, int client, int select)
{
	if (BaseFighter(client).Class != TFClass_Engineer or IsClientObserver(client) or !IsPlayerAlive(client))
		return;

	else if (GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3) < 200) {
		CPrintToChat(client, "{red}[Mechanized Mercs] {white}You need 200 Metal to build a Mainframe.");
		SpawnVehicleGarageMenu(client, -1);
		return;
	}
	char info1[16]; menu.GetItem(select, info1, sizeof(info1));
	if (action == MenuAction_Select) {
		//BaseVehicle player = BaseVehicle(client);
		int garageflag = StringToInt(info1);
		int team = GetClientTeam(client);
		int offset = FlagtoOffset(garageflag);	// in gamemodemanager.sp

		if ( GarageRefs[team-2][offset] and IsValidEntity(EntRefToEntIndex(GarageRefs[team-2][offset])) ) {
			CPrintToChat(client, "{red}[Mechanized Mercs] {white}The Mainframe you've selected has already been built.");
			SpawnVehicleGarageMenu(client, -1);
			return;
		}

		float flEyePos[3], flAng[3];
		GetClientEyePosition(client, flEyePos);
		GetClientEyeAngles(client, flAng);

		TR_TraceRayFilter( flEyePos, flAng, MASK_SOLID, RayType_Infinite, TraceFilterIgnorePlayers, client );

		if ( TR_GetFraction() < 1.0 ) {
			float flEndPos[3]; TR_GetEndPosition(flEndPos);
			{
				float spawnPos[3];
				int iEnt = -1;
				while ( (iEnt = FindEntityByClassname(iEnt, "info_player_teamspawn")) != -1 )
				{
					if (GetEntProp(iEnt, Prop_Send, "m_iTeamNum") != team)
						continue;

					spawnPos = Vec_GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin");
					if ( GetVectorDistance(flEndPos, spawnPos) <= 650.0 ) {
						CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Vehicle Mainframe near Spawn!");
						SpawnVehicleGarageMenu(client, -1);
						return;
					}
				}
				if (TR_PointOutsideWorld(flEndPos)) {
					CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build a Vehicle Mainframe outside the Playable Area!");
					SpawnVehicleGarageMenu(client, -1);
					return;
				}
			}
			GetClientAbsAngles(client, flAng); //flAng[1] += 90.0;

			int pStruct = CreateEntityByName("prop_dynamic_override");
			if ( pStruct <= 0 or !IsValidEdict(pStruct) )
				return;
			
			char tName[32]; tName[0] = '\0';
			
			char szModelPath[PLATFORM_MAX_PATH];
			switch (garageflag) {
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

			if ( CanBuildHere(flEndPos, mins, maxs) ) {
				DispatchSpawn(pStruct);
				SetEntProp( pStruct, Prop_Send, "m_nSolidType", 6 );
				TeleportEntity(pStruct, flEndPos, flAng, NULL_VECTOR);

				int beamcolor[4] = {0, 255, 90, 255};

				float vecMins[3], vecMaxs[3];
				mins = Vec_GetEntPropVector(pStruct, Prop_Send, "m_vecMins");
				maxs = Vec_GetEntPropVector(pStruct, Prop_Send, "m_vecMaxs");

				vecMins = Vec_AddVectors(flEndPos, mins); //AddVectors(flEndPos, mins, vecMins);
				vecMaxs = Vec_AddVectors(flEndPos, maxs); //AddVectors(flEndPos, maxs, vecMaxs);

				int laser = PrecacheModel("sprites/laser.vmt", true);
				TE_SendBeamBoxToAll( vecMaxs, vecMins, laser, laser, 1, 1, 5.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );

				SetEntProp(pStruct, Prop_Data, "m_takedamage", 2, 1);
				SDKHook(pStruct, SDKHook_OnTakeDamage, OnGarageTakeDamage);
				SDKHook(pStruct, SDKHook_ShouldCollide, OnGarageCollide);
				
				int iGlow = CreateEntityByName("tf_taunt_prop");
				if (iGlow != -1) {
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
				switch (team) {
					case 2:	SetEntityRenderColor(pStruct, 255, 30, 30, 255);	// RED
					case 3:	SetEntityRenderColor(pStruct, 30, 150, 255, 255);	// BLU
				}

				if ( IsValidEntity(pStruct) and IsValidEdict(pStruct) ) {
					int baseid = EntIndexToEntRef(pStruct);
					switch ( garageflag ) {
						case SUPPORTBUILT:	GarageBuildTime[team-2][offset] = MMCvars[SupportBuildTime].FloatValue;
						case OFFENSIVEBUILT:	GarageBuildTime[team-2][offset] = MMCvars[OffensiveBuildTime].FloatValue;
						case HEAVYBUILT:	GarageBuildTime[team-2][offset] = MMCvars[HeavySupportBuildTime].FloatValue;
					}
					GarageRefs[team-2][offset] = baseid;
					for (int i=MaxClients ; i ; --i) {
						if (!IsValidClient(i))
							continue;
						else if (GetClientTeam(i) != team)
							continue;

						switch (garageflag) {
							case SUPPORTBUILT:	CPrintToChat(i, "{red}[Mechanized Mercs] {white}Support Mainframe Built, Will activate in 1 Minute.");
							case OFFENSIVEBUILT:	CPrintToChat(i, "{red}[Mechanized Mercs] {white}Offense Mainframe Built, Will activate in 2 Minutes.");
							case HEAVYBUILT:	CPrintToChat(i, "{red}[Mechanized Mercs] {white}Heavy Support Mainframe Built, Will activate in 4 Minutes");
						}
					}
					SetEntProp(client, Prop_Data, "m_iAmmo", 0, 4, 3);
				}
			}
			else {
				CPrintToChat(client, "{red}[Mechanized Mercs] {white}You can't build that Vehicle Mainframe there.");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(pStruct) );
				SpawnVehicleGarageMenu(client, -1);
			}
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}


#define CONTENTS_REDTEAM			0x800
#define CONTENTS_BLUTEAM			0x1000
#define COLLISION_GROUP_PLAYER_MOVEMENT		8

public bool OnGarageCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	if ( entity and IsValidEntity(entity) ) {
		int ent_team = GetEntProp( entity, Prop_Send, "m_iTeamNum" );
		char tName[64]; GetEntPropString(entity, Prop_Data, "m_iName", tName, sizeof(tName));
		
		if ( collisiongroup == COLLISION_GROUP_PLAYER_MOVEMENT and StrContains(tName, "mechmercs_garage", false) != -1) {
			switch ( ent_team ) {	// Do collisions by team
				case 2: if ( !(contentsmask & CONTENTS_REDTEAM) ) return false;
				case 3: if ( !(contentsmask & CONTENTS_BLUTEAM) ) return false;
			}
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
		for ( int i=0 ; i < target_count ; i++ )
			if ( IsValidClient(target_list[i], false) )
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
	if ( IsClientObserver(client) )
		return;
	
	if (GamePlayMode.IntValue == Powerup) {
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
			
			int metalcost;
			switch ( TankConstruct[team-2][index][1] ) {
				case Tank:			metalcost = 4000;
				case ArmoredCar:		metalcost = 2000;
				case Ambulance:			metalcost = 600;
				case KingPanzer:		metalcost = 5000;
				case PanzerIII, Destroyer:	metalcost = 3000;
			}
			SetHudTextParams(0.93, -1.0, 0.1, 0, 255, 0, 255);
			if (TankConstruct[team-2][index][3] < metalcost)
				ShowHudText(client, -1, "Metal Progress for Vehicle: %i / %i\nVehicle Health: %i", TankConstruct[team-2][index][3], metalcost, GetEntProp(entity, Prop_Data, "m_iHealth"));
			else ShowHudText(client, -1, "Vehicle is Ready to Board!");
		}
	}

	BaseVehicle player = BaseVehicle(client);
	if (player.bIsVehicle) {
		if ( IsNearSpencer(client) )
			ManageVehicleNearDispenser(player); // in handler.sp
		
		for ( int i=MaxClients ; i ; --i ) {
			if ( !IsValidClient(i, false) )
				continue;

			else if ( client == GetHealingTarget(i) )
				ManageVehicleMedigunHeal(player, BaseVehicle(i)); // in handler.sp
		}
		if (bGasPowered.BoolValue)
			player.UpdateGas();
	}
	else {
		if (GamePlayMode.IntValue == Powerup)
			return;

		BaseVehicle human = BaseVehicle(client);
		for ( int i=MaxClients ; i ; --i ) {
			if ( !IsValidClient(i, false) )
				continue;
			else if ( !IsPlayerAlive(i) or GetClientTeam(i) != GetClientTeam(client) or i == client )
				continue;
			human = BaseVehicle(i);
			// 320 in Hammer units is 20 feet, do NOT let vehicles get buffed by Officer
			if ( IsInRange(client, i, 320.0, false) and human.Class == TFClass_Spy ) {
				if (!human.bNearOfficer)
					human.bNearOfficer = true;
				//if (!IsNearOfficer[client])
					//IsNearOfficer[client] = true;
				// IDEA: Have officer be able to turn into a Command vehicle to give buffs for vehicles and humans alike.
			}
			else {
				if (human.bNearOfficer)
					human.bNearOfficer = false;
				//if (IsNearOfficer[client])
					//IsNearOfficer[client] = false;
			}
		}
	}
}
public Action TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	if ( IsClientValid(attacker) and IsClientValid(victim) ) {
		/* this is basically the same code from my Advanced armor plugin but with the difference of making it work for the vehicle classes */
		if (GetClientTeam(attacker) == GetClientTeam(victim)) {
			if (TF2_GetPlayerClass(attacker) == TFClass_Engineer and HealthFromEngies.BoolValue and BaseVehicle(victim).bIsVehicle)
			{
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
	if (!bEnabled.BoolValue)
		return Plugin_Continue;
	else if ( !IsValidClient(victim, false) )
		return Plugin_Continue;

	BaseVehicle vehVictim = BaseVehicle(victim);
	BaseVehicle vehAttacker = BaseVehicle(attacker);

	if (vehVictim.bIsVehicle) {	// in handler.sp
		if (vehAttacker.bNearOfficer) //if (IsNearOfficer[attacker])
			damage *= 1.2;
		return ManageOnVehicleTakeDamage(vehVictim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
	}
	if (damagetype & DMG_CRIT)
		return Plugin_Continue; //this prevents damage fall off applying to crits
	
	if (attacker < 1)
		return Plugin_Continue;
	
	if (vehAttacker.bIsVehicle)	// in handler.sp
		return ManageOnVehicleDealDamage(vehVictim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);

	return Plugin_Continue;
}
public Action OnGarageTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsValidClient(attacker))
		return Plugin_Continue;
	
	int team = GetClientTeam(attacker);
	if ( team == GetEntProp(victim, Prop_Data, "m_iTeamNum") ) {
		damage = 0.0;
		int maxhp, offset;
		char tName[64]; GetEntPropString(victim, Prop_Data, "m_iName", tName, sizeof(tName));
		
		if (StrContains(tName, "mechmercs_garage_support") != -1)
			{maxhp = 1000; offset = SUPPORTGARAGE;}
		else if (StrContains(tName, "mechmercs_garage_offense") != -1)
			{maxhp = 1500; offset = OFFENSEGARAGE;}
		else if (StrContains(tName, "mechmercs_garage_heavy") != -1)
			{maxhp = 2500; offset = HEAVYGARAGE;}

		int iCurrentMetal = GetEntProp(attacker, Prop_Data, "m_iAmmo", 4, 3);
		int repairamount = HealthFromMetal.IntValue;	//default 10
		int mult = HealthFromMetalMult.IntValue;	//default 10
		int flag = OffsetToFlag(offset);	// in gamemodemanager.sp

		char classname[64];
		if ( IsValidEdict(weapon) )
			GetEdictClassname(weapon, classname, sizeof(classname));

		if ( !strcmp(classname, "tf_weapon_wrench", false) or !strcmp(classname, "tf_weapon_robot_arm", false) )
		{
			int health = GetEntProp(victim, Prop_Data, "m_iHealth");
			// PATCH: only be able to fix mainframes that are fully built.
			if ( (GarageFlags[team-2] & flag) and health < maxhp and iCurrentMetal > 0) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;

				if ( maxhp-health < repairamount*mult )
					repairamount = RoundToCeil( float((maxhp - health)/mult) );

				if (repairamount < 1 and iCurrentMetal)
					repairamount = 1;

				health += repairamount*mult;

				if (health > maxhp)
					health = maxhp;

				iCurrentMetal -= repairamount;
				SetEntProp(attacker, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
				SetEntProp(victim, Prop_Data, "m_iHealth", health);
				EmitSoundToClient(attacker, "ui/item_store_add_to_cart.wav");
			}
			if (GarageBuildTime[team-2][offset] > 0.0) {
				GarageBuildTime[team-2][offset] -= MMCvars[OnEngieHitBuildTime].FloatValue;
				EmitSoundToClient(attacker, "ui/item_store_add_to_cart.wav", _, SNDCHAN_AUTO, _, _, _, 80);
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
		*/
		else if (TF2_GetPlayerClass(attacker) == TFClass_Spy and weapon == GetPlayerWeaponSlot(attacker, 2))
		{
			if (GarageBuildTime[team-2][offset] > 0.0) {
				GarageBuildTime[team-2][offset] -= MMCvars[OnOfficerHitBuildTime].FloatValue;
				EmitSoundToClient(attacker, "ui/item_store_add_to_cart.wav", _, SNDCHAN_AUTO, _, _, _, 80);
			}
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action RemoveEnt(Handle timer, any entid)
{
	int ent = EntRefToEntIndex(entid);
	if (ent and IsValidEntity(ent))
		AcceptEntityInput(ent, "Kill");
	return Plugin_Continue;
}
/*
When using intended garage models, have going inside the garages heal and rearm the respective vehicle.
*/
public Action Timer_GarageThink(Handle timer)
{
	if ( !bEnabled.BoolValue or GamePlayMode.IntValue )
		return Plugin_Continue;

	int garage, /*owner,*/ health[2][3], buildinghp[3];
	for ( int team=0 ; team<2 ; ++team ) {
		for (int offset=0 ; offset<3 ; ++offset) {
			garage = manager.GetGarage(team, offset);
			if ( !GarageRefs[team][offset] ) {
				if (GarageGlowRefs[team][offset])
					CreateTimer( 0.1, RemoveEnt, GarageGlowRefs[team][offset] );
				GarageGlowRefs[team][offset] = 0;
				manager.DeleteGarage(team, OffsetToFlag(offset));
				continue;
			}
			else if ( !IsValidEntity(garage) or !IsValidEdict(garage) ) {
				if ( GarageRefs[team][offset] )
					GarageRefs[team][offset] = 0;	// If the index has a true entry but still invalid, set to 0

				if (GarageGlowRefs[team][offset])
					CreateTimer( 0.1, RemoveEnt, GarageGlowRefs[team][offset] );
				GarageGlowRefs[team][offset] = 0;
				manager.DeleteGarage(team, OffsetToFlag(offset));
				continue;
			}

			// If the owner engineer disconnects OR changes team, kill the garage
			/*
			owner = GetOwner(garage);
			if ( owner <= 0 ) {
				CreateTimer( 0.1, RemoveEnt, GarageGlowRefs[team][offset] );
				GarageGlowRefs[team][offset] = 0;

				CreateTimer( 0.1, RemoveEnt, GarageRefs[team][offset] );
				GarageRefs[team][offset] = 0;
				manager.DeleteGarage(team, OffsetToFlag(offset));
				continue;
			}
			else if ( GetClientTeam(owner) != GetEntProp(garage, Prop_Data, "m_iTeamNum") )
			{
				CreateTimer( 0.1, RemoveEnt, GarageRefs[team][offset] );
				GarageRefs[team][offset] = 0;
				manager.DeleteGarage(team, OffsetToFlag(offset));
				continue;
			}
			*/
			health[team][offset] = GetEntProp(garage, Prop_Data, "m_iHealth");
			
			if (GarageBuildTime[team][offset] <= 0.0) {
				int flag = OffsetToFlag(offset);
				if (GarageFlags[team] & flag) {
					continue;
				}
				else {
					GarageFlags[team] |= flag;
					switch ( flag ) {
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
	for (int i=MaxClients ; i ; --i) {
		if ( !IsValidClient(i, false) )
			continue;
		else if ( GetClientButtons(i) & IN_SCORE )
			continue;

		team = GetClientTeam(i)-2;
		switch (team) {
			case 0: { buildinghp[0] = health[team][0]; buildinghp[1] = health[team][1]; buildinghp[2] = health[team][2]; }
			case 1: { buildinghp[0] = health[team][0]; buildinghp[1] = health[team][1]; buildinghp[2] = health[team][2]; }
		}
		buildingflag = manager.GetGarageRefFlags(team);
		supporttime = RoundFloat(GarageBuildTime[team][SUPPORTGARAGE]);
		offensetime = RoundFloat(GarageBuildTime[team][OFFENSEGARAGE]);
		heavytime = RoundFloat(GarageBuildTime[team][HEAVYGARAGE]);

		SetHudTextParams(0.93, -1.0, 0.1, 0, 255, 0, 255);
		switch (GarageFlags[team]) {
			case 14: ShowHudText(i, -1, "Support Mainframe Online: Health %i\nOffensive Mainframe Online: Health %i\nHeavy Support Mainframe Online: Health %i", buildinghp[0], buildinghp[1], buildinghp[2]);
			case 12: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Mainframe Online in %i Seconds\nOffensive Mainframe Online: Health %i\nHeavy Support Mainframe Online: Health %i", supporttime, buildinghp[1], buildinghp[2]);
					continue;
				}
				ShowHudText(i, -1, "Offensive Mainframe Online: Health %i\nHeavy Support Mainframe Online: Health %i", buildinghp[1], buildinghp[2]);
			}
			case 10: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Mainframe Online: Health %i\nOffensive Mainframe Online in %i Seconds\nHeavy Support Mainframe Online: Health %i", buildinghp[0], offensetime, buildinghp[2]);
					continue;
				}
				ShowHudText(i, -1, "Support Mainframe Online: Health %i\nHeavy Support Mainframe Online: Health %i", buildinghp[0], buildinghp[2]);
			}
			case 8: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Mainframe Online in %i Seconds\nOffensive Mainframe Online in %i Seconds\nHeavy Support Mainframe Online: Health %i", supporttime, offensetime, buildinghp[2]);
					continue;
				}
				else if (buildingflag == 12) {
					ShowHudText(i, -1, "Offensive Mainframe Online in %i Seconds\nHeavy Support Mainframe Online: Health %i", offensetime, buildinghp[2]);
					continue;
				}
				else if (buildingflag == 10) {
					ShowHudText(i, -1, "Support Mainframe Online in %i Seconds\nHeavy Support Mainframe Online: Health %i", supporttime, buildinghp[2]);
					continue;
				}
				ShowHudText(i, -1, "Heavy Support Mainframe Online: Health %i", buildinghp[2]);
			}
			case 6: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Mainframe Online: Health %i\nOffensive Mainframe Online: Health %i\nHeavy Support Mainframe Online in %i Seconds", buildinghp[0], buildinghp[1], heavytime);
					continue;
				}
				ShowHudText(i, -1, "Support Mainframe Online: Health %i\nOffensive Mainframe Online: Health %i", buildinghp[0], buildinghp[1]);
			}
			case 4: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Mainframe Online in %i Seconds\nOffensive Mainframe Online: Health %i\nHeavy Support Mainframe Online in %i Seconds", supporttime, buildinghp[1], heavytime);
					continue;
				}
				else if (buildingflag == 12) {
					ShowHudText(i, -1, "Offensive Mainframe Online: Health %i\nHeavy Support Mainframe Online in %i Seconds", buildinghp[1], heavytime);
					continue;
				}
				else if (buildingflag == 6) {
					ShowHudText(i, -1, "Support Mainframe Online in %i Seconds\nOffensive Mainframe Online: Health %i", supporttime, buildinghp[1]);
					continue;
				}
				ShowHudText(i, -1, "Offensive Mainframe Online: Health %i", buildinghp[1]);
			}
			case 2: {
				if (buildingflag == 14) {
					ShowHudText(i, -1, "Support Mainframe Online: Health %i\nOffensive Mainframe Online in %i Seconds\nHeavy Support Mainframe Online in %i Seconds", buildinghp[0], offensetime, heavytime);
					continue;
				}
				else if (buildingflag == 10) {
					ShowHudText(i, -1, "Support Mainframe Online: Health %i\nHeavy Support Mainframe Online in %i Seconds", buildinghp[0], heavytime);
					continue;
				}
				else if (buildingflag == 6) {
					ShowHudText(i, -1, "Support Mainframe Online: Health %i\nOffensive Mainframe Online in %i Seconds", buildinghp[0], offensetime);
					continue;
				}
				ShowHudText(i, -1, "Support Mainframe Online: Health %i", buildinghp[0]);
			}
			case 0: {
				switch (buildingflag) {
					case 2: ShowHudText(i, -1, "Support Mainframe Online in %i Seconds", supporttime);
					case 4: ShowHudText(i, -1, "Offensive Mainframe Online in %i Seconds", offensetime);
					case 6: ShowHudText(i, -1, "Support Mainframe Online in %i Seconds\nOffensive Mainframe Online in %i Seconds", supporttime, offensetime);
					case 8: ShowHudText(i, -1, "Heavy Support Mainframe Online in %i Seconds", heavytime);
					case 10: ShowHudText(i, -1, "Support Mainframe Online in %i Seconds\nHeavy Support Mainframe Online in %i Seconds", supporttime, heavytime);
					case 12: ShowHudText(i, -1, "Offensive Mainframe Online in %i Seconds\nHeavy Support Mainframe Online in %i Seconds", offensetime, heavytime);
					case 14: ShowHudText(i, -1, "Support Mainframe Online in %i Seconds\nOffensive Mainframe Online in %i Seconds\nHeavy Support Mainframe Online in %i Seconds", supporttime, offensetime, heavytime);
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
			
			if (GamePlayMode.IntValue == Powerup) {
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
	if (!bEnabled.BoolValue or !IsValidEntity(entity))
		return;

	if ( GamePlayMode.IntValue == Powerup and StrContains(classname, "rune") != -1 )
		SDKHook(entity, SDKHook_SpawnPost, HookPowerup);
}

public void HookPowerup(int entity)
{
	float vecOrigin[3]; vecOrigin = Vec_GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin");
	CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(entity) );
	//vecOrigin[2] += 5.0;
	manager.SpawnTankPowerup(vecOrigin, GetRandomInt(Tank, Destroyer));
}


/*************************************************/
/******************* STOCKS **********************/
/*************************************************/
stock int GetHealingTarget(const int client)
{
	int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if (!IsValidEdict(medigun) or !IsValidEntity(medigun))
		return -1;

	char s[32]; GetEdictClassname(medigun, s, sizeof(s));
	if ( !strcmp(s, "tf_weapon_medigun", false) ) {
		if ( GetEntProp(medigun, Prop_Send, "m_bHealing") )
			return GetEntPropEnt( medigun, Prop_Send, "m_hHealingTarget" );
	}
	return -1;
}
stock bool IsNearSpencer(const int client)
{
	int medics=0;
	for ( int i=MaxClients ; i ; --i ) {
		if (!IsValidClient(i))
			continue;
		else if ( GetHealingTarget(i) == client )
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
	if ( !AllowBlu.BoolValue and GetClientTeam(client) == 3 )
		return true;
	return false;
}

stock bool IsRedBlocked(const int client)
{
	if ( !AllowRed.BoolValue and GetClientTeam(client) == 2 )
		return true;
	return false;
}
stock int GetOwner(const int ent)
{
	if ( IsValidEdict(ent) and IsValidEntity(ent) )
		return GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	return -1;
}
stock void DoExplosion(const int owner, const int damage, const int radius, const float pos[3])
{
	int explode = CreateEntityByName("env_explosion");
	if ( !IsValidEntity(explode) )
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

public TFClassType GetRandomClass(const int team)	// 0, 1 return support garage vehicles, 2, 3 returns offensive, 4, 5 returns heavy
{
	switch ( manager.GaragesBuilt(team) )
	{
		case 14: {	// check if ALL the garages are built for that team
			switch ( GetRandomInt(0, 8) ) {		// since all garages are built, randomly pick up to 8
				case 0: return TFClass_Soldier;
				case 1: return TFClass_Spy;
				case 2: return TFClass_Engineer;

				case 3: return TFClass_Scout;
				case 4: return TFClass_Medic;

				case 5: return TFClass_Pyro;
				case 6: return TFClass_DemoMan;

				case 7: return TFClass_Heavy;
				case 8: return TFClass_Sniper;
			}
		}
		case 12: { // heavy support and offensive garage built, no support garage
			switch ( GetRandomInt(0, 6) ) {
				case 0: return TFClass_Soldier;
				case 1: return TFClass_Spy;
				case 2: return TFClass_Engineer;

				case 3: return TFClass_Pyro;
				case 4: return TFClass_DemoMan;

				case 5: return TFClass_Heavy;
				case 6: return TFClass_Sniper;
			}
		}
		case 10: { // heavy support and support garage built, no offensive garage
			switch ( GetRandomInt(0, 6) ) {
				case 0: return TFClass_Soldier;
				case 1: return TFClass_Spy;
				case 2: return TFClass_Engineer;

				case 3: return TFClass_Scout;
				case 4: return TFClass_Medic;

				case 5: return TFClass_Heavy;
				case 6: return TFClass_Sniper;
			}
		}
		case 8: { // only heavy support garage built
			switch ( GetRandomInt(0, 4) )
			{
				case 0: return TFClass_Soldier;
				case 1: return TFClass_Spy;
				case 2: return TFClass_Engineer;

				case 3: return TFClass_Heavy;
				case 4: return TFClass_Sniper;
			}
		}
		case 6: { // support and offensive garage built, no heavy support
			switch ( GetRandomInt(0, 6) ) {
				case 0: return TFClass_Soldier;
				case 1: return TFClass_Spy;
				case 2: return TFClass_Engineer;

				case 3: return TFClass_Scout;
				case 4: return TFClass_Medic;

				case 5: return TFClass_Pyro;
				case 6: return TFClass_DemoMan;
			}
		}
		case 4: { // offensive garage built only
			switch ( GetRandomInt(0, 4) ) {
				case 0: return TFClass_Soldier;
				case 1: return TFClass_Spy;
				case 2: return TFClass_Engineer;

				case 3: return TFClass_Pyro;
				case 4: return TFClass_DemoMan;
			}
		}
		case 2: { // support garage built only
			switch ( GetRandomInt(0, 4) ) {
				case 0: return TFClass_Soldier;
				case 1: return TFClass_Spy;
				case 2: return TFClass_Engineer;

				case 3: return TFClass_Scout;
				case 4: return TFClass_Medic;
			}
		}
		default: { // no garage built yet
			switch ( GetRandomInt(0, 2) ) {
				case 0: return TFClass_Soldier;
				case 1: return TFClass_Spy;
				case 2: return TFClass_Engineer;
			}
		}
	}
	return TFClass_Soldier;
}
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
stock void SetPawnTimer(Function func, float thinktime = 0.1, any param1 = -999, any param2 = -999)
{
	DataPack thinkpack = new DataPack();
	thinkpack.WriteFunction(func);
	thinkpack.WriteCell(param1);
	thinkpack.WriteCell(param2);

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

