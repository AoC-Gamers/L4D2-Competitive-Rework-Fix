#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <sdkhooks>
#include <left4dhooks>
#include <sdktools>
#include <l4d2lib>

#define SURVIVOR_STATE_LENGTH 32

enum SMPlusBonusType
{
    SMPlusBonusType_Total = 0,
    SMPlusBonusType_Health,
    SMPlusBonusType_Damage,
    SMPlusBonusType_Pills
}

/**
    Bibliography:
    'l4d2_scoremod' by CanadaRox, ProdigySim
    'damage_bonus' by CanadaRox, Stabby
    'l4d2_scoringwip' by ProdigySim
    'srs.scoringsystem' by AtomicStryker
**/

ConVar g_cvBonusPerSurvivorMultiplier;
ConVar g_cvPermanentHealthProportion;
ConVar g_cvPillsHpFactor;
ConVar g_cvPillsMaxBonus;
ConVar g_cvDebug;
ConVar g_cvValveSurvivalBonus;
ConVar g_cvValveTieBreaker;
GlobalForward g_fwMatchFinalized;

float g_fMapBonus;
float g_fMapHealthBonus;
float g_fMapDamageBonus;
float g_fMapTempHealthBonus;
float g_fPermHpWorth;
float g_fTempHpWorth;
float g_fSurvivorBonus[2];

int g_iMapDistance;
int g_iTeamSize;
int g_iPillWorth;
int g_iLostTempHealth[2];
int g_iTempHealth[MAXPLAYERS + 1];
int g_iSiDamage[2];

char g_sSurvivorState[2][SURVIVOR_STATE_LENGTH];

bool g_bLateLoad;
bool g_bRoundOver;
bool g_bTiebreakerEligibility[2];

public Plugin myinfo =
{
    name = "L4D2 Scoremod+",
    author = "Visor, Sir",
    description = "The next generation scoring mod",
    version = "2.2.6",
    url = "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
    CreateNative("SMPlus_GetBonus", Native_GetBonus);
    CreateNative("SMPlus_GetMaxBonus", Native_GetMaxBonus);
    CreateNative("SMPlus_FillBonusSnapshotKv", Native_FillBonusSnapshotKv);

    RegPluginLibrary("l4d2_hybrid_scoremod_zone");
    g_fwMatchFinalized = new GlobalForward("SMPlus_OnMatchFinalized", ET_Ignore, Param_Cell);
    g_bLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("l4d2_hybrid_scoremod.phrases");

    g_cvBonusPerSurvivorMultiplier = CreateConVar("sm2_bonus_per_survivor_multiplier", "0.5", "Total Survivor Bonus = this * Number of Survivors * Map Distance");
    g_cvPermanentHealthProportion = CreateConVar("sm2_permament_health_proportion", "0.75", "Permanent Health Bonus = this * Map Bonus; rest goes for Temporary Health Bonus");
    g_cvPillsHpFactor = CreateConVar("sm2_pills_hp_factor", "6.0", "Unused pills HP worth = map bonus HP value / this");
    g_cvPillsMaxBonus = CreateConVar("sm2_pills_max_bonus", "30", "Unused pills cannot be worth more than this");
    g_cvDebug = CreateConVar("smplus_debug", "0", "Enable scoremod debug output");

    g_cvValveSurvivalBonus = FindConVar("vs_survival_bonus");
    g_cvValveTieBreaker = FindConVar("vs_tiebreak_bonus");

    HookConVarChange(g_cvBonusPerSurvivorMultiplier, CvarChanged);
    HookConVarChange(g_cvPermanentHealthProportion, CvarChanged);

    HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
    HookEvent("player_ledge_grab", OnPlayerLedgeGrab);
    HookEvent("player_incapacitated", OnPlayerIncapped);
    HookEvent("player_hurt", OnPlayerHurt);
    HookEvent("revive_success", OnPlayerRevived, EventHookMode_Post);
    HookEvent("player_death", OnPlayerDeath);

    RegConsoleCmd("sm_health", CmdBonus);
    RegConsoleCmd("sm_damage", CmdBonus);
    RegConsoleCmd("sm_bonus", CmdBonus);
    RegConsoleCmd("sm_mapinfo", CmdMapInfo);

    if (g_bLateLoad)
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
    UnhookConVarChange(g_cvBonusPerSurvivorMultiplier, CvarChanged);
    UnhookConVarChange(g_cvPermanentHealthProportion, CvarChanged);
    UnhookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
    UnhookEvent("player_ledge_grab", OnPlayerLedgeGrab);
    UnhookEvent("player_incapacitated", OnPlayerIncapped);
    UnhookEvent("player_hurt", OnPlayerHurt);
    UnhookEvent("revive_success", OnPlayerRevived, EventHookMode_Post);
    UnhookEvent("player_death", OnPlayerDeath);

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
        {
            continue;
        }

        SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
        SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
    }

    ResetConVar(g_cvValveSurvivalBonus);
    ResetConVar(g_cvValveTieBreaker);
    delete g_fwMatchFinalized;
}

