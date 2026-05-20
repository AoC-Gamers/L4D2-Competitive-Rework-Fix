#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <left4dhooks>

#define AUTO_ASSIGN_WARNING_SUPPRESS_ATTEMPTS 2

bool		  g_bFixTeam = false;

ConVar		  g_cvEnabled;
ConVar		  g_cvAnnouncer;
ConVar		  g_cvOrganizationTime;
ConVar		  g_cvSurvivorLimit;
ConVar		  g_cvInfectedLimit;
ConVar		  g_cvDebug;
StringMap	  g_smSavedPlayerNames;
GlobalForward g_fwdOrganizationStart;
GlobalForward g_fwdOrganizationEnd;
GlobalForward g_fwdBlockedJoin;
GlobalForward g_fwdSafeToMovePlayers;
ArrayList	  g_aAbandonedAccountIds;
ArrayList	  g_aAbandonedTeams;
ArrayList	  g_aAbandonedNames;
int			  g_iSuppressBlockedJoinWarningsLeft[MAXPLAYERS + 1];

methodmap	  TeamSnapshot < ArrayList
{
	// Creates a new team snapshot list.
	//
	// @return			A new TeamSnapshot instance.
	public 	TeamSnapshot()
	{
		return view_as<TeamSnapshot>(new ArrayList());
	}

	// Captures all human players currently in the specified team.
	//
	// @param team			Team to snapshot.
	// @noreturn
	public 	void Capture(L4DTeam team)
	{
		this.Clear();
		DebugPrintAll("Snapshot.Capture -> team=%d", view_as<int>(team));

		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != team)
				continue;

			SaveClientName(client);
			int accountId = GetSteamAccountID(client);
			if (accountId > 0)
			{
				this.Push(accountId);
				DebugPrintAll("Snapshot.Capture -> team=%d added=%N account=%d", view_as<int>(team), client, accountId);
			}
		}
	}

	// Returns whether the snapshot contains the specified client.
	//
	// @param client			Client index to search for.
	// @return			True if the client is stored in the snapshot, false otherwise.
	public 	bool ContainsClient(int client)
	{
		if (!IsRealClientInGame(client))
			return false;

		int accountId = GetSteamAccountID(client);
		return accountId > 0 && this.FindValue(accountId) != -1;
	}

	// Moves team members not stored in the snapshot to spectators.
	//
	// @param team			Team to validate against the snapshot.
	// @noreturn
	public 	void MoveNonMembersToSpectator(L4DTeam team)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != team)
				continue;

			if (!this.ContainsClient(client))
			{
				DebugPrintAll("Snapshot.MoveNonMembers -> moving=%N from=%d to=%d", client, view_as<int>(team), view_as<int>(L4DTeam_Spectator));
				MovePlayerToTeam(client, L4DTeam_Spectator);
			}
		}
	}

	// Moves spectator clients stored in the snapshot back to the specified team.
	//
	// @param team			Destination team for matching spectators.
	// @noreturn
	public 	void MoveSpectatorsToTeam(L4DTeam team)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != L4DTeam_Spectator)
				continue;

			if (this.ContainsClient(client))
			{
				DebugPrintAll("Snapshot.MoveSpectators -> moving=%N from=%d to=%d", client, view_as<int>(L4DTeam_Spectator), view_as<int>(team));
				MovePlayerToTeam(client, team);
			}
		}
	}

	// Returns whether all stored clients are currently in the specified team.
	//
	// @param team			Team to verify.
	// @return			True if every stored client is in the expected team, false otherwise.
	public 	bool IsEveryoneInTeam(L4DTeam team)
	{
		for (int i = 0; i < this.Length; i++)
		{
			int client = FindClientByAccountID(this.Get(i));

			if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != team)
			{
				DebugPrintAll("Snapshot.IsEveryoneInTeam -> missing account=%d expected=%d client=%d", this.Get(i), view_as<int>(team), client);
				return false;
			}
		}

		return true;
	}

	public bool BuildMissingPlayersList(L4DTeam team, char[] buffer, int maxlen)
	{
		buffer[0] = '\0';
		bool added = false;

		for (int i = 0; i < this.Length; i++)
		{
			int	 accountId			   = this.Get(i);
			int	 client				   = FindClientByAccountID(accountId);
			bool isPlayerAlreadyInTeam = client > 0 && IsClientInGame(client) && !IsFakeClient(client) && L4D_GetClientTeam(client) == team;
			if (isPlayerAlreadyInTeam)
				continue;

			char playerName[MAX_NAME_LENGTH];
			if (!GetSavedPlayerName(accountId, playerName, sizeof(playerName)))
				Format(playerName, sizeof(playerName), "ID %d", accountId);

			if (buffer[0] != '\0')
				StrCat(buffer, maxlen, ", ");

			StrCat(buffer, maxlen, playerName);
			added = true;
		}

		return added;
	}

	public void CacheAbandonedPlayers(L4DTeam team)
	{
		char playerName[MAX_NAME_LENGTH];

		for (int i = 0; i < this.Length; i++)
		{
			int accountId = this.Get(i);
			int client	  = FindClientByAccountID(accountId);
			if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
				continue;

			if (!GetSavedPlayerName(accountId, playerName, sizeof(playerName)))
				Format(playerName, sizeof(playerName), "ID %d", accountId);

			g_aAbandonedAccountIds.Push(accountId);
			g_aAbandonedTeams.Push(view_as<int>(team));
			g_aAbandonedNames.PushString(playerName);
			DebugPrintAll("CacheAbandoned -> account=%d expected=%d name=%s", accountId, view_as<int>(team), playerName);
		}
	}

	public void NormalizeToActualTeam(L4DTeam team)
	{
		int teamLimit = TeamSize(team);
		if (teamLimit < 1)
			return;

		TeamSnapshot normalized = new TeamSnapshot();

		for (int client = 1; client <= MaxClients && normalized.Length < teamLimit; client++)
		{
			if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != team)
				continue;

			int accountId = GetSteamAccountID(client);
			if (accountId <= 0)
				continue;

			normalized.Push(accountId);
		}

		DebugPrintAll("NormalizeSnapshot -> team=%d old=%d new=%d", view_as<int>(team), this.Length, normalized.Length);
		this.Clear();

		for (int i = 0; i < normalized.Length; i++)
			this.Push(normalized.Get(i));

		delete normalized;
	}
}

