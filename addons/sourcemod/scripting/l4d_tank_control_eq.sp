#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <readyup>
#include <sourcemod>
#include <l4d_tank_control_eq>
#include <left4dhooks>

ArrayList g_hWhosHadTank;
ArrayList g_hTankQueue;

ConVar 
    g_cvTankPrint,
    g_cvTankWindow, 
    g_cvTankDebug;

GlobalForward
    g_hForwardOnTryOfferingTankBot,
    g_hForwardOnTankSelection,
    g_hForwardOnTankLifecycleStarted,
    g_hForwardOnTankControlChanged,
    g_hForwardOnTankLifecycleEnded;

int g_iTankLifecycleSerial = 0;

enum struct TankLifecycleState
{
	int id;
	int currentClient;
	int pendingClient;
	int disconnectFrustration;
	float graceTime;
	float gotTankAt;

	void Reset()
	{
		this.id = 0;
		this.currentClient = -1;
		this.pendingClient = -1;
		this.disconnectFrustration = -1;
		this.graceTime = 0.0;
		this.gotTankAt = 0.0;
	}
}

enum struct TankSelectionState
{
	char queuedSteamId[64];
	char initialSteamId[64];
	float initialTankLeft;

	void Reset()
	{
		this.queuedSteamId[0] = '\0';
		this.initialSteamId[0] = '\0';
		this.initialTankLeft = 0.0;
	}
}

