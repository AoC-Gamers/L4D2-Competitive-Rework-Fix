#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <caster_system>
#define REQUIRE_PLUGIN

enum L4DTeam
{
	L4DTeam_Unassigned = 0,
	L4DTeam_Spectator  = 1,
	L4DTeam_Survivor   = 2,
	L4DTeam_Infected   = 3
}

enum StatusRates
{
	RatesLimit = 0,
	RatesFree  = 1,
}

enum RateProfile
{
	RateProfile_None = 0,
	RateProfile_Limit,
	RateProfile_Reset
}

enum struct Player
{
	float		LastAdjusted;
	StatusRates Status;
	RateProfile AppliedProfile;
}

bool
	g_bCasterSystem,
	g_bLateload;

ConVar
	g_cvDebug,
	g_cvReplicateAlways,
	sv_mincmdrate,
	sv_maxcmdrate,
	sv_minupdaterate,
	sv_maxupdaterate,
	sv_minrate,
	sv_maxrate,
	sv_client_min_interp_ratio,
	sv_client_max_interp_ratio;

char
	g_sNetVars[8][8];

Player
	g_Players[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name		= "Lightweight Spectating",
	author		= "Visor, lechuga",
	description = "Forces low rates on spectators",
	version		= "1.3",
	url			= "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("SetStatusRates", Native_SetStatusRates);
	CreateNative("GetStatusRates", Native_GetStatusRates);

	g_bLateload = late;
	RegPluginLibrary("specrates");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bCasterSystem = LibraryExists("caster_system");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "caster_system", true))
		g_bCasterSystem = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "caster_system", true))
		g_bCasterSystem = true;
}