TeamSnapshot winners;
TeamSnapshot losers;

public Plugin myinfo =
{
	name		= "L4D2 - Fix team shuffle",
	author		= "Altair Sossai, lechuga",
	description = "Fix teams shuffling during map switching",
	version		= "1.1.0",
	url			= "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d2_fix_team_shuffle");

	CreateNative("L4D2FixTeamShuffle_IsOrganizationActive", Native_IsOrganizationActive);
	CreateNative("L4D2FixTeamShuffle_HasSavedTeam", Native_HasSavedTeam);
	CreateNative("L4D2FixTeamShuffle_GetSavedTeam", Native_GetSavedTeam);
	CreateNative("L4D2FixTeamShuffle_IsClientBlocked", Native_IsClientBlocked);
	CreateNative("L4D2FixTeamShuffle_GetAbandonedPlayerCount", Native_GetAbandonedPlayerCount);
	CreateNative("L4D2FixTeamShuffle_FillAbandonedPlayers", Native_FillAbandonedPlayers);

	g_fwdOrganizationStart	= new GlobalForward("L4D2FixTeamShuffle_OnOrganizationStart", ET_Ignore);
	g_fwdOrganizationEnd	= new GlobalForward("L4D2FixTeamShuffle_OnOrganizationEnd", ET_Ignore);
	g_fwdBlockedJoin		= new GlobalForward("L4D2FixTeamShuffle_OnBlockedJoin", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwdSafeToMovePlayers = new GlobalForward("L4D2FixTeamShuffle_OnSafeToMovePlayers", ET_Ignore, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4d2_fix_team_shuffle.phrases");
	g_cvEnabled			 = CreateConVar("l4d2_fix_team_shuffle_enabled", "1", "Enable fix team shuffle logic.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvAnnouncer		 = CreateConVar("l4d2_fix_team_shuffle_announcer", "1", "Enable fix team shuffle announcements.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvOrganizationTime = CreateConVar("l4d2_fix_team_shuffle_organization_time", "30.0", "Duration in seconds for the team organization window.", FCVAR_NONE, true, 0.0);
	g_cvDebug			 = CreateConVar("l4d2_fix_team_shuffle_debug", "0", "Enable debug log messages for fix team shuffle.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSurvivorLimit	 = FindConVar("survivor_limit");
	g_cvInfectedLimit	 = FindConVar("z_max_player_zombies");
	g_cvEnabled.AddChangeHook(OnEnabledChanged);
	AutoExecConfig(true, "l4d2_fix_team_shuffle");

	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("player_team", PlayerTeam_Event);

	g_smSavedPlayerNames   = new StringMap();
	winners				   = new TeamSnapshot();
	losers				   = new TeamSnapshot();
	g_aAbandonedAccountIds = new ArrayList();
	g_aAbandonedTeams	   = new ArrayList();
	g_aAbandonedNames	   = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
}

public void OnPluginEnd()
{
	DebugPrintAll("OnPluginEnd -> cleanup");
	UnhookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookEvent("player_team", PlayerTeam_Event);
	g_cvEnabled.RemoveChangeHook(OnEnabledChanged);
	DisableFixTeam();
	ClearTeamsData();

	delete g_fwdOrganizationStart;
	delete g_fwdOrganizationEnd;
	delete g_fwdBlockedJoin;
	delete g_fwdSafeToMovePlayers;
	delete g_smSavedPlayerNames;
	delete winners;
	delete losers;
	delete g_aAbandonedAccountIds;
	delete g_aAbandonedTeams;
	delete g_aAbandonedNames;

	g_smSavedPlayerNames   = null;
	winners				   = view_as<TeamSnapshot>(null);
	losers				   = view_as<TeamSnapshot>(null);
	g_aAbandonedAccountIds = null;
	g_aAbandonedTeams	   = null;
	g_aAbandonedNames	   = null;
	g_fwdOrganizationStart = null;
	g_fwdOrganizationEnd = null;
	g_fwdBlockedJoin = null;
	g_fwdSafeToMovePlayers = null;
}

public void OnRoundIsLive()
{
	DebugPrintAll("OnRoundIsLive -> disable + clear");
	DisableFixTeam();
	ClearTeamsData();
}

public void L4D2_OnEndVersusModeRound_Post()
{
	if (!g_cvEnabled.BoolValue)
	{
		DebugPrintAll("EndRound -> plugin disabled");
		return;
	}

	DebugPrintAll("EndRound -> saving teams");
	SaveTeams();
}

void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	DebugPrintAll("Enabled changed -> %d", convar.BoolValue);

	if (convar.BoolValue)
		return;

	DisableFixTeam();
	ClearTeamsData();
}

void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
	{
		DebugPrintAll("RoundStart -> plugin disabled");
		return;
	}

	bool teamsDataEmpty = TeamsDataIsEmpty();
	DebugPrintAll("RoundStart -> mapStarted=%d teamsDataEmpty=%d", L4D_HasMapStarted(), teamsDataEmpty);
	DisableFixTeam();

	if (L4D_HasMapStarted() && IsNewGame())
	{
		DebugPrintAll("RoundStart -> new game detected, clearing saved teams");
		ClearTeamsData();
		return;
	}

	if (teamsDataEmpty)
	{
		DebugPrintAll("RoundStart -> no saved teams, skipping organization");
		return;
	}

	if (InSecondHalfOfRound())
	{
		DebugPrintAll("RoundStart -> second half, skipping organization");
		return;
	}

	DebugPrintAll("RoundStart -> scheduling enable timer");
	CreateTimer(2.0, EnableFixTeam_Timer);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
	{
		DebugPrintAll("PlayerTeam -> plugin disabled");
		return;
	}

	if (!L4D_HasMapStarted())
	{
		DebugPrintAll("PlayerTeam -> map not started");
		return;
	}

	if (event.GetBool("isbot"))
		return;

	if (event.GetBool("disconnect"))
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if (client > 0 && client <= MaxClients)
			g_iSuppressBlockedJoinWarningsLeft[client] = 0;

		DebugPrintAll("PlayerTeam -> disconnect ignored userid=%d", event.GetInt("userid"));
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}

	L4DTeam team		 = view_as<L4DTeam>(event.GetInt("team"));
	L4DTeam oldTeam		 = view_as<L4DTeam>(event.GetInt("oldteam"));
	bool	mustFixTeams = MustFixTheTeams();
	DebugPrintAll("PlayerTeam -> client=%N team=%d oldteam=%d fix=%d", client, view_as<int>(team), event.GetInt("oldteam"), mustFixTeams);

	if (team == L4DTeam_Unassigned)
	{
		DebugPrintAll("PlayerTeam -> unassigned transition ignored for %N", client);
		return;
	}

	if (mustFixTeams && oldTeam != L4DTeam_Unassigned && team != L4DTeam_Spectator && HandleBlockedTeamJoinAttempt(client, team, oldTeam))
		return;

	if (team == L4DTeam_Spectator)
	{
		if (oldTeam == L4DTeam_Unassigned)
		{
			if (mustFixTeams)
			{
				g_iSuppressBlockedJoinWarningsLeft[client] = AUTO_ASSIGN_WARNING_SUPPRESS_ATTEMPTS;
				DebugPrintAll("PlayerTeam -> suppressing next %d blocked warnings for %N", g_iSuppressBlockedJoinWarningsLeft[client], client);
			}

			DebugPrintAll("PlayerTeam -> scheduling respec for %N", client);
			CreateTimer(0.5, ReSpec_Timer, GetClientUserId(client));
		}

		return;
	}

	if (IsNewGame())
	{
		DebugPrintAll("PlayerTeam -> new game detected, clearing saved teams");
		DisableFixTeam();
		ClearTeamsData();
		return;
	}

	if (TeamsDataIsEmpty())
	{
		DebugPrintAll("PlayerTeam -> no saved teams, skipping organization");
		DisableFixTeam();
		return;
	}

	DebugPrintAll("PlayerTeam -> scheduling fix timer for %N", client);
	CreateTimer(1.0, FixTeam_Timer);
}

