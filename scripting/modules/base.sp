

#define OfficerModel			"models/custom/player/officer/army_spy/spy_officer.mdl"		// thx to Ravensbro!
#define OfficerModelPrefix		"models/custom/player/officer/army_spy/spy_officer"

//int
	//Health[PLYR],			/* amount of health given to vehicles */
	//VehicleType[PLYR]		/* what kind of vehicle is player? */
	//FourthWep[ PLYR ]		/* this is for storing soldier's smg */
//;

//int RightClickAmmo[PLYR];

//bool
	//IsVehicle[PLYR],		/* Is the player a vehicle? */
	//IsToSpawnAsVehicle[PLYR],	/* Is the player set to become a vehicle when they spawn? */
	//HonkedHorn[PLYR]		/* Is the Vehicle/Player currently honking the vehicle's horn? */
	//IsNearOfficer[PLYR]		/* Is the player near an officer? (to receive buffs) */
//;

//float
//	fSpeed[PLYR],			/* vehicles usually move, this dictates how fast they move :3 */
//	Gas[PLYR],			/* movement requires energy, gas is that energy! */
//	IdleSound[PLYR],		/* when to play idling sound and when to stop it */
//	SoundDelay[PLYR]		/* when to play moving sound and when to stop it */
//;

StringMap hFields[PLYR];

char snd[PLATFORM_MAX_PATH];

methodmap BaseFighter {		/* the methodmap for all 'classes' */
	public BaseFighter(const int ind, bool uid=false)
	{
		int player=0;
		if (uid and GetClientOfUserId(ind))
			player = ( ind );
		else if ( IsClientValid(ind) )
			player = GetClientUserId(ind);
		return view_as< BaseFighter >( player );
	}
	///////////////////////////////

	/* [ P R O P E R T I E S ] */

	property int userid {
		public get()				{ return view_as< int >(this); }
	}
	property int index {
		public get()				{ return GetClientOfUserId( view_as< int >(this) ); }
	}

	property bool bIsGunner
	{
		public get() {
			bool item; hFields[this.index].GetValue("bIsGunner", item);
			return item;
		}
		public set( const bool val ) {
			hFields[this.index].SetValue("bIsGunner", val);
		}
	}
	property TFClassType Class	/* automatically converts between entity indexes and references */
	{
		public get()				{ return TF2_GetPlayerClass(this.index); }
		public set( const TFClassType val )	{ TF2_SetPlayerClass(this.index, val); }
	}
	property int iTeam
	{
		public get()				{ return GetClientTeam(this.index); }
	}

	public int SpawnWeapon (char[] name, const int index, const int level, const int qual, char[] att)
	{
		TF2Item hWep = new TF2Item(OVERRIDE_ALL|FORCE_GENERATION);
		if( !hWep )
			return -1;

		hWep.SetClassname(name);
		hWep.iItemIndex = index;
		hWep.iLevel = level;
		hWep.iQuality = qual;
		char atts[32][32];
		int count = ExplodeString(att, " ; ", atts, 32, 32);
		count &= ~1;
		if( count > 0 ) {
			hWep.iNumAttribs = count/2;
			int i2 = 0;
			for( int i=0 ; i < count ; i += 2 ) {
				hWep.SetAttribute( i2, StringToInt(atts[i]), StringToFloat(atts[i+1]) );
				i2++;
			}
		}
		else hWep.iNumAttribs = 0;

		int entity = hWep.GiveNamedItem(this.index);
		delete hWep;
		EquipPlayerWeapon(this.index, entity);
		return entity;
	}

	public void HelpPanel()
	{
		if( IsVoteInProgress() )
			return;

		Panel panel = new Panel();
		//SetGlobalTransTarget(this.index);
		char helpstr[512];
		switch( this.Class ) {
			case TFClass_Scout:	helpstr = "Scout Car:\nSMG turret + 20mm Cannon.\nRight Click: 40 damage Cannon shot.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case TFClass_Soldier:	helpstr = "Soldier:\nMouse3|Attack3 Button: Equip SMG\nVehicles take 2x Explosives Damage! Plan Ahead.\nRocket Launchers have\n\t-longer reload,\n\t-less clipsize,\n\t-less ammo,\n\t-less accuracy,\n\t-more damage.";
			case TFClass_Pyro:	helpstr = "Panzer II:\nFlamethrower + Arcing Rocket cannon.\nRight Click: High Explosive 80 damage Rocket.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case TFClass_DemoMan:	helpstr = "Panzer IV:\nSMG turret + Rocket cannon.\nRight Click: 100 damage Rocket.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case TFClass_Heavy:	helpstr = "King Panzer:\nSMG turret + Rocket cannon.\nRight Click: 150 damage Rocket.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case TFClass_Engineer:	helpstr = "Engineer:\ntype !garage or !base to build Vehicle Mainframes (Costs 200 Metal).\nMouse3|Attack3 Button: Anti-Tank Sticky Launcher - Increases Damage on Chargeup.\nYOU CAN ONLY DETONATE STICKIES AS AN ACTIVE WEAPON.\nUse your Wrench to Heal & Arm Vehicles! (uses up metal!)\nYour Wrench can Fix and Speed building Vehicle Mainframes!";
			case TFClass_Medic:	helpstr = "Ambulance:\nSMG turret\nArea of Effect Healing 20ft|6m\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case TFClass_Sniper:	helpstr = "Marder II Tank Destroyer:\nRocket cannon.\nRight Click: Max. 700 damage Rocket.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case TFClass_Spy:	helpstr = "Officer:\nEnforcer Revolver: 50%+ more Accurate for Long Range Combat.\nPistol for Short range Combat\nArea of Effect Buffs to nearby Infantry\n3x Capturing Power.\nHit Mainframes to Help Engineers build them faster!";
		}

		panel.SetTitle(helpstr);
		panel.DrawItem( "Exit" );
		panel.Send(this.index, HintPanel, 30);
		delete (panel);
	}
	public void Think()
	{
	}
};