TankLifecycleState g_TankLifecycle;
TankSelectionState g_TankSelection;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("GetTankSelection", Native_GetTankSelection);
    CreateNative("TankControl_GetActiveTankLifecycleId", Native_TankControl_GetActiveTankLifecycleId);
    CreateNative("TankControl_GetCurrentTankClient", Native_TankControl_GetCurrentTankClient);
    CreateNative("TankControl_GetPendingTankClient", Native_TankControl_GetPendingTankClient);
    CreateNative("TankControl_GetClientTankLifecycleId", Native_TankControl_GetClientTankLifecycleId);

    g_hForwardOnTryOfferingTankBot = new GlobalForward("TankControl_OnTryOfferingTankBot", ET_Ignore, Param_String);
    g_hForwardOnTankSelection = new GlobalForward("TankControl_OnTankSelection", ET_Ignore, Param_String);
    g_hForwardOnTankLifecycleStarted = new GlobalForward("TankControl_OnTankLifecycleStarted", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardOnTankControlChanged = new GlobalForward("TankControl_OnTankControlChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardOnTankLifecycleEnded = new GlobalForward("TankControl_OnTankLifecycleEnded", ET_Ignore, Param_Cell, Param_Cell);
    RegPluginLibrary(LIBRARY_L4D_TANK_CONTROL_EQ);

    return APLRes_Success;
}

int Native_GetTankSelection(Handle plugin, int numParams) { return FindInfectedPlayerBySteamId(g_TankSelection.queuedSteamId); }
int Native_TankControl_GetActiveTankLifecycleId(Handle plugin, int numParams) { return g_TankLifecycle.id; }
int Native_TankControl_GetCurrentTankClient(Handle plugin, int numParams) { return g_TankLifecycle.id > 0 ? g_TankLifecycle.currentClient : -1; }
int Native_TankControl_GetPendingTankClient(Handle plugin, int numParams) { return g_TankLifecycle.pendingClient; }

int Native_TankControl_GetClientTankLifecycleId(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (g_TankLifecycle.id <= 0 || client < 1 || client > MaxClients)
        return 0;

    if (client == g_TankLifecycle.currentClient || client == g_TankLifecycle.pendingClient)
        return g_TankLifecycle.id;

    return 0;
}

public Plugin myinfo = 
{
    name = "L4D2 Tank Control",
    author = "arti, (Contributions by: Sheo, Sir, Altair-Sossai)",
    description = "Distributes the role of the tank evenly throughout the team, allows for overrides. (Includes forwards)",
    version = "0.0.28",
    url = "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
}

public void OnPluginStart()
{
    LoadTranslation("l4d_tank_control_eq.phrases");
    LoadTranslations("common.phrases");
    
    // Event hooks
    HookEvent("player_left_start_area", PlayerLeftStartArea_Event, EventHookMode_PostNoCopy);
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    
    // Initialise the tank arrays/data values
    g_hWhosHadTank = new ArrayList(ByteCountToCells(64));
    g_hTankQueue = new ArrayList(ByteCountToCells(64));

    // Admin commands
    RegAdminCmd("sm_tankshuffle", TankShuffle_Cmd, ADMFLAG_SLAY, "Re-picks at random someone to become tank.");
    RegAdminCmd("sm_givetank", GiveTank_Cmd, ADMFLAG_SLAY, "Gives the tank to a selected player");

    // Register the boss commands
    RegConsoleCmd("sm_tank", Tank_Cmd, "Shows who is becoming the tank.");
    RegConsoleCmd("sm_boss", Tank_Cmd, "Shows who is becoming the tank.");
    RegConsoleCmd("sm_witch", Tank_Cmd, "Shows who is becoming the tank.");
    
    // Cvars
    g_cvTankPrint  = CreateConVar("tankcontrol_print_all", "0", "Who gets to see who will become the tank? (0 = Infected, 1 = Everyone)");
    g_cvTankWindow = CreateConVar("tankcontrol_force_window", "0.0", "Give player that was initially going to be Tank (or was Tank and dced) back the Tank this long after Tank was given to somebody else (0 = Off)");
    g_cvTankDebug  = CreateConVar("tankcontrol_debug", "0", "Whether or not to debug to console");
}

public void OnPluginEnd()
{
    ResetTankLifecycleState();
    g_TankSelection.Reset();

    if (g_hWhosHadTank != null)
    {
        delete g_hWhosHadTank;
        g_hWhosHadTank = null;
    }

    if (g_hTankQueue != null)
    {
        delete g_hTankQueue;
        g_hTankQueue = null;
    }
}

void ResetTankLifecycleState()
{
    g_TankLifecycle.Reset();
}

void UpdatePendingTankClient()
{
    g_TankLifecycle.pendingClient = FindInfectedPlayerBySteamId(g_TankSelection.queuedSteamId);
}

void FireTankLifecycleStarted(int lifecycleId, int client)
{
    Call_StartForward(g_hForwardOnTankLifecycleStarted);
    Call_PushCell(lifecycleId);
    Call_PushCell(client);
    Call_PushCell(client > 0 ? view_as<int>(IsFakeClient(client)) : 1);
    Call_Finish();
}

void FireTankControlChanged(int lifecycleId, int oldClient, int newClient)
{
    Call_StartForward(g_hForwardOnTankControlChanged);
    Call_PushCell(lifecycleId);
    Call_PushCell(oldClient);
    Call_PushCell(newClient);
    Call_PushCell(oldClient > 0 ? view_as<int>(IsFakeClient(oldClient)) : 1);
    Call_PushCell(newClient > 0 ? view_as<int>(IsFakeClient(newClient)) : 1);
    Call_Finish();
}

void FireTankLifecycleEnded(int lifecycleId, TankControlLifecycleEndReason reason)
{
    Call_StartForward(g_hForwardOnTankLifecycleEnded);
    Call_PushCell(lifecycleId);
    Call_PushCell(reason);
    Call_Finish();
}

void StartTankLifecycle(int client)
{
    if (g_TankLifecycle.id > 0)
        return;

    g_TankLifecycle.id = ++g_iTankLifecycleSerial;
    g_TankLifecycle.currentClient = client;
    FireTankLifecycleStarted(g_TankLifecycle.id, client);

    if (g_cvTankDebug.BoolValue)
        PrintToConsoleAll("[TC API] Lifecycle started: id=%d client=%N bot=%d", g_TankLifecycle.id, client, client > 0 ? IsFakeClient(client) : true);
}

void EndTankLifecycle(TankControlLifecycleEndReason reason)
{
    if (g_TankLifecycle.id <= 0)
        return;

    int lifecycleId = g_TankLifecycle.id;
    if (g_cvTankDebug.BoolValue)
        PrintToConsoleAll("[TC API] Lifecycle ended: id=%d reason=%d current=%d pending=%d", lifecycleId, reason, g_TankLifecycle.currentClient, g_TankLifecycle.pendingClient);

    FireTankLifecycleEnded(lifecycleId, reason);
    ResetTankLifecycleState();
}

void SetCurrentTankController(int client)
{
    if (g_TankLifecycle.id <= 0)
        StartTankLifecycle(client);

    if (g_TankLifecycle.currentClient == client)
    {
        UpdatePendingTankClient();
        return;
    }

    int oldClient = g_TankLifecycle.currentClient;
    g_TankLifecycle.currentClient = client;
    FireTankControlChanged(g_TankLifecycle.id, oldClient, client);
    UpdatePendingTankClient();

    if (g_cvTankDebug.BoolValue)
        PrintToConsoleAll("[TC API] Control changed: id=%d old=%d new=%d", g_TankLifecycle.id, oldClient, client);
}


/*=========================================================================
|                            Left4Dhooks                                  |
=========================================================================*/


public void L4D2_OnTankPassControl(int iOldTank, int iNewTank, int iPassCount)
{
    /*
    * As the Player switches to AI on disconnect/team switch, we have to make sure we're only checking this if the old Tank was AI.
    * Then apply the previous' Tank's Frustration and Grace Period (if it still had Grace)
    * We'll also be keeping the same Tank pass, which resolves Tanks that dc on 1st pass resulting into the Tank instantly going to 2nd pass.
    */
    if (g_TankLifecycle.disconnectFrustration != -1 && IsFakeClient(iOldTank))
    {
        SetTankFrustration(iNewTank, g_TankLifecycle.disconnectFrustration);
        CTimer_Start(GetFrustrationTimer(iNewTank), g_TankLifecycle.graceTime);
        L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() - 1);
    }

    g_TankLifecycle.gotTankAt = GetGameTime();
    SetCurrentTankController(iNewTank);
    if (g_cvTankDebug.BoolValue)
        PrintToConsoleAll("[TC] gotTankAt set to %f (iOldTank: %N - iNewTank: %N)", GetGameTime(), iOldTank, iNewTank);
}