Action ReSpec_Timer(Handle timer, int userId)
{
	if (EnsureClientStaysSpectator(userId, "ReSpec_Timer", true))
		CreateTimer(0.1, ReSpec_Recheck_Timer, userId);

	return Plugin_Stop;
}

Action ReSpec_Recheck_Timer(Handle timer, int userId)
{
	if (EnsureClientStaysSpectator(userId, "ReSpec_Recheck", false))
		CreateTimer(0.1, ReSpec_Recheck_Timer, userId);

	return Plugin_Stop;
}

Action FixTeam_Timer(Handle timer)
{
	DebugPrintAll("FixTeam_Timer -> running FixTeams");
	FixTeams();

	return Plugin_Continue;
}

Action EnableFixTeam_Timer(Handle timer)
{
	int activePlayers = NumberOfPlayersInTheTeam(L4DTeam_Survivor) + NumberOfPlayersInTheTeam(L4DTeam_Infected);
	if (activePlayers < 1)
	{
		DebugPrintAll("EnableFixTeam_Timer -> waiting for players active=%d", activePlayers);
		CreateTimer(1.0, EnableFixTeam_Timer);
		return Plugin_Stop;
	}

	DebugPrintAll("EnableFixTeam_Timer -> enable + fix");
	EnableFixTeam();
	FixTeams();
	CreateTimer(g_cvOrganizationTime.FloatValue, DisableFixTeam_Timer);

	return Plugin_Continue;
}

