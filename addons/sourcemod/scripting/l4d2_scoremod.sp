#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <l4d2lib>
#define REQUIRE_PLUGIN

enum SMClassicBonusType
{
    SMClassicBonusType_Total = 0
}

public Plugin myinfo =
{
    name = "L4D2 Scoremod",
    author = "CanadaRox, ProdigySim",
    description = "L4D2 Custom Scoring System (Health Bonus)",
    version = "1.1.2",
    url = "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

bool g_bL4D2LibAvailable = false;

int g_iDefaultSurvivalBonus;
int g_iDefaultTieBreaker;
int g_iPillPercent;
int g_iAdrenPercent;
int g_iFirstScore;
int g_iDifference;

float g_fHealPercent;
float g_fMapMulti;
float g_fHBRatio;
float g_fSurvivalBonusRatio;
float g_fTempMulti[3];

bool g_bModuleIsEnabled;
bool g_bHooked;
bool g_bIsFirstRoundOver;
bool g_bIsSecondRoundStarted;
bool g_bIsSecondRoundOver;

ConVar g_cvEnable;
ConVar g_cvHBRatio;
ConVar g_cvSurvivalBonusRatio;
ConVar g_cvMapMulti;
ConVar g_cvCustomMaxDistance;
ConVar g_cvSurvivalBonus;
ConVar g_cvTieBreaker;
ConVar g_cvHealPercent;
ConVar g_cvPillPercent;
ConVar g_cvAdrenPercent;
ConVar g_cvTempMulti0;
ConVar g_cvTempMulti1;
ConVar g_cvTempMulti2;
ConVar g_cvDebug;
GlobalForward g_fwMatchFinalized;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
    CreateNative("SMClassic_GetBonus", Native_GetBonus);
    CreateNative("SMClassic_GetMaxBonus", Native_GetMaxBonus);
    CreateNative("SMClassic_FillBonusSnapshotKv", Native_FillBonusSnapshotKv);

    RegPluginLibrary("l4d2_scoremod");
    g_fwMatchFinalized = new GlobalForward("SMClassic_OnMatchFinalized", ET_Ignore, Param_Cell);
    return APLRes_Success;
}

int Native_GetBonus(Handle plugin, int numParams)
{
    SMClassicBonusType type = GetNativeCell(1);
    int client = numParams >= 2 ? GetNativeCell(2) : 0;
    return GetBonusValue(type, client);
}

int Native_GetMaxBonus(Handle plugin, int numParams)
{
    SMClassicBonusType type = GetNativeCell(1);
    return GetMaxBonusValue(type);
}

int Native_FillBonusSnapshotKv(Handle plugin, int numParams)
{
    KeyValues kv = GetNativeCell(1);
    FillBonusSnapshotKv(kv);
    return 0;
}

