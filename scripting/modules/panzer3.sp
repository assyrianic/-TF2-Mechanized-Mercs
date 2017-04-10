
//defines
#define LightTankModel			"models/custom/tanks/panzer_short.mdl" // thx to Friagram for saving teh day!
#define LightTankModelPrefix		"models/custom/tanks/panzer_short"

#define LIGHTROCKET_DMG			80.0
#define LIGHTTANK_ACCELERATION		5.0
#define LIGHTTANK_SPEEDMAX		250.0
#define LIGHTTANK_SPEEDMAXREVERSE	220.0
#define LIGHTTANK_INITSPEED		60.0


methodmap CLightTank < CTank
{
	public CLightTank(const int ind, bool uid = false)
	{
		return view_as<CLightTank>( CTank(ind, uid) );
	}

	public void PlaySpawnSound (const int number)
	{
		char sound[PLATFORM_MAX_PATH];
		Format(sound, PLATFORM_MAX_PATH, "%s%i.mp3", TankSpawn, number); // sounds from Company of Heroes 1
		EmitSoundToAll(sound, this.index, SNDCHAN_VOICE); EmitSoundToAll(sound, this.index, SNDCHAN_VOICE); EmitSoundToAll(sound, this.index, SNDCHAN_VOICE);
	}

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

			this.flSpeed += LIGHTTANK_ACCELERATION; /*simulates vehicular physics; not as good as Valve does with vehicle entities though*/
			if (this.flSpeed > LIGHTTANK_SPEEDMAX)
				this.flSpeed = LIGHTTANK_SPEEDMAX;

			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankMove);
				EmitSoundToAll(TankMove, this.index, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 110);
				this.flSoundDelay = currtime+27.745;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else if ( (buttons & IN_BACK) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(this.index, SNDCHAN_AUTO, TankIdle);

			this.flSpeed += LIGHTTANK_ACCELERATION;
			if (this.flSpeed > LIGHTTANK_SPEEDMAXREVERSE)
				this.flSpeed = LIGHTTANK_SPEEDMAXREVERSE;
			
			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankMove);
				EmitSoundToAll(TankMove, this.index, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 110);
				this.flSoundDelay = currtime+27.745;
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
				EmitSoundToAll(TankIdle, this.index, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 110);
				this.flIdleSound = currtime+4.475;
			}
			this.flSpeed -= LIGHTTANK_ACCELERATION;
			if (this.flSpeed < LIGHTTANK_INITSPEED)
				this.flSpeed = LIGHTTANK_INITSPEED;
		}

		if ( bGasPowered.BoolValue and this.flGas <= 0.0 )
			this.flSpeed = 1.0;
		SetEntPropFloat(this.index, Prop_Send, "m_flMaxspeed", this.flSpeed);

		if ( (buttons & IN_ATTACK2) and this.bIsVehicle ) //MOUSE2 Rocket firing mechanic
		{
			if ( this.flLastFire < currtime and this.iRockets > 0 ) {
				float vPosition[3], vAngles[3], vVec[3];
				GetClientEyePosition(this.index, vPosition);
				GetClientEyeAngles(this.index, vAngles);

				vVec[0] = Cosine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[1] = Sine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[2] = -Sine( DegToRad(vAngles[0]) );

				vPosition[0] += vVec[0] * 25.0;
				vPosition[1] += vVec[1] * 25.0;
				vPosition[2] += vVec[2] * 25.0;
				bool crit = ( TF2_IsPlayerInCondition(this.index, TFCond_Kritzkrieged) or TF2_IsPlayerInCondition(this.index, TFCond_CritOnWin) );
				TE_SetupMuzzleFlash(vPosition, vAngles, 9.0, 1);
				TE_SendToAll();
				int rocket = ShootRocket(this.index, crit, vPosition, vAngles, MMCvars[RocketSpeed].FloatValue*0.3333, LIGHTROCKET_DMG, "", true);
				if (rocket>MaxClients)
					SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon"));
				Format(snd, PLATFORM_MAX_PATH, "%s%i.mp3", TankShoot, GetRandomInt(1, 3)); //sounds from Call of duty 1
				EmitSoundToAll(snd, this.index, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 110);
				CreateTimer(1.0, Timer_ReloadTank, this.userid, TIMER_FLAG_NO_MAPCHANGE); //useless, only plays a 'reload' sound
				this.flLastFire = currtime + 4.0;
				this.iRockets -= 1;

				float PunchVec[3] = {80.0, 0.0, 45.0};
				SetEntPropVector(this.index, Prop_Send, "m_vecPunchAngleVel", PunchVec);
			}
		}
		//CreateTimer(0.1, Timer_TankCrush, client);
		//TF2_AddCondition(this.index, TFCond_MegaHeal, 0.2); /*prevent tanks from being airblasted and gives a team colored aura to allow teams to tell who's on what side */
	}
	public void SetModel ()
	{
		SetVariantString(LightTankModel);
		AcceptEntityInput(this.index, "SetCustomModel");
		SetEntProp(this.index, Prop_Send, "m_bUseClassAnimations", 1);
		//SetEntPropFloat(this.index, Prop_Send, "m_flModelScale", 1.25);
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
		Format( attribs, sizeof(attribs), "356 ; 1.0 ; 400 ; 1.0 ; 125 ; %i ; 326 ; 0.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 99 ; 2.0 ; 68 ; %f", (1-maxhp), (this.Class == TFClass_Scout) ? -2.0 : -1.0 );

		int Turret = this.SpawnWeapon("tf_weapon_smg", 16, 1, 0, attribs);
		SetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon", Turret);
		SetWeaponClip(Turret, MMCvars[MaxSMGAmmo].IntValue);
		SetWeaponAmmo(Turret, 0);
		//SetClientOverlay( this.index, "effects/combine_binocoverlay" );
		this.iRockets = MMCvars[MaxRocketAmmo].IntValue;
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
			if (this.iHealth > 0 and this.iHealth < MMCvars[LightPanzerHP].IntValue) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;

				if ( ( MMCvars[LightPanzerHP].IntValue - this.iHealth < repairamount*mult ) )
					repairamount = RoundToCeil( float((MMCvars[LightPanzerHP].IntValue - this.iHealth)/mult) );

				if (repairamount < 1 and iCurrentMetal > 0)
					repairamount = 1;

				this.iHealth += repairamount*mult;

				if (this.iHealth > MMCvars[LightPanzerHP].IntValue)
					this.iHealth = MMCvars[LightPanzerHP].IntValue;

				iCurrentMetal -= repairamount;
				SetEntProp(engie.index, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
			}
			int clip = GetWeaponClip(Turret);
			if ( clip >= 0 and clip < MMCvars[MaxSMGAmmo].IntValue ) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;
				if ( (MMCvars[MaxSMGAmmo].IntValue-clip < repairamount*mult) )
					repairamount = RoundToCeil( float((MMCvars[MaxSMGAmmo].IntValue-clip)/mult) );

				if (repairamount < 1 and iCurrentMetal)
					repairamount = 1;

				SetWeaponClip(Turret, clip+repairamount*mult);
				if (GetWeaponClip(Turret) > MMCvars[MaxSMGAmmo].IntValue) 
					SetWeaponClip(Turret, MMCvars[MaxSMGAmmo].IntValue);
					
				this.iRockets += repairamount*mult;
				if( this.iRockets > MMCvars[MaxRocketAmmo].IntValue )
					this.iRockets = MMCvars[MaxRocketAmmo].IntValue;

				iCurrentMetal -= repairamount;
				SetEntProp(engie.index, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
			}
			if( this.bHasGunner ) {
				int gunner = this.hGunner.index;
				int gunner_turret = GetEntPropEnt(gunner, Prop_Send, "m_hActiveWeapon");
				int gunner_clip = GetWeaponClip(gunner_turret);
				if( gunner_clip < MMCvars[MaxGunnerAmmo].IntValue )
					SetWeaponClip(gunner_turret, gunner_clip+repairamount*mult);
				if( GetWeaponClip(gunner_turret) > MMCvars[MaxGunnerAmmo].IntValue )
					SetWeaponClip(gunner_turret, MMCvars[MaxGunnerAmmo].IntValue);
			}
			if (repairamount)
				EmitSoundToClient(engie.index, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
			else EmitSoundToClient(engie.index, "weapons/wrench_hit_build_fail.wav");
		}
	}
	public void Heal()
	{
		//this.iHealth += 1;
		//if (this.iHealth > MMCvars[LightPanzerHP].IntValue)
		//	this.iHealth = MMCvars[LightPanzerHP].IntValue;
		
		int Turret = GetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon");
		int clip = GetWeaponClip(Turret);
		SetWeaponClip(Turret, ++clip);
		if (clip > MMCvars[MaxSMGAmmo].IntValue) 
			SetWeaponClip(Turret, MMCvars[MaxSMGAmmo].IntValue);
			
		this.iRockets += 1;
		if( this.iRockets > MMCvars[MaxRocketAmmo].IntValue )
			this.iRockets = MMCvars[MaxRocketAmmo].IntValue;
		
		if( this.bHasGunner ) {
			int gunner = this.hGunner.index;
			int gunner_turret = GetEntPropEnt(gunner, Prop_Send, "m_hActiveWeapon");
			int gunner_clip = GetWeaponClip(gunner_turret);
			if( gunner_clip < MMCvars[MaxGunnerAmmo].IntValue )
				SetWeaponClip(gunner_turret, ++gunner_clip);
			if( GetWeaponClip(gunner_turret) > MMCvars[MaxGunnerAmmo].IntValue )
				SetWeaponClip(gunner_turret, MMCvars[MaxGunnerAmmo].IntValue);
		}
	}
};

public CLightTank ToCLightTank (BaseVehicle veh)
{
	return view_as<CLightTank> (veh);
}

public void AddLightTankToDownloads ()
{
	char s[PLATFORM_MAX_PATH];
	char extensions[][] = { ".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd", ".phy" };
	//char extensionsb[][] = { ".vtf", ".vmt" };
	//char extensionsc[][] = { ".wav", ".mp3" };
	int i;
	PrecacheModel(LightTankModel, true);
	for (i = 0; i < sizeof(extensions); i++) {
		Format(s, PLATFORM_MAX_PATH, "%s%s", LightTankModelPrefix, extensions[i]);
		CheckDownload(s);
	}
}

public void AddLightTankToMenu ( Menu& menu )
{
	menu.AddItem("6", "Panzer III");
}