Action DisableFixTeam_Timer(Handle timer)
{
	bool mustFixTeams = MustFixTheTeams();
	DebugPrintAll("DisableFixTeam_Timer -> announcer=%d mustFix=%d", g_cvAnnouncer.BoolValue, mustFixTeams);

	if (g_cvAnnouncer.BoolValue && mustFixTeams)
	{
		PrintMissingPlayersToAll();
		CPrintToChatAll("%t %t", "Tag", "TeamsOrganizationFinished");
	}

	DisableFixTeam();

	if (mustFixTeams)
	{
		NormalizeSavedTeamsToActualRosters();
		NotifySafeToMovePlayers();
	}

	return Plugin_Continue;
}

void SaveTeams()
{
	ClearTeamsData();

	L4DTeam winnerTeam;
	L4DTeam loserTeam;
	GetSavedTeamTargets(winnerTeam, loserTeam);
	DebugPrintAll("SaveTeams -> winner=%d loser=%d secondHalf=%d", view_as<int>(winnerTeam), view_as<int>(loserTeam), InSecondHalfOfRound());

	winners.Capture(winnerTeam);
	losers.Capture(loserTeam);
	SanitizeSavedTeams();
	DebugPrintAll("SaveTeams -> winners=%d losers=%d", winners.Length, losers.Length);
}

void FixTeams()
{
	bool mustFixTeams = MustFixTheTeams();
	if (!mustFixTeams)
	{
		DebugPrintAll("FixTeams -> skipped enabled=%d fix=%d empty=%d", g_cvEnabled.BoolValue, g_bFixTeam, TeamsDataIsEmpty());
		return;
	}

	DebugPrintAll("FixTeams -> starting winners=%d losers=%d", winners.Length, losers.Length);

	L4DTeam winnerTeam;
	L4DTeam losersTeam;
	GetSavedTeamTargets(winnerTeam, losersTeam);
	DebugPrintAll("FixTeams -> current winner=%d loser=%d", view_as<int>(winnerTeam), view_as<int>(losersTeam));

	SanitizeSavedTeams();

	winners.MoveNonMembersToSpectator(winnerTeam);
	losers.MoveNonMembersToSpectator(losersTeam);

	winners.MoveSpectatorsToTeam(winnerTeam);
	losers.MoveSpectatorsToTeam(losersTeam);

	bool winnersInCorrectTeam = winners.IsEveryoneInTeam(winnerTeam);
	bool losersInCorrectTeam  = losers.IsEveryoneInTeam(losersTeam);
	DebugPrintAll("FixTeams -> winnersOk=%d losersOk=%d winnerCount=%d loserCount=%d", winnersInCorrectTeam, losersInCorrectTeam, NumberOfPlayersInTheTeam(winnerTeam), NumberOfPlayersInTheTeam(losersTeam));

	if (!winnersInCorrectTeam || !losersInCorrectTeam)
	{
		DebugPrintAll("FixTeams -> still pending");
		return;
	}

	bool winnersWithinLimit = EnforceTeamLimit(winnerTeam);
	bool losersWithinLimit  = EnforceTeamLimit(losersTeam);
	if (!winnersWithinLimit || !losersWithinLimit)
	{
		DebugPrintAll("FixTeams -> overflow corrected winnerWithinLimit=%d loserWithinLimit=%d", winnersWithinLimit, losersWithinLimit);
		return;
	}

	DebugPrintAll("FixTeams -> teams placed, keeping organization window active");
}

bool HandleBlockedTeamJoinAttempt(int client, L4DTeam team, L4DTeam oldTeam)
{
	if (ClientBelongsToTeamList(client, team))
		return false;

	DebugPrintAll("BlockedJoin -> client=%N requested=%d oldteam=%d saved=%d", client, view_as<int>(team), view_as<int>(oldTeam), winners.ContainsClient(client) || losers.ContainsClient(client));
	Call_StartForward(g_fwdBlockedJoin);
	Call_PushCell(client);
	Call_PushCell(view_as<int>(team));
	Call_PushCell(view_as<int>(oldTeam));
	Call_Finish();
	MovePlayerToTeam(client, L4DTeam_Spectator);
	CreateTimer(0.0, ReSpec_Timer, GetClientUserId(client));
	DebugVerifyTeamNextFrame(client, L4DTeam_Spectator, "BlockedJoin");

	bool isSuppressedByAutoAssign = IsBlockedJoinWarningSuppressed(client);
	bool shouldAnnounce = g_cvAnnouncer.BoolValue && oldTeam != L4DTeam_Unassigned && !isSuppressedByAutoAssign;
	if (isSuppressedByAutoAssign)
		DebugPrintAll("BlockedJoin -> warning suppressed for %N due auto-assign chain", client);

	if (!shouldAnnounce)
		return true;

	CPrintToChat(client, "%t %t", "Tag", "WrongTeamDuringOrganization");

	PrintMissingPlayers(client, team, false);

	return true;
}