public void OnPluginStart()
{
    LoadTranslations("l4d2_scoremod.phrases");

    g_cvEnable = CreateConVar("SM_enable", "1", "L4D2 Custom Scoring - Enable/Disable", FCVAR_NONE);
    HookConVarChange(g_cvEnable, ConVarChanged_Enable);

    g_cvHBRatio = CreateConVar("SM_healthbonusratio", "2.0", "L4D2 Custom Scoring - Healthbonus Multiplier", FCVAR_NONE, true, 0.25, true, 5.0);
    HookConVarChange(g_cvHBRatio, ConVarChanged_HealthBonusRatio);

    g_cvSurvivalBonusRatio = CreateConVar("SM_survivalbonusratio", "0.0", "Ratio to be used for a static survival bonus against Map distance. 25% == 100 points maximum health bonus on a 400 distance map", FCVAR_NONE);
    HookConVarChange(g_cvSurvivalBonusRatio, ConVarChanged_SurvivalBonusRatio);

    g_cvTempMulti0 = CreateConVar("SM_tempmulti_incap_0", "0.30625", "L4D2 Custom Scoring - How important temp health is on survivors who have had no incaps", FCVAR_NONE, true, 0.0, true, 1.0);
    HookConVarChange(g_cvTempMulti0, ConVarChanged_TempMulti0);

    g_cvTempMulti1 = CreateConVar("SM_tempmulti_incap_1", "0.17500", "L4D2 Custom Scoring - How important temp health is on survivors who have had one incap", FCVAR_NONE, true, 0.0, true, 1.0);
    HookConVarChange(g_cvTempMulti1, ConVarChanged_TempMulti1);

    g_cvTempMulti2 = CreateConVar("SM_tempmulti_incap_2", "0.10000", "L4D2 Custom Scoring - How important temp health is on survivors who have had two incaps (black and white)", FCVAR_NONE, true, 0.0, true, 1.0);
    HookConVarChange(g_cvTempMulti2, ConVarChanged_TempMulti2);
    g_cvDebug = CreateConVar("smclassic_debug", "0", "Enable scoremod debug output");

    g_fTempMulti[0] = g_cvTempMulti0.FloatValue;
    g_fTempMulti[1] = g_cvTempMulti1.FloatValue;
    g_fTempMulti[2] = g_cvTempMulti2.FloatValue;

    char buffer[32];
    FloatToString(FindConVar("first_aid_heal_percent").FloatValue, buffer, sizeof(buffer));
    g_cvHealPercent = CreateConVar("SM_first_aid_heal_percent", buffer, "L4D2 Custom Scoring: What percent of health is healed by medkits?");

    IntToString(FindConVar("pain_pills_health_value").IntValue, buffer, sizeof(buffer));
    g_cvPillPercent = CreateConVar("SM_pain_pills_health_value", buffer, "L4D2 Custom Scoring: How much health is added by pills?");

    IntToString(FindConVar("adrenaline_health_buffer").IntValue, buffer, sizeof(buffer));
    g_cvAdrenPercent = CreateConVar("SM_adrenaline_health_buffer", buffer, "L4D2 Custom Scoring: How much health is added by adrenaline?");

    g_cvMapMulti = CreateConVar("SM_mapmulti", "1", "L4D2 Custom Scoring - Increases Healthbonus Max to Distance Max", FCVAR_NONE);
    g_cvCustomMaxDistance = CreateConVar("SM_custommaxdistance", "0", "L4D2 Custom Scoring - Custom max distance from config", FCVAR_NONE);

    g_cvSurvivalBonus = FindConVar("vs_survival_bonus");
    g_cvTieBreaker = FindConVar("vs_tiebreak_bonus");

    HookConVarChange(g_cvHealPercent, ConVarChanged_Health);
    HookConVarChange(g_cvPillPercent, ConVarChanged_Health);
    HookConVarChange(g_cvAdrenPercent, ConVarChanged_Health);

    g_iDefaultSurvivalBonus = g_cvSurvivalBonus.IntValue;
    g_iDefaultTieBreaker = g_cvTieBreaker.IntValue;
    g_fHealPercent = g_cvHealPercent.FloatValue;
    g_iPillPercent = g_cvPillPercent.IntValue;
    g_iAdrenPercent = g_cvAdrenPercent.IntValue;
    DebugPrint("Plugin start complete. hb_ratio=%.2f survival_ratio=%.2f", g_cvHBRatio.FloatValue, g_cvSurvivalBonusRatio.FloatValue);

    RegConsoleCmd("sm_health", Cmd_Health);
    RegConsoleCmd("say", Command_Say);
    RegConsoleCmd("say_team", Command_Say);
    g_bL4D2LibAvailable = LibraryExists("l4d2lib");
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "l4d2lib") == 0)
    {
        g_bL4D2LibAvailable = false;
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (strcmp(name, "l4d2lib") == 0)
    {
        g_bL4D2LibAvailable = true;
    }
}

public void OnPluginEnd()
{
    PluginDisable();
    UnhookConVarChange(g_cvEnable, ConVarChanged_Enable);
    UnhookConVarChange(g_cvHBRatio, ConVarChanged_HealthBonusRatio);
    UnhookConVarChange(g_cvSurvivalBonusRatio, ConVarChanged_SurvivalBonusRatio);
    UnhookConVarChange(g_cvTempMulti0, ConVarChanged_TempMulti0);
    UnhookConVarChange(g_cvTempMulti1, ConVarChanged_TempMulti1);
    UnhookConVarChange(g_cvTempMulti2, ConVarChanged_TempMulti2);
    UnhookConVarChange(g_cvHealPercent, ConVarChanged_Health);
    UnhookConVarChange(g_cvPillPercent, ConVarChanged_Health);
    UnhookConVarChange(g_cvAdrenPercent, ConVarChanged_Health);
    delete g_fwMatchFinalized;
}

