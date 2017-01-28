
//defines
#define KingTankModel			"models/custom/tanks/tiger2.mdl" //thx to Friagram for saving teh day!
#define KingTankModelPrefix		"models/custom/tanks/tiger2"

#define KINGROCKET_DMG			150.0
#define KINGTANK_ACCELERATION		2.0
#define KINGTANK_SPEEDMAX		150.0
#define KINGTANK_SPEEDMAXREVERSE	130.0
#define KINGTANK_INITSPEED		20.0


methodmap CKingTank < CTank
{
	public CKingTank(const int ind, bool uid=false)
	{
		return view_as<CKingTank>( CTank(ind, uid) );
	}
	public void Think ()
	{
		int client = this.index;
		if ( !IsPlayerAlive(client) )
			return;

		int buttons = GetClientButtons(client);
		float vell[3];	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vell);
		float currtime = GetGameTime();
		if ( (buttons & IN_FORWARD) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(client, SNDCHAN_AUTO, TankIdle);

			this.flSpeed += KINGTANK_ACCELERATION; /*simulates vehicular physics; not as good as Valve does with vehicle entities though*/
			if (this.flSpeed > KINGTANK_SPEEDMAX)
				this.flSpeed = KINGTANK_SPEEDMAX;

			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankMove);
				EmitSoundToAll(TankMove, client, SNDCHAN_AUTO, _, _, _, 80);
				this.flSoundDelay = currtime+31.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else if ( (buttons & IN_BACK) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(client, SNDCHAN_AUTO, TankIdle);

			this.flSpeed += KINGTANK_ACCELERATION;
			if (this.flSpeed > KINGTANK_SPEEDMAXREVERSE)
				this.flSpeed = KINGTANK_SPEEDMAXREVERSE;
			
			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankMove);
				EmitSoundToAll(TankMove, client, SNDCHAN_AUTO, _, _, _, 80);
				this.flSoundDelay = currtime+31.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else {
			StopSound(client, SNDCHAN_AUTO, TankMove);
			this.flGas += 0.001;

			if (this.flSoundDelay != 0.0)
				this.flSoundDelay = 0.0;
			if ( this.flIdleSound < currtime ) {
				//strcopy(snd, PLATFORM_MAX_PATH, TankIdle);
				EmitSoundToAll(TankIdle, client, SNDCHAN_AUTO, _, _, _, 80);
				this.flIdleSound = currtime+5.0;
			}
			this.flSpeed -= KINGTANK_ACCELERATION;
			if (this.flSpeed < KINGTANK_INITSPEED)
				this.flSpeed = KINGTANK_INITSPEED;
		}

		if ( bGasPowered.BoolValue and this.flGas <= 0.0 )
			this.flSpeed = 1.0;
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", this.flSpeed);

		if ( (buttons & IN_ATTACK2) and this.bIsVehicle ) //MOUSE2 Rocket firing mechanic
		{
			if ( this.flLastFire < currtime ) {
				float vPosition[3], vAngles[3], vVec[3];
				GetClientEyePosition(client, vPosition);
				GetClientEyeAngles(client, vAngles);

				vVec[0] = Cosine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[1] = Sine( DegToRad(vAngles[1]) ) * Cosine( DegToRad(vAngles[0]) );
				vVec[2] = -Sine( DegToRad(vAngles[0]) );

				vPosition[0] += vVec[0] * 100.0;
				vPosition[1] += vVec[1] * 100.0;
				vPosition[2] += vVec[2] * 100.0;
				bool crit = ( TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) or TF2_IsPlayerInCondition(client, TFCond_CritOnWin) );
				TE_SetupMuzzleFlash(vPosition, vAngles, 9.0, 1);
				TE_SendToAll();
				ShootRocket(client, crit, vPosition, vAngles, MMCvars[RocketSpeed].FloatValue, KINGROCKET_DMG, "");
				Format(snd, PLATFORM_MAX_PATH, "%s%i.mp3", TankShoot, GetRandomInt(1, 3)); //sounds from Call of duty 1
				EmitSoundToAll(snd, client, SNDCHAN_AUTO, _, _, _, 80);
				CreateTimer(1.0, Timer_ReloadTank, this.userid, TIMER_FLAG_NO_MAPCHANGE); //useless, only plays a 'reload' sound
				this.flLastFire = currtime + 4.0;

				float PunchVec[3] = {100.0, 0.0, 150.0};
				SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", PunchVec);
			}
		}
		//CreateTimer(0.1, Timer_TankCrush, client);
		//TF2_AddCondition(client, TFCond_MegaHeal, 0.2); /*prevent tanks from being airblasted and gives a team colored aura to allow teams to tell who's on what side */
	}
	public void SetModel ()
	{
		SetVariantString(KingTankModel);
		AcceptEntityInput(this.index, "SetCustomModel");
		SetEntProp(this.index, Prop_Send, "m_bUseClassAnimations", 1);
		/*SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.25);*/
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
		
		if (GamePlayMode.IntValue != GunGame)
			Format( attribs, sizeof(attribs), "521 ; 1.0 ; 2 ; %f ; 125 ; %i ; 6 ; 0.5 ; 326 ; 0.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 68 ; -2.0", SMG_DAMAGE_MULT, (1-maxhp) );
		else Format( attribs, sizeof(attribs), "521 ; 1.0 ; 2 ; %f ; 26 ; %i ; 6 ; 0.5 ; 326 ; 0.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 68 ; -2.0", SMG_DAMAGE_MULT, (MMCvars[KingPanzerHP].IntValue-maxhp) );

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
		if ( IsValidEdict(hClientWeapon) )
			GetEdictClassname(hClientWeapon, classname, sizeof(classname));
	
		if ( !strcmp(classname, "tf_weapon_wrench", false) or !strcmp(classname, "tf_weapon_robot_arm", false) )
		{
			if (this.iHealth and this.iHealth < MMCvars[KingPanzerHP].IntValue) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;

				if ( ( MMCvars[KingPanzerHP].IntValue - this.iHealth < repairamount*mult ) )
					repairamount = RoundToCeil( float((MMCvars[KingPanzerHP].IntValue - this.iHealth)/mult) );

				if (repairamount < 1 and iCurrentMetal)
					repairamount = 1;

				this.iHealth += repairamount*mult;
				if (this.iHealth > MMCvars[KingPanzerHP].IntValue)
					this.iHealth = MMCvars[KingPanzerHP].IntValue;

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

public CKingTank ToCKingTank (BaseVehicle veh)
{
	return view_as<CKingTank> (veh);
}

public void AddKingTankToDownloads ()
{
	char s[PLATFORM_MAX_PATH];
	char extensions[][] = { ".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd", ".phy" };
	char extensionsb[][] = { ".vtf", ".vmt" };
	//char extensionsc[][] = { ".wav", ".mp3" };
	int i;
	PrecacheModel(KingTankModel, true);
	for (i = 0; i < sizeof(extensions); i++) {
		Format(s, PLATFORM_MAX_PATH, "%s%s", KingTankModelPrefix, extensions[i]);
		CheckDownload(s);
	}
	for (i = 0; i < sizeof(extensionsb); i++) {
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/tiger2%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/tiger2_blue%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/tiger2_track%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/tiger_ii_track%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/tiger_ii_track_nm%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/e-75_blue%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/e-75_nm%s", extensionsb[i]);
		CheckDownload(s);
		Format(s, PLATFORM_MAX_PATH, "materials/models/custom/tanks/e-75_red%s", extensionsb[i]);
		CheckDownload(s);
	}
}

public void AddKingTankToMenu ( Menu& menu )
{
	menu.AddItem("5", "King Panzer (Tiger II)");
}


