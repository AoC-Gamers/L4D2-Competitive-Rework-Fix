 #if 0
public void OnPluginStart()
{
	LoadPluginTranslations();
	
	(	g_cvSurvivorLimit		= FindConVar("survivor_limit")		).AddChangeHook(GameConVarChanged);
	(	g_cvVersusBossBuffer	= FindConVar("versus_boss_buffer")	).AddChangeHook(GameConVarChanged);
	(	g_cvMaxPlayers			= FindConVar("sv_maxplayers")		).AddChangeHook(GameConVarChanged);
	(	g_cvTankBurnDuration	= FindConVar("tank_burn_duration")	).AddChangeHook(GameConVarChanged);

	RefreshCachedCvars();
	
	RefreshBossPercentHandles();
	RefreshServerNameCache();
	RefreshReadyCfgName();
	g_iGamemode = L4D_GetGameModeType();
	g_BossFlow.Reset();
	g_BossRound.Reset();
	InitTankSpawnSchemeMaps();
	
	RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
	RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);
	
	HookEvent("round_start",		Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("player_death",		Event_PlayerDeath,		EventHookMode_Post);
	HookEvent("witch_killed",		Event_WitchDeath,		EventHookMode_PostNoCopy);
	HookEvent("player_team",		Event_PlayerTeam,		EventHookMode_Post);
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		g_bSpecHudActive[i] = false;
		g_bSpecHudHintShown[i] = false;
		g_bTankHudActive[i] = true;
		g_bTankHudHintShown[i] = false;
	}
	
	CreateTimer(SPECHUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errorMax)
{
	g_Runtime.Reset();
	g_Runtime.lateload = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_Runtime.Refresh();
	RefreshBossPercentHandles();
	RefreshServerNameCache();
	RefreshReadyCfgName();
	RefreshBossPercentCache();
}

public void OnLibraryAdded(const char[] name)
{
	g_Runtime.Refresh();
	if (StrEqual(name, LIBRARY_L4D_BOSS_PERCENT))
	{
		RefreshBossPercentCache();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	g_Runtime.Refresh();
	if (StrEqual(name, LIBRARY_L4D_BOSS_PERCENT))
	{
		g_BossFlow.Reset();
	}
}

public void L4D2_OnBossPercentsUpdated(int tankPercent, int witchPercent)
{
	g_BossFlow.tankPercent = tankPercent;
	g_BossFlow.witchPercent = witchPercent;
	g_BossFlow.synced = true;
}

void RefreshBossPercentCache()
{
	if (!g_Runtime.l4dBossPercent || g_BossFlow.synced)
	{
		return;
	}

	g_BossFlow.tankPercent = (GetFeatureStatus(FeatureType_Native, "GetStoredTankPercent") != FeatureStatus_Unknown)
		? GetStoredTankPercent()
		: -1;

	g_BossFlow.witchPercent = (GetFeatureStatus(FeatureType_Native, "GetStoredWitchPercent") != FeatureStatus_Unknown)
		? GetStoredWitchPercent()
		: -1;

	g_BossFlow.synced = true;
}

void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "translations/"...TRANSLATION_FILE... ".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \""...TRANSLATION_FILE...".txt\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}

void GameConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshCachedCvars();
}

void ServerCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvTankBurnDuration.GetString(g_sReadyCfgName, sizeof(g_sReadyCfgName));
}

void ReadyCfgChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvReadyCfgName.GetString(g_sReadyCfgName, sizeof(g_sReadyCfgName));
}

void RefreshCachedCvars()
{
	g_iSurvivorLimit	= g_cvSurvivorLimit.IntValue;
	g_fVersusBossBuffer	= g_cvVersusBossBuffer.FloatValue;
	g_iMaxPlayers		= g_cvMaxPlayers.IntValue;
	g_fTankBurnDuration	= g_cvTankBurnDuration.FloatValue;
}

void RefreshBossPercentHandles()
{
	g_cvTankPercent = FindConVar("tank_burn_duration");
	g_cvWitchPercent = FindConVar("tank_burn_duration");
}

