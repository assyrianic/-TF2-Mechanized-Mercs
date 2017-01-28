
//defines
#define ArmCarModel		"models/custom/daimler/daimler.mdl"	// Thx to Friagram for saving teh day! Credit goes to daimler for model!
#define ArmCarModelPrefix	"models/custom/daimler/daimler"
#define ArmCarShoot		"armoredcar/cannon.mp3"
#define ArmCarSpawn		"armoredcar/spawn"
#define ArmCarMove		"armoredcar/driveloop.mp3"
#define ArmCarIdle		"armoredcar/idle.mp3"

#define ARMCAR_ACCELERATION	8.0
#define ARMCAR_SPEEDMAX		330.0
#define ARMCAR_SPEEDMAXREVERSE	300.0	// 20 units slower than Medic
#define ARMCAR_INITSPEED	200.0


methodmap CArmCar < CTank
{
	public CArmCar (const int ind, bool uid=false)
	{
		return view_as<CArmCar>( CTank(ind, uid) );
	}

	public void PlaySpawnSound (const int number)
	{
		char sound[PLATFORM_MAX_PATH];
		Format(sound, PLATFORM_MAX_PATH, "%s%i.mp3", ArmCarSpawn, number); //sounds from Company of Heroes 1
		EmitSoundToAll(sound, this.index, SNDCHAN_VOICE); EmitSoundToAll(sound, this.index, SNDCHAN_VOICE); EmitSoundToAll(sound, this.index, SNDCHAN_VOICE);
	}

	public void Think ()
	{
		int client = this.index;
		if ( !IsPlayerAlive(client) )
			return;
		
		if (GamePlayMode.IntValue == GunGame and this.iHealth < MMCvars[ArmoredCarHP].IntValue) {
			this.iHealth++;
			SetEntityHealth(client, this.iHealth);
		}

		int buttons = GetClientButtons(client);
		float vell[3];	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vell);
		float currtime = GetGameTime();

		if ( (buttons & IN_FORWARD) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(client, SNDCHAN_AUTO, ArmCarIdle);

			this.flSpeed += ARMCAR_ACCELERATION; /*simulates vehicular physics; not as good as Valve does with vehicle entities though*/
			if (this.flSpeed > ARMCAR_SPEEDMAX)
				this.flSpeed = ARMCAR_SPEEDMAX;

			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, ArmCarMove);
				EmitSoundToAll(ArmCarMove, client, SNDCHAN_AUTO);
				this.flSoundDelay = currtime+1.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else if ( (buttons & IN_BACK) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(client, SNDCHAN_AUTO, ArmCarIdle);

			this.flSpeed += ARMCAR_ACCELERATION;

			if (this.flSpeed > ARMCAR_SPEEDMAXREVERSE)
				this.flSpeed = ARMCAR_SPEEDMAXREVERSE;

			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, ArmCarMove);
				EmitSoundToAll(ArmCarMove, client, SNDCHAN_AUTO);
				this.flSoundDelay = currtime+1.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else {
			StopSound(client, SNDCHAN_AUTO, ArmCarMove);

			this.flGas += 0.001;
			if (this.flSoundDelay != 0.0)
				this.flSoundDelay = 0.0;

			if (this.flIdleSound < currtime) {
				//strcopy(snd, PLATFORM_MAX_PATH, ArmCarIdle);
				EmitSoundToAll(ArmCarIdle, client, SNDCHAN_AUTO);
				this.flIdleSound = currtime+2.0;
			}
			this.flSpeed -= ARMCAR_ACCELERATION;
			if (this.flSpeed < ARMCAR_INITSPEED)
				this.flSpeed = ARMCAR_INITSPEED;
		}

		if ( bGasPowered.BoolValue and this.flGas <= 0.0 )
			this.flSpeed = 1.0;
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", this.flSpeed);

		if ( (buttons & IN_ATTACK2) and this.bIsVehicle )	// MOUSE2 20mm Hitscan Cannon
		{
			if ( this.flLastFire < currtime ) {
				float vPosition[3], vAngles[3], vVec[3];
				GetClientEyePosition(client, vPosition);
				GetClientEyeAngles(client, vAngles);

				vVec[0] = Cosine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[1] = Sine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[2] = -Sine( DegToRad(vAngles[0]) );

				vPosition[0] += vVec[0] * 40.0;
				vPosition[1] += vVec[1] * 40.0;
				vPosition[2] += vVec[2] * 40.0;
				vPosition[2] += 3.0;

				float RandAngle = GetRandomFloat(0.0, 360.0); // Handle's 20mm Cannon accuracy
				float RandMagnitudeX = (GetRandomInt(0, 250) / 100.0), RandMagnitudeY = (GetRandomInt(0, 250) / 100.0);

				vAngles[0] += (RandMagnitudeX)*Cosine(RandAngle) * (GetRandomInt(0, 1) == 1 ? -1 : 1);
				vAngles[1] += (RandMagnitudeY)*Sine(RandAngle) * (GetRandomInt(0, 1) == 1 ? -1 : 1);

				int beamcolor[4];
				switch (this.iTeam) {
					case 2: { beamcolor[0] = 190; beamcolor[1] = 59; beamcolor[2] = 59; }
					case 3: { beamcolor[0] = 71; beamcolor[1] = 102; beamcolor[2] = 190; }
				}
				beamcolor[3] = 255;

				TR_TraceRayFilter( vPosition, vAngles, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, client );
				float endpos[3]; TR_GetEndPosition(endpos);

				TE_SetupBeamPoints( vPosition, endpos, PrecacheModel("sprites/laser.vmt", true), PrecacheModel("sprites/laser.vmt", true), 1, 1, 1.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );
				TE_SendToAll();
				
				TE_SetupMuzzleFlash(vPosition, vAngles, 5.0, 1);
				TE_SendToAll();

				if ( TR_DidHit() ) {
					int target = TR_GetEntityIndex();
					if ( IsClientValid(target) and target != client and GetClientTeam(target) != this.iTeam )
					{
						if ( TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) or TF2_IsPlayerInCondition(client, TFCond_CritOnWin) )
						{
							SDKHooks_TakeDamage( target, client, client, MMCvars[ArmoredCarGunDmg].FloatValue*3, DMG_DIRECT );
						}
						else SDKHooks_TakeDamage( target, client, client, MMCvars[ArmoredCarGunDmg].FloatValue, DMG_DIRECT );
					}
					else if ( target > MaxClients and IsValidEntity(target) and GetEntProp(target, Prop_Data, "m_iTeamNum") != this.iTeam)
						SDKHooks_TakeDamage( target, client, client, MMCvars[ArmoredCarGunDmg].FloatValue, DMG_DIRECT);
				}
				EmitSoundToAll(ArmCarShoot, client, SNDCHAN_AUTO); EmitSoundToAll(ArmCarShoot, client, SNDCHAN_AUTO); EmitSoundToAll(ArmCarShoot, client, SNDCHAN_AUTO);
				// Sounds from Company of Heroes 1
				this.flLastFire = currtime + 0.4;

				float PunchVec[3] = {40.0, 0.0, 30.0};
				SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", PunchVec);
			}
		}
		// Stop airblast from pushing vehicles
		//TF2_AddCondition(client, TFCond_MegaHeal, 0.2);
	}
	public void SetModel ()
	{
		SetVariantString(ArmCarModel);
		AcceptEntityInput(this.index, "SetCustomModel");
		SetEntProp(this.index, Prop_Send, "m_bUseClassAnimations", 1);
		/*SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.25);*/
	}

	public void Death ()
	{
		StopSound(this.index, SNDCHAN_AUTO, ArmCarIdle);
		StopSound(this.index, SNDCHAN_AUTO, ArmCarMove);

		char sound[PLATFORM_MAX_PATH];
		Format(sound, PLATFORM_MAX_PATH, "%s%i.mp3", TankDeath, GetRandomInt(1, 2)); //sounds from Call of Duty 1
		EmitSoundToAll(sound, this.index, SNDCHAN_AUTO);
		AttachParticle(this.index, "buildingdamage_dispenser_fire1", 1.0);
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
			Format( attribs, sizeof(attribs), "2 ; %f ; 125 ; %i ; 6 ; 0.5 ; 326 ; 0.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 100 ; 0.01 ; 68 ; -2.0", SMG_DAMAGE_MULT, (1-maxhp) );
		else Format( attribs, sizeof(attribs), "2 ; %f ; 26 ; %i ; 6 ; 0.5 ; 326 ; 0.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 100 ; 0.01 ; 68 ; 1.0", SMG_DAMAGE_MULT, (MMCvars[ArmoredCarHP].IntValue-maxhp) );

		int Turret = this.SpawnWeapon("tf_weapon_smg", 16, 1, 0, attribs);
		SetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon", Turret);
		SetWeaponClip(Turret, MMCvars[MaxSMGAmmo].IntValue);
		SetWeaponAmmo(Turret, 0);
	}

	public void DoEngieInteraction(BaseVehicle engie)
	{
		int iCurrentMetal = GetEntProp(engie.index, Prop_Data, "m_iAmmo", 4, 3);
		int repairamount = HealthFromMetal.IntValue; //default 10
		int mult = HealthFromMetalMult.IntValue; //default 10

		int hClientWeapon = GetEntPropEnt(engie.index, Prop_Send, "m_hActiveWeapon");
		int Turret = GetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon");
		//new wepindex = (IsValidEdict(hClientWeapon) and GetEntProp(hClientWeapon, Prop_Send, "m_iItemDefinitionIndex"));
		char classname[64];
		if (IsValidEdict(hClientWeapon)) GetEdictClassname(hClientWeapon, classname, sizeof(classname));
	
		if (StrEqual(classname, "tf_weapon_wrench", false) or StrEqual(classname, "tf_weapon_robot_arm", false))
		{
			if (this.iHealth > 0 and this.iHealth < MMCvars[ArmoredCarHP].IntValue)
			{
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;

				if ( (MMCvars[ArmoredCarHP].IntValue - this.iHealth < repairamount*mult) )
					repairamount = RoundToCeil( float((MMCvars[ArmoredCarHP].IntValue - this.iHealth)/mult) );

				if (repairamount < 1 and iCurrentMetal > 0)
					repairamount = 1;

				this.iHealth += repairamount*mult;

				if (this.iHealth > MMCvars[ArmoredCarHP].IntValue)
					this.iHealth = MMCvars[ArmoredCarHP].IntValue;

				iCurrentMetal -= repairamount;
				SetEntProp(engie.index, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
			}
			int clip = GetWeaponClip(Turret);
			if ( clip >= 0 and clip < MMCvars[MaxSMGAmmo].IntValue )
			{
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;
				if ((MMCvars[MaxSMGAmmo].IntValue-clip < repairamount*mult))
					repairamount = RoundToCeil(float((MMCvars[MaxSMGAmmo].IntValue-clip)/mult));
				if (repairamount < 1 and iCurrentMetal > 0)
					repairamount = 1;

				SetWeaponClip(Turret, clip+repairamount*mult);
				if (clip > MMCvars[MaxSMGAmmo].IntValue)
					SetWeaponClip(Turret, MMCvars[MaxSMGAmmo].IntValue);

				iCurrentMetal -= repairamount;
				SetEntProp(engie.index, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
			}
			if (repairamount)
				EmitSoundToClient(engie.index, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
			else EmitSoundToClient(engie.index, "weapons/wrench_hit_build_fail.wav");
		}
	}
};

public CArmCar ToCArmCar(BaseVehicle veh)
{
	return view_as<CArmCar> (veh);
}

public void AddArmCarToDownloads()
{
	char s[PLATFORM_MAX_PATH];
	char extensions[][] = { ".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd", ".phy" };
	char extensionsb[][] = { ".vtf", ".vmt" };
	//char extensionsc[][] = { ".wav", ".mp3" };

	AddFileToDownloadsTable("sound/armoredcar/driveloop.mp3");
	AddFileToDownloadsTable("sound/armoredcar/cannon.mp3");
	AddFileToDownloadsTable("sound/armoredcar/idle.mp3");

	int i;
	PrecacheModel(ArmCarModel, true);
	for (i = 0; i < sizeof(extensions); i++)
	{
		Format(s, PLATFORM_MAX_PATH, "%s%s", ArmCarModelPrefix, extensions[i]);
		if (FileExists(s, true))
			AddFileToDownloadsTable(s);
	}
	for (i = 0; i < sizeof(extensionsb); i++)
	{
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/daimler/daimler%s", extensionsb[i]);
		if (FileExists(s, true))
			AddFileToDownloadsTable(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/daimler/daimler_blue%s", extensionsb[i]);
		if (FileExists(s, true))
			AddFileToDownloadsTable(s);
	}
	PrecacheSound(ArmCarShoot, true);
	Format(s, PLATFORM_MAX_PATH, "sound/%s", ArmCarShoot);
	if (FileExists(s, true))
		AddFileToDownloadsTable(s);

	for (i = 1; i < 4; i++) {
		Format(s, PLATFORM_MAX_PATH, "%s%i.mp3", ArmCarSpawn, i);
		PrecacheSound(s, true);
		Format(s, PLATFORM_MAX_PATH, "sound/%s", s);
		if (FileExists(s, true))
			AddFileToDownloadsTable(s);
	}
	PrecacheSound(ArmCarMove, true);
	PrecacheSound(ArmCarIdle, true);
}

public void AddArmCarToMenu( Menu& menu )
{
	menu.AddItem("2", "Armored Car");
}