/**
 * Make sure we give the tank to our queued player.
 */
public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStatis)
{
    StartTankLifecycle(tank_index);

    // Reset the tank's frustration if need be
    if (!IsFakeClient(tank_index)) 
    {
        PrintHintText(tank_index, "%t", "HintText");
        for (int i = 1; i <= MaxClients; i++) 
        {
            if (!bIsValidInfected(i) && !bIsValidSpectator(i))
                continue;

            if (tank_index == i) 
                CPrintToChat(i, "%t %t", "TagRage", "RefilledBot");
            else 
                CPrintToChat(i, "%t %t", "TagRage", "Refilled", tank_index);
        }
        
        SetTankFrustration(tank_index, 100);
        L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);

        return Plugin_Handled;
    }

    // Allow third party plugins to override tank selection
    char overrideTankSteamId[64];
    overrideTankSteamId[0] = '\0';
    Call_StartForward(g_hForwardOnTryOfferingTankBot);
    Call_PushStringEx(overrideTankSteamId, sizeof(overrideTankSteamId), SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
    Call_Finish();

    if (!StrEqual(overrideTankSteamId, ""))
        strcopy(g_TankSelection.queuedSteamId, sizeof(g_TankSelection.queuedSteamId), overrideTankSteamId);
    
    // If we don't have a queued tank, choose one
    if (StrEqual(g_TankSelection.queuedSteamId, ""))
        SelectTank(0);

    UpdatePendingTankClient();
    
    // Mark the player as having had tank
    if (!StrEqual(g_TankSelection.queuedSteamId, ""))
    {
        SetTankTicketsForPlayer(g_TankSelection.queuedSteamId, 20000);

        if (g_hWhosHadTank.FindString(g_TankSelection.queuedSteamId) == -1)
            g_hWhosHadTank.PushString(g_TankSelection.queuedSteamId);

        int index = g_hTankQueue.FindString(g_TankSelection.queuedSteamId);
        if (index != -1)
            g_hTankQueue.Erase(index);
    }
    
    return Plugin_Continue;
}

public void L4D_OnLeaveStasis(int tank)
{
    // Tank is always AI here, delay by a frame.
    RequestFrame(L4D_OnLeaveStasis_Post, GetClientUserId(tank));
}