bool ClientBelongsToTeamList(int client, L4DTeam team)
{
	TeamSnapshot snapshot = GetSnapshotForTeam(team);
	return snapshot != view_as<TeamSnapshot>(null) && snapshot.ContainsClient(client);
}

L4DTeam GetWinnerTeam()
{
	return SurvivorsAreWinning() ? L4DTeam_Survivor : L4DTeam_Infected;
}

int FindClientByAccountID(int accountId)
{
	if (accountId <= 0)
		return 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client))
			continue;

		if (GetSteamAccountID(client) == accountId)
		{
			DebugPrintAll("FindClientByAccountID -> account=%d client=%N", accountId, client);
			return client;
		}
	}

	DebugPrintAll("FindClientByAccountID -> account=%d missing", accountId);
	return 0;
}

void SaveClientName(int client)
{
	int accountId = GetSteamAccountID(client);
	if (accountId <= 0)
		return;

	char key[16];
	char name[MAX_NAME_LENGTH];
	IntToString(accountId, key, sizeof(key));
	GetClientName(client, name, sizeof(name));
	g_smSavedPlayerNames.SetString(key, name);
	DebugPrintAll("SaveClientName -> client=%N account=%d", client, accountId);
}

bool GetSavedPlayerName(int accountId, char[] buffer, int maxlen)
{
	char key[16];
	IntToString(accountId, key, sizeof(key));
	return g_smSavedPlayerNames.GetString(key, buffer, maxlen);
}

void PrintMissingPlayersToAll()
{
	L4DTeam winnerTeam;
	L4DTeam loserTeam;
	GetSavedTeamTargets(winnerTeam, loserTeam);
	PrintMissingPlayers(0, winnerTeam, true);
	PrintMissingPlayers(0, loserTeam, true);
}

bool BuildMissingPlayersList(TeamSnapshot snapshot, L4DTeam team, char[] buffer, int maxlen)
{
	return snapshot != view_as<TeamSnapshot>(null) && snapshot.BuildMissingPlayersList(team, buffer, maxlen);
}

bool EnsureClientStaysSpectator(int userId, const char[] source, bool allowSpectateCommand)
{
	int client = GetClientOfUserId(userId);
	if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
	{
		DebugPrintAll("%s -> userid=%d missing", source, userId);
		return false;
	}

	bool inWinners = winners.ContainsClient(client);
	bool inLosers  = losers.ContainsClient(client);
	DebugPrintAll("%s -> client=%N userid=%d team=%d inWinners=%d inLosers=%d", source, client, userId, view_as<int>(L4D_GetClientTeam(client)), inWinners, inLosers);

	if (inWinners || inLosers || !MustFixTheTeams())
		return false;

	if (L4D_GetClientTeam(client) == L4DTeam_Spectator)
	{
		if (allowSpectateCommand)
			FakeClientCommand(client, "sm_spectate");

		return allowSpectateCommand;
	}

	DebugPrintAll("%s -> retrying spectator for %N team=%d", source, client, view_as<int>(L4D_GetClientTeam(client)));
	ForcePlayerToSpectator(client, source);
	return true;
}

void PrintMissingPlayers(int client, L4DTeam team, bool toAll)
{
	TeamSnapshot snapshot = GetSnapshotForTeam(team);
	if (snapshot == view_as<TeamSnapshot>(null))
		return;

	char missingNames[192];
	if (!BuildMissingPlayersList(snapshot, team, missingNames, sizeof(missingNames)))
		return;

	char phrase[48];
	if (toAll)
		strcopy(phrase, sizeof(phrase), team == L4DTeam_Survivor ? "MissingSurvivorsAfterOrganization" : "MissingInfectedAfterOrganization");
	else
		strcopy(phrase, sizeof(phrase), team == L4DTeam_Survivor ? "WaitingForSurvivorsList" : "WaitingForInfectedList");

	if (toAll)
		CPrintToChatAll("%t %t", "Tag", phrase, missingNames);
	else if (client > 0)
		CPrintToChat(client, "%t %t", "Tag", phrase, missingNames);
}

void NotifySafeToMovePlayers()
{
	int count = BuildAbandonedPlayersCache();
	DebugPrintAll("NotifySafeToMovePlayers -> count=%d", count);
	Call_StartForward(g_fwdSafeToMovePlayers);
	Call_PushCell(count);
	Call_Finish();
}

