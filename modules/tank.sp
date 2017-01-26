
//defines
#define TankModel			"models/custom/tanks/panzer.mdl" //thx to Friagram for saving teh day!
#define TankModelPrefix			"models/custom/tanks/panzer"

#define TankShoot			"acvshtank/fire"
#define TankDeath			"acvshtank/dead"
#define TankSpawn			"acvshtank/spawn"
#define TankReload			"acvshtank/reload.mp3"
#define TankCrush			"acvshtank/vehicle_hit_person.mp3"
#define TankMove			"acvshtank/tankdrive.mp3"
#define TankIdle			"acvshtank/tankidle.mp3"

#define ROCKET_SPEED			4000.0
#define ROCKET_DMG			100.0
#define TANK_ACCELERATION		3.0
#define TANK_SPEEDMAX			200.0
#define TANK_SPEEDMAXREVERSE		180.0
#define TANK_INITSPEED			40.0
#define SMG_DAMAGE_MULT			1.0

//float LastFire[PLYR] ;

methodmap CTank < BaseVehicle
{
	public CTank(const int ind, bool uid = false)
	{
		return view_as<CTank>( BaseVehicle(ind, uid) );
	}

	property float flLastFire
	{
		public get()				//{ return LastFire[ this.index ]; }
		{
			float item; hFields[this.index].GetValue("flLastFire", item);
			return item;
		}
		public set( const float val )		//{ LastFire[ this.index ] = val; }
		{
			hFields[this.index].SetValue("flLastFire", val);
		}
	}

	public void PlaySpawnSound (const int number)
	{
		char sound[PLATFORM_MAX_PATH];
		Format(sound, PLATFORM_MAX_PATH, "%s%i.mp3", TankSpawn, number); //sounds from Company of Heroes 1
		EmitSoundToAll(sound, this.index, SNDCHAN_VOICE); EmitSoundToAll(sound, this.index, SNDCHAN_VOICE); EmitSoundToAll(sound, this.index, SNDCHAN_VOICE);
	}

	public void Think ()
	{
		int player = this.index;
		if ( !IsPlayerAlive(player) )
			return;

		int buttons = GetClientButtons(player);
		float vell[3];	GetEntPropVector(player, Prop_Data, "m_vecAbsVelocity", vell);
		float currtime = GetGameTime();
		if ( (buttons & IN_FORWARD) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(player, SNDCHAN_AUTO, TankIdle);

			this.flSpeed += TANK_ACCELERATION; /*simulates vehicular physics; not as good as Valve does with vehicle entities though*/
			if (this.flSpeed > TANK_SPEEDMAX)
				this.flSpeed = TANK_SPEEDMAX;

			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankMove);
				EmitSoundToAll(TankMove, player, SNDCHAN_AUTO);
				this.flSoundDelay = currtime+31.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else if ( (buttons & IN_BACK) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(player, SNDCHAN_AUTO, TankIdle);

			this.flSpeed += TANK_ACCELERATION;
			if (this.flSpeed > TANK_SPEEDMAXREVERSE)
				this.flSpeed = TANK_SPEEDMAXREVERSE;
			
			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankMove);
				EmitSoundToAll(TankMove, player, SNDCHAN_AUTO);
				this.flSoundDelay = currtime+31.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else {
			StopSound(player, SNDCHAN_AUTO, TankMove);
			this.flGas += 0.001;

			if (this.flSoundDelay != 0.0)
				this.flSoundDelay = 0.0;
			if ( this.flIdleSound < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankIdle);
				EmitSoundToAll(TankIdle, player, SNDCHAN_AUTO);
				this.flIdleSound = currtime+5.0;
			}
			this.flSpeed -= TANK_ACCELERATION;
			if (this.flSpeed < TANK_INITSPEED)
				this.flSpeed = TANK_INITSPEED;
		}

		if ( bGasPowered.BoolValue and this.flGas <= 0.0 )
			this.flSpeed = 1.0;
		SetEntPropFloat(player, Prop_Send, "m_flMaxspeed", this.flSpeed);

		if ( (buttons & IN_ATTACK2) and this.bIsVehicle ) //MOUSE2 Rocket firing mechanic
		{
			if ( this.flLastFire < currtime ) {
				float vPosition[3], vAngles[3], vVec[3];
				GetClientEyePosition(player, vPosition);
				GetClientEyeAngles(player, vAngles);

				vVec[0] = Cosine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[1] = Sine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[2] = -Sine( DegToRad(vAngles[0]) );

				vPosition[0] += vVec[0] * 50.0;
				vPosition[1] += vVec[1] * 50.0;
				vPosition[2] += vVec[2] * 50.0;
				bool crit = ( TF2_IsPlayerInCondition(player, TFCond_Kritzkrieged) or TF2_IsPlayerInCondition(player, TFCond_CritOnWin) );
				TE_SetupMuzzleFlash(vPosition, vAngles, 9.0, 1);
				TE_SendToAll();
				ShootRocket(player, crit, vPosition, vAngles, ROCKET_SPEED, ROCKET_DMG, "");
				Format(snd, PLATFORM_MAX_PATH, "%s%i.mp3", TankShoot, GetRandomInt(1, 3)); //sounds from Call of duty 1
				EmitSoundToAll(snd, player, SNDCHAN_AUTO);
				CreateTimer(1.0, Timer_ReloadTank, this.userid, TIMER_FLAG_NO_MAPCHANGE); //useless, only plays a 'reload' sound
				this.flLastFire = currtime + 4.0;

				float PunchVec[3] = {100.0, 0.0, 90.0};
				SetEntPropVector(player, Prop_Send, "m_vecPunchAngleVel", PunchVec);
			}
		}
		//CreateTimer(0.1, Timer_TankCrush, client);
		//TF2_AddCondition(player, TFCond_MegaHeal, 0.2); /*prevent tanks from being airblasted and gives a team colored aura to allow teams to tell who's on what side */
	}
	public void SetModel ()
	{
		SetVariantString(TankModel);
		AcceptEntityInput(this.index, "SetCustomModel");
		SetEntProp(this.index, Prop_Send, "m_bUseClassAnimations", 1);
		/*SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.25);*/
	}

	public void Death ()
	{
		StopSound(this.index, SNDCHAN_AUTO, TankIdle);
		StopSound(this.index, SNDCHAN_AUTO, TankMove);

		char sound[PLATFORM_MAX_PATH];
		Format(sound, PLATFORM_MAX_PATH, "%s%i.mp3", TankDeath, GetRandomInt(1, 2)); // Sounds from Call of Duty 1
		EmitSoundToAll(sound, this.index, SNDCHAN_AUTO);
		AttachParticle(this.index, "buildingdamage_dispenser_fire1", 1.0);
		SetClientOverlay(this.index, "0");
		this.flIdleSound = 0.0;
		this.flSoundDelay = 0.0;
	}

	public void Equip ()
	{
		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "tf_wearable_demoshield")) != -1)
		{
			if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == this.index)
				AcceptEntityInput(ent, "kill");
		}

		TF2_RemoveAllWeapons(this.index);
		int maxhp = GetEntProp(this.index, Prop_Data, "m_iMaxHealth");
		char attribs[128];
		if (GamePlayMode.IntValue != GunGame)
			Format( attribs, sizeof(attribs), "2 ; %f ; 125 ; %i ; 6 ; 0.5 ; 326 ; 0.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 68 ; -2.0", SMG_DAMAGE_MULT, (1-maxhp) );
		else Format( attribs, sizeof(attribs), "2 ; %f ; 26 ; %i ; 6 ; 0.5 ; 326 ; 0.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 68 ; -2.0", SMG_DAMAGE_MULT, (MMCvars[Panzer4HP].IntValue-maxhp) );

		int Turret = this.SpawnWeapon("tf_weapon_smg", 16, 1, 0, attribs);
		SetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon", Turret);
		SetWeaponClip(Turret, MMCvars[MaxSMGAmmo].IntValue);
		SetWeaponAmmo(Turret, 0);
		SetClientOverlay( this.index, "effects/combine_binocoverlay" );
	}
	public void DoEngieInteraction (BaseVehicle engie)
	{
		int iCurrentMetal = GetEntProp(engie.index, Prop_Data, "m_iAmmo", 4, 3);
		int repairamount = HealthFromMetal.IntValue;	//default 10
		int mult = HealthFromMetalMult.IntValue;	//default 10

		int hClientWeapon = GetEntPropEnt(engie.index, Prop_Send, "m_hActiveWeapon");
		int Turret = GetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon");
		//new wepindex = (IsValidEdict(hClientWeapon) and GetEntProp(hClientWeapon, Prop_Send, "m_iItemDefinitionIndex"));
		char classname[64];
		if (IsValidEdict(hClientWeapon))
			GetEdictClassname(hClientWeapon, classname, sizeof(classname));
	
		if ( !strcmp(classname, "tf_weapon_wrench", false) or !strcmp(classname, "tf_weapon_robot_arm", false) )
		{
			if (this.iHealth > 0 and this.iHealth < MMCvars[Panzer4HP].IntValue) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;

				if ( ( MMCvars[Panzer4HP].IntValue - this.iHealth < repairamount*mult ) )
					repairamount = RoundToCeil( float((MMCvars[Panzer4HP].IntValue - this.iHealth)/mult) );

				if (repairamount < 1 and iCurrentMetal > 0)
					repairamount = 1;

				this.iHealth += repairamount*mult;

				if (this.iHealth > MMCvars[Panzer4HP].IntValue)
					this.iHealth = MMCvars[Panzer4HP].IntValue;

				iCurrentMetal -= repairamount;
				SetEntProp(engie.index, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
			}
			int clip = GetWeaponClip(Turret);
			if ( clip >= 0 and clip < MMCvars[MaxSMGAmmo].IntValue ) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;
				if ( (MMCvars[MaxSMGAmmo].IntValue-clip < repairamount*mult) )
					repairamount = RoundToCeil( float((MMCvars[MaxSMGAmmo].IntValue-clip)/mult) );

				if (repairamount < 1 and iCurrentMetal > 0)
					repairamount = 1;

				SetWeaponClip(Turret, clip+repairamount*mult);
				if (clip > MMCvars[MaxSMGAmmo].IntValue) 
					SetWeaponClip(Turret, MMCvars[MaxSMGAmmo].IntValue);

				iCurrentMetal -= repairamount;
				SetEntProp(engie.index, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
			}
		}
	}
};