public int HintPanel(Menu menu, MenuAction action, int param1, int param2)
{
	if( !IsValidClient(param1) )
		return;
	return;
}

methodmap BaseVehicle < BaseFighter	/* the methodmap for all vehicles to use. Use this if you're making a totally different vehicle */
{
	public BaseVehicle(const int ind, bool uid=false)
	{
		return view_as< BaseVehicle >( BaseFighter(ind, uid) );
	}
	///////////////////////////////

	/* [ P R O P E R T I E S ] */
	/*
	public any getProp(const char prop[64])
	{
		any item; hFields[this.index].GetValue(prop, item);
		return item;
	}
	public void setProp(const char prop[64], any val)
	{
		hFields[this.index].SetValue(prop, val);
	}
	*/
	property int iHealth
	{
		public get() {				//{ return Health[ this.index ]; } {
			int item; hFields[this.index].GetValue("iHealth", item);
			return item;
		}
		public set( const int val ) {		//{ Health[ this.index ] = val; } {
			hFields[this.index].SetValue("iHealth", val);
		}
	}
	property int iType
	{
		public get() {				//{ return VehicleType[ this.index ]; } {
			int item; hFields[this.index].GetValue("iType", item);
			return item;
		}
		public set( const int val ) {		//{ VehicleType[ this.index ] = val; } {
			hFields[this.index].SetValue("iType", val);
		}
	}
	property bool bIsVehicle
	{
		public get() {				//{ return IsVehicle[ this.index ]; } {
			bool item; hFields[this.index].GetValue("bIsVehicle", item);
			return item;
		}
		public set( const bool val ) {		//{ IsVehicle[ this.index ] = val; } {
			hFields[this.index].SetValue("bIsVehicle", val);
		}
	}
	property bool bSetOnSpawn
	{
		public get() {				//{ return IsToSpawnAsVehicle[ this.index ]; } {
			bool item; hFields[this.index].GetValue("bSetOnSpawn", item);
			return item;
		}
		public set( const bool val ) {		//{ IsToSpawnAsVehicle[ this.index ] = val; } {
			hFields[this.index].SetValue("bSetOnSpawn", val);
		}
	}
	property bool bHonkedHorn
	{
		public get() {				//{ return HonkedHorn[ this.index ]; } {
			bool item; hFields[this.index].GetValue("bHonkedHorn", item);
			return item;
		}
		public set( const bool val ) {		//{ HonkedHorn[ this.index ] = val; } {
			hFields[this.index].SetValue("bHonkedHorn", val);
		}
	}
	/****
		Purpose: This is for when the vehicle actually uses gas
	****/
	property float flGas
	{
		public get() {				//{ return Gas[ this.index ]; } {
			float item; hFields[this.index].GetValue("flGas", item);
			return item;
		}
		public set( const float val ) {		//{ Gas[ this.index ] = val; } {
			hFields[this.index].SetValue("flGas", val);
		}
	}
	/****
		Purpose: all vehicles have a speed or else they're not vehicles!
	****/
	property float flSpeed
	{
		public get() {				//{ return fSpeed[ this.index ]; } {
			float item; hFields[this.index].GetValue("flSpeed", item);
			return item;
		}
		public set( const float val ) {		//{ fSpeed[ this.index ] = val; } {
			hFields[this.index].SetValue("flSpeed", val);
		}
	}
	/****
		Purpose: sound delay for when the next sound should play
	****/
	property float flSoundDelay
	{
		public get() {				//{ return SoundDelay[ this.index ]; } {
			float item; hFields[this.index].GetValue("flSoundDelay", item);
			return item;
		}
		public set( const float val ) {		//{ SoundDelay[ this.index ] = val; } {
			hFields[this.index].SetValue("flSoundDelay", val);
		}
	}
	/****
		Purpose: play the sound the vehicle should make when it's idle (not doing anything)
	****/
	property float flIdleSound
	{
		public get() {				//{ return IdleSound[ this.index ]; } {
			float item; hFields[this.index].GetValue("flIdleSound", item);
			return item;
		}
		public set( const float val ) {		//{ IdleSound[ this.index ] = val; } {
			hFields[this.index].SetValue("flIdleSound", val);
		}
	}

	property bool bHasGunner	// vehicle has gunner
	{
		public get() {
			bool item; hFields[this.index].GetValue("bHasGunner", item);
			return item;
		}
		public set( const bool val ) {
			hFields[this.index].SetValue("bHasGunner", val);
		}
	}
	property BaseFighter hGunner	// gunner's userid
	{
		public get() {
			BaseFighter item; hFields[this.index].GetValue("hGunner", item);
			return item;
		}
		public set( const BaseFighter val ) {
			hFields[this.index].SetValue("hGunner", val);
		}
	}

	/****
		Purpose: revert the vehicle back to a normal player
	****/
	public void Reset ()
	{
		//this.bIsVehicle = this.bSetOnSpawn;
		SetClientOverlay(this.index, "0");
		SetVariantString("");
		AcceptEntityInput(this.index, "SetCustomModel");
		StopSound(this.index, SNDCHAN_AUTO, "acvshtank/tankidle.mp3");
		StopSound(this.index, SNDCHAN_AUTO, "acvshtank/tankdrive.mp3");
		StopSound(this.index, SNDCHAN_AUTO, "armoredcar/idle.mp3");
		StopSound(this.index, SNDCHAN_AUTO, "armoredcar/driveloop.mp3");
		SetEntPropFloat(this.index, Prop_Send, "m_flModelScale", 1.0);
		
		//int health = GetEntProp(this.index, Prop_Data, "m_iMaxHealth");
		//SetEntityHealth(this.index, health);
		//TF2_RegeneratePlayer(this.index);
	}
	public void Resupply ()
	{
		if ( !this.bIsVehicle )
			return;

		ManageVehicleTransition(this);
		//this.iHealth = iTankerHealth.IntValue;
		ManageHealth(this);
		if (bGasPowered.BoolValue)
			this.flGas = StartingFuel.FloatValue;
	}
	public void ConvertToVehicle ()
	{
		//this.bIsVehicle = this.bSetOnSpawn;
		CreateTimer(0.1, Timer_MakePlayerVehicle, this.userid);
	}
	public void DrainGas (const float amount)
	{
		this.flGas -= amount;
		if (this.flGas <= 0.0)
			this.flGas = 0.0;
	}
	public void UpdateGas ()
	{
		if( IsClientObserver(this.index) )
			return;

		float x = HUDX.FloatValue, y = HUDY.FloatValue;
		int gas_remaining = RoundFloat( this.flGas );
		if( gas_remaining > 60 ) {
			SetHudTextParams(x, y, 1.0, 0, 255, 0, 255);
			ShowSyncHudText(this.index, hHudText, "Gas: %i", gas_remaining);
		}
		else if( 30 < gas_remaining < 60 ) {
			SetHudTextParams(x, y, 1.0, 255, 255, 0, 255);
			ShowSyncHudText(this.index, hHudText, "Gas: %i", gas_remaining);
		}
		else if( gas_remaining < 30 ) {
			SetHudTextParams(x, y, 1.0, 255, 0, 0, 255);
			ShowSyncHudText(this.index, hHudText, "Gas: %i", gas_remaining);
		}
	}
	public void VehHelpPanel ()
	{
		if( IsVoteInProgress() )
			return;

		Panel panel = new Panel();
		//SetGlobalTransTarget(this.index);
		char helpstr[512];
		switch( this.iType ) {
			case 0:	helpstr = "Panzer IV:\nSMG turret + Rocket Cannon.\nRight Click: Rocket.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case 1:	helpstr = "Scout Car:\nSMG turret + 20mm Cannon.\nRight Click: 20mm Cannon.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case 2:	helpstr = "Ambulance:\nSMG turret\nArea of Effect Healing 20ft|6m\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case 4:	helpstr = "King Panzer:\nSMG turret + Rocket Cannon.\nRight Click: Nuclear Rocket.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case 3:	helpstr = "Panzer II:\nSMG Turret + Howitzer Cannon.\nRight Click: Arcing, Hi-Explosive Rocket.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
			case 5:	helpstr = "Marder II Tank Destroyer:\nRocket Cannon.\nLeft Click: Max. 700 damage Rocket.\nGo near friendly Engineers to heal and re-arm you!\nMouse3/Attack3: Honk horn.";
		}
		panel.SetTitle(helpstr);
		panel.DrawItem( "Exit" );
		panel.Send(this.index, HintPanel, 30);
		delete (panel);
	}
	public void SetUpGunner (const BaseVehicle gunner)
	{
		// we already have a gunner, 1 is enough.
		if( this.bHasGunner )
			return;
		
		// need valid gunner!
		if( gunner.index <= 0 )
			return;
		
		// prevent vehicles from becoming gunners or else tankception :).
		if( gunner.bIsVehicle )
			return;
		
		this.bHasGunner = true;
		this.hGunner = gunner;
		
		// remove stuff and set up for secondary gunner's SMG
		int ent = -1;
		while( (ent = FindEntityByClassname(ent, "tf_wearable_demoshield")) != -1 ) {
			if( GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == gunner.index )
				AcceptEntityInput(ent, "Kill");
		}
		
		TF2_RemoveAllWeapons(gunner.index);
		char attribs[64];
		Format( attribs, sizeof(attribs), "400 ; 1.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 100 ; 0.01 ; 68 ; %f", (gunner.Class == TFClass_Scout) ? -2.0 : -1.0 );
		int secnd_turret = gunner.SpawnWeapon("tf_weapon_smg", 16, 1, 0, attribs);
		SetEntPropEnt(gunner.index, Prop_Send, "m_hActiveWeapon", secnd_turret);
		SetWeaponClip(secnd_turret, MMCvars[MaxGunnerAmmo].IntValue);
		SetWeaponAmmo(secnd_turret, 0);
		
		// gunner equipped, let's affirm their gunner status and move them to the top of the weapon.
		gunner.bIsGunner = true;
		
		float thisOrigin[3]; GetClientAbsOrigin(this.index, thisOrigin);
		thisOrigin[2] += 50.0;
		TeleportEntity(gunner.index, thisOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	public void RemoveGunner ()
	{
		// removing a gunner that doesn't exist?
		if( !this.bHasGunner )
			return;
		
		// We're gonna regenerate our ex-gunner but without resetting health.
		int gunner = this.hGunner.index;
		
		// get gunner's hp
		int gunner_hp = GetClientHealth(gunner);
		TF2_RemoveAllWeapons(gunner);
		// regenerate gunner and set hp back
		TF2_RegeneratePlayer(gunner);
		SetEntityHealth(gunner, gunner_hp);
		
		this.hGunner.bIsGunner = false;
		this.hGunner = view_as< BaseFighter >(0);
		this.bHasGunner = false;
		
		float playerVel[3]; playerVel[0] = playerVel[1] = playerVel[2] = 0.0;
		TeleportEntity(gunner, NULL_VECTOR, NULL_VECTOR, playerVel);
	}
	public void UpdateGunner()
	{
		if( !this.bHasGunner )
			return;
		
		// vehicle supposedly has a gunner but hGunner was some how not set?
		else if( !this.hGunner ) {
			this.bHasGunner = false;
			return;
		}
		
		// we have a registered gunner but doesn't exist, erase the gunner registration
		else if( this.hGunner.index <= 0 ) {
			this.hGunner = view_as< BaseFighter >(0);
			this.bHasGunner = false;
			return;
		}
		
		// If gunner died, we no longer have a gunner do we?
		else if( !IsPlayerAlive(this.hGunner.index) ) {
			this.hGunner.bIsGunner = false;
			this.hGunner = view_as< BaseFighter >(0);
			this.bHasGunner = false;
			return;
		}
		
		int gunner = this.hGunner.index;
		if ( (GetClientButtons(gunner) & IN_JUMP) ) {
			this.RemoveGunner();
			return;
		}
		
		int driver = this.index;
		float thisVel[3]; GetEntPropVector(driver, Prop_Data, "m_vecAbsVelocity", thisVel);

		float thisOrigin[3], plyrOrigin[3];
		GetClientAbsOrigin(driver, thisOrigin);
		GetClientAbsOrigin(gunner, plyrOrigin);

		if (GetVectorDistance(thisOrigin, plyrOrigin, false) > 10.0) {
			thisOrigin[2] += 50.0;
			TeleportEntity(gunner, thisOrigin, NULL_VECTOR, thisVel);
		}
		else TeleportEntity(gunner, NULL_VECTOR, NULL_VECTOR, thisVel);
	}
};

public void _RemoveGlow(const BaseVehicle car)
{
	if( !IsClientValid(car.index) )
		return;
	SetEntProp(car.index, Prop_Send, "m_bGlowEnabled", 0);
}