public void OnConfigsExecuted()
{
    float fPermHealthProportion = g_cvPermanentHealthProportion.FloatValue;
    float fTempHealthProportion = 1.0 - fPermHealthProportion;

    g_iTeamSize = FindConVar("survivor_limit").IntValue;
    g_cvValveTieBreaker.IntValue = 0;

    g_iMapDistance = L4D2_GetMapValueInt("max_distance", L4D_GetVersusMaxCompletionScore());
    L4D_SetVersusMaxCompletionScore(g_iMapDistance);

    g_fMapBonus = g_iMapDistance * (g_cvBonusPerSurvivorMultiplier.FloatValue * g_iTeamSize);
    g_fMapHealthBonus = g_fMapBonus * fPermHealthProportion;
    g_fMapDamageBonus = g_fMapBonus * fTempHealthProportion;
    g_fMapTempHealthBonus = g_iTeamSize * 100.0 / fPermHealthProportion * fTempHealthProportion;
    g_fPermHpWorth = g_fMapBonus / g_iTeamSize / 100.0 * fPermHealthProportion;
    g_fTempHpWorth = g_fMapBonus * fTempHealthProportion / g_fMapTempHealthBonus;
    g_iPillWorth = ClampInt(RoundToNearest(50.0 * (g_fPermHpWorth / g_cvPillsHpFactor.FloatValue) / 5.0) * 5, 5, g_cvPillsMaxBonus.IntValue);
    DebugPrint("Map bonus: %.1f, temp health bonus: %.1f, perm HP worth: %.1f, temp HP worth: %.1f, pill worth: %i", g_fMapBonus, g_fMapTempHealthBonus, g_fPermHpWorth, g_fTempHpWorth, g_iPillWorth);
}