public CTank ToCTank (BaseVehicle veh)
{
	return view_as<CTank> (veh);
}

public void AddTankToDownloads ()
{
	char s[PLATFORM_MAX_PATH];
	char extensions[][] = { ".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd", ".phy" };
	char extensionsb[][] = { ".vtf", ".vmt" };
	//char extensionsc[][] = { ".wav", ".mp3" };
	int i;
	PrecacheModel(TankModel, true);
	for (i = 0; i < sizeof(extensions); ++i) {
		Format(s, PLATFORM_MAX_PATH, "%s%s", TankModelPrefix, extensions[i]);
		CheckDownload(s);
	}
	for (i = 0; i < sizeof(extensionsb); ++i) {
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/panzer%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/panzer_blue%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/panzer_track%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/pziv_ausfg%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/pziv_ausfg_nm%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/pziv_ausfg_red%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/hummel_track%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/hummel_track_nm%s", extensionsb[i]);
		CheckDownload(s);
	}
	for (i = 1; i < 4; ++i) {
		if (i < 3) {
			Format(s, PLATFORM_MAX_PATH, "%s%i.mp3", TankDeath, i);
			PrecacheSound(s, true);
			Format(s, PLATFORM_MAX_PATH, "sound/%s", s);
			AddFileToDownloadsTable(s);
		}
		Format(s, PLATFORM_MAX_PATH, "%s%i.mp3", TankShoot, i);
		PrecacheSound(s, true);
		Format(s, PLATFORM_MAX_PATH, "sound/%s", s);
		AddFileToDownloadsTable(s);

		Format(s, PLATFORM_MAX_PATH, "%s%i.mp3", TankSpawn, i);
		PrecacheSound(s, true);
		Format(s, PLATFORM_MAX_PATH, "sound/%s", s);
		AddFileToDownloadsTable(s);
	}
	AddFileToDownloadsTable("sound/acvshtank/reload.mp3");
	AddFileToDownloadsTable("sound/acvshtank/vehicle_hit_person.mp3");
	AddFileToDownloadsTable("sound/acvshtank/tankidle.mp3");
	AddFileToDownloadsTable("sound/acvshtank/tankdrive.mp3");
	PrecacheSound(TankReload, true);
	PrecacheSound(TankCrush, true);
	PrecacheSound(TankMove, true);
	PrecacheSound(TankIdle, true);
}

public void AddTankToMenu ( Menu& menu )
{
	menu.AddItem("0", "Panzer IV");
}

public Action Timer_ReloadTank (Handle hTimer, any userid)
{
	int client = GetClientOfUserId(userid);
	CTank tanker = CTank(client);
	if (!tanker.bIsVehicle)
		return Plugin_Continue;

	if (client and IsClientInGame(client)) {
		//char s[PLATFORM_MAX_PATH];
		//strcopy(s, PLATFORM_MAX_PATH, TankReload);
		EmitSoundToAll(TankReload, client, SNDCHAN_AUTO);
	}
	return Plugin_Continue;
}


