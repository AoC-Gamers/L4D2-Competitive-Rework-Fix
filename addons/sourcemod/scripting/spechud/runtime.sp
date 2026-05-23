InitHookEvent()
{
	HookEvent("round_start",		Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("player_death",		Event_PlayerDeath,		EventHookMode_Post);
	HookEvent("witch_killed",		Event_WitchDeath,		EventHookMode_PostNoCopy);
	HookEvent("player_team",		Event_PlayerTeam,		EventHookMode_Post);
}

void ResetRoundLiveState()
{
	g_bRoundLive = false;
}

void RefreshVersusBossState()
{
	g_BossRound.roundHasFlowTank = RoundHasFlowTank();
	g_BossRound.roundHasFlowWitch = RoundHasFlowWitch();
	g_BossRound.flowTankActive = g_BossRound.roundHasFlowTank;
	g_BossRound.customBossSys = IsDarkCarniRemix();

	g_bStaticTank = g_Runtime.witchAndTankifier && IsStaticTankMap();
	g_bStaticWitch = g_Runtime.witchAndTankifier && IsStaticWitchMap();

	g_iMaxDistance = L4D_GetVersusMaxCompletionScore() / 4 * g_iSurvivorLimit;

	g_BossRound.tankCount = 0;
	g_BossRound.witchCount = 0;

	if (g_cvTankPercent != null && g_cvTankPercent.BoolValue)
	{
		g_BossRound.tankCount = 1;

		char mapname[64];
		bool dummy;
		GetCurrentMap(mapname, sizeof(mapname));

		// TODO: individual plugin served as an interface to tank counts?
		if (g_hCustomTankScriptMaps.GetValue(mapname, dummy))
		{
			g_BossRound.tankCount += 1;
		}
		else if (!g_BossRound.customBossSys && L4D_IsMissionFinalMap())
		{
			g_BossRound.tankCount = 3
						- view_as<int>(g_hFirstTankSpawningScheme.GetValue(mapname, dummy))
						- view_as<int>(g_hSecondTankSpawningScheme.GetValue(mapname, dummy))
						- view_as<int>(g_hFinaleExceptionMaps.Size > 0 && !g_hFinaleExceptionMaps.GetValue(mapname, dummy))
						- view_as<int>(g_bStaticTank);
		}
	}

	if (g_cvWitchPercent != null && g_cvWitchPercent.BoolValue)
	{
		g_BossRound.witchCount = 1;
	}
}

void ResetHudHintState(int client)
{
	g_bSpecHudHintShown[client] = false;
	g_bTankHudHintShown[client] = false;
}

void ResetClientHudState(int client)
{
	g_bSpecHudActive[client] = false;
	g_bTankHudActive[client] = true;
	ResetHudHintState(client);
}

void ForceSpectatorsToSpectate()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && L4D_GetClientTeam(i) == L4DTeam_Spectator && !IsClientSourceTV(i))
		{
			FakeClientCommand(i, "sm_spectate");
		}
	}
}

public void OnClientDisconnect(int client)
{
	ResetClientHudState(client);
}

public void OnMapStart()
{
	ResetRoundLiveState();
}

public void OnRoundIsLive()
{
	RefreshReadyCfgName();
	RefreshBossPercentCache();
	
	g_bRoundLive = true;

	ForceSpectatorsToSpectate();
	
	if (g_iGamemode == GAMEMODE_VERSUS)
	{
		RefreshVersusBossState();
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetRoundLiveState();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetRoundLiveState();
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || L4D_GetClientTeam(client) != L4DTeam_Infected) return;
	
	if (L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
	{
		if (g_BossRound.tankCount > 0) g_BossRound.tankCount--;
		if (!RoundHasFlowTank()) g_BossRound.flowTankActive = false;
	}
}

void Event_WitchDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (g_BossRound.witchCount > 0) g_BossRound.witchCount--;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client) return;
	
	int team = event.GetInt("team");
	
	if (view_as<L4DTeam>(team) == L4DTeam_Unassigned)
	{
		g_bSpecHudActive[client] = false;
		g_bTankHudActive[client] = true;
	}
}

Action ToggleSpecHudCmd(int client, int args)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Handled;
	
	if (L4D_GetClientTeam(client) != L4DTeam_Spectator)
		return Plugin_Handled;
	
	g_bSpecHudActive[client] = !g_bSpecHudActive[client];
	
	CPrintToChat(client, "%t", "Notify_SpechudState", "Tag", (g_bSpecHudActive[client] ? "on" : "off"));
	return Plugin_Handled;
}

Action ToggleTankHudCmd(int client, int args)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Handled;
	
	if (L4D_GetClientTeam(client) == L4DTeam_Survivor)
		return Plugin_Handled;
	
	g_bTankHudActive[client] = !g_bTankHudActive[client];
	
	CPrintToChat(client, "%t", "Notify_TankhudState", "Tag", (g_bTankHudActive[client] ? "on" : "off"));
	return Plugin_Handled;
}