void L4D_OnLeaveStasis_Post(int userid)
{
    int tank = GetClientOfUserId(userid);
    // Tank passed from AI to a player, nothing to do here.
    if (!tank || !IsClientInGame(tank))
        return;
    
    // @Forgetest: 
    //   AI Tank may have committed suicide at the moment
    if (!IsPlayerAlive(tank) || GetEntProp(tank, Prop_Send, "m_isIncapacitated")) // Thanks to @sheo for noting the tank incap
        return;

    if (g_cvTankDebug.BoolValue)
        PrintToConsoleAll("[TC] Tank was not properly assigned to a player, trying to re-assign...");

    int newTank = FindInfectedPlayerBySteamId(g_TankSelection.queuedSteamId);

    // Still no candidates, give up.
    if (newTank == -1)
    {
        if (g_cvTankDebug.BoolValue)
            PrintToConsoleAll("[TC] Tried to assign Tank to another player, but there's no one available?");

        return;
    }

    if (g_cvTankDebug.BoolValue)
        PrintToConsoleAll("[TC] Assigned tank to %N.", newTank);

    L4D_ReplaceTank(tank, newTank);
    L4D2Direct_SetTankPassedCount(1); // Otherwise the Tank gets 3 controls.
}

/*=========================================================================
|                                 Events                                  |
=========================================================================*/


/**
 * When a new game starts, reset the tank pool.
 */
void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    CreateTimer(10.0, OnNewGameTimer);
    g_TankLifecycle.disconnectFrustration = -1;
    g_TankLifecycle.gotTankAt = 0.0;
    g_TankSelection.initialSteamId[0] = '\0';
    ResetTankLifecycleState();
}

Action OnNewGameTimer(Handle timer)
{
    int teamAScore = L4D2Direct_GetVSCampaignScore(0);
    int teamBScore = L4D2Direct_GetVSCampaignScore(1);

    // If it's a new game, reset the tank pool
    if (teamAScore == 0 && teamBScore == 0)
    {
        g_hWhosHadTank.Clear();
        g_hTankQueue.Clear();
        g_TankSelection.Reset();
    }

    return Plugin_Stop;
}

/**
 * When the round ends, reset the active tank.
 */
void RoundEnd_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    EndTankLifecycle(TankControlLifecycleEnd_RoundEnded);
    g_TankSelection.queuedSteamId[0] = '\0';
    UpdatePendingTankClient();
    g_TankSelection.initialSteamId[0] = '\0';
}

/**
 * When a player leaves the start area, choose a tank and output to all.
 */
void PlayerLeftStartArea_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    g_TankSelection.initialSteamId[0] = '\0';

    SelectTank(0);
    ShowTankToAll(0);
}

/**
 * When the queued tank switches teams, choose a new one
 */
void PlayerTeam_Event(Event hEvent, const char[] name, bool dontBroadcast)
{
    int team = hEvent.GetInt("team");
    int oldTeam = hEvent.GetInt("oldteam");
    int client = GetClientOfUserId(hEvent.GetInt("userid"));
    char tmpSteamId[64];

    if (client < 1 || client > MaxClients)
        return;

    if (view_as<L4DTeam>(oldTeam) == L4DTeam_Infected)
    {
        /*
        * Triggers for disconnects as well as forced-swaps and whatnot.
        * Allows us to always reliably detect when the current Tank player loses control due to unnatural reasons.
        */
        if (!IsFakeClient(client))
        {
            if (bIsTankPlayer(client))
            {
                g_TankLifecycle.disconnectFrustration = GetTankFrustration(client);
                g_TankLifecycle.graceTime = CTimer_GetRemainingTime(GetFrustrationTimer(client));

                // Slight fix due to the timer seemingly always getting stuck between 0.5s~1.2s even after Grace period has passed.
                // CTimer_IsElapsed still returns false as well.
                if (g_TankLifecycle.graceTime < 0.0 || g_TankLifecycle.disconnectFrustration < 100) 
                    g_TankLifecycle.graceTime = 0.0;
            }
        }

        GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));

        if (StrEqual(g_TankSelection.initialSteamId, tmpSteamId))
            g_TankSelection.initialTankLeft = GetGameTime();

        if (StrEqual(g_TankSelection.queuedSteamId, tmpSteamId))
        {
            RequestFrame(SelectTank, 0);
            RequestFrame(ShowTankToAll, 0);
        }
    }

    if (view_as<L4DTeam>(team) == L4DTeam_Infected && !IsFakeClient(client) && !StrEqual(g_TankSelection.initialSteamId, ""))
    {
        GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
        if (StrEqual(g_TankSelection.initialSteamId, tmpSteamId))
        {
            /* Not touching multiple tanks with a ten-foot pole.
            Could technically be done though.. TODO? */
            int tank = FindTankPlayer();

            if (g_cvTankDebug.BoolValue)
                PrintToConsoleAll("[TC] Tank: %N - L4D2_GetTankCount: %i - initialTankLeft: %f - gotTankAt: %f", tank, L4D2_GetTankCount(), g_TankSelection.initialTankLeft, g_TankLifecycle.gotTankAt);

            float window = g_cvTankWindow.FloatValue;
            if (window > 0.0 && L4D2_GetTankCount() == 1 && tank != -1 && (g_TankLifecycle.gotTankAt - g_TankSelection.initialTankLeft) < window)
            {
                // Delay by a frame as player needs to "settle in"
                RequestFrame(ReplaceTank, client);
            }
            else
            {
                strcopy(g_TankSelection.queuedSteamId, sizeof(g_TankSelection.queuedSteamId), g_TankSelection.initialSteamId);
                UpdatePendingTankClient();
                RequestFrame(ShowTankToAll, 0);
            }
        }
    }
}