int BuildAbandonedPlayersCache()
{
	ClearAbandonedPlayersCache();
	CacheAbandonedPlayersFromSavedTeams();
	DebugPrintAll("BuildAbandonedPlayersCache -> count=%d", g_aAbandonedAccountIds.Length);
	return g_aAbandonedAccountIds.Length;
}

void CacheAbandonedPlayersFromSavedTeams()
{
	L4DTeam winnerTeam;
	L4DTeam loserTeam;
	GetSavedTeamTargets(winnerTeam, loserTeam);
	CacheAbandonedPlayersFromSnapshot(winners, winnerTeam);
	CacheAbandonedPlayersFromSnapshot(losers, loserTeam);
}

void CacheAbandonedPlayersFromSnapshot(TeamSnapshot snapshot, L4DTeam team)
{
	if (snapshot != view_as<TeamSnapshot>(null))
		snapshot.CacheAbandonedPlayers(team);
}

void ClearAbandonedPlayersCache()
{
	DebugPrintAll("ClearAbandonedPlayersCache -> ids=%d teams=%d names=%d", g_aAbandonedAccountIds.Length, g_aAbandonedTeams.Length, g_aAbandonedNames.Length);
	g_aAbandonedAccountIds.Clear();
	g_aAbandonedTeams.Clear();
	g_aAbandonedNames.Clear();
}

L4DTeam GetLoserTeam()
{
	return SurvivorsAreWinning() ? L4DTeam_Infected : L4DTeam_Survivor;
}

void GetSavedTeamTargets(L4DTeam &winnerTeam, L4DTeam &loserTeam)
{
	winnerTeam = GetWinnerTeam();
	loserTeam  = GetLoserTeam();
}

TeamSnapshot GetSnapshotForTeam(L4DTeam team)
{
	if (team == GetWinnerTeam())
		return winners;

	if (team == GetLoserTeam())
		return losers;

	return view_as<TeamSnapshot>(null);
}

bool SurvivorsAreWinning()
{
	int flipped		  = GameRules_GetProp("m_bAreTeamsFlipped");

	int survivorIndex = flipped ? 1 : 0;
	int infectedIndex = flipped ? 0 : 1;

	int survivorScore = L4D2Direct_GetVSCampaignScore(survivorIndex);
	int infectedScore = L4D2Direct_GetVSCampaignScore(infectedIndex);

	return survivorScore >= infectedScore;
}

bool MustFixTheTeams()
{
	return g_cvEnabled.BoolValue && g_bFixTeam && !TeamsDataIsEmpty();
}

void EnableFixTeam()
{
	bool wasActive = g_bFixTeam;
	g_bFixTeam	   = true;
	DebugPrintAll("EnableFixTeam -> fixTeam=1");

	if (!wasActive)
	{
		Call_StartForward(g_fwdOrganizationStart);
		Call_Finish();
	}
}

void DisableFixTeam()
{
	bool wasActive = g_bFixTeam;
	g_bFixTeam	   = false;
	DebugPrintAll("DisableFixTeam -> fixTeam=0");

	if (wasActive)
	{
		Call_StartForward(g_fwdOrganizationEnd);
		Call_Finish();
	}
}

void ClearTeamsData()
{
	DebugPrintAll("ClearTeamsData -> winners=%d losers=%d", winners.Length, losers.Length);
	winners.Clear();
	losers.Clear();
	ClearAbandonedPlayersCache();
	ResetBlockedJoinWarningSuppression();
}

void ResetBlockedJoinWarningSuppression()
{
	for (int client = 1; client <= MaxClients; client++)
		g_iSuppressBlockedJoinWarningsLeft[client] = 0;
}

bool IsBlockedJoinWarningSuppressed(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;

	if (g_iSuppressBlockedJoinWarningsLeft[client] <= 0)
		return false;

	g_iSuppressBlockedJoinWarningsLeft[client]--;
	return true;
}

bool TeamsDataIsEmpty()
{
	return winners.Length == 0 && losers.Length == 0;
}

bool IsNewGame()
{
	int teamAScore = L4D2Direct_GetVSCampaignScore(0);
	int teamBScore = L4D2Direct_GetVSCampaignScore(1);

	return teamAScore == 0 && teamBScore == 0;
}

bool InSecondHalfOfRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

void DebugVerifyTeamNextFrame(int client, L4DTeam expectedTeam, const char[] source)
{
	if (!g_cvDebug.BoolValue || client <= 0 || client > MaxClients)
		return;

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(view_as<int>(expectedTeam));
	pack.WriteString(source);
	RequestFrame(DebugVerifyTeamNextFrame_Frame, pack);
}

void DebugVerifyTeamNextFrame_Frame(DataPack pack)
{
	pack.Reset();

	int		userId		 = pack.ReadCell();
	L4DTeam expectedTeam = view_as<L4DTeam>(pack.ReadCell());
	char	source[32];
	pack.ReadString(source, sizeof(source));
	delete pack;

	int client = GetClientOfUserId(userId);
	if (client <= 0 || !IsClientInGame(client))
	{
		DebugPrintAll("VerifyTeamNextFrame -> source=%s userid=%d missing", source, userId);
		return;
	}

	DebugPrintAll("VerifyTeamNextFrame -> source=%s client=%N expected=%d actual=%d", source, client, view_as<int>(expectedTeam), view_as<int>(L4D_GetClientTeam(client)));
}