public void OnMapStart()
{
    OnConfigsExecuted();

    g_iLostTempHealth[0] = 0;
    g_iLostTempHealth[1] = 0;
    g_iSiDamage[0] = 0;
    g_iSiDamage[1] = 0;
    g_bTiebreakerEligibility[0] = false;
    g_bTiebreakerEligibility[1] = false;
    DebugPrint("Map start reset complete. team_size=%d map_distance=%d", g_iTeamSize, g_iMapDistance);
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    OnConfigsExecuted();
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

void RoundStartEvent(Event event, const char[] eventName, bool dontBroadcast)
{
    for (int client = 0; client <= MAXPLAYERS; client++)
    {
        g_iTempHealth[client] = 0;
    }

    g_bTiebreakerEligibility[0] = false;
    g_bTiebreakerEligibility[1] = false;
    g_bRoundOver = false;
}

int Native_GetBonus(Handle plugin, int numParams)
{
    SMPlusBonusType type = GetNativeCell(1);
    int client = numParams >= 2 ? GetNativeCell(2) : 0;
    return GetBonusValue(type, client);
}

int Native_GetMaxBonus(Handle plugin, int numParams)
{
    SMPlusBonusType type = GetNativeCell(1);
    return GetMaxBonusValue(type);
}

int Native_FillBonusSnapshotKv(Handle plugin, int numParams)
{
    KeyValues kv = GetNativeCell(1);
    FillBonusSnapshotKv(kv);
    return 0;
}

Action CmdBonus(int client, int args)
{
    char cmdType[64];
    float healthBonus = 0.0;
    float damageBonus = 0.0;
    float pillsBonus = 0.0;
    float maxPillsBonus = 0.0;

    if (g_bRoundOver || !client)
    {
        return Plugin_Handled;
    }

    GetCmdArg(1, cmdType, sizeof(cmdType));

    healthBonus = GetSurvivorHealthBonus();
    damageBonus = GetSurvivorDamageBonus();
    pillsBonus = GetSurvivorPillBonus();
    maxPillsBonus = float(g_iPillWorth * g_iTeamSize);

    if (StrEqual(cmdType, "full"))
    {
        if (GameRules_GetProp("m_bInSecondHalfOfRound"))
        {
            CPrintToChat(client, "%t %t", "Tag", "RoundBonusSummary", 1, RoundToFloor(g_fSurvivorBonus[0]), RoundToFloor(g_fMapBonus + maxPillsBonus), CalculateBonusPercent(g_fSurvivorBonus[0]), g_sSurvivorState[0]);
        }

        CPrintToChat(client, "%t %t", "Tag", "RoundBonusFull", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(healthBonus + damageBonus + pillsBonus), CalculateBonusPercent(healthBonus + damageBonus + pillsBonus, g_fMapHealthBonus + g_fMapDamageBonus + maxPillsBonus), RoundToFloor(healthBonus), CalculateBonusPercent(healthBonus, g_fMapHealthBonus), RoundToFloor(damageBonus), CalculateBonusPercent(damageBonus, g_fMapDamageBonus), RoundToFloor(pillsBonus), CalculateBonusPercent(pillsBonus, maxPillsBonus));
    }
    else if (StrEqual(cmdType, "lite"))
    {
        CPrintToChat(client, "%t %t", "Tag", "RoundBonusLite", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(healthBonus + damageBonus + pillsBonus), CalculateBonusPercent(healthBonus + damageBonus + pillsBonus, g_fMapHealthBonus + g_fMapDamageBonus + maxPillsBonus));
    }
    else
    {
        if (GameRules_GetProp("m_bInSecondHalfOfRound"))
        {
            CPrintToChat(client, "%t %t", "Tag", "RoundBonusSimplePrevious", 1, RoundToFloor(g_fSurvivorBonus[0]), CalculateBonusPercent(g_fSurvivorBonus[0]));
        }

        CPrintToChat(client, "%t %t", "Tag", "RoundBonusSimple", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(healthBonus + damageBonus + pillsBonus), CalculateBonusPercent(healthBonus + damageBonus + pillsBonus, g_fMapHealthBonus + g_fMapDamageBonus + maxPillsBonus), CalculateBonusPercent(healthBonus, g_fMapHealthBonus), CalculateBonusPercent(damageBonus, g_fMapDamageBonus), CalculateBonusPercent(pillsBonus, maxPillsBonus));
    }

    return Plugin_Handled;
}

Action CmdMapInfo(int client, int args)
{
    float maxPillsBonus = float(g_iPillWorth * g_iTeamSize);
    float totalBonus = g_fMapBonus + maxPillsBonus;

    CPrintToChat(client, "%t %t", "Tag", "MapInfoTitle", g_iTeamSize, g_iTeamSize);
    CPrintToChat(client, "%t %t", "Tag", "MapInfoDistance", g_iMapDistance);
    CPrintToChat(client, "%t %t", "Tag", "MapInfoTotalBonus", RoundToFloor(totalBonus));
    CPrintToChat(client, "%t %t", "Tag", "MapInfoHealthBonus", RoundToFloor(g_fMapHealthBonus), CalculateBonusPercent(g_fMapHealthBonus, totalBonus));
    CPrintToChat(client, "%t %t", "Tag", "MapInfoDamageBonus", RoundToFloor(g_fMapDamageBonus), CalculateBonusPercent(g_fMapDamageBonus, totalBonus));
    CPrintToChat(client, "%t %t", "Tag", "MapInfoPillsBonus", g_iPillWorth, RoundToFloor(maxPillsBonus), CalculateBonusPercent(maxPillsBonus, totalBonus));
    CPrintToChat(client, "%t %t", "Tag", "MapInfoTiebreaker", g_iPillWorth);
    return Plugin_Handled;
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType)
{
    if (!IsSurvivor(victim) || L4D_IsPlayerIncapacitated(victim))
    {
        return Plugin_Continue;
    }

    if (GetSurvivorTemporaryHealth(victim) > 0)
    {
        DebugPrint("%N temp HP: %d (damage: %.1f)", victim, GetSurvivorTemporaryHealth(victim), damage);
    }

    g_iTempHealth[victim] = GetSurvivorTemporaryHealth(victim);

    if (!IsAnyInfected(attacker))
    {
        g_iSiDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += (damage <= 100.0) ? RoundFloat(damage) : 100;
    }

    return Plugin_Continue;
}

void OnPlayerLedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += L4D2Direct_GetPreIncapHealthBuffer(client);
}

void OnPlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (IsSurvivor(victim) && !g_bRoundOver)
    {
        int incaps = L4D_GetPlayerReviveCount(victim);
        int standardPenalty = RoundToFloor((g_fMapDamageBonus / 100.0) * 5.0 / g_fTempHpWorth);
        int penalty = 0;

        for (int loops = 2 - incaps; loops > 0; loops--)
        {
            penalty += standardPenalty + 30;
        }

        g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += penalty;
        DebugPrint("Valid death for %N: incaps %i, total penalty now %i", victim, incaps, penalty);
    }
}

void OnPlayerIncapped(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (IsSurvivor(client))
    {
        g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += RoundToFloor((g_fMapDamageBonus / 100.0) * 5.0 / g_fTempHpWorth);
    }
}

void OnPlayerRevived(Event event, const char[] name, bool dontBroadcast)
{
    int client = 0;

    if (!event.GetBool("ledge_hang"))
    {
        return;
    }

    client = GetClientOfUserId(event.GetInt("subject"));
    if (!IsSurvivor(client))
    {
        return;
    }

    RequestFrame(Revival, client);
}

void Revival(int client)
{
    g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] -= GetSurvivorTemporaryHealth(client);
}

Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int damage = event.GetInt("dmg_health");
    int damageType = event.GetInt("type");
    int fakeDamage = damage;

    if (!IsSurvivor(victim) || !IsSurvivor(attacker) || L4D_IsPlayerIncapacitated(victim) || damageType != DMG_PLASMA || fakeDamage < GetSurvivorPermanentHealth(victim))
    {
        return Plugin_Continue;
    }

    g_iTempHealth[victim] = GetSurvivorTemporaryHealth(victim);
    if (fakeDamage > g_iTempHealth[victim])
    {
        fakeDamage = g_iTempHealth[victim];
    }

    g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += fakeDamage;
    g_iTempHealth[victim] = GetSurvivorTemporaryHealth(victim) - fakeDamage;
    return Plugin_Continue;
}

void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damageType)
{
    if (!IsSurvivor(victim))
    {
        return;
    }

    DebugPrint("%N lost %i temp HP after being attacked (damage: %.1f)", victim, g_iTempHealth[victim] - (IsPlayerAlive(victim) ? GetSurvivorTemporaryHealth(victim) : 0), damage);

    if (!IsPlayerAlive(victim) || (L4D_IsPlayerIncapacitated(victim) && !IsPlayerLedged(victim)))
    {
        g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += g_iTempHealth[victim];
    }
    else if (!IsPlayerLedged(victim))
    {
        g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += g_iTempHealth[victim] ? (g_iTempHealth[victim] - GetSurvivorTemporaryHealth(victim)) : 0;
    }

    g_iTempHealth[victim] = L4D_IsPlayerIncapacitated(victim) ? 0 : GetSurvivorTemporaryHealth(victim);
}

