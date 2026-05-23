#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <left4dhooks>
#include <colors>
#include <l4d2util_weapons>
#include <readyup>
#include <pause>
#include <l4d2_boss_percents>
#include <l4d2_hybrid_scoremod_zone>
#include <l4d2_scoremod>
#include <l4d2_health_temp_bonus>
#include <l4d_tank_control_eq>
#include <lerpmonitor>
#include <witch_and_tankifier>
#include <client_name_helpers>

#include "spechud/types.sp"
#include "spechud/helpers.sp"
#include "spechud/runtime.sp"
#include "spechud/render.sp"

public Plugin myinfo =
{
	name = "Hyper-V HUD Manager",
	author = "Visor, Forgetest",
	description = "Provides different HUDs for spectators",
	version = "3.9.0",
	url = "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

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
	InitHookEvent();
	
	RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
	RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);

	
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
	g_BossRound.Reset();
}

public void OnLibraryAdded(const char[] name)
{
	g_Runtime.Refresh();
	if (StrEqual(name, LIBRARY_READYUP))
	{
		RefreshServerNameCache();
		RefreshReadyCfgName();
	}
	if (StrEqual(name, LIBRARY_L4D_BOSS_PERCENT))
	{
		RefreshBossPercentHandles();
		RefreshBossPercentCache();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	g_Runtime.Refresh();
	if (StrEqual(name, LIBRARY_READYUP))
	{
		if (g_cvReadyServerCvar != null)
		{
			g_cvReadyServerCvar.RemoveChangeHook(ReadyServerCvarChanged);
		}
		if (g_hServerNamer != null)
		{
			g_hServerNamer.RemoveChangeHook(ServerCvarChanged);
		}
		if (g_cvReadyCfgName != null)
		{
			g_cvReadyCfgName.RemoveChangeHook(ReadyCfgChanged);
		}
		g_cvReadyServerCvar = null;
		g_hServerNamer = null;
		g_cvReadyCfgName = null;
		g_sHostname[0] = '\0';
		g_sReadyCfgName[0] = '\0';
	}
	if (StrEqual(name, LIBRARY_L4D_BOSS_PERCENT))
	{
		g_cvTankPercent = null;
		g_cvWitchPercent = null;
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

	g_BossFlow.tankPercent = GetStoredTankPercent();
	g_BossFlow.witchPercent = GetStoredWitchPercent();

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
	if (g_hServerNamer != null)
	{
		g_hServerNamer.GetString(g_sHostname, sizeof(g_sHostname));
	}
}

void ReadyServerCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshServerNameCache();
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
	g_cvTankPercent = FindConVar("l4d_tank_percent");
	g_cvWitchPercent = FindConVar("l4d_witch_percent");
}

void RefreshServerNameCache()
{
	ConVar convar = null;

	if (g_Runtime.readyUp)
	{
		if (g_cvReadyServerCvar == null)
		{
			g_cvReadyServerCvar = FindConVar("l4d_ready_server_cvar");
			if (g_cvReadyServerCvar != null)
			{
				g_cvReadyServerCvar.AddChangeHook(ReadyServerCvarChanged);
			}
		}

		char buffer[64];
		g_cvReadyServerCvar.GetString(buffer, sizeof(buffer));
		convar = FindConVar(buffer);
	}

	if (convar == null)
	{
		convar = FindConVar("hostname");
	}

	if (g_hServerNamer != convar)
	{
		if (g_hServerNamer != null)
		{
			g_hServerNamer.RemoveChangeHook(ServerCvarChanged);
		}

		g_hServerNamer = convar;
		if (g_hServerNamer != null)
		{
			g_hServerNamer.AddChangeHook(ServerCvarChanged);
		}
	}

	if (g_hServerNamer != null)
	{
		g_hServerNamer.GetString(g_sHostname, sizeof(g_sHostname));
	}
	else
	{
		g_sHostname[0] = '\0';
	}
}

void RefreshReadyCfgName()
{
	if (!g_Runtime.readyUp)
	{
		g_sReadyCfgName[0] = '\0';
		return;
	}

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