void MovePlayerToTeam(int client, L4DTeam team)
{
	if (!IsRealClientInGame(client))
	{
		DebugPrintAll("MovePlayerToTeam -> skipped invalid client=%d target=%d", client, view_as<int>(team));
		return;
	}

	// No need to check multiple times if we're trying to move a player to a possibly full team.
	if (team != L4DTeam_Spectator && NumberOfPlayersInTheTeam(team) >= TeamSize(team))
	{
		DebugPrintAll("MovePlayerToTeam -> skipped full client=%N current=%d target=%d", client, view_as<int>(L4D_GetClientTeam(client)), view_as<int>(team));
		return;
	}

	DebugPrintAll("MovePlayerToTeam -> client=%N current=%d target=%d", client, view_as<int>(L4D_GetClientTeam(client)), view_as<int>(team));

	if (team == L4DTeam_Survivor)
	{
		int bot = FindSurvivorBot();
		if (bot > 0)
		{
			DebugPrintAll("MovePlayerToTeam -> survivor bot found client=%N bot=%N", client, bot);
			ChangeClientTeam(client, view_as<int>(L4DTeam_Unassigned));
			if (L4D_SetHumanSpec(bot, client) && L4D_TakeOverBot(client))
			{
				DebugPrintAll("MovePlayerToTeam -> %N took over survivor bot %N", client, bot);
				return;
			}

			DebugPrintAll("MovePlayerToTeam -> native takeover failed for %N bot=%d, falling back", client, bot);
			FakeClientCommand(client, "jointeam 2");
			DebugPrintAll("MovePlayerToTeam -> fallback jointeam 2 for %N", client);
			return;
		}

		FakeClientCommand(client, "jointeam 2");
		DebugPrintAll("MovePlayerToTeam -> jointeam 2 no bot for %N", client);
		return;
	}

	switch (team)
	{
		case L4DTeam_Spectator:
		{
			L4D_ChangeClientTeam(client, L4DTeam_Spectator);
			DebugPrintAll("MovePlayerToTeam -> moved %N to spectator", client);
			return;
		}

		case L4DTeam_Infected:
		{
			L4D_ChangeClientTeam(client, L4DTeam_Infected);
			DebugPrintAll("MovePlayerToTeam -> moved %N to infected", client);
			return;
		}
	}
}

int FindSurvivorBot()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsFakeClient(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor)
		{
			DebugPrintAll("FindSurvivorBot -> bot=%N", client);
			return client;
		}
	}

	DebugPrintAll("FindSurvivorBot -> none");
	return 0;
}

int NumberOfPlayersInTheTeam(L4DTeam team)
{
	int count = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != team)
			continue;

		count++;
	}

	DebugPrintAll("NumberOfPlayersInTheTeam -> team=%d count=%d", view_as<int>(team), count);
	return count;
}

int TeamSize(L4DTeam team)
{
	switch (team)
	{
		case L4DTeam_Survivor:
			return g_cvSurvivorLimit != null ? g_cvSurvivorLimit.IntValue : 4;
		case L4DTeam_Infected:
			return g_cvInfectedLimit != null ? g_cvInfectedLimit.IntValue : 4;
	}

	return MaxClients;
}

void SanitizeSavedTeams()
{
	L4DTeam winnerTeam;
	L4DTeam loserTeam;
	GetSavedTeamTargets(winnerTeam, loserTeam);
	SanitizeSnapshotForTeam(winners, winnerTeam);
	SanitizeSnapshotForTeam(losers, loserTeam);
}

void SanitizeSnapshotForTeam(TeamSnapshot snapshot, L4DTeam team)
{
	if (snapshot == view_as<TeamSnapshot>(null))
		return;

	int teamLimit = TeamSize(team);
	if (teamLimit < 1)
		return;

	while (snapshot.Length > teamLimit)
	{
		int indexToRemove = SelectSnapshotRemovalIndex(snapshot, team);
		int accountId = snapshot.Get(indexToRemove);
		char playerName[MAX_NAME_LENGTH];
		if (!GetSavedPlayerName(accountId, playerName, sizeof(playerName)))
			Format(playerName, sizeof(playerName), "ID %d", accountId);

		DebugPrintAll("SanitizeSnapshot -> team=%d limit=%d removing=%s account=%d index=%d", view_as<int>(team), teamLimit, playerName, accountId, indexToRemove);
		snapshot.Erase(indexToRemove);
	}
}

int SelectSnapshotRemovalIndex(TeamSnapshot snapshot, L4DTeam team)
{
	int fallbackIndex = snapshot.Length - 1;

	for (int i = snapshot.Length - 1; i >= 0; i--)
	{
		int client = FindClientByAccountID(snapshot.Get(i));
		if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
			return i;
	}

	for (int i = snapshot.Length - 1; i >= 0; i--)
	{
		int client = FindClientByAccountID(snapshot.Get(i));
		if (client <= 0 || L4D_GetClientTeam(client) != team)
			return i;
	}

	return fallbackIndex;
}