/**
 * Replaces the current tank with the initially chosen Tank.
 * And requeues the old Tank.
 * 
 * @param deservingTank
 *      The player to give the Tank to.
 */
void ReplaceTank(int deservingTank)
{
    int oldTank = FindTankPlayer();

    if (oldTank != -1 && bIsInfected(deservingTank))
    {
        if (g_cvTankDebug.BoolValue)
            PrintToConsoleAll("[TC] Tank: %N being replaced by %N", oldTank, deservingTank);

        L4D_ReplaceTank(oldTank, deservingTank);

        char steamId[64];

        // Requeue the old tank        
        GetClientAuthId(oldTank, AuthId_Steam2, steamId, sizeof(steamId));
        if (g_hTankQueue.FindString(steamId) == -1)
        {
            g_hTankQueue.ShiftUp(0);
            g_hTankQueue.SetString(0, steamId);
        }

        int index = g_hWhosHadTank.FindString(steamId);
        if (index != -1)
            g_hWhosHadTank.Erase(index);

        // Remove the deserving tank from the queue if they're in it
        GetClientAuthId(deservingTank, AuthId_Steam2, steamId, sizeof(steamId));
        index = g_hTankQueue.FindString(steamId);
        if (index != -1)
            g_hTankQueue.Erase(index);

        index = g_hWhosHadTank.FindString(steamId);
        if (index == -1)
            g_hWhosHadTank.PushString(steamId);                
    }
    else if (g_cvTankDebug.BoolValue)
        PrintToConsoleAll("[TC] oldTank: %i and deservingTank: is%s valid", oldTank, bIsInfected(deservingTank) ? "" : " NOT");
}

/**
 * When the tank dies, requeue a player to become tank (for finales)
 */
void PlayerDeath_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    int victim = GetClientOfUserId(hEvent.GetInt("userid"));
    
    if (victim && bIsValidInfected(victim) && g_TankLifecycle.gotTankAt > 0.0)
    {
        if (bIsTankPlayer(victim))
        {
            if (g_cvTankDebug.BoolValue)
                PrintToConsoleAll("[TC] Tank died (player_death), choosing a new tank");

            EndTankLifecycle(TankControlLifecycleEnd_TankDied);
            g_TankSelection.initialSteamId[0] = '\0';
            SelectTank(0);
            g_TankLifecycle.gotTankAt = 0.0;
            g_TankLifecycle.disconnectFrustration = -1;
        }
    }
}

/*=========================================================================
|                               Commands                                  |
=========================================================================*/


/**
 * When a player wants to find out whos becoming tank,
 * output to them.
 */
Action Tank_Cmd(int client, int args)
{
    // Only output if client is in-game and we have a queued tank
    if (!IsClientInGame(client) || StrEqual(g_TankSelection.queuedSteamId, ""))
        return Plugin_Handled;
    
    int tankClientId = FindInfectedPlayerBySteamId(g_TankSelection.queuedSteamId);

    if (tankClientId != -1 && (g_cvTankPrint.BoolValue || bIsInfected(client) || bIsSpectator(client)))
    {
        if (client == tankClientId) 
            CPrintToChat(client, "%t %t", "TagSelection", "YouBecomeTank");
        else 
            CPrintToChat(client, "%t %t", "TagSelection", "BecomeTank", tankClientId);
    }
    
    return Plugin_Handled;
}