public void OnPluginStart()
{
	g_cvDebug				   = CreateConVar("sm_specrates_debug", "0", "Enable debug output for spectator rate changes.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvReplicateAlways	       = CreateConVar("sm_specrates_replicate_always", "0", "Reapply the spectator server rate profile even when the same profile was already replicated to the client.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sv_mincmdrate			   = FindConVar("sv_mincmdrate");
	sv_maxcmdrate			   = FindConVar("sv_maxcmdrate");
	sv_minupdaterate		   = FindConVar("sv_minupdaterate");
	sv_maxupdaterate		   = FindConVar("sv_maxupdaterate");
	sv_minrate				   = FindConVar("sv_minrate");
	sv_maxrate				   = FindConVar("sv_maxrate");
	sv_client_min_interp_ratio = FindConVar("sv_client_min_interp_ratio");
	sv_client_max_interp_ratio = FindConVar("sv_client_max_interp_ratio");

	HookEvent("player_team", OnTeamChange);

	if (!g_bLateload)
		return;

	g_bCasterSystem = LibraryExists("caster_system");
}

public void OnPluginEnd()
{
	UnhookEvent("player_team", OnTeamChange);
	sv_minupdaterate.SetString(g_sNetVars[2]);
	sv_mincmdrate.SetString(g_sNetVars[0]);
}

public void OnConfigsExecuted()
{
	sv_mincmdrate.GetString(g_sNetVars[0], 8);
	sv_maxcmdrate.GetString(g_sNetVars[1], 8);
	sv_minupdaterate.GetString(g_sNetVars[2], 8);
	sv_maxupdaterate.GetString(g_sNetVars[3], 8);
	sv_minrate.GetString(g_sNetVars[4], 8);
	sv_maxrate.GetString(g_sNetVars[5], 8);
	sv_client_min_interp_ratio.GetString(g_sNetVars[6], 8);
	sv_client_max_interp_ratio.GetString(g_sNetVars[7], 8);

	// Preserve the original enforcement model: spectator rate forcing depends on
	// tightening these server-side minimums after configs have been executed.
	sv_minupdaterate.SetInt(30);
	sv_mincmdrate.SetInt(30);

	for (int client = 1; client <= MaxClients; client++)
	{
		g_Players[client].AppliedProfile = RateProfile_None;

		if (IsValidClient(client))
			AdjustRates(client);
	}
}

public void OnClientPutInServer(int client)
{
	g_Players[client].LastAdjusted = 0.0;
	g_Players[client].Status	   = RatesLimit;
	g_Players[client].AppliedProfile = RateProfile_None;
}

void OnTeamChange(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetBool("disconnect"))
		return;

	CreateTimer(10.0, TimerAdjustRates, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

Action TimerAdjustRates(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
		return Plugin_Handled;

	AdjustRates(client);
	return Plugin_Handled;
}

public void OnClientSettingsChanged(int client)
{
	AdjustRates(client);
}

void AdjustRates(int client)
{
	if (!IsValidClient(client))
		return;

	if (g_Players[client].LastAdjusted < GetEngineTime() - 1.0)
	{
		g_Players[client].LastAdjusted = GetEngineTime();

		L4DTeam team = L4D_GetClientTeam(client);
		if (team == L4DTeam_Survivor || team == L4DTeam_Infected || (g_bCasterSystem && IsClientCaster(client)))
			ResetRates(client);
		else if (team == L4DTeam_Spectator)
		{
			if (g_Players[client].Status == RatesLimit)
				SetSpectatorRates(client);
			else
				ResetRates(client);
		}
	}
}

void SetSpectatorRates(int client)
{
	if (!ShouldForceRateProfile(client, RateProfile_Limit))
	{
		vPrintSkippedRatesDebug(client, "LIMIT");
		return;
	}

	bool replicatedMinCmdRate = sv_mincmdrate.ReplicateToClient(client, "30");
	bool replicatedMaxCmdRate = sv_maxcmdrate.ReplicateToClient(client, "30");
	bool replicatedMinUpdateRate = sv_minupdaterate.ReplicateToClient(client, "30");
	bool replicatedMaxUpdateRate = sv_maxupdaterate.ReplicateToClient(client, "30");
	bool replicatedMinRate = sv_minrate.ReplicateToClient(client, "10000");
	bool replicatedMaxRate = sv_maxrate.ReplicateToClient(client, "10000");
	bool replicatedProfile = replicatedMinCmdRate && replicatedMaxCmdRate && replicatedMinUpdateRate && replicatedMaxUpdateRate && replicatedMinRate && replicatedMaxRate;

	vApplyClientRateSettings(client, "10000", "30", "30");
	if (replicatedProfile)
		g_Players[client].AppliedProfile = RateProfile_Limit;
	else
		g_Players[client].AppliedProfile = RateProfile_None;

	vPrintRatesDebug(client, "LIMIT", "30", "30", "30", "30", "10000", "10000", "10000", "30", "30");
	vPrintReplicationDebug(client, replicatedMinCmdRate, replicatedMaxCmdRate, replicatedMinUpdateRate, replicatedMaxUpdateRate, replicatedMinRate, replicatedMaxRate);
}

void ResetRates(int client)
{
	if (!ShouldForceRateProfile(client, RateProfile_Reset))
	{
		vPrintSkippedRatesDebug(client, "RESET");
		return;
	}

	bool replicatedMinCmdRate = sv_mincmdrate.ReplicateToClient(client, g_sNetVars[0]);
	bool replicatedMaxCmdRate = sv_maxcmdrate.ReplicateToClient(client, g_sNetVars[1]);
	bool replicatedMinUpdateRate = sv_minupdaterate.ReplicateToClient(client, g_sNetVars[2]);
	bool replicatedMaxUpdateRate = sv_maxupdaterate.ReplicateToClient(client, g_sNetVars[3]);
	bool replicatedMinRate = sv_minrate.ReplicateToClient(client, g_sNetVars[4]);
	bool replicatedMaxRate = sv_maxrate.ReplicateToClient(client, g_sNetVars[5]);
	bool replicatedProfile = replicatedMinCmdRate && replicatedMaxCmdRate && replicatedMinUpdateRate && replicatedMaxUpdateRate && replicatedMinRate && replicatedMaxRate;

	vApplyClientRateSettings(client, g_sNetVars[5], g_sNetVars[3], g_sNetVars[1]);
	if (replicatedProfile)
		g_Players[client].AppliedProfile = RateProfile_Reset;
	else
		g_Players[client].AppliedProfile = RateProfile_None;

	vPrintRatesDebug(client, "RESET", g_sNetVars[0], g_sNetVars[1], g_sNetVars[2], g_sNetVars[3], g_sNetVars[4], g_sNetVars[5], g_sNetVars[5], g_sNetVars[3], g_sNetVars[1]);
	vPrintReplicationDebug(client, replicatedMinCmdRate, replicatedMaxCmdRate, replicatedMinUpdateRate, replicatedMaxUpdateRate, replicatedMinRate, replicatedMaxRate);
}

void vApplyClientRateSettings(int client, const char[] rateValue, const char[] updateRateValue, const char[] cmdRateValue)
{
	SetClientInfo(client, "rate", rateValue);
	SetClientInfo(client, "cl_updaterate", updateRateValue);
	SetClientInfo(client, "cl_cmdrate", cmdRateValue);
}

bool ShouldForceRateProfile(int client, RateProfile profile)
{
	if (g_cvReplicateAlways == null || g_cvReplicateAlways.BoolValue)
		return true;

	return g_Players[client].AppliedProfile != profile;
}

void vPrintRatesDebug(int client, const char[] mode, const char[] minCmdRate, const char[] maxCmdRate, const char[] minUpdateRate, const char[] maxUpdateRate, const char[] minRate, const char[] maxRate, const char[] clientRate, const char[] clientUpdateRate, const char[] clientCmdRate)
{
	if (g_cvDebug == null || !g_cvDebug.BoolValue || !IsValidClient(client))
		return;

	PrintToConsole(client, "[SpecRates] mode=%s team=%d status=%d", mode, GetClientTeam(client), g_Players[client].Status);
	PrintToConsole(client, "[SpecRates] replicated sv_mincmdrate=%s sv_maxcmdrate=%s", minCmdRate, maxCmdRate);
	PrintToConsole(client, "[SpecRates] replicated sv_minupdaterate=%s sv_maxupdaterate=%s", minUpdateRate, maxUpdateRate);
	PrintToConsole(client, "[SpecRates] replicated sv_minrate=%s sv_maxrate=%s", minRate, maxRate);
	PrintToConsole(client, "[SpecRates] setinfo rate=%s cl_updaterate=%s cl_cmdrate=%s", clientRate, clientUpdateRate, clientCmdRate);
	PrintToConsole(client, "[SpecRates] note: effective values come from the replicated server rate profile; specrates does not modify cl_interp or cl_interp_ratio");
}

void vPrintSkippedRatesDebug(int client, const char[] mode)
{
	if (g_cvDebug == null || !g_cvDebug.BoolValue || !IsValidClient(client))
		return;

	PrintToConsole(client, "[SpecRates] mode=%s skipped: the same replicated server rate profile was already applied to this client", mode);
}

void vPrintReplicationDebug(int client, bool replicatedMinCmdRate, bool replicatedMaxCmdRate, bool replicatedMinUpdateRate, bool replicatedMaxUpdateRate, bool replicatedMinRate, bool replicatedMaxRate)
{
	if (g_cvDebug == null || !g_cvDebug.BoolValue || !IsValidClient(client))
		return;

	char currentMinCmdRate[16], currentMaxCmdRate[16], currentMinUpdateRate[16], currentMaxUpdateRate[16], currentMinRate[16], currentMaxRate[16];
	sv_mincmdrate.GetString(currentMinCmdRate, sizeof(currentMinCmdRate));
	sv_maxcmdrate.GetString(currentMaxCmdRate, sizeof(currentMaxCmdRate));
	sv_minupdaterate.GetString(currentMinUpdateRate, sizeof(currentMinUpdateRate));
	sv_maxupdaterate.GetString(currentMaxUpdateRate, sizeof(currentMaxUpdateRate));
	sv_minrate.GetString(currentMinRate, sizeof(currentMinRate));
	sv_maxrate.GetString(currentMaxRate, sizeof(currentMaxRate));

	PrintToConsole(client, "[SpecRates] replicate ok sv_mincmdrate=%d sv_maxcmdrate=%d sv_minupdaterate=%d sv_maxupdaterate=%d sv_minrate=%d sv_maxrate=%d", replicatedMinCmdRate, replicatedMaxCmdRate, replicatedMinUpdateRate, replicatedMaxUpdateRate, replicatedMinRate, replicatedMaxRate);
	PrintToConsole(client, "[SpecRates] server actual sv_mincmdrate=%s sv_maxcmdrate=%s", currentMinCmdRate, currentMaxCmdRate);
	PrintToConsole(client, "[SpecRates] server actual sv_minupdaterate=%s sv_maxupdaterate=%s", currentMinUpdateRate, currentMaxUpdateRate);
	PrintToConsole(client, "[SpecRates] server actual sv_minrate=%s sv_maxrate=%s", currentMinRate, currentMaxRate);
}

void vPrintStatusChangeDebug(Handle plugin, int client, StatusRates oldStatus, StatusRates newStatus)
{
	if (g_cvDebug == null || !g_cvDebug.BoolValue)
		return;

	char pluginFile[PLATFORM_MAX_PATH];
	GetPluginFilename(plugin, pluginFile, sizeof(pluginFile));
	PrintToServer("[SpecRates] SetStatusRates caller=%s client=%N old=%d new=%d", pluginFile, client, oldStatus, newStatus);

	if (!IsValidClient(client))
		return;

	PrintToConsole(client, "[SpecRates] SetStatusRates caller=%s old=%d new=%d", pluginFile, oldStatus, newStatus);
}

// void SetStatusRates(int client, StatusRates Status);
int Native_SetStatusRates(Handle plugin, int numParams)
{
	int			client		 = GetNativeCell(1);
	StatusRates status		 = view_as<StatusRates>(GetNativeCell(2));
	StatusRates oldStatus	 = g_Players[client].Status;

	g_Players[client].Status = status;
	vPrintStatusChangeDebug(plugin, client, oldStatus, status);
	AdjustRates(client);
	return 0;
}

// StatusRates GetStatusRates(int client);
any Native_GetStatusRates(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_Players[client].Status;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

/**
 * Returns the clients team using L4DTeam.
 *
 * @param client		Player's index.
 * @return				Current L4DTeam of player.
 * @error				Invalid client index.
 */
stock L4DTeam L4D_GetClientTeam(int client)
{
	int team = GetClientTeam(client);
	return view_as<L4DTeam>(team);
}