void NormalizeSavedTeamsToActualRosters()
{
	L4DTeam winnerTeam;
	L4DTeam loserTeam;
	GetSavedTeamTargets(winnerTeam, loserTeam);
	NormalizeSnapshotToActualTeam(winners, winnerTeam);
	NormalizeSnapshotToActualTeam(losers, loserTeam);
}

void NormalizeSnapshotToActualTeam(TeamSnapshot snapshot, L4DTeam team)
{
	if (snapshot != view_as<TeamSnapshot>(null))
		snapshot.NormalizeToActualTeam(team);
}

bool EnforceTeamLimit(L4DTeam team)
{
	int teamLimit = TeamSize(team);
	int teamCount = NumberOfPlayersInTheTeam(team);
	if (team == L4DTeam_Spectator || teamLimit < 1 || teamCount <= teamLimit)
		return true;

	DebugPrintAll("EnforceTeamLimit -> team=%d count=%d limit=%d", view_as<int>(team), teamCount, teamLimit);

	TeamSnapshot snapshot = GetSnapshotForTeam(team);

	for (int client = MaxClients; client >= 1 && teamCount > teamLimit; client--)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != team)
			continue;

		bool isExpectedMember = snapshot != view_as<TeamSnapshot>(null) && snapshot.ContainsClient(client);
		if (isExpectedMember)
			continue;

		ForcePlayerToSpectator(client, "EnforceTeamLimitUnexpected");
		teamCount = NumberOfPlayersInTheTeam(team);
	}

	for (int client = MaxClients; client >= 1 && teamCount > teamLimit; client--)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || L4D_GetClientTeam(client) != team)
			continue;

		ForcePlayerToSpectator(client, "EnforceTeamLimitOverflow");
		teamCount = NumberOfPlayersInTheTeam(team);
	}

	teamCount = NumberOfPlayersInTheTeam(team);
	return teamCount <= teamLimit;
}

void ForcePlayerToSpectator(int client, const char[] source)
{
	DebugPrintAll("%s -> moving %N from=%d to=%d", source, client, view_as<int>(L4D_GetClientTeam(client)), view_as<int>(L4DTeam_Spectator));
	MovePlayerToTeam(client, L4DTeam_Spectator);
	DebugVerifyTeamNextFrame(client, L4DTeam_Spectator, source);
}

void DebugPrintAll(const char[] format, any...)
{
	if (!g_cvDebug.BoolValue)
		return;

	char message[192];
	VFormat(message, sizeof(message), format, 2);
	LogMessage("[ShuffleDebug] %s", message);
}

int Native_IsOrganizationActive(Handle plugin, int numParams)
{
	return MustFixTheTeams();
}

int Native_HasSavedTeam(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsRealClientInGame(client))
		return false;

	return winners.ContainsClient(client) || losers.ContainsClient(client);
}

int Native_GetSavedTeam(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsRealClientInGame(client))
		return view_as<int>(L4DTeam_Unassigned);

	if (winners.ContainsClient(client))
		return view_as<int>(GetWinnerTeam());

	if (!losers.ContainsClient(client))
		return view_as<int>(L4DTeam_Unassigned);

	return view_as<int>(GetLoserTeam());
}

int Native_IsClientBlocked(Handle plugin, int numParams)
{
	int		client = GetNativeCell(1);
	L4DTeam team   = view_as<L4DTeam>(GetNativeCell(2));

	if (!IsRealClientInGame(client))
		return false;

	if (!MustFixTheTeams())
		return false;

	if (team == L4DTeam_Unassigned || team == L4DTeam_Spectator)
		return false;

	return !ClientBelongsToTeamList(client, team);
}

int Native_GetAbandonedPlayerCount(Handle plugin, int numParams)
{
	return g_aAbandonedAccountIds.Length;
}

int Native_FillAbandonedPlayers(Handle plugin, int numParams)
{
	KeyValues kv = view_as<KeyValues>(GetNativeCell(1));
	if (kv == null)
		return ThrowNativeError(SP_ERROR_NATIVE, "KeyValues handle cannot be null");

	int abandonedCount = g_aAbandonedAccountIds.Length;
	kv.Rewind();
	kv.DeleteKey("abandoned_players");
	kv.JumpToKey("abandoned_players", true);
	kv.SetNum("count", abandonedCount);

	char indexKey[12];
	char playerName[MAX_NAME_LENGTH];

	for (int i = 0; i < abandonedCount; i++)
	{
		IntToString(i, indexKey, sizeof(indexKey));
		kv.JumpToKey(indexKey, true);
		kv.SetNum("account_id", g_aAbandonedAccountIds.Get(i));
		kv.SetNum("expected_team", g_aAbandonedTeams.Get(i));
		g_aAbandonedNames.GetString(i, playerName, sizeof(playerName));
		kv.SetString("name", playerName);
		kv.GoBack();
	}

	kv.GoBack();
	kv.Rewind();
	return abandonedCount;
}

bool IsRealClientInGame(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}