/**
 * Shuffle the tank (randomly give to another player in
 * the pool.
 */
Action TankShuffle_Cmd(int client, int args)
{
    g_TankSelection.initialSteamId[0] = '\0';

    SelectTank(0);
    ShowTankToAll(0);
    
    return Plugin_Handled;
}

/**
 * Give the tank to a specific player.
 */
Action GiveTank_Cmd(int client, int args)
{    
    // Who are we targetting?
    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    // Try and find a matching player
    int target = FindTarget(client, arg1);

    if (target == -1 || !IsClientInGame(target) || IsFakeClient(target))
    {
        CPrintToChat(client, "%t %t", "TagControl", "InvalidTarget");
        return Plugin_Handled;
    }

    // Checking if on our desired team
    if (!bIsInfected(target))
    {
        CPrintToChat(client, "%t %t", "TagControl", "NoInfected", target);
        return Plugin_Handled;
    }
    
    // Set the tank
    char steamId[64];
    GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

    strcopy(g_TankSelection.queuedSteamId, sizeof(g_TankSelection.queuedSteamId), steamId);
    strcopy(g_TankSelection.initialSteamId, sizeof(g_TankSelection.initialSteamId), steamId);
    UpdatePendingTankClient();

    ShowTankToAll(0);
    
    return Plugin_Handled;
}


/*=========================================================================
|                                 Stocks                                  |
=========================================================================*/


/**
 * Selects a player on the infected team from random who hasn't been
 * tank and gives it to them.
 */
void SelectTank(any data)
{
    // Allow other plugins to override tank selection.
    char overrideTankSteamId[64];
    overrideTankSteamId[0] = '\0';
    Call_StartForward(g_hForwardOnTankSelection);
    Call_PushStringEx(overrideTankSteamId, sizeof(overrideTankSteamId), SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
    Call_Finish();

    if (!StrEqual(overrideTankSteamId, ""))
    {
        strcopy(g_TankSelection.queuedSteamId, sizeof(g_TankSelection.queuedSteamId), overrideTankSteamId);
        UpdatePendingTankClient();
        return;
    }

    g_TankSelection.queuedSteamId[0] = '\0';

    int nextTankIndex = PeekNextTankIndexInTheQueue();

    if (nextTankIndex == -1)
    {
        EnqueueNewInfectedPlayers();
        nextTankIndex = PeekNextTankIndexInTheQueue();
    }

    if (nextTankIndex == -1)
    {
        RemoveAllInfectedFrom(g_hTankQueue);
        RemoveAllInfectedFrom(g_hWhosHadTank);
        EnqueueNewInfectedPlayers();
        nextTankIndex = PeekNextTankIndexInTheQueue();
    }

    if (nextTankIndex == -1)
        return;

    char steamId[64];

    g_hTankQueue.GetString(nextTankIndex, steamId, sizeof(steamId));

    strcopy(g_TankSelection.queuedSteamId, sizeof(g_TankSelection.queuedSteamId), steamId);
    UpdatePendingTankClient();

    if (StrEqual(g_TankSelection.initialSteamId, ""))
        strcopy(g_TankSelection.initialSteamId, sizeof(g_TankSelection.initialSteamId), steamId);
}

/**
 * Sets the amount of tickets for a particular player, essentially giving them tank.
 */
void SetTankTicketsForPlayer(const char[] steamId, int tickets)
{
    int tankClientId = FindInfectedPlayerBySteamId(steamId);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (bIsValidInfected(i) && !IsFakeClient(i))
            L4D2Direct_SetTankTickets(i, (i == tankClientId) ? tickets : 0);
    }
}

/**
 * Output who will become tank
 */
void ShowTankToAll(any data)
{
    int tankClientId = FindInfectedPlayerBySteamId(g_TankSelection.queuedSteamId);
    
    if (tankClientId != -1)
    {
        for (int i = 1; i <= MaxClients; i++) 
        {
            if (!IsClientInGame(i) || (!g_cvTankPrint.BoolValue && !bIsInfected(i) && !bIsSpectator(i)))
                continue;

            if (tankClientId == i) 
                CPrintToChat(i, "%t %t", "TagSelection", "YouBecomeTank");
            else 
                CPrintToChat(i, "%t %t", "TagSelection", "BecomeTank", tankClientId);
        }
    }
}