void RefreshServerNameCache()
{
	if (g_hServerNamer == null)
	{
		g_hServerNamer = FindConVar("hostname");
		if (g_hServerNamer != null)
		{
			g_hServerNamer.AddChangeHook(ServerCvarChanged);
		}
	}

	if (g_hServerNamer != null)
	{
		g_hServerNamer.GetString(g_sHostname, sizeof(g_sHostname));
	}
}

void RefreshReadyCfgName()
{
	if (g_cvReadyCfgName == null)
	{
		g_cvReadyCfgName = FindConVar("l4d_ready_cfg_name");
		if (g_cvReadyCfgName != null)
		{
			g_cvReadyCfgName.AddChangeHook(ReadyCfgChanged);
		}
	}

	if (g_cvReadyCfgName != null)
	{
		g_cvReadyCfgName.GetString(g_sReadyCfgName, sizeof(g_sReadyCfgName));
	}
}

public void L4D_OnGameModeChange(int gamemode)
{
	g_iGamemode = gamemode;
}
#endif

#if 0
// ======================================================================
//  Bosses Caching
// ======================================================================
void AddStaticTankMapEntries()
{
	// Haunted Forest 3
	g_hCustomTankScriptMaps.SetValue("hf03_themansion", true);
}

void InitTankSpawnSchemeMaps()
{
	g_hFirstTankSpawningScheme	= new StringMap();
	g_hSecondTankSpawningScheme	= new StringMap();
	g_hFinaleExceptionMaps		= new StringMap();
	g_hCustomTankScriptMaps		= new StringMap();
	
	RegServerCmd("tank_map_flow_and_second_event",	SetMapFirstTankSpawningScheme);
	RegServerCmd("tank_map_only_first_event",		SetMapSecondTankSpawningScheme);
	RegServerCmd("finale_tank_default",				SetFinaleExceptionMap);
	
	AddStaticTankMapEntries();
}

Action SetMapFirstTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	g_hFirstTankSpawningScheme.SetValue(mapname, true);

	return Plugin_Handled;
}

Action SetMapSecondTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	g_hSecondTankSpawningScheme.SetValue(mapname, true);
	return Plugin_Handled;
}

Action SetFinaleExceptionMap(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	g_hFinaleExceptionMaps.SetValue(mapname, true);
	return Plugin_Handled;
}
#endif

// ======================================================================
//  Forwards
// ======================================================================
public void OnClientDisconnect(int client)
{
	g_bSpecHudHintShown[client] = false;
	g_bTankHudHintShown[client] = false;
}

public void OnMapStart() { g_bRoundLive = false; }
public void OnRoundIsLive()
{
	RefreshReadyCfgName();
	RefreshBossPercentCache();
	
	g_bRoundLive = true;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && L4D_GetClientTeam(i) == L4DTeam_Spectator && !IsClientSourceTV(i))
			FakeClientCommand(i, "sm_spectate");
	}
	
	if (g_iGamemode == GAMEMODE_VERSUS)
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
			if (g_hCustomTankScriptMaps.GetValue(mapname, dummy)) g_BossRound.tankCount += 1;
			
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
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundLive = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundLive = false;
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
	if (!IsValidClientIndex(client) || !IsClientInGame(client))
		return Plugin_Handled;
	
	if (L4D_GetClientTeam(client) != L4DTeam_Spectator)
		return Plugin_Handled;
	
	g_bSpecHudActive[client] = !g_bSpecHudActive[client];
	
	CPrintToChat(client, "%t", "Notify_SpechudState", "Tag", (g_bSpecHudActive[client] ? "on" : "off"));
	return Plugin_Handled;
}

Action ToggleTankHudCmd(int client, int args)
{
	if (!IsValidClientIndex(client) || !IsClientInGame(client))
		return Plugin_Handled;
	
	if (L4D_GetClientTeam(client) == L4DTeam_Survivor)
		return Plugin_Handled;
	
	g_bTankHudActive[client] = !g_bTankHudActive[client];
	
	CPrintToChat(client, "%t", "Notify_TankhudState", "Tag", (g_bTankHudActive[client] ? "on" : "off"));
	return Plugin_Handled;
}
