#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>

#undef REQUIRE_PLUGIN
#include <l4d2lib>
#include <readyup>
#define REQUIRE_PLUGIN

#define SURVIVOR_STATE_LENGTH 32
#define LIBRARY_L4DLIB "l4d2lib"
#define LIBRARY_READYUP "readyup"
#define SMPLUS_BONUS_TYPE_COUNT 4

enum SMPlusBonusType
{
	SMPlusBonusType_Total = 0,
	SMPlusBonusType_Health,
	SMPlusBonusType_Damage,
	SMPlusBonusType_Pills
}

enum SMPlusMode
{
	SMPlusMode_Legacy = 0,
	SMPlusMode_Hybrid,
	SMPlusMode_Zone
}

enum SMPlusRoundStartSignalType
{
	SMPlusRoundStartSignal_None = 0,
	SMPlusRoundStartSignal_GenericRoundStart,
	SMPlusRoundStartSignal_ScavengeRoundStart
}

enum SMPlusRoundEndSignalType
{
	SMPlusRoundEndSignal_None = 0,
	SMPlusRoundEndSignal_GenericRoundEnd,
	SMPlusRoundEndSignal_ScavengeRoundFinished
}

enum SMPlusRoundLiveSignalType
{
	SMPlusRoundLiveSignal_None = 0,
	SMPlusRoundLiveSignal_Immediate,
	SMPlusRoundLiveSignal_SafeArea,
	SMPlusRoundLiveSignal_ReadyUpOrSafeArea
}

enum struct SMPlusTeamSnapshot
{
	SMPlusMode mode;
	int		   currentRound;
	bool	   roundFinalized;
	bool	   matchFinalized;
	int		   teamSize;
	int		   mapDistance;
	int		   aliveSurvivors;
	int		   uprightSurvivors;
	int		   pillWorth;
	int		   adrenalineWorth;
	float	   healthBonus;
	float	   damageBonus;
	float	   pillsBonus;
	float	   totalBonus;
	float	   maxHealthBonus;
	float	   maxDamageBonus;
	float	   maxPillsBonus;
	float	   maxTotalBonus;
	float	   externalHealthBonus;
	float	   externalDamageBonus;
	float	   externalPillsBonus;
	float	   externalTotalBonus;
	float	   effectiveHealthBonus;
	float	   effectiveDamageBonus;
	float	   effectivePillsBonus;
	float	   effectiveTotalBonus;
	float	   roundBonus[2];
	int		   roundSIDamage[2];
	char	   roundState1[SURVIVOR_STATE_LENGTH];
	char	   roundState2[SURVIVOR_STATE_LENGTH];
}

enum struct SMPlusClientSnapshot
{
	int	  client;
	int	  userid;
	bool  alive;
	bool  incapped;
	bool  ledged;
	bool  hasPills;
	bool  hasAdrenaline;
	int	  permanentHealth;
	int	  temporaryHealth;
	int	  reviveCount;
	float healthBonus;
	float damageBonus;
	float pillsBonus;
	float totalBonus;
	float externalHealthBonus;
	float externalDamageBonus;
	float externalPillsBonus;
	float externalTotalBonus;
	float effectiveHealthBonus;
	float effectiveDamageBonus;
	float effectivePillsBonus;
	float effectiveTotalBonus;
}

enum struct RuntimeState
{
	bool lateLoad;
	bool roundOver;
	bool roundLive;
	bool hasL4D2Lib;
	bool hasReadyUp;
	bool tiebreakerEligibility[2];
	int baseMode;
	SMPlusRoundStartSignalType roundStartSignal;
	SMPlusRoundEndSignalType roundEndSignal;
	SMPlusRoundLiveSignalType roundLiveSignal;

	void Reset()
	{
		this.lateLoad = false;
		this.roundOver = false;
		this.roundLive = false;
		this.hasL4D2Lib = false;
		this.hasReadyUp = false;
		this.tiebreakerEligibility[0] = false;
		this.tiebreakerEligibility[1] = false;
		this.baseMode = GAMEMODE_UNKNOWN;
		this.roundStartSignal = SMPlusRoundStartSignal_None;
		this.roundEndSignal = SMPlusRoundEndSignal_None;
		this.roundLiveSignal = SMPlusRoundLiveSignal_None;
	}

