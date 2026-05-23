// Shared state and typed snapshots for spechud.

#define SPECHUD_DRAW_INTERVAL 0.5
#define TRANSLATION_FILE "spechud.phrases"

#define LIBRARY_READYUP "readyup"
#define LIBRARY_PAUSE "pause"
#define LIBRARY_L4D_BOSS_PERCENT "l4d_boss_percent"
#define LIBRARY_L4D2_HYBRID_SCOREMOD_ZONE "l4d2_hybrid_scoremod_zone"
#define LIBRARY_L4D2_HYBRID_SCOREMOD "l4d2_hybrid_scoremod"
#define LIBRARY_L4D2_SCOREMOD "l4d2_scoremod"
#define LIBRARY_L4D2_HEALTH_TEMP_BONUS "l4d2_health_temp_bonus"
#define LIBRARY_L4D_TANK_CONTROL_EQ "l4d_tank_control_eq"
#define LIBRARY_LERP_MONITOR "lerpmonitor"
#define LIBRARY_WITCH_AND_TANKIFIER "witch_and_tankifier"

int g_iGamemode;

ConVar g_cvSurvivorLimit;
ConVar g_cvVersusBossBuffer;
ConVar g_cvMaxPlayers;
ConVar g_cvTankBurnDuration;
int g_iSurvivorLimit;
int g_iMaxPlayers;
float g_fVersusBossBuffer;
float g_fTankBurnDuration;

ConVar g_cvTankPercent;
ConVar g_cvWitchPercent;
ConVar g_cvReadyServerCvar;
ConVar g_hServerNamer;
ConVar g_cvReadyCfgName;

char g_sReadyCfgName[64];
char g_sHostname[64];
bool g_bRoundLive;

/**
 * @brief Stores the cached boss percentage state.
 */
enum struct BossFlowState
{
	int tankPercent;
	int witchPercent;
	bool synced;

	/**
	 * @brief Resets the cached boss percentages.
	 */
	void Reset()
	{
		this.tankPercent = -1;
		this.witchPercent = -1;
		this.synced = false;
	}
}

BossFlowState g_BossFlow;

/**
 * @brief Stores boss-round counters and flags.
 */
enum struct BossRoundState
{
	int tankCount;
	int witchCount;
	bool roundHasFlowTank;
	bool roundHasFlowWitch;
	bool flowTankActive;
	bool customBossSys;

	/**
	 * @brief Resets the cached boss-round state.
	 */
	void Reset()
	{
		this.tankCount = 0;
		this.witchCount = 0;
		this.roundHasFlowTank = false;
		this.roundHasFlowWitch = false;
		this.flowTankActive = false;
		this.customBossSys = false;
	}
}

BossRoundState g_BossRound;

// Boss Spawn Scheme
StringMap g_hFirstTankSpawningScheme, g_hSecondTankSpawningScheme;		// eq_finale_tanks (Zonemod, Acemod, etc.)
StringMap g_hFinaleExceptionMaps;										// finale_tank_blocker (Promod and older?)
StringMap g_hCustomTankScriptMaps;										// Handled by this plugin

// Score & Scoremod
//int iFirstHalfScore;
int g_iMaxDistance;

// Witch and Tankifier
bool g_bStaticTank, g_bStaticWitch;

// Hud Toggle & Hint Message
bool g_bSpecHudActive[MAXPLAYERS+1], g_bTankHudActive[MAXPLAYERS+1];
bool g_bSpecHudHintShown[MAXPLAYERS+1], g_bTankHudHintShown[MAXPLAYERS+1];

/**
 * @brief Pre-formatted tank HUD lines.
 */
enum struct TankHudSnapshot
{
	char title[64];
	char control[64];
	char health[64];
	char frustration[64];
	char network[64];
	char fire[64];
	bool hasFire;
}

/**
 * @brief Cached weapon state for HUD formatting.
 */
enum struct WeaponSnapshot
{
	int client;
	int activeWep;
	int primaryWep;
	int secondaryWep;
	int activeWepId;
	int primaryWepId;
	bool dualWield;
	int activeClip;
	int primaryClip;
	int primaryExtra;
}

/**
 * @brief Cached survivor state for HUD formatting.
 */
enum struct SurvivorSnapshot
{
	int client;
	int health;
	int incapCount;
	int tempHealth;
	bool alive;
	bool hanging;
	bool incapacitated;
}

/**
 * @brief Cached infected state for HUD formatting.
 */
enum struct InfectedSnapshot
{
	int client;
	L4D2ZombieClassType zClass;
	int health;
	int maxHealth;
	int victim;
	int cooldown;
	bool alive;
	bool ghost;
	bool onFire;
	bool hasCooldown;
	char className[10];
}

/**
 * @brief Runtime feature flags and late-load state.
 */
enum struct RuntimeState
{
	bool lateload;
	bool readyUp;
	bool pause;
	bool l4dBossPercent;
	bool hybridScoremodZone;
	bool hybridScoremod;
	bool scoremod;
	bool healthTempBonus;
	bool tankControlEq;
	bool lerpMonitor;
	bool witchAndTankifier;
	bool tankSelection;

	/**
	 * @brief Resets runtime flags.
	 */
	void Reset()
	{
		this.lateload = false;
		this.readyUp = false;
		this.pause = false;
		this.l4dBossPercent = false;
		this.hybridScoremodZone = false;
		this.hybridScoremod = false;
		this.scoremod = false;
		this.healthTempBonus = false;
		this.tankControlEq = false;
		this.lerpMonitor = false;
		this.witchAndTankifier = false;
		this.tankSelection = false;
	}

	/**
	 * @brief Refreshes the full runtime snapshot.
	 */
	void Refresh()
	{
		this.readyUp = LibraryExists(LIBRARY_READYUP);
		this.pause = LibraryExists(LIBRARY_PAUSE);
		this.l4dBossPercent = LibraryExists(LIBRARY_L4D_BOSS_PERCENT);
		this.hybridScoremodZone = LibraryExists(LIBRARY_L4D2_HYBRID_SCOREMOD_ZONE);
		this.hybridScoremod = LibraryExists(LIBRARY_L4D2_HYBRID_SCOREMOD);
		this.scoremod = LibraryExists(LIBRARY_L4D2_SCOREMOD);
		this.healthTempBonus = LibraryExists(LIBRARY_L4D2_HEALTH_TEMP_BONUS);
		this.tankControlEq = LibraryExists(LIBRARY_L4D_TANK_CONTROL_EQ);
		this.lerpMonitor = LibraryExists(LIBRARY_LERP_MONITOR);
		this.witchAndTankifier = LibraryExists(LIBRARY_WITCH_AND_TANKIFIER);
		this.tankSelection = (GetFeatureStatus(FeatureType_Native, "GetTankSelection") != FeatureStatus_Unknown);
	}
}

RuntimeState g_Runtime;