public void L4D2_ADM_OnTemporaryHealthSubtracted(int client, int oldHealth, int newHealth)
{
    int healthLost = oldHealth - newHealth;
    int team = GameRules_GetProp("m_bInSecondHalfOfRound");

    g_iTempHealth[client] = newHealth;
    g_iLostTempHealth[team] += healthLost;
    g_iSiDamage[team] += healthLost;
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    int team = 0;
    int survivalMultiplier = 0;

    DebugPrint("CDirector::OnEndVersusModeRound() called. InSecondHalfOfRound(): %d, countSurvivors: %d", GameRules_GetProp("m_bInSecondHalfOfRound"), countSurvivors);

    if (g_bRoundOver)
    {
        return Plugin_Continue;
    }

    team = GameRules_GetProp("m_bInSecondHalfOfRound");
    survivalMultiplier = countSurvivors ? GetAliveSurvivorCount(false) : 0;
    g_fSurvivorBonus[team] = GetSurvivorHealthBonus() + GetSurvivorDamageBonus() + GetSurvivorPillBonus();
    g_fSurvivorBonus[team] = float(RoundToFloor(g_fSurvivorBonus[team] / float(g_iTeamSize)) * g_iTeamSize);

    if (survivalMultiplier > 0 && RoundToFloor(g_fSurvivorBonus[team] / survivalMultiplier) >= g_iTeamSize)
    {
        g_cvValveSurvivalBonus.IntValue = RoundToFloor(g_fSurvivorBonus[team] / survivalMultiplier);
        g_fSurvivorBonus[team] = float(g_cvValveSurvivalBonus.IntValue * survivalMultiplier);
        Format(g_sSurvivorState[team], sizeof(g_sSurvivorState[]), "%s%i{default}/{green}%i{default}", (survivalMultiplier == g_iTeamSize ? "{green}" : "{olive}"), survivalMultiplier, g_iTeamSize);
        DebugPrint("Survival bonus cvar updated. Value: %i [multiplier: %i]", g_cvValveSurvivalBonus.IntValue, survivalMultiplier);
    }
    else
    {
        g_fSurvivorBonus[team] = 0.0;
        g_cvValveSurvivalBonus.IntValue = 0;
        Format(g_sSurvivorState[team], sizeof(g_sSurvivorState[]), "%s", (survivalMultiplier == 0 ? "{olive}wiped out{default}" : "{olive}bonus depleted{default}"));
        g_bTiebreakerEligibility[team] = (survivalMultiplier == g_iTeamSize);
    }

    if (team > 0 && g_bTiebreakerEligibility[0] && g_bTiebreakerEligibility[1])
    {
        GameRules_SetProp("m_iChapterDamage", g_iSiDamage[0], _, 0, true);
        GameRules_SetProp("m_iChapterDamage", g_iSiDamage[1], _, 1, true);

        if (g_iSiDamage[0] != g_iSiDamage[1])
        {
            g_cvValveTieBreaker.IntValue = g_iPillWorth;
        }
    }

    if (team > 0)
    {
        NotifyMatchFinalized();
    }

    CreateTimer(3.0, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
    g_bRoundOver = true;
    return Plugin_Continue;
}

Action PrintRoundEndStats(Handle timer)
{
    for (int team = 0; team <= GameRules_GetProp("m_bInSecondHalfOfRound"); team++)
    {
        CPrintToChatAll("%t %t", "Tag", "RoundBonusSummary", team + 1, RoundToFloor(g_fSurvivorBonus[team]), RoundToFloor(g_fMapBonus + float(g_iPillWorth * g_iTeamSize)), CalculateBonusPercent(g_fSurvivorBonus[team]), g_sSurvivorState[team]);
    }

    if (GameRules_GetProp("m_bInSecondHalfOfRound") && g_bTiebreakerEligibility[0] && g_bTiebreakerEligibility[1])
    {
        CPrintToChatAll("%t %t", "Tag", "TiebreakerScores", g_iSiDamage[0], g_iSiDamage[1]);
        if (g_iSiDamage[0] == g_iSiDamage[1])
        {
            CPrintToChatAll("%t %t", "Tag", "TiebreakerEqual");
        }
    }

    return Plugin_Stop;
}

float GetSurvivorHealthBonus()
{
    float healthBonus = 0.0;
    int survivorCount = 0;
    int survivalMultiplier = 0;

    for (int client = 1; client <= MaxClients && survivorCount < g_iTeamSize; client++)
    {
        if (!IsSurvivor(client))
        {
            continue;
        }

        survivorCount++;
        if (IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client) && !IsPlayerLedged(client))
        {
            survivalMultiplier++;
            healthBonus += GetSurvivorPermanentHealth(client) * g_fPermHpWorth;
            DebugPrint("Adding %N perm HP contribution: %d perm HP -> %.1f bonus; total: %.1f", client, GetSurvivorPermanentHealth(client), GetSurvivorPermanentHealth(client) * g_fPermHpWorth, healthBonus);
        }
    }

    return healthBonus / g_iTeamSize * survivalMultiplier;
}