	void Refresh()
	{
		this.hasL4D2Lib = LibraryExists(LIBRARY_L4DLIB);
		this.hasReadyUp = LibraryExists(LIBRARY_READYUP);
	}
}

enum struct SMPlusModeContextData
{
	int baseMode;
	bool hasReadyUp;
	bool isVersusMode;

	void Reset()
	{
		this.baseMode = GAMEMODE_UNKNOWN;
		this.hasReadyUp = false;
		this.isVersusMode = false;
	}
}

enum struct SMPlusLifecyclePolicyData
{
	int baseMode;
	SMPlusRoundStartSignalType roundStartSignal;
	SMPlusRoundEndSignalType roundEndSignal;
	SMPlusRoundLiveSignalType roundLiveSignal;

	void Reset()
	{
		this.baseMode = GAMEMODE_UNKNOWN;
		this.roundStartSignal = SMPlusRoundStartSignal_None;
		this.roundEndSignal = SMPlusRoundEndSignal_None;
		this.roundLiveSignal = SMPlusRoundLiveSignal_None;
	}
}

enum struct LegacyConfigState
{
    bool enabled;
    int defaultSurvivalBonus;
    int defaultTieBreaker;
    int pillsHealthValue;
    int adrenalineHealthBuffer;
    int customMaxDistance;
    float firstAidHealPercent;
    float mapMulti;
    float healthBonusRatio;
    float survivalBonusRatio;
    float tempMulti[3];
}

enum struct LegacyRoundState
{
    bool firstRoundOver;
    bool secondRoundStarted;
    bool secondRoundOver;
    int firstScore;
    int difference;

    void Reset()
    {
        this.firstRoundOver = false;
        this.secondRoundStarted = false;
        this.secondRoundOver = false;
        this.firstScore = 0;
        this.difference = 0;
    }
}

enum struct SurvivorCountCacheState
{
	bool dirty;
	int alive;
	int upright;

	void Reset()
	{
		this.dirty = true;
		this.alive = 0;
		this.upright = 0;
	}
}

enum struct LegacyEvalCacheState
{
	bool dirty;
	int aliveCount;
	float averageHealth;
	int survivalBonus;

	void Reset()
	{
		this.dirty = true;
		this.aliveCount = 0;
		this.averageHealth = 0.0;
		this.survivalBonus = 0;
	}
}

enum struct TeamSnapshotCacheState
{
	bool dirty;
	SMPlusTeamSnapshot snapshot;

	void Reset()
	{
		this.dirty = true;
	}
}

enum struct ClientSnapshotCacheState
{
	bool dirty;
	SMPlusClientSnapshot snapshot;

	void Reset()
	{
		this.dirty = true;
	}
}

/**
	Bibliography:
	'l4d2_scoremod' by CanadaRox, ProdigySim
	'damage_bonus' by CanadaRox, Stabby
	'l4d2_scoringwip' by ProdigySim
	'srs.scoringsystem' by AtomicStryker
**/

ConVar		  g_cvBonusPerSurvivorMultiplier;
ConVar		  g_cvPermanentHealthProportion;
ConVar		  g_cvPillsHpFactor;
ConVar		  g_cvPillsMaxBonus;
ConVar		  g_cvMode;
ConVar		  g_cvDebug;
ConVar		  g_cvValveSurvivalBonus;
ConVar		  g_cvValveTieBreaker;
ConVar		  g_cvSurvivorLimit;
ConVar		  g_cvPainPillsDecayRate;
GlobalForward g_fwOnScoreUpdated;
GlobalForward g_fwOnRoundFinalized;
GlobalForward g_fwOnMatchFinalized;

float		  g_fMapBonus;
float		  g_fMapHealthBonus;
float		  g_fMapDamageBonus;
float		  g_fMapTempHealthBonus;
float		  g_fPermHpWorth;
float		  g_fTempHpWorth;
float		  g_fSurvivorBonus[2];

int			  g_iMapDistance;
int			  g_iTeamSize;
int			  g_iPillWorth;
int			  g_iLostTempHealth[2];
int			  g_iTempHealth[MAXPLAYERS + 1];
int			  g_iSiDamage[2];
float		  g_fExternalTeamBonus[SMPLUS_BONUS_TYPE_COUNT];
float		  g_fExternalClientBonus[MAXPLAYERS + 1][SMPLUS_BONUS_TYPE_COUNT];