/**
 * Retrieves the current Tank player.
 * 
 * @return
 *     The tank's client index or -1 if not found.
 */
int FindTankPlayer()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !bIsInfected(i) || IsFakeClient(i))
            continue;

        if (bIsTankPlayer(i))
            return i;
    }

    return -1;
}

/**
 * Retrieves a player's client index by their steam id.
 * 
 * @param steamId
 *     The steam id string to look for.
 * 
 * @return
 *     The player's client index or -1 if not found.
 */
int FindInfectedPlayerBySteamId(const char[] steamId) 
{
    char authSteamId[64];
   
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!bIsValidInfected(i))
            continue;

        GetClientAuthId(i, AuthId_Steam2, authSteamId, sizeof(authSteamId));
        
        if (StrEqual(steamId, authSteamId))
            return i;
    }
    
    return -1;
}

void SetTankFrustration(int client, int frustration) 
{
    if (frustration >= 0 && frustration <= 100)
        SetEntProp(client, Prop_Send, "m_frustration", 100-frustration);
}

int GetTankFrustration(int client) 
{
    return 100 - GetEntProp(client, Prop_Send, "m_frustration");
}

CountdownTimer GetFrustrationTimer(int client)
{
    static int frustrationTimerOffset = -1;

    if (frustrationTimerOffset == -1)
        frustrationTimerOffset = FindSendPropInfo("CTerrorPlayer", "m_frustration") + 4;
    
    return view_as<CountdownTimer>(GetEntityAddress(client) + view_as<Address>(frustrationTimerOffset));
}

int PeekNextTankIndexInTheQueue()
{
    if (g_hTankQueue.Length == 0)
        return -1;

    char steamId[64];

    for (int i = 0; i < g_hTankQueue.Length; i++)
    {
        g_hTankQueue.GetString(i, steamId, sizeof(steamId));

        int client = FindInfectedPlayerBySteamId(steamId);
        if (client != -1)
            return i;
    }

    return -1;
}

void EnqueueNewInfectedPlayers()
{
    char steamId[64];

    int start = g_hTankQueue.Length;
    int end = -1;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != L4DTeam_Infected)
            continue;
        
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

        if (g_hTankQueue.FindString(steamId) != -1 || g_hWhosHadTank.FindString(steamId) != -1)
            continue;

        g_hTankQueue.PushString(steamId);

        end = g_hTankQueue.Length - 1;
    }

    if (end != -1)
        ShuffleArray(g_hTankQueue, start, end);
}

void RemoveAllInfectedFrom(ArrayList arrayList)
{
    char steamId[64];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != L4DTeam_Infected)
            continue;
        
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

        int index = arrayList.FindString(steamId);
        if (index != -1)
            arrayList.Erase(index);
    }
}

void ShuffleArray(ArrayList arrayList, int start, int end)
{
    if (start == end)
        return;

    int swaps = (end - start + 1) * 2;

    for (int i = 0; i < swaps; i++)
    {
        int index1 = GetRandomInt(start, end);
        int index2 = GetRandomInt(start, end);

        if (index1 == index2)
            continue;

        arrayList.SwapAt(index1, index2);
    }
}

/**
 * Check if the translation file exists
 *
 * @param translation	Translation name.
 * @noreturn
 */
stock void LoadTranslation(const char[] translation)
{
	char
		sPath[PLATFORM_MAX_PATH],
		sName[64];

	Format(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}

bool bIsSpectator(int client)
{
    return L4D_GetClientTeam(client) == L4DTeam_Spectator;
}

bool bIsInfected(int client)
{
    return L4D_GetClientTeam(client) == L4DTeam_Infected;
}

bool bIsValidInfected(int client)
{
    return IsClientInGame(client) && bIsInfected(client);
}

bool bIsValidSpectator(int client)
{
    return IsClientInGame(client) && bIsSpectator(client);
}

bool bIsTankPlayer(int client)
{
    return IsClientInGame(client) && L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank;
}