public void OnMapStart()
{
    if (!g_cvMapMulti.BoolValue)
    {
        g_fMapMulti = 1.0;
    }
    else
    {
        g_fMapMulti = float(L4D_GetVersusMaxCompletionScore()) / 400.0;
    }

    g_bModuleIsEnabled = g_cvEnable.BoolValue;

    if (g_bModuleIsEnabled && !g_bHooked)
    {
        PluginEnable();
    }

    if (g_bModuleIsEnabled)
    {
        g_cvTieBreaker.IntValue = 0;
    }

    if (g_bModuleIsEnabled && g_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1)
    {
        L4D_SetVersusMaxCompletionScore(GetCustomMapMaxScore());
        if (GetCustomMapMaxScore() > 0)
        {
            g_fMapMulti = float(GetCustomMapMaxScore()) / 400.0;
        }
    }

    g_bIsFirstRoundOver = false;
    g_bIsSecondRoundStarted = false;
    g_bIsSecondRoundOver = false;
    g_iFirstScore = 0;

    g_fTempMulti[0] = g_cvTempMulti0.FloatValue;
    g_fTempMulti[1] = g_cvTempMulti1.FloatValue;
    g_fTempMulti[2] = g_cvTempMulti2.FloatValue;
    DebugPrint("Map start complete. map_multi=%.2f custom_distance=%d", g_fMapMulti, GetCustomMapMaxScore());
}

void ConVarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (StringToInt(newValue) == 0)
    {
        PluginDisable();
        g_bModuleIsEnabled = false;
        return;
    }

    PluginEnable();
    g_bModuleIsEnabled = true;
}

void ConVarChanged_TempMulti0(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_fTempMulti[0] = StringToFloat(newValue);
}

void ConVarChanged_TempMulti1(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_fTempMulti[1] = StringToFloat(newValue);
}

void ConVarChanged_TempMulti2(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_fTempMulti[2] = StringToFloat(newValue);
}

void ConVarChanged_HealthBonusRatio(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_fHBRatio = StringToFloat(newValue);
}

void ConVarChanged_SurvivalBonusRatio(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_fSurvivalBonusRatio = StringToFloat(newValue);
}

void ConVarChanged_Health(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_fHealPercent = g_cvHealPercent.FloatValue;
    g_iPillPercent = g_cvPillPercent.IntValue;
    g_iAdrenPercent = g_cvAdrenPercent.IntValue;
}

void PluginEnable()
{
    HookEvent("door_close", DoorCloseEvent);
    HookEvent("player_death", PlayerDeathEvent);
    HookEvent("round_end", RoundEndEvent);
    HookEvent("round_start", RoundStartEvent);
    HookEvent("finale_vehicle_leaving", FinaleVehicleLeavingEvent, EventHookMode_PostNoCopy);

    g_fHBRatio = g_cvHBRatio.FloatValue;
    g_fSurvivalBonusRatio = g_cvSurvivalBonusRatio.FloatValue;
    g_iDefaultSurvivalBonus = g_cvSurvivalBonus.IntValue;
    g_iDefaultTieBreaker = g_cvTieBreaker.IntValue;
    g_cvTieBreaker.IntValue = 0;
    g_fHealPercent = g_cvHealPercent.FloatValue;
    g_iPillPercent = g_cvPillPercent.IntValue;
    g_iAdrenPercent = g_cvAdrenPercent.IntValue;
    g_bHooked = true;
}

void PluginDisable()
{
    if (g_bHooked)
    {
        UnhookEvent("door_close", DoorCloseEvent);
        UnhookEvent("player_death", PlayerDeathEvent);
        UnhookEvent("round_end", RoundEndEvent);
        UnhookEvent("round_start", RoundStartEvent);
        UnhookEvent("finale_vehicle_leaving", FinaleVehicleLeavingEvent, EventHookMode_PostNoCopy);
    }

    g_cvSurvivalBonus.IntValue = g_iDefaultSurvivalBonus;
    g_cvTieBreaker.IntValue = g_iDefaultTieBreaker;
    g_bHooked = false;
}

