
#define SUPPORTBUILT		2	// wtf is the point of bit shifting when I can just directly put the number?
#define OFFENSIVEBUILT		4
#define HEAVYBUILT		8

#define SUPPORTGARAGE		0
#define OFFENSEGARAGE		1
#define HEAVYGARAGE		2

#if defined _steamtools_included
bool steamtools;
#endif

bool
	isVSH, isMVM
;

/*
int
	GarageFlags[2],
	GarageRefs[2][3],	/// index 0-2 stores support, offensive, and heavy garages
	GarageGlowRefs[2][3]	/// I should've made GarageRefs like this but I'm too lazy to modify. EDIT: did it :3
;
*/
/*
float
	GarageBuildTime[2][3]
;
*/
#define	MAX_CONSTRUCT_VEHICLES	10

#define ENTREF		0
#define VEHTYPE		1
#define BUILDER		2
#define METAL		3
#define AMMO		4
#define HEALTH		5
#define PLYRHP		6
#define MAXMETAL	7
#define ROCKETS		8
#define GASLEFT		9

int TankConstruct[2][MAX_CONSTRUCT_VEHICLES][10];
/** 0-red ; 1-blue */

methodmap GameModeManager {
	public GameModeManager() {}
	/*
	property int RedGarageFlags
	{
		public get()				{ return GarageFlags[0]; }
		public set( const int val )		{ GarageFlags[0] = val; }
	}
	property int BluGarageFlags
	{
		public get()				{ return GarageFlags[1]; }
		public set( const int val )		{ GarageFlags[1] = val; }
	}
	*/
#if defined _steamtools_included
	property bool bSteam
	{
		public get()				{ return steamtools; }
		public set( const bool val )		{ steamtools = val; }
	}
#endif
	property bool bisVSH
	{
		public get()				{ return isVSH; }
		public set( const bool val )		{ isVSH = val; }
	}
	property bool bisMVM
	{
		public get()				{ return isMVM; }
		public set( const bool val )		{ isMVM = val; }
	}
	/*
	public int GetGarage(const int index, const int offset)
	{
		return EntRefToEntIndex( GarageRefs[index][ offset ] );
	}
	public int GaragesBuilt(const int team)
	{
		int num = team;
		if (num-2 < 0)
			num = 2;
		switch (num-2) {
			case 0: return this.RedGarageFlags;
			case 1: return this.BluGarageFlags;
		}
		return 0;
	}
	public void DeleteGarage(const int x, const int flag)
	{
		GarageFlags[x] &= ~flag ;
	}
	public int GetGarageRefFlags(const int index)
	{
		int flag;
		if (GarageRefs[index][SUPPORTGARAGE] and IsValidEntity(this.GetGarage(index, SUPPORTGARAGE)))
			flag |= SUPPORTBUILT;
		if (GarageRefs[index][OFFENSEGARAGE] and IsValidEntity(this.GetGarage(index, OFFENSEGARAGE)))
			flag |= OFFENSIVEBUILT;
		if (GarageRefs[index][HEAVYGARAGE] and IsValidEntity(this.GetGarage(index, HEAVYGARAGE)))
			flag |= HEAVYBUILT;
		return flag;
	}
	public bool IsNearGarage(const int client, const float dist)
	{
		int team = GetClientTeam(client);
		float vecPlayerOrigin[3], vecGarageOrigin[3];
		vecPlayerOrigin = Vec_GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin");
		for( int off=0 ; off<3 ; ++off ) {
			int garage=this.GetGarage(team-2, off);
			vecGarageOrigin = Vec_GetEntPropVector(garage, Prop_Data, "m_vecAbsOrigin");
			if( GetVectorDistance(vecPlayerOrigin, vecGarageOrigin) <= dist )
				return true;
		}
		return false;
	}
	*/
	
	public bool IsPowerupFull(int team) {
		int count=0;
		for (int k=0 ; k < MAX_CONSTRUCT_VEHICLES ; ++k) {
			if (!TankConstruct[team-2][k][ENTREF])
				continue;
			else if (TankConstruct[team-2][k][ENTREF] and !IsValidEntity(EntRefToEntIndex(TankConstruct[team-2][k][ENTREF])))
				TankConstruct[team-2][k][ENTREF] = 0;
			
			if (TankConstruct[team-2][k][ENTREF])
				++count;
		}
		return (count == MAX_CONSTRUCT_VEHICLES);
	}
	
	public int GetNextEmptyPowerUpSlot(int team) {
		for( int k=0; k < MAX_CONSTRUCT_VEHICLES; k++ ) {
			if( TankConstruct[team-2][k][ENTREF] != 0 ) {
				continue;
			}
			return k;
		}
		return -1;
	}
	
	public int FindEntityPowerUpIndex(int team, int entity) {
		if( entity < 0 )
			return -1;
		
		for( int k; k < MAX_CONSTRUCT_VEHICLES; k++ ) {
			int construct = TankConstruct[team-2][k][ENTREF];
			if( !construct )
				continue;
			else if( construct && !IsValidEntity(EntRefToEntIndex(construct)) )
				TankConstruct[team-2][k][ENTREF] = 0;
			else if( EntRefToEntIndex(construct)==entity )
				return k;
		}
		return -1;
	}
	
	public int SpawnTankConstruct(int builder, float vecOrigin[3], int team, int vehtype, bool ask) {
		int construct = CreateEntityByName("prop_dynamic_override");
		if( construct <= 0 or !IsValidEdict(construct) )
			return -1;
		
		char tName[32]; tName[0] = '\0';
		char szModelPath[PLATFORM_MAX_PATH];
		int metal;
		switch (vehtype) {
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
		
		DispatchSpawn(construct);
		SetEntProp( construct, Prop_Send, "m_nSolidType", 6 );
		TeleportEntity(construct, vecOrigin, NULL_VECTOR, NULL_VECTOR);

		int beamcolor[4] = {0, 255, 90, 255};

		float vecMins[3], vecMaxs[3];
		vecMins = Vec_AddVectors(vecOrigin, mins); //AddVectors(vecOrigin, mins, vecMins);
		vecMaxs = Vec_AddVectors(vecOrigin, maxs); //AddVectors(vecOrigin, maxs, vecMaxs);

		int laser = PrecacheModel("sprites/laser.vmt", true);
		TE_SendBeamBoxToAll( vecMaxs, vecMins, laser, laser, 1, 1, 5.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );

		SetEntProp(construct, Prop_Data, "m_takedamage", 2, 1);
		SDKHook(construct, SDKHook_OnTakeDamage,	OnConstructTakeDamage);
		SDKHook(construct, SDKHook_Touch,		OnConstructTouch);
		
		SetEntProp(construct, Prop_Data, "m_iHealth", MMCvars[VehicleConstructHP].IntValue);
		if ( IsValidEntity(construct) and IsValidEdict(construct) ) {
			int index = this.GetNextEmptyPowerUpSlot(team);
			if (index == -1) {
				CPrintToChat(builder, "{red}[Mechanized Mercs] {white}SpawnTankConstruct::Logic Error.");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(construct) );
				return -1;
			}
			TankConstruct[team-2][index][ENTREF] = EntIndexToEntRef(construct);
			TankConstruct[team-2][index][VEHTYPE] = vehtype;
			TankConstruct[team-2][index][BUILDER] = GetClientUserId(builder);
			TankConstruct[team-2][index][METAL] = 0;
			TankConstruct[team-2][index][AMMO] = 0;
			TankConstruct[team-2][index][HEALTH] = 0;
			//TankConstruct[team-2][index][PLYRHP] = 0;
			TankConstruct[team-2][index][MAXMETAL] = metal;
			return index;
		}
		return -1;
	}
	
	public int SpawnTankPowerup(float vecOrigin[3], int vehtype) {
		int PowUp = CreateEntityByName("prop_dynamic_override");
		if ( PowUp <= 0 or !IsValidEdict(PowUp) )
			return -1;
		
		char tName[32]; tName[0] = '\0';
		char szModelPath[PLATFORM_MAX_PATH];
		switch (vehtype) {
			case Tank: {
				szModelPath = TankModel;
				Format(tName, sizeof(tName), "panzer4%i", GetRandomInt(0, 9999999));
			}
			case ArmoredCar: {
				szModelPath = ArmCarModel;
				Format(tName, sizeof(tName), "armoredcar%i", GetRandomInt(0, 9999999));
			}
			case Ambulance: {
				szModelPath = AmbModel;
				Format(tName, sizeof(tName), "ambulance%i", GetRandomInt(0, 9999999));
			}
			case PanzerIII: {
				szModelPath = LightTankModel;
				Format(tName, sizeof(tName), "lighttank%i", GetRandomInt(0, 9999999));
			}
			case KingPanzer: {
				szModelPath = KingTankModel;
				Format(tName, sizeof(tName), "tiger%i", GetRandomInt(0, 9999999));
			}
			case Destroyer: {
				szModelPath = DestroyerModel;
				Format(tName, sizeof(tName), "marder%i", GetRandomInt(0, 9999999));
			}
		}
		DispatchKeyValue(PowUp, "targetname", tName);
		char szskin[32]; Format(szskin, sizeof(szskin), "%d", GetRandomInt(0,1));
		DispatchKeyValue(PowUp, "skin", szskin);

		SetEntityModel(PowUp, szModelPath);
		SetEntPropFloat(PowUp, Prop_Send, "m_flModelScale", 1.25);

		float mins[3], maxs[3];
		mins = Vec_GetEntPropVector(PowUp, Prop_Send, "m_vecMins");
		maxs = Vec_GetEntPropVector(PowUp, Prop_Send, "m_vecMaxs");

		DispatchSpawn(PowUp);
		SetEntProp( PowUp, Prop_Send, "m_nSolidType", 6 );
		TeleportEntity(PowUp, vecOrigin, NULL_VECTOR, NULL_VECTOR);

		int beamcolor[4] = {0, 255, 90, 255};

		float vecMins[3], vecMaxs[3];
		mins = Vec_GetEntPropVector(PowUp, Prop_Send, "m_vecMins");
		maxs = Vec_GetEntPropVector(PowUp, Prop_Send, "m_vecMaxs");

		vecMins = Vec_AddVectors(vecOrigin, mins); //AddVectors(vecOrigin, mins, vecMins);
		vecMaxs = Vec_AddVectors(vecOrigin, maxs); //AddVectors(vecOrigin, maxs, vecMaxs);

		int laser = PrecacheModel("sprites/laser.vmt", true);
		TE_SendBeamBoxToAll( vecMaxs, vecMins, laser, laser, 1, 1, 5.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );

		SDKHook(PowUp, SDKHook_Touch, OnPowUpTouch);
		return PowUp;
	}
};

stock int OffsetToFlag(int x) {
	return 2 << x;
}
stock int FlagtoOffset(int x) {
	return x >>> 2;
}