float GetSurvivorDamageBonus()
{
    int survivalMultiplier = GetAliveSurvivorCount();
    float damageBonus = (g_fMapTempHealthBonus - float(g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")])) * g_fTempHpWorth / g_iTeamSize * survivalMultiplier;
    DebugPrint("Adding temp HP bonus: %.1f (eligible survivors: %d)", damageBonus, survivalMultiplier);
    return (damageBonus > 0.0 && survivalMultiplier > 0) ? damageBonus : 0.0;
}

float GetSurvivorPillBonus()
{
    int pillsBonus = 0;
    int survivorCount = 0;

    for (int client = 1; client <= MaxClients && survivorCount < g_iTeamSize; client++)
    {
        if (!IsSurvivor(client))
        {
            continue;
        }

        survivorCount++;
        if (IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client) && HasPills(client))
        {
            pillsBonus += g_iPillWorth;
            DebugPrint("Adding %N pills contribution, total pills bonus: %d pts", client, pillsBonus);
        }
    }

    return float(pillsBonus);
}

float GetSurvivorTotalBonus()
{
    return GetSurvivorHealthBonus() + GetSurvivorDamageBonus() + GetSurvivorPillBonus();
}

float GetRoundMaxBonus()
{
    return g_fMapHealthBonus + g_fMapDamageBonus + float(g_iPillWorth * g_iTeamSize);
}

float GetClientTotalBonus(int client)
{
    return GetClientHealthBonus(client) + GetClientDamageBonus(client) + GetClientPillsBonus(client);
}

int GetBonusValue(SMPlusBonusType type, int client = 0)
{
    if (client == 0)
    {
        switch (type)
        {
            case SMPlusBonusType_Health: return RoundToFloor(GetSurvivorHealthBonus());
            case SMPlusBonusType_Damage: return RoundToFloor(GetSurvivorDamageBonus());
            case SMPlusBonusType_Pills:  return RoundToFloor(GetSurvivorPillBonus());
        }

        return RoundToFloor(GetSurvivorTotalBonus());
    }

    switch (type)
    {
        case SMPlusBonusType_Health: return RoundToFloor(GetClientHealthBonus(client));
        case SMPlusBonusType_Damage: return RoundToFloor(GetClientDamageBonus(client));
        case SMPlusBonusType_Pills:  return RoundToFloor(GetClientPillsBonus(client));
    }

    return RoundToFloor(GetClientTotalBonus(client));
}

int GetMaxBonusValue(SMPlusBonusType type)
{
    switch (type)
    {
        case SMPlusBonusType_Health: return RoundToFloor(g_fMapHealthBonus);
        case SMPlusBonusType_Damage: return RoundToFloor(g_fMapDamageBonus);
        case SMPlusBonusType_Pills:  return g_iPillWorth * g_iTeamSize;
    }

    return RoundToFloor(GetRoundMaxBonus());
}

float GetClientHealthBonus(int client)
{
    int survivalMultiplier = 0;

    if (!IsClientEligibleForBonus(client))
    {
        return 0.0;
    }

    survivalMultiplier = GetAliveSurvivorCount();
    return GetSurvivorPermanentHealth(client) * g_fPermHpWorth / g_iTeamSize * survivalMultiplier;
}

float GetClientDamageBonus(int client)
{
    int survivalMultiplier = 0;

    if (!IsClientEligibleForBonus(client))
    {
        return 0.0;
    }

    survivalMultiplier = GetAliveSurvivorCount();
    if (survivalMultiplier < 1)
    {
        return 0.0;
    }

    return GetSurvivorDamageBonus() / survivalMultiplier;
}

float GetClientPillsBonus(int client)
{
    if (!IsClientEligibleForBonus(client) || !HasPills(client))
    {
        return 0.0;
    }

    return float(g_iPillWorth);
}

void FillBonusSnapshotKv(KeyValues kv)
{
    int currentRound = GameRules_GetProp("m_bInSecondHalfOfRound") + 1;
    int aliveSurvivors = GetAliveSurvivorCount();
    float totalBonus = GetSurvivorTotalBonus();
    float maxBonus = GetRoundMaxBonus();

    KvRewind(kv);
    KvDeleteKey(kv, "rounds");
    KvDeleteKey(kv, "clients");
    KvSetNum(kv, "current_round", currentRound);
    KvSetNum(kv, "team_size", g_iTeamSize);
    KvSetNum(kv, "map_distance", g_iMapDistance);
    KvSetNum(kv, "alive_survivors", aliveSurvivors);
    KvSetNum(kv, "pill_worth", g_iPillWorth);
    KvSetFloat(kv, "map_bonus", g_fMapBonus);
    KvSetFloat(kv, "health_bonus", GetSurvivorHealthBonus());
    KvSetFloat(kv, "damage_bonus", GetSurvivorDamageBonus());
    KvSetFloat(kv, "pills_bonus", GetSurvivorPillBonus());
    KvSetFloat(kv, "total_bonus", totalBonus);
    KvSetFloat(kv, "max_health_bonus", g_fMapHealthBonus);
    KvSetFloat(kv, "max_damage_bonus", g_fMapDamageBonus);
    KvSetFloat(kv, "max_pills_bonus", float(g_iPillWorth * g_iTeamSize));
    KvSetFloat(kv, "round_max_bonus", maxBonus);
    DebugPrint("Snapshot fill: round=%d alive=%d total=%.1f max=%.1f", currentRound, aliveSurvivors, totalBonus, maxBonus);

    KvJumpToKey(kv, "rounds", true);
    KvSetFloat(kv, "round1_bonus", g_fSurvivorBonus[0]);
    KvSetFloat(kv, "round2_bonus", g_fSurvivorBonus[1]);
    KvSetString(kv, "round1_state", g_sSurvivorState[0]);
    KvSetString(kv, "round2_state", g_sSurvivorState[1]);
    KvSetNum(kv, "round1_si_damage", g_iSiDamage[0]);
    KvSetNum(kv, "round2_si_damage", g_iSiDamage[1]);
    KvGoBack(kv);

    KvJumpToKey(kv, "clients", true);
    for (int client = 1; client <= MaxClients; client++)
    {
        char key[16];

        if (!IsSurvivor(client))
        {
            continue;
        }

        IntToString(GetClientUserId(client), key, sizeof(key));
        KvJumpToKey(kv, key, true);
        KvSetNum(kv, "alive", IsPlayerAlive(client));
        KvSetNum(kv, "incapped", L4D_IsPlayerIncapacitated(client));
        KvSetNum(kv, "ledged", IsPlayerLedged(client));
        KvSetNum(kv, "permanent_health", GetSurvivorPermanentHealth(client));
        KvSetNum(kv, "temporary_health", GetSurvivorTemporaryHealth(client));
        KvSetNum(kv, "has_pills", HasPills(client));
        KvSetFloat(kv, "health_bonus", GetClientHealthBonus(client));
        KvSetFloat(kv, "damage_bonus", GetClientDamageBonus(client));
        KvSetFloat(kv, "pills_bonus", GetClientPillsBonus(client));
        KvSetFloat(kv, "total_bonus", GetClientTotalBonus(client));
        KvGoBack(kv);
    }
    KvGoBack(kv);
}

void NotifyMatchFinalized()
{
    int winningTeam = 0;
    int round1Bonus = RoundToFloor(g_fSurvivorBonus[0]);
    int round2Bonus = RoundToFloor(g_fSurvivorBonus[1]);

    if (round1Bonus > round2Bonus)
    {
        winningTeam = 1;
    }
    else if (round2Bonus > round1Bonus)
    {
        winningTeam = 2;
    }
    else if (g_iSiDamage[0] < g_iSiDamage[1])
    {
        winningTeam = 1;
    }
    else if (g_iSiDamage[1] < g_iSiDamage[0])
    {
        winningTeam = 2;
    }
    DebugPrint("Match finalized. winner=%d round1=%d round2=%d si1=%d si2=%d", winningTeam, round1Bonus, round2Bonus, g_iSiDamage[0], g_iSiDamage[1]);

    Call_StartForward(g_fwMatchFinalized);
    Call_PushCell(winningTeam);
    Call_Finish();
}

void DebugPrint(const char[] format, any ...)
{
    if (!g_cvDebug.BoolValue)
    {
        return;
    }

    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 2);
    CPrintToChatAll("{olive}[Hybrid Bonus Zone Debug]{default} %s", buffer);
}