void DoorCloseEvent(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bModuleIsEnabled)
    {
        return;
    }

    if (event.GetBool("checkpoint"))
    {
        g_cvSurvivalBonus.IntValue = CalculateSurvivalBonus();
    }
}

void PlayerDeathEvent(Event event, const char[] name, bool dontBroadcast)
{
    int client = 0;

    if (!g_bModuleIsEnabled)
    {
        return;
    }

    client = GetClientOfUserId(event.GetInt("userid"));
    if (client && L4D_GetClientTeam(client) == L4DTeam_Survivor)
    {
        g_cvSurvivalBonus.IntValue = CalculateSurvivalBonus();
    }
}

void RoundEndEvent(Event event, const char[] name, bool dontBroadcast)
{
    int aliveCount = 0;
    int score = 0;

    if (!g_bModuleIsEnabled)
    {
        return;
    }

    if (!g_bIsFirstRoundOver)
    {
        g_bIsFirstRoundOver = true;
        g_iFirstScore = RoundToFloor(CalculateAvgHealth(aliveCount) * g_fMapMulti * g_fHBRatio + 400.0 * g_fMapMulti * g_fSurvivalBonusRatio);
        g_iFirstScore = g_iFirstScore ? g_cvSurvivalBonus.IntValue * aliveCount : 0;
        CPrintToChatAll("%t %t", "Tag", "RoundBonus", 1, g_iFirstScore);
        if (g_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1)
        {
            CPrintToChatAll("%t %t", "Tag", "CustomMaxDistance", GetCustomMapMaxScore());
        }
    }
    else if (g_bIsSecondRoundStarted && !g_bIsSecondRoundOver)
    {
        g_bIsSecondRoundOver = true;
        score = RoundToFloor(CalculateAvgHealth(aliveCount) * g_fMapMulti * g_fHBRatio + 400.0 * g_fMapMulti * g_fSurvivalBonusRatio);
        score = score ? g_cvSurvivalBonus.IntValue * aliveCount : 0;

        CPrintToChatAll("%t %t", "Tag", "RoundBonus", 1, g_iFirstScore);
        CPrintToChatAll("%t %t", "Tag", "RoundBonus", 2, score);

        g_iDifference = g_iFirstScore - score;
        if (score > g_iFirstScore)
        {
            g_iDifference = (~g_iDifference) + 1;
        }

        CPrintToChatAll("%t %t", "Tag", "Difference", g_iDifference);
        DebugPrint("Round end scores. round1=%d round2=%d diff=%d", g_iFirstScore, score, g_iDifference);
        if (g_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1)
        {
            CPrintToChatAll("%t %t", "Tag", "CustomMaxDistance", GetCustomMapMaxScore());
        }

        NotifyMatchFinalized(g_iFirstScore, score);
    }
}

void RoundStartEvent(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bModuleIsEnabled)
    {
        return;
    }

    if (g_bIsFirstRoundOver)
    {
        g_bIsSecondRoundStarted = true;
    }
}

void FinaleVehicleLeavingEvent(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bModuleIsEnabled)
    {
        return;
    }

    g_cvSurvivalBonus.IntValue = CalculateSurvivalBonus();
}

Action Cmd_Health(int client, int args)
{
    int aliveCount = 0;
    int score = 0;
    float avgHealth = 0.0;

    if (!g_bModuleIsEnabled)
    {
        return Plugin_Handled;
    }

    avgHealth = CalculateAvgHealth(aliveCount);
    score = RoundToFloor(avgHealth * g_fMapMulti * g_fHBRatio) * aliveCount;

    if (g_bIsSecondRoundStarted)
    {
        g_iDifference = g_iFirstScore - score;
        if (score > g_iFirstScore)
        {
            g_iDifference = (~g_iDifference) + 1;
        }

        CPrintToChat(client, "%t %t", "Tag", "RoundBonusWithDifference", 1, g_iFirstScore, g_iDifference);
    }

    DebugPrint("Cmd health calc. score=%d map_multi=%.2f hb_ratio=%.2f alive=%d", score, g_fMapMulti, g_fHBRatio, aliveCount);

    if (client)
    {
        CPrintToChat(client, "%t %t", "Tag", "HealthBonus", score);
    }
    else
    {
        PrintToServer("[ScoreMod] Health Bonus: %d", score);
    }

    if (g_cvCustomMaxDistance.BoolValue && GetCustomMapMaxScore() > -1)
    {
        if (client)
        {
            CPrintToChat(client, "%t %t", "Tag", "CustomMaxDistance", GetCustomMapMaxScore());
        }
        else
        {
            PrintToServer("[ScoreMod] Custom Max Distance: %d", GetCustomMapMaxScore());
        }
    }

    return Plugin_Handled;
}