char		  g_sSurvivorState[2][SURVIVOR_STATE_LENGTH];
RuntimeState  g_Runtime;
LegacyConfigState g_LegacyConfig;
LegacyRoundState  g_LegacyRound;
SurvivorCountCacheState g_SurvivorCountCache;
LegacyEvalCacheState g_LegacyEvalCache;
TeamSnapshotCacheState g_TeamSnapshotCache;
ClientSnapshotCacheState g_ClientSnapshotCache[MAXPLAYERS + 1];
ConVar		  g_cvLegacyEnable;
ConVar		  g_cvLegacyHBRatio;
ConVar		  g_cvLegacySurvivalBonusRatio;
ConVar		  g_cvLegacyMapMulti;
ConVar		  g_cvLegacyCustomMaxDistance;
ConVar		  g_cvLegacyHealPercent;
ConVar		  g_cvLegacyPillPercent;
ConVar		  g_cvLegacyAdrenPercent;
ConVar		  g_cvLegacyTempMulti0;
ConVar		  g_cvLegacyTempMulti1;
ConVar		  g_cvLegacyTempMulti2;

public Plugin myinfo =
{
	name		= "L4D2 Scoremod+",
	author		= "Visor, Sir",
	description = "The next generation scoring mod",
	version		= "3.0.0",
	url			= "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

#include "l4d2_hybrid_scoremod/shared.sp"
#include "l4d2_hybrid_scoremod/external_bonus.sp"
#include "l4d2_hybrid_scoremod/hybrid.sp"
#include "l4d2_hybrid_scoremod/legacy.sp"
#include "l4d2_hybrid_scoremod/snapshot.sp"
#include "l4d2_hybrid_scoremod/natives.sp"
#include "l4d2_hybrid_scoremod/commands.sp"
#include "l4d2_hybrid_scoremod/events.sp"

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	CreateNative("SMPlus_GetMode", Native_GetMode);
	CreateNative("SMPlus_AddExternalBonus", Native_AddExternalBonus);
	CreateNative("SMPlus_SetExternalBonus", Native_SetExternalBonus);
	CreateNative("SMPlus_GetExternalBonus", Native_GetExternalBonus);
	CreateNative("SMPlus_ResetExternalBonus", Native_ResetExternalBonus);
	CreateNative("SMPlus_FillSnapshot", Native_FillSnapshot);
	CreateNative("SMPlus_FillClientSnapshot", Native_FillClientSnapshot);

	RegPluginLibrary("l4d2_hybrid_scoremod");
	g_fwOnScoreUpdated	 = new GlobalForward("SMPlus_OnScoreUpdated", ET_Ignore);
	g_fwOnRoundFinalized = new GlobalForward("SMPlus_OnRoundFinalized", ET_Ignore, Param_Cell);
	g_fwOnMatchFinalized = new GlobalForward("SMPlus_OnMatchFinalized", ET_Ignore, Param_Cell);
	g_Runtime.Reset();
	g_Runtime.lateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4d2_hybrid_scoremod.phrases");
	g_SurvivorCountCache.Reset();
	g_LegacyEvalCache.Reset();
	g_TeamSnapshotCache.Reset();
	for (int client = 0; client <= MaxClients; client++)
	{
		g_ClientSnapshotCache[client].Reset();
	}

	g_cvDebug					   = CreateConVar("smplus_debug", "0", "Enable scoremod debug output");
	g_cvMode					   = CreateConVar("smplus_mode", "2", "Score mode: 0 = legacy, 1 = hybrid, 2 = zone");
    
	g_cvBonusPerSurvivorMultiplier = CreateConVar("smplus_bonus_per_survivor_multiplier", "0.5", "Total Survivor Bonus = this * Number of Survivors * Map Distance");
	g_cvPermanentHealthProportion  = CreateConVar("smplus_permanent_health_proportion", "0.75", "Permanent Health Bonus = this * Map Bonus; rest goes for Temporary Health Bonus");
	g_cvPillsHpFactor			   = CreateConVar("smplus_pills_hp_factor", "6.0", "Unused pills HP worth = map bonus HP value / this");
	g_cvPillsMaxBonus			   = CreateConVar("smplus_pills_max_bonus", "30", "Unused pills cannot be worth more than this");

	g_cvLegacyEnable			   = CreateConVar("smplus_legacy_enable", "1", "Legacy score model enabled");
	g_cvLegacyHBRatio			   = CreateConVar("smplus_legacy_health_bonus_ratio", "2.0", "Legacy health bonus multiplier", FCVAR_NONE, true, 0.25, true, 5.0);
	g_cvLegacySurvivalBonusRatio   = CreateConVar("smplus_legacy_survival_bonus_ratio", "0.0", "Legacy static survival bonus ratio", FCVAR_NONE);
	g_cvLegacyTempMulti0		   = CreateConVar("smplus_legacy_temp_multi_incap_0", "0.30625", "Legacy temp health multiplier for zero incaps", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLegacyTempMulti1		   = CreateConVar("smplus_legacy_temp_multi_incap_1", "0.17500", "Legacy temp health multiplier for one incap", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLegacyTempMulti2		   = CreateConVar("smplus_legacy_temp_multi_incap_2", "0.10000", "Legacy temp health multiplier for two incaps", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLegacyHealPercent		   = CreateConVar("smplus_legacy_first_aid_heal_percent", "0.8", "Legacy first aid heal percent");
	g_cvLegacyPillPercent		   = CreateConVar("smplus_legacy_pain_pills_health_value", "50", "Legacy pills buffer amount");
	g_cvLegacyAdrenPercent		   = CreateConVar("smplus_legacy_adrenaline_health_buffer", "30", "Legacy adrenaline buffer amount");
	g_cvLegacyMapMulti			   = CreateConVar("smplus_legacy_map_multi", "1", "Legacy max bonus scales to map distance");
	g_cvLegacyCustomMaxDistance	   = CreateConVar("smplus_legacy_custom_max_distance", "0", "Legacy custom max distance from l4d2lib");

	g_cvValveSurvivalBonus		   = FindConVar("vs_survival_bonus");
	g_cvValveTieBreaker			   = FindConVar("vs_tiebreak_bonus");
	g_cvSurvivorLimit			   = FindConVar("survivor_limit");
	g_cvPainPillsDecayRate		   = FindConVar("pain_pills_decay_rate");
	g_LegacyConfig.defaultSurvivalBonus  = g_cvValveSurvivalBonus.IntValue;
	g_LegacyConfig.defaultTieBreaker	   = g_cvValveTieBreaker.IntValue;
	g_Runtime.Refresh();

	g_cvBonusPerSurvivorMultiplier.AddChangeHook(CvarChanged);
	g_cvPermanentHealthProportion.AddChangeHook(CvarChanged);
	g_cvPillsHpFactor.AddChangeHook(CvarChanged);
	g_cvPillsMaxBonus.AddChangeHook(CvarChanged);
	g_cvMode.AddChangeHook(CvarChanged);
	g_cvLegacyEnable.AddChangeHook(CvarChanged);
	g_cvLegacyHBRatio.AddChangeHook(CvarChanged);
	g_cvLegacySurvivalBonusRatio.AddChangeHook(CvarChanged);
	g_cvLegacyMapMulti.AddChangeHook(CvarChanged);
	g_cvLegacyCustomMaxDistance.AddChangeHook(CvarChanged);
	g_cvLegacyHealPercent.AddChangeHook(CvarChanged);
	g_cvLegacyPillPercent.AddChangeHook(CvarChanged);
	g_cvLegacyAdrenPercent.AddChangeHook(CvarChanged);
	g_cvLegacyTempMulti0.AddChangeHook(CvarChanged);
	g_cvLegacyTempMulti1.AddChangeHook(CvarChanged);
	g_cvLegacyTempMulti2.AddChangeHook(CvarChanged);

	HookEvent("door_close", DoorCloseEvent);
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEndEvent);
	HookEvent("player_left_start_area", OnPlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("scavenge_round_start", ScavengeRoundStartEvent, EventHookMode_PostNoCopy);
	HookEvent("scavenge_round_finished", ScavengeRoundFinishedEvent, EventHookMode_PostNoCopy);
	HookEvent("scavenge_match_finished", ScavengeMatchFinishedEvent, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", FinaleVehicleLeavingEvent, EventHookMode_PostNoCopy);
	HookEvent("player_ledge_grab", OnPlayerLedgeGrab);
	HookEvent("player_incapacitated", OnPlayerIncapped);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("revive_success", OnPlayerRevived, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath);

	RegConsoleCmd("sm_health", CmdBonus);
	RegConsoleCmd("sm_damage", CmdBonus);
	RegConsoleCmd("sm_bonus", CmdBonus);
	RegConsoleCmd("sm_mapinfo", CmdMapInfo);

	if (g_Runtime.lateLoad)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
			{
				continue;
			}

			OnClientPutInServer(client);
		}
	}
}

public void OnPluginEnd()
{
	g_cvValveSurvivalBonus.IntValue = g_LegacyConfig.defaultSurvivalBonus;
	g_cvValveTieBreaker.IntValue	= g_LegacyConfig.defaultTieBreaker;
}

void RefreshScoreConfig(bool refreshModeContext = false)
{
	float fPermHealthProportion	 = 0.0;
	float fTempHealthProportion	 = 0.0;
	InvalidateLegacyEvalCache();
	InvalidateTeamSnapshotCache();
	InvalidateClientSnapshotCache();

	g_iTeamSize					 = g_cvSurvivorLimit.IntValue;
	if (refreshModeContext)
	{
		SMPlus_RefreshModeContext();
	}

	if (!SMPlus_IsScoremodSupported())
	{
		g_fMapBonus = 0.0;
		g_fMapHealthBonus = 0.0;
		g_fMapDamageBonus = 0.0;
		g_fMapTempHealthBonus = 0.0;
		g_fPermHpWorth = 0.0;
		g_fTempHpWorth = 0.0;
		g_iPillWorth = 0;
		g_cvValveSurvivalBonus.IntValue = g_LegacyConfig.defaultSurvivalBonus;
		g_cvValveTieBreaker.IntValue = g_LegacyConfig.defaultTieBreaker;
		return;
	}

	g_cvValveTieBreaker.IntValue = 0;

	g_iMapDistance				 = L4D2_GetMapValueInt("max_distance", L4D_GetVersusMaxCompletionScore());
	L4D_SetVersusMaxCompletionScore(g_iMapDistance);

	fPermHealthProportion = g_cvPermanentHealthProportion.FloatValue;
	fTempHealthProportion = 1.0 - fPermHealthProportion;
	g_fMapBonus			  = g_iMapDistance * (g_cvBonusPerSurvivorMultiplier.FloatValue * g_iTeamSize);
	g_fMapHealthBonus	  = g_fMapBonus * fPermHealthProportion;
	g_fMapDamageBonus	  = g_fMapBonus * fTempHealthProportion;
	g_fMapTempHealthBonus = g_iTeamSize * 100.0 / fPermHealthProportion * fTempHealthProportion;
	g_fPermHpWorth		  = g_fMapBonus / g_iTeamSize / 100.0 * fPermHealthProportion;
	g_fTempHpWorth		  = g_fMapBonus * fTempHealthProportion / g_fMapTempHealthBonus;
	g_iPillWorth		  = ClampInt(RoundToNearest(50.0 * (g_fPermHpWorth / g_cvPillsHpFactor.FloatValue) / 5.0) * 5, 5, g_cvPillsMaxBonus.IntValue);
	g_LegacyConfig.enabled = false;
	g_LegacyConfig.mapMulti = 0.0;
	g_LegacyConfig.healthBonusRatio = 0.0;
	g_LegacyConfig.survivalBonusRatio = 0.0;
	g_LegacyConfig.firstAidHealPercent = 0.0;
	g_LegacyConfig.pillsHealthValue = 0;
	g_LegacyConfig.adrenalineHealthBuffer = 0;
	g_LegacyConfig.customMaxDistance = 0;
	g_LegacyConfig.tempMulti[0] = 0.0;
	g_LegacyConfig.tempMulti[1] = 0.0;
	g_LegacyConfig.tempMulti[2] = 0.0;

	if (GetScoreMode() == SMPlusMode_Legacy)
	{
		g_LegacyConfig.enabled = g_cvLegacyEnable.BoolValue;
		g_LegacyConfig.mapMulti = g_cvLegacyMapMulti.BoolValue ? float(L4D_GetVersusMaxCompletionScore()) / 400.0 : 1.0;

		if (g_cvLegacyEnable.BoolValue && g_cvLegacyCustomMaxDistance.BoolValue && GetLegacyCustomMapMaxScore() > -1)
		{
			L4D_SetVersusMaxCompletionScore(GetLegacyCustomMapMaxScore());
			if (GetLegacyCustomMapMaxScore() > 0)
			{
				g_LegacyConfig.mapMulti = float(GetLegacyCustomMapMaxScore()) / 400.0;
			}
		}

		g_iMapDistance = L4D_GetVersusMaxCompletionScore();
		g_LegacyConfig.healthBonusRatio = g_cvLegacyHBRatio.FloatValue;
		g_LegacyConfig.survivalBonusRatio = g_cvLegacySurvivalBonusRatio.FloatValue;
		g_LegacyConfig.firstAidHealPercent = g_cvLegacyHealPercent.FloatValue;
		g_LegacyConfig.pillsHealthValue = g_cvLegacyPillPercent.IntValue;
		g_LegacyConfig.adrenalineHealthBuffer = g_cvLegacyAdrenPercent.IntValue;
		g_LegacyConfig.customMaxDistance = GetLegacyCustomMapMaxScore();
		g_LegacyConfig.tempMulti[0] = g_cvLegacyTempMulti0.FloatValue;
		g_LegacyConfig.tempMulti[1] = g_cvLegacyTempMulti1.FloatValue;
		g_LegacyConfig.tempMulti[2] = g_cvLegacyTempMulti2.FloatValue;
	}
	g_cvValveTieBreaker.IntValue = 0;
	DebugPrint("Map bonus: %.1f, temp health bonus: %.1f, perm HP worth: %.1f, temp HP worth: %.1f, pill worth: %i", g_fMapBonus, g_fMapTempHealthBonus, g_fPermHpWorth, g_fTempHpWorth, g_iPillWorth);
}

public void OnConfigsExecuted()
{
	RefreshScoreConfig(true);
}

public void OnMapStart()
{
	RefreshScoreConfig(true);
	InvalidateSurvivorCountCache();
	InvalidateLegacyEvalCache();
	InvalidateTeamSnapshotCache();
	InvalidateClientSnapshotCache();

	g_iLostTempHealth[0]			   = 0;
	g_iLostTempHealth[1]			   = 0;
	g_iSiDamage[0]					   = 0;
	g_iSiDamage[1]					   = 0;
	ResetAllExternalBonuses();
	g_Runtime.tiebreakerEligibility[0] = false;
	g_Runtime.tiebreakerEligibility[1] = false;
	g_Runtime.roundLive			   = false;
	g_LegacyRound.Reset();
	DebugPrint("Map start reset complete. team_size=%d map_distance=%d", g_iTeamSize, g_iMapDistance);
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, LIBRARY_L4DLIB))
	{
		g_Runtime.hasL4D2Lib = false;
	}
	else if (StrEqual(name, LIBRARY_READYUP))
	{
		g_Runtime.hasReadyUp = false;
		SMPlus_RefreshModeContext();
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, LIBRARY_L4DLIB))
	{
		g_Runtime.hasL4D2Lib = true;
	}
	else if (StrEqual(name, LIBRARY_READYUP))
	{
		g_Runtime.hasReadyUp = true;
		SMPlus_RefreshModeContext();
	}
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshScoreConfig();
	if (SMPlus_IsScoremodSupported())
	{
		NotifyScoreUpdated();
	}
}

public void L4D_OnGameModeChange(int gamemode)
{
	g_Runtime.baseMode = gamemode;
	SMPlus_RefreshModeContext();
}

public void OnRoundIsLive()
{
	if (g_Runtime.roundLiveSignal == SMPlusRoundLiveSignal_ReadyUpOrSafeArea)
	{
		g_Runtime.roundLive = true;
		InvalidateTeamSnapshotCache();
		InvalidateClientSnapshotCache();
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	InvalidateSurvivorCountCache();
	InvalidateClientSnapshotCache(client);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	InvalidateSurvivorCountCache();
	InvalidateClientSnapshotCache(client);
}
