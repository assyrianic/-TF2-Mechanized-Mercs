
//defines
#define AmbModel		"models/custom/tanks/ambulance.mdl" //thx to Friagram for saving teh day!
#define AmbModelPrefix		"models/custom/tanks/ambulance"

#define AMB_ACCELERATION	6.0
#define AMB_SPEEDMAX		400.0
#define AMB_SPEEDMAXREVERSE	350.0 //20 units slower than medic
#define AMB_INITSPEED		250.0

methodmap CAmbulance < CTank	/*you MUST inherit from CTank if u want roadkilling to work*/
{
	public CAmbulance (const int ind, bool uid=false)
	{
		return view_as<CAmbulance>( CTank(ind, uid) );
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
			StopSound(client, SNDCHAN_AUTO, ArmCarIdle);

			this.flSpeed += AMB_ACCELERATION;
			if (this.flSpeed > AMB_SPEEDMAX)
				this.flSpeed = AMB_SPEEDMAX;

			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(s, PLATFORM_MAX_PATH, ArmCarMove);
				EmitSoundToAll(ArmCarMove, client, SNDCHAN_AUTO);
				this.flSoundDelay = currtime+1.0;
			}
			if (bGasPowered.BoolValue)
				this.DrainGas(0.1);
		}
		else if ( (buttons & IN_BACK) and vell[0] != 0.0 and vell[1] != 0.0 )
		{
			StopSound(client, SNDCHAN_AUTO, ArmCarIdle);

			this.flSpeed += AMB_ACCELERATION;
			if (this.flSpeed > AMB_SPEEDMAXREVERSE)
				this.flSpeed = AMB_SPEEDMAXREVERSE;
			
			if (this.flIdleSound != 0.0)
				this.flIdleSound = 0.0;
			if ( this.flSoundDelay < currtime ) {
				//strcopy(s, PLATFORM_MAX_PATH, ArmCarMove);
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
			if ( this.flIdleSound < currtime ) {
				//strcopy(s, PLATFORM_MAX_PATH, ArmCarIdle);
				EmitSoundToAll(ArmCarIdle, client, SNDCHAN_AUTO);
				this.flIdleSound = currtime+2.0;
			}
			this.flSpeed -= AMB_ACCELERATION;
			if (this.flSpeed < AMB_INITSPEED)
				this.flSpeed = AMB_INITSPEED;
		}

		if ( bGasPowered.BoolValue and this.flGas <= 0.0 )
			this.flSpeed = 1.0;
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", this.flSpeed);

		//TF2_AddCondition(client, TFCond_MegaHeal, 0.1);
		/* prevent tanks from being airblasted and gives a team colored aura to allow teams to tell who's on what side */

		for ( int i=MaxClients ; i ; --i ) {
			if ( !IsValidClient(i) )
				continue;

			else if ( !IsPlayerAlive(i) or !IsInRange(client, i, 300.0) )
				continue;
				
			else if ( BaseVehicle(i).bIsVehicle )
				continue;
			
			else if ( GetClientTeam(i) != this.iTeam or i == client )
				continue;

			int maxhp = GetEntProp(i, Prop_Data, "m_iMaxHealth");
			int curHealth = GetClientHealth(i);
			if ( curHealth < maxhp )
				SetEntityHealth( i, ++curHealth );

			TF2_AddCondition(i, TFCond_InHealRadius, 0.1);
		}
	}
	public void SetModel ()
	{
		SetVariantString(AmbModel);
		AcceptEntityInput(this.index, "SetCustomModel");
		SetEntProp(this.index, Prop_Send, "m_bUseClassAnimations", 1);
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
				AcceptEntityInput(ent, "Kill");
		}

		TF2_RemoveAllWeapons(this.index);
		int maxhp = GetEntProp(this.index, Prop_Data, "m_iMaxHealth");

		char attribs[128];
		Format( attribs, sizeof(attribs), "2 ; %f ; 125 ; %i ; 326 ; 0.0 ; 252 ; 0.0 ; 25 ; 0.0 ; 53 ; 1 ; 59 ; 0.0 ; 60 ; 0.01 ; 100 ; 0.01 ; 68 ; -2.0", SMG_DAMAGE_MULT, (1-maxhp) );

		int Turret = this.SpawnWeapon("tf_weapon_smg", 16, 1, 0, attribs);
		SetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon", Turret);
		SetWeaponClip(Turret, MMCvars[MaxSMGAmmo].IntValue);
		SetWeaponAmmo(Turret, 0);
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
			if (this.iHealth > 0 and this.iHealth < MMCvars[AmbulanceHP].IntValue) {
				if (iCurrentMetal < repairamount)
					repairamount = iCurrentMetal;

				if ( (MMCvars[AmbulanceHP].IntValue - this.iHealth < repairamount*mult) )
					repairamount = RoundToCeil( float((MMCvars[AmbulanceHP].IntValue - this.iHealth)/mult) );

				if (repairamount < 1 and iCurrentMetal > 0)
					repairamount = 1;

				this.iHealth += repairamount*mult;

				if (this.iHealth > MMCvars[AmbulanceHP].IntValue)
					this.iHealth = MMCvars[AmbulanceHP].IntValue;

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

public CAmbulance ToCAmbulance (BaseVehicle veh)
{
	return view_as<CAmbulance> (veh);
}

public void AddAmbToDownloads ()
{
	char s[PLATFORM_MAX_PATH];
	char extensions[][] = { ".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd", ".phy" };
	//char extensionsb[][] = { ".vtf", ".vmt" };
	//char extensionsc[][] = { ".wav", ".mp3" };
	int i;
	PrecacheModel(AmbModel, true);
	for (i = 0; i < sizeof(extensions); i++) {
		Format(s, PLATFORM_MAX_PATH, "%s%s", AmbModelPrefix, extensions[i]);
		CheckDownload(s);
	}
}

public void AddAmbToMenu ( Menu& menu )
{
	menu.AddItem("3", "Ambulance");
}