int CalculateSurvivalBonus()
{
    return RoundToFloor(CalculateAvgHealth() * g_fMapMulti * g_fHBRatio + 400.0 * g_fMapMulti * g_fSurvivalBonusRatio);
}

float CalculateAvgHealth(int &aliveCount = 0)
{
    int totalHealth = 0;
    int totalTempHealth[3];
    float totalAdjustedTempHealth = 0.0;
    bool isFinale = L4D_IsMissionFinalMap();
    int item = 0;
    int currentHealth = 0;
    int currentTemp = 0;
    int incapCount = 0;
    int survivorCount = 0;
    char className[50];

    aliveCount = 0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsSurvivorClassic(client))
        {
            continue;
        }

        survivorCount++;
        if (!IsPlayerAlive(client))
        {
            continue;
        }

        if (!L4D_IsPlayerIncapacitated(client))
        {
            currentHealth = GetSurvivorPermanentHealth(client);
            currentTemp = GetSurvivorTempHealth(client);
            incapCount = L4D_GetPlayerReviveCount(client);

            item = GetPlayerWeaponSlot(client, L4DWeaponSlot_FirstAid);
            if (item > -1)
            {
                GetEdictClassname(item, className, sizeof(className));
                if (StrEqual(className, "weapon_first_aid_kit"))
                {
                    currentHealth = RoundToFloor(currentHealth + ((100 - currentHealth) * g_fHealPercent));
                    currentTemp = 0;
                    incapCount = 0;
                }
            }

            item = GetPlayerWeaponSlot(client, L4DWeaponSlot_Pills);
            if (item > -1)
            {
                GetEdictClassname(item, className, sizeof(className));
                if (StrEqual(className, "weapon_pain_pills"))
                {
                    currentTemp += g_iPillPercent;
                }
                else if (StrEqual(className, "weapon_adrenaline"))
                {
                    currentTemp += g_iAdrenPercent;
                }
            }

            if ((currentTemp + currentHealth) > 100)
            {
                currentTemp = 100 - currentHealth;
            }

            aliveCount++;
            totalHealth += currentHealth;
            totalTempHealth[incapCount] += currentTemp;
        }
        else if (!isFinale)
        {
            aliveCount++;
        }
    }

    for (int i = 0; i < 3; i++)
    {
        totalAdjustedTempHealth += totalTempHealth[i] * g_fTempMulti[i];
    }

    if (survivorCount < 1)
    {
        return 0.0;
    }

    return (totalHealth + totalAdjustedTempHealth) / survivorCount;
}

float GetClientClassicBonus(int client)
{
    int aliveCount = 0;

    if (!IsClientEligibleForClassicBonus(client))
    {
        return 0.0;
    }

    CalculateAvgHealth(aliveCount);
    if (aliveCount < 1)
    {
        return 0.0;
    }

    return float(CalculateSurvivalBonus()) / aliveCount;
}

int GetBonusValue(SMClassicBonusType type, int client = 0)
{
    switch (type)
    {
        case SMClassicBonusType_Total:
        {
            if (client == 0)
            {
                return CalculateSurvivalBonus();
            }

            return RoundToFloor(GetClientClassicBonus(client));
        }
    }

    return 0;
}

int GetMaxBonusValue(SMClassicBonusType type)
{
    switch (type)
    {
        case SMClassicBonusType_Total:
        {
            return GetMaxClassicBonus();
        }
    }

    return 0;
}

int GetMaxClassicBonus()
{
    return RoundToFloor(400.0 * g_fMapMulti * (g_fHBRatio + g_fSurvivalBonusRatio));
}

