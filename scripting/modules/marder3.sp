
//defines
#define DestroyerModel			"models/custom/tanks/marder3.mdl" //thx to Friagram for saving teh day!
#define DestroyerModelPrefix		"models/custom/tanks/marder3"

#define DESTROYER_SPEED			2000.0
#define DESTROYER_DMG			1000.0
#define DESTROYER_ACCELERATION		5.0
#define DESTROYER_SPEEDMAX		270.0
#define DESTROYER_SPEEDMAXREVERSE	240.0
#define DESTROYER_INITSPEED		50.0
#define DESTROYER_MAXROCKETAMMO		500



methodmap CDestroyer < CTank
{
	public CDestroyer(const int ind, bool uid = false)
	{
		return view_as<CDestroyer>( CTank(ind, uid) );
	}

	/*public void PlaySpawnSound (const int number)
	{
		char sound[PLATFORM_MAX_PATH];
		Format(sound, PLATFORM_MAX_PATH, "%s%i.mp3", TankSpawn, number); //sounds from Company of Heroes 1
		EmitSoundToAll(sound, this.index, SNDCHAN_VOICE); EmitSoundToAll(sound, this.index, SNDCHAN_VOICE); EmitSoundToAll(sound, this.index, SNDCHAN_VOICE);
	}*/

	public void Think ()
	{
		if ( !IsPlayerAlive(this.index) )
			return;

		int buttons = GetClientButtons(this.index);
		float vell[3];	GetEntPropVector(this.index, Prop_Data, "m_vecAbsVelocity", vell);
		float currtime = GetGameTime();
		if ( (buttons & IN_FORWARD) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(this.index, SNDCHAN_AUTO, TankIdle);

			this.flSpeed += DESTROYER_ACCELERATION; /*simulates vehicular physics; not as good as Valve does with vehicle entities though*/
			if (this.flSpeed > DESTROYER_SPEEDMAX)
				this.flSpeed = DESTROYER_SPEEDMAX;

			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankMove);
				EmitSoundToAll(TankMove, this.index, SNDCHAN_AUTO);
				this.flSoundDelay = currtime+31.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else if ( (buttons & IN_BACK) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(this.index, SNDCHAN_AUTO, TankIdle);

			this.flSpeed += DESTROYER_ACCELERATION;
			if (this.flSpeed > DESTROYER_SPEEDMAXREVERSE)
				this.flSpeed = DESTROYER_SPEEDMAXREVERSE;
			
			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankMove);
				EmitSoundToAll(TankMove, this.index, SNDCHAN_AUTO);
				this.flSoundDelay = currtime+31.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else {
			StopSound(this.index, SNDCHAN_AUTO, TankMove);
			this.flGas += 0.001;

			if (this.flSoundDelay != 0.0)
				this.flSoundDelay = 0.0;
			if ( this.flIdleSound < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankIdle);
				EmitSoundToAll(TankIdle, this.index, SNDCHAN_AUTO);
				this.flIdleSound = currtime+5.0;
			}
			this.flSpeed -= DESTROYER_ACCELERATION;
			if (this.flSpeed < DESTROYER_INITSPEED)
				this.flSpeed = DESTROYER_INITSPEED;
		}

		if ( bGasPowered.BoolValue and this.flGas <= 0.0 )
			this.flSpeed = 1.0;
		SetEntPropFloat(this.index, Prop_Send, "m_flMaxspeed", this.flSpeed);

		/*
		if ( (buttons & IN_ATTACK2) and this.bIsVehicle ) //MOUSE2 Rocket firing mechanic
		{
			if ( this.flLastFire < currtime ) {
				float vPosition[3], vAngles[3], vVec[3];
				GetClientEyePosition(this.index, vPosition);
				GetClientEyeAngles(this.index, vAngles);

				vVec[0] = Cosine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[1] = Sine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[2] = -Sine( DegToRad(vAngles[0]) );

				vPosition[0] += vVec[0] * 50.0;
				vPosition[1] += vVec[1] * 50.0;
				vPosition[2] += vVec[2] * 50.0;
				bool crit = ( TF2_IsPlayerInCondition(this.index, TFCond_Kritzkrieged) or TF2_IsPlayerInCondition(this.index, TFCond_CritOnWin) );
				TE_SetupMuzzleFlash(vPosition, vAngles, 9.0, 1);
				TE_SendToAll();
				ShootRocket(this.index, crit, vPosition, vAngles, DESTROYER_SPEED, DESTROYER_DMG, "");
				Format(snd, PLATFORM_MAX_PATH, "%s%i.mp3", TankShoot, GetRandomInt(1, 3)); //sounds from Call of duty 1
				EmitSoundToAll(snd, this.index, SNDCHAN_AUTO);
				CreateTimer(1.0, Timer_ReloadTank, this.userid, TIMER_FLAG_NO_MAPCHANGE); //useless, only plays a 'reload' sound
				CreateTimer(4.0, Timer_ReloadTank, this.userid, TIMER_FLAG_NO_MAPCHANGE);
				this.flLastFire = currtime + 8.0;

				float PunchVec[3] = {80.0, 0.0, 45.0};
				SetEntPropVector(this.index, Prop_Send, "m_vecPunchAngleVel", PunchVec);
			}
		}
		CreateTimer(0.1, Timer_TankCrush, client);
		TF2_AddCondition(this.index, TFCond_MegaHeal, 0.2);
		*/
		/*prevent tanks from being airblasted and gives a team colored aura to allow teams to tell who's on what side */
	}
	public void SetModel ()
	{
		SetVariantString(DestroyerModel);
		AcceptEntityInput(this.index, "SetCustomModel");
		//SetEntProp(this.index, Prop_Send, "m_bUseClassAnimations", 1);
		SetEntProp(this.index, Prop_Send, "m_bCustomModelRotates", 1); 
		//SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.25);
	}
	public void Equip ()
	{
		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "tf_wearable_demoshield")) != -1)
		{
			if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == this.index)
				AcceptEntityInput(ent, "Kill");
		}

		TF2_RemoveAllWeapons(this.index);
		int maxhp = GetEntProp(this.index, Prop_Data, "m_iMaxHealth");

		char attribs[150];
		if (GamePlayMode.IntValue != GunGame)
			Format( attribs, sizeof(attribs), "125 ; %i ; 326 ; 0.0 ; 252 ; 0.0 ; 37 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 100 ; 0.2 ; 5 ; 3.0 ; 2 ; 3.8 ; 103 ; 3.636 ; 68 ; -2.0", (1-maxhp) );
		else Format( attribs, sizeof(attribs), "26 ; %i ; 326 ; 0.0 ; 252 ; 0.0 ; 37 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 100 ; 0.2 ; 5 ; 3.0 ; 2 ; 3.8 ; 103 ; 3.636 ; 68 ; -2.0", (MMCvars[Marder3HP].IntValue-maxhp) );

		int Turret = this.SpawnWeapon("tf_weapon_rocketlauncher_directhit", 127, 1, 0, attribs);
		SetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon", Turret);
		SetWeaponClip(Turret, DESTROYER_MAXROCKETAMMO);
		SetWeaponAmmo(Turret, 0);
		SetWeaponInvis(this.index, 0);
	}
	public void Death ()
	{
		StopSound(this.index, SNDCHAN_AUTO, TankIdle);
		StopSound(this.index, SNDCHAN_AUTO, TankMove);

		char sound[PLATFORM_MAX_PATH];
		Format(sound, PLATFORM_MAX_PATH, "%s%i.mp3", TankDeath, GetRandomInt(1, 2)); //sounds from Call of Duty 1
		EmitSoundToAll(sound, this.index, SNDCHAN_AUTO);
		AttachParticle(this.index, "buildingdamage_dispenser_fire1", 1.0);
		SetClientOverlay(this.index, "0");
		this.flIdleSound = 0.0;
		this.flSoundDelay = 0.0;
		SetEntProp(this.index, Prop_Send, "m_bCustomModelRotates", 0); 
	}

	public void DoEngieInteraction (BaseVehicle engie)
	{
		int iCurrentMetal = GetEntProp(engie.index, Prop_Data, "m_iAmmo", 4, 3);
		int repairamount = HealthFromMetal.IntValue;	//default 10
		int mult = HealthFromMetalMult.IntValue;	//default 10

		int hClientWeapon = GetEntPropEnt(engie.index, Prop_Send, "m_hActiveWeapon");
		int Turret = GetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon");
		char classname[64];
		if (IsValidEdict(hClientWeapon))
			GetEdictClassname(hClientWeapon, classname, sizeof(classname));
	
		if ( !strcmp(classname, "tf_weapon_wrench", false) or !strcmp(classname, "tf_weapon_robot_arm", false) )
		{
			if (this.iHealth > 0 and this.iHealth < MMCvars[Marder3HP].IntValue) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;

				if ( ( MMCvars[Marder3HP].IntValue - this.iHealth < repairamount*mult ) )
					repairamount = RoundToCeil( float((MMCvars[Marder3HP].IntValue - this.iHealth)/mult) );

				if (repairamount < 1 and iCurrentMetal > 0)
					repairamount = 1;

				this.iHealth += repairamount*mult;
				if (this.iHealth > MMCvars[Marder3HP].IntValue)
					this.iHealth = MMCvars[Marder3HP].IntValue;

				iCurrentMetal -= repairamount;
				SetEntProp(engie.index, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
			}
			int clip = GetWeaponClip(Turret);
			if ( clip >= 0 and clip < DESTROYER_MAXROCKETAMMO ) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;
				if ( (DESTROYER_MAXROCKETAMMO-clip < repairamount*mult) )
					repairamount = RoundToCeil( float((DESTROYER_MAXROCKETAMMO-clip)/mult) );

				if (repairamount < 1 and iCurrentMetal > 0)
					repairamount = 1;

				SetWeaponClip(Turret, clip+repairamount*mult);
				if (clip > DESTROYER_MAXROCKETAMMO) 
					SetWeaponClip(Turret, DESTROYER_MAXROCKETAMMO);

				iCurrentMetal -= repairamount;
				SetEntProp(engie.index, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
			}
			if (repairamount)
				EmitSoundToClient(engie.index, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
			else EmitSoundToClient(engie.index, "weapons/wrench_hit_build_fail.wav");
		}
	}
};

public CDestroyer ToCDestroyer (BaseVehicle veh)
{
	return view_as<CDestroyer> (veh);
}

public void AddDestroyerToDownloads ()
{
	char s[PLATFORM_MAX_PATH];
	char extensions[][] = { ".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd", ".phy" };
	char extensionsb[][] = { ".vtf", ".vmt" };
	//char extensionsc[][] = { ".wav", ".mp3" };
	int i;
	PrecacheModel(DestroyerModel, true);
	for (i = 0; i < sizeof(extensions); i++) {
		Format(s, PLATFORM_MAX_PATH, "%s%s", DestroyerModelPrefix, extensions[i]);
		CheckDownload(s);
	}
	for (i = 0; i < sizeof(extensionsb); i++) {
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/marder3%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/marder3_blue%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/marder3_track%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/hetzer_track%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/hetzer_track_nm%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/marder_iii_blue%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/marder_iii_nm%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/marder_iii_red%s", extensionsb[i]);
		CheckDownload(s);
	}
}

public void AddDestroyerToMenu ( Menu& menu )
{
	menu.AddItem("7", "Marder III Tank Destroyer");
}

