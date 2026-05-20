#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.3"

#include <sourcemod>
#include <sdktools>

static const int L4D_VOTE_TEAM_ALL = -1;
static const int L4D2_VOTE_TEAM_ALL = 255;
static const int TEAM_SPECTATOR = 1;
static const int TEAM_SURVIVOR = 2;
static const int TEAM_INFECTED = 3;

int g_iVoteEntity = INVALID_ENT_REFERENCE;
int g_iVoteTeamAll = 0;
bool g_bVotePoolFixTriggered = false;
bool g_bIsLeft4Dead1 = false;

public Plugin myinfo =
{
	name = "[L4D & L4D2] Vote Poll Fix",
	author = "raziEiL [disawar1]",
	description = "Changes number of players eligible to vote",
	version = PLUGIN_VERSION,
	url = "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (late)
		PrepareToFindVoteEnt();

	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_votepoll_fix_version", PLUGIN_VERSION, "Vote Poll Fix plugin version.", FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_DONTRECORD);

	char gameFolder[32];
	GetGameFolderName(gameFolder, sizeof(gameFolder));

	g_bIsLeft4Dead1 = StrEqual(gameFolder, "left4dead");
	if (g_bIsLeft4Dead1)
	{
		g_iVoteTeamAll = L4D_VOTE_TEAM_ALL;
		HookEvent("vote_started", Event_VoteStarted, EventHookMode_Pre);
	}
	else
	{
		g_iVoteTeamAll = L4D2_VOTE_TEAM_ALL;
		HookUserMessage(GetUserMessageId("VoteStart"), Message_OnVoteStart);
	}

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	AddCommandListener(Command_Vote, "vote");
}

public void OnPluginEnd()
{
	RemoveCommandListener(Command_Vote, "vote");
	UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	if (g_bIsLeft4Dead1)
		UnhookEvent("vote_started", Event_VoteStarted, EventHookMode_Pre);

	g_iVoteEntity = INVALID_ENT_REFERENCE;
	g_bVotePoolFixTriggered = false;
}

public Action Command_Vote(int client, const char[] command, int argc)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Continue;

	if (g_bVotePoolFixTriggered && GetClientTeam(client) == TEAM_SPECTATOR)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	PrepareToFindVoteEnt();
	return Plugin_Continue;
}

public Action Event_VoteStarted(Event event, const char[] name, bool dontBroadcast)
{
	PrepareToFix(event.GetInt("team"), event.GetInt("initiator"));
	return Plugin_Continue;
}

public Action Message_OnVoteStart(UserMsg msgId, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	int team = bf.ReadByte();
	int client = bf.ReadByte();

	PrepareToFix(team, client);
	return Plugin_Continue;
}

void PrepareToFix(int team, int client)
{
	int polls = 0;
	if (IsValidInitiator(client)
		&& IsValidVoteEnt()
		&& IsAnyoneSpectator()
		&& ((team == g_iVoteTeamAll && (polls = GetTotalPlayers()) > 0) || (polls = GetTeammateCount(team)) > 0))
	{
		g_bVotePoolFixTriggered = true;
		SetEntProp(g_iVoteEntity, Prop_Send, "m_potentialVotes", polls);
	}
	else
	{
		g_bVotePoolFixTriggered = false;
	}
}

void PrepareToFindVoteEnt()
{
	if (!IsValidVoteEnt())
		CreateTimer(0.5, Timer_FindVoteControllerEnt, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FindVoteControllerEnt(Handle timer)
{
	g_iVoteEntity = EntIndexToEntRef(FindEntityByClassname(-1, "vote_controller"));
	return Plugin_Stop;
}

int GetTotalPlayers()
{
	int players = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) > TEAM_SPECTATOR && !IsFakeClient(client))
			players++;
	}

	return players;
}

int GetTeammateCount(int team)
{
	if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
		return 0;

	int teammates = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team && !IsFakeClient(client))
			teammates++;
	}

	return teammates;
}

bool IsValidInitiator(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) != TEAM_SPECTATOR;
}

bool IsValidVoteEnt()
{
	return EntRefToEntIndex(g_iVoteEntity) != INVALID_ENT_REFERENCE;
}

bool IsAnyoneSpectator()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR && !IsFakeClient(client))
			return true;
	}

	return false;
}