void FillBonusSnapshotKv(KeyValues kv)
{
    int currentRound = GetCurrentRoundNumber();
    int aliveCount = 0;
    int totalBonus = 0;
    int maxBonus = 0;
    int score1 = g_iFirstScore;
    int score2 = 0;

    totalBonus = CalculateSurvivalBonus();
    maxBonus = GetMaxClassicBonus();
    CalculateAvgHealth(aliveCount);

    if (g_bIsSecondRoundOver)
    {
        score2 = GetCurrentRoundFinalBonus();
    }

    KvRewind(kv);
    KvDeleteKey(kv, "rounds");
    KvDeleteKey(kv, "clients");
    KvSetNum(kv, "current_round", currentRound);
    KvSetNum(kv, "alive_survivors", aliveCount);
    KvSetFloat(kv, "map_multi", g_fMapMulti);
    KvSetFloat(kv, "hb_ratio", g_fHBRatio);
    KvSetFloat(kv, "survival_bonus_ratio", g_fSurvivalBonusRatio);
    KvSetNum(kv, "total_bonus", totalBonus);
    KvSetNum(kv, "max_bonus", maxBonus);
    DebugPrint("Snapshot fill: round=%d alive=%d total=%d max=%d", currentRound, aliveCount, totalBonus, maxBonus);

    KvJumpToKey(kv, "rounds", true);
    KvSetNum(kv, "round1_bonus", score1);
    KvSetNum(kv, "round2_bonus", score2);
    KvGoBack(kv);

    KvJumpToKey(kv, "clients", true);
    for (int client = 1; client <= MaxClients; client++)
    {
        char key[16];

        if (!IsSurvivorClassic(client))
        {
            continue;
        }

        IntToString(GetClientUserId(client), key, sizeof(key));
        KvJumpToKey(kv, key, true);
        KvSetNum(kv, "alive", IsPlayerAlive(client));
        KvSetNum(kv, "incapped", L4D_IsPlayerIncapacitated(client));
        KvSetNum(kv, "permanent_health", GetSurvivorPermanentHealth(client));
        KvSetNum(kv, "temporary_health", GetSurvivorTempHealth(client));
        KvSetNum(kv, "incap_count", L4D_GetPlayerReviveCount(client));
        KvSetFloat(kv, "bonus", GetClientClassicBonus(client));
        KvGoBack(kv);
    }
    KvGoBack(kv);
}

int GetCurrentRoundNumber()
{
    if (!g_bIsFirstRoundOver)
    {
        return 1;
    }

    return g_bIsSecondRoundStarted ? 2 : 1;
}

int GetCurrentRoundFinalBonus()
{
    int aliveCount = 0;
    int score = RoundToFloor(CalculateAvgHealth(aliveCount) * g_fMapMulti * g_fHBRatio + 400.0 * g_fMapMulti * g_fSurvivalBonusRatio);
    return score ? g_cvSurvivalBonus.IntValue * aliveCount : 0;
}

void NotifyMatchFinalized(int round1Bonus, int round2Bonus)
{
    int winningTeam = 0;

    if (round1Bonus > round2Bonus)
    {
        winningTeam = 1;
    }
    else if (round2Bonus > round1Bonus)
    {
        winningTeam = 2;
    }
    DebugPrint("Match finalized. winner=%d round1=%d round2=%d", winningTeam, round1Bonus, round2Bonus);

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
    CPrintToChatAll("{olive}[ScoreMod Debug]{default} %s", buffer);
    LogMessage("[ScoreMod Debug] %s", buffer);
}

Action Command_Say(int client, int args)
{
    char message[MAX_NAME_LENGTH];

    if (!g_bModuleIsEnabled)
    {
        return Plugin_Continue;
    }

    GetCmdArg(1, message, sizeof(message));
    if (StrEqual(message, "!health"))
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

bool IsSurvivorClassic(int client)
{
    return IsClientInGame(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor;
}

bool IsClientEligibleForClassicBonus(int client)
{
    return IsSurvivorClassic(client) && IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client);
}

int GetSurvivorPermanentHealth(int client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

int GetSurvivorTempHealth(int client)
{
    int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * FindConVar("pain_pills_decay_rate").FloatValue)) - 1;
    return tempHealth > 0 ? tempHealth : 0;
}

int GetCustomMapMaxScore()
{
    return g_bL4D2LibAvailable ? L4D2_GetMapValueInt("max_distance", -1) : -1;
}