float CalculateBonusPercent(float score, float maxBonus = -1.0)
{
    return score / (maxBonus == -1.0 ? (g_fMapBonus + float(g_iPillWorth * g_iTeamSize)) : maxBonus) * 100.0;
}

bool IsSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor;
}

bool IsAnyInfected(int entity)
{
    char className[64];

    if (entity > 0 && entity <= MaxClients)
    {
        return IsClientInGame(entity) && L4D_GetClientTeam(entity) == L4DTeam_Infected;
    }

    if (entity > MaxClients)
    {
        GetEdictClassname(entity, className, sizeof(className));
        if (StrEqual(className, "infected") || StrEqual(className, "witch"))
        {
            return true;
        }
    }

    return false;
}

bool IsPlayerLedged(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

bool IsClientEligibleForBonus(int client)
{
    return IsSurvivor(client) && IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client) && !IsPlayerLedged(client);
}

int GetAliveSurvivorCount(bool uprightOnly = true)
{
    int survivorCount = 0;
    int aliveCount = 0;
    int uprightCount = 0;

    for (int client = 1; client <= MaxClients && survivorCount < g_iTeamSize; client++)
    {
        if (!IsSurvivor(client))
        {
            continue;
        }

        survivorCount++;

        if (IsPlayerAlive(client))
        {
            aliveCount++;
        }

        if (!L4D_IsPlayerIncapacitated(client) && !IsPlayerLedged(client))
        {
            uprightCount++;
        }
    }

    return uprightOnly ? uprightCount : aliveCount;
}

int GetSurvivorTemporaryHealth(int client)
{
    int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * FindConVar("pain_pills_decay_rate").FloatValue)) - 1;
    return tempHealth > 0 ? tempHealth : 0;
}

int ClampInt(int value, int minValue, int maxValue)
{
    if (value > maxValue)
    {
        return maxValue;
    }

    if (value < minValue)
    {
        return minValue;
    }

    return value;
}

int GetSurvivorPermanentHealth(int client)
{
    return L4D_GetPlayerReviveCount(client) > 0 ? 0 : (GetEntProp(client, Prop_Send, "m_iHealth") > 0 ? GetEntProp(client, Prop_Send, "m_iHealth") : 0);
}

bool HasPills(int client)
{
    int item = GetPlayerWeaponSlot(client, L4DWeaponSlot_Pills);
    char buffer[64];

    if (!IsValidEdict(item))
    {
        return false;
    }

    GetEdictClassname(item, buffer, sizeof(buffer));
    return StrEqual(buffer, "weapon_pain_pills");
}
