#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <builtinvotes>
#include <colors>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define TEAM_SPECTATE	1
#define MATCHMODES_PATH "configs/matchmodes.txt"
#define PATCH_DEBUG		"logs/matchmodes.log"

enum MatchVoteType
{
	MatchVote_Load = 0,
	MatchVote_Change,
	MatchVote_Reset
}

enum MatchVoteAccessType
{
	MatchVoteAccess_Menu = 0,
	MatchVoteAccess_Execute
}

Handle
	g_hVote;

GlobalForward
	g_gfCanAccessConfig;

KeyValues
	g_kvModesKV;

ConVar
	g_cvDebug,
	g_cvEnabled,
	g_cvPlayerLimit,
	g_cvMaxPlayers,
	g_cvSvMaxplayers;

int g_iDefaultMaxPlayers;

char
	g_sCfg[64];

bool
	g_bLateload,
	g_bConfogl,

	g_bOnSet,
	g_bShutdown;

MatchVoteType g_eMenuAccessType[MAXPLAYERS + 1];

char g_sLogPath[PLATFORM_MAX_PATH];

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/
public Plugin myinfo =
{
	name		= "Match Vote",
	author		= "vintik, Sir, StarterX4",
	description = "!match !rmatch !chmatch - Change Hostname and Slots while you're at it!",
	version		= "1.4",
	url			= "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	RegPluginLibrary("match_vote");

	CreateNative("MatchVote_ShowMenu", Native_ShowMenu);
	CreateNative("MatchVote_StartVote", Native_StartVote);
	CreateNative("MatchVote_StartResetVote", Native_StartResetVote);
	CreateNative("MatchVote_ConfigExists", Native_ConfigExists);
	CreateNative("MatchVote_GetConfigDisplayName", Native_GetConfigDisplayName);
	CreateNative("MatchVote_GetConfigNum", Native_GetConfigNum);
	CreateNative("MatchVote_GetConfigString", Native_GetConfigString);

	g_gfCanAccessConfig = new GlobalForward("MatchVote_OnCanAccessConfig", ET_Hook, Param_Cell, Param_String, Param_Cell, Param_Cell);

	g_bLateload = bLate;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bConfogl = LibraryExists("confogl");
}

public void OnLibraryRemoved(const char[] sPluginName)
{
	if (StrEqual(sPluginName, "confogl"))
		g_bConfogl = false;
}

public void OnLibraryAdded(const char[] sPluginName)
{
	if (StrEqual(sPluginName, "confogl"))
		g_bConfogl = true;
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), PATCH_DEBUG);

	char configPath[PLATFORM_MAX_PATH];
	g_kvModesKV = new KeyValues("MatchModes");
	BuildPath(Path_SM, configPath, sizeof(configPath), MATCHMODES_PATH);

	if (!g_kvModesKV.ImportFromFile(configPath))
		SetFailState("Couldn't load matchmodes.txt!");

	vLoadTranslation("match_vote.phrases");

	g_cvDebug		= CreateConVar("match_vote_debug", "0", "Enable match vote debug logging", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvEnabled		= CreateConVar("sm_match_vote_enabled", "1", "Plugin enabled", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvMaxPlayers	= CreateConVar("mv_maxplayers", "-1", "How many slots should the server use at config load/unload? Use -1 to keep the default sv_maxplayers.", FCVAR_NONE, true, -1.0, true, 32.0);
	g_cvPlayerLimit = CreateConVar("sm_match_player_limit", "1", "Minimum # of players in game to start the vote", FCVAR_NONE, true, 1.0, true, 32.0);

	RegConsoleCmd("sm_match", OnMatchRequest);
	RegConsoleCmd("sm_chmatch", OnChangeMatchRequest);
	RegConsoleCmd("sm_rmatch", OnMatchReset);

	AddCommandListener(OnQuitCommand, "quit");
	AddCommandListener(OnQuitCommand, "_restart");
	AddCommandListener(OnQuitCommand, "crash");

	g_cvSvMaxplayers = FindConVar("sv_maxplayers");
	
	AutoExecConfig(true, "match_vote");
	if (!g_bLateload)
		return;

	g_bConfogl = LibraryExists("confogl");
}

Action OnMatchRequest(int client, int args)
{
	LogDebug("OnMatchRequest called by client %N with args %d", client, args);

	if (!bCanHandleClientCommand(client, "OnMatchRequest"))
		return Plugin_Handled;

	bool bUseChangeFlow = LGO_IsMatchModeLoaded();

	if (bUseChangeFlow)
		LogDebug("OnMatchRequest: Match mode already loaded, rerouting to change flow while keeping load restrictions");

	if (args > 0)
	{
		char config[64], displayName[64];
		GetCmdArg(1, config, sizeof(config));
		LogDebug("OnMatchRequest: Received config argument '%s'", config);

		if (bFindConfigName(config, displayName, sizeof(displayName)))
		{
			LogDebug("OnMatchRequest: Config '%s' found with name '%s'", config, displayName);
			bStartVoteByTypesResolved(client, config, displayName, bUseChangeFlow ? MatchVote_Change : MatchVote_Load, MatchVote_Load, true);
			return Plugin_Handled;
		}
	}

	LogDebug("OnMatchRequest: Displaying %s menu to client %N", bUseChangeFlow ? "change" : "load", client);
	if (bUseChangeFlow)
		vShowChangeMatchModeMenu(client, MatchVote_Load);
	else
		vShowLoadMatchModeMenu(client, MatchVote_Load);
	return Plugin_Handled;
}

Action OnChangeMatchRequest(int client, int args)
{
	LogDebug("OnChangeMatchRequest called by client %N with args %d", client, args);

	if (!bCanHandleClientCommand(client, "OnChangeMatchRequest"))
		return Plugin_Handled;

	if (!LGO_IsMatchModeLoaded())
	{
		CPrintToChat(client, "%t %t", "Tag", "MatchNotLoaded");
		LogDebug("OnChangeMatchRequest: No match mode loaded");
		return Plugin_Handled;
	}

	if (args > 0)
	{
		char config[64], displayName[64];
		GetCmdArg(1, config, sizeof(config));
		LogDebug("OnChangeMatchRequest: Received config argument '%s'", config);

		if (bFindConfigName(config, displayName, sizeof(displayName)))
		{
			LogDebug("OnChangeMatchRequest: Config '%s' found with name '%s'", config, displayName);
			bStartVoteByTypesResolved(client, config, displayName, MatchVote_Change, MatchVote_Load, true);
			return Plugin_Handled;
		}
	}

	LogDebug("OnChangeMatchRequest: Displaying change match mode menu to client %N", client);
	vShowChangeMatchModeMenu(client, MatchVote_Load);
	return Plugin_Handled;
}

Action OnMatchReset(int client, int args)
{
	LogDebug("OnMatchReset called by client %N with args %d", client, args);

	if (!bCanHandleClientCommand(client, "OnMatchReset"))
		return Plugin_Handled;

	if (!LGO_IsMatchModeLoaded())
	{
		CPrintToChat(client, "%t %t", "Tag", "MatchNotLoaded");
		LogDebug("OnMatchReset: No match mode loaded");
		return Plugin_Handled;
	}

	LogDebug("OnMatchReset: Starting reset match vote for client %N", client);
	bStartResetMatchVote(client);
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	if (!g_bOnSet)
	{
		g_iDefaultMaxPlayers = g_cvSvMaxplayers.IntValue;
		vApplyConfiguredMaxPlayers();
		g_bOnSet = true;
	}
}

public void OnPluginEnd()
{
	if (g_bShutdown)
		return;

	if (g_hVote != null)
	{
		delete g_hVote;
		g_hVote = null;
	}

	delete g_kvModesKV;
	delete g_gfCanAccessConfig;

	vApplyConfiguredMaxPlayers();
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

Action OnQuitCommand(int client, const char[] command, int argc)
{
	g_bShutdown = true;
	return Plugin_Continue;
}

void vApplyConfiguredMaxPlayers()
{
	if (g_cvSvMaxplayers == null)
		return;

	int configuredMaxPlayers = g_cvMaxPlayers.IntValue;
	if (configuredMaxPlayers < 0)
		configuredMaxPlayers = g_iDefaultMaxPlayers;

	g_cvSvMaxplayers.SetInt(configuredMaxPlayers);
}

bool bCanHandleClientCommand(int client, const char[] context)
{
	if (!g_cvEnabled.BoolValue)
	{
		if (client)
			CPrintToChat(client, "%t %t", "Tag", "Disabled");
		else
			CReplyToCommand(client, "%t %t", "Tag", "Disabled");

		LogDebug("%s: Plugin is disabled", context);
		return false;
	}

	if (!client)
	{
		CReplyToCommand(client, "%t %t", "Tag", "NoConsole");
		LogDebug("%s: Command called from console", context);
		return false;
	}

	if (!g_bConfogl)
	{
		CPrintToChat(client, "%t %t", "Tag", "ConfoglNotAvailable");
		LogDebug("%s: Confogl library not available", context);
		return false;
	}

	return true;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

void vDisplayMatchModeMenu(int client, MatchVoteType voteType, MatchVoteType accessVoteType)
{
	char title[64];
	Format(title, sizeof(title), "%t", "Title_Match");

	Menu menu;
	if (voteType == MatchVote_Load)
		menu = new Menu(HandleLoadModeMenu);
	else
		menu = new Menu(HandleChangeModeMenu);

	g_eMenuAccessType[client] = accessVoteType;
	menu.SetTitle(title);

	char groupName[64];
	g_kvModesKV.Rewind();

	if (g_kvModesKV.GotoFirstSubKey())
	{
		do
		{
			g_kvModesKV.GetSectionName(groupName, sizeof(groupName));
			menu.AddItem(groupName, groupName);
		}
		while (g_kvModesKV.GotoNextKey(false));
	}

	menu.Display(client, 20);
}

bool bDisplayConfigSelectionMenu(int client, const char[] groupName, MatchVoteType voteType, MatchVoteType accessVoteType)
{
	g_kvModesKV.Rewind();

	if (!g_kvModesKV.JumpToKey(groupName) || !g_kvModesKV.GotoFirstSubKey())
		return false;

	char title[64];
	Format(title, sizeof(title), "%t", "Title_Config", groupName);

	Menu menu;
	if (voteType == MatchVote_Load)
		menu = new Menu(HandleLoadConfigMenu);
	else
		menu = new Menu(HandleChangeConfigMenu);

	menu.SetTitle(title);

	char config[64], displayName[64];
	do
	{
		g_kvModesKV.GetSectionName(config, sizeof(config));
		g_kvModesKV.GetString("name", displayName, sizeof(displayName));

		if (!bCanClientAccessConfig(client, config, accessVoteType, MatchVoteAccess_Menu))
		{
			menu.AddItem(config, displayName, ITEMDRAW_DISABLED);
			continue;
		}

		menu.AddItem(config, displayName);
	}
	while (g_kvModesKV.GotoNextKey());

	menu.Display(client, 20);
	return true;
}

/**
 * Displays a menu to the client for selecting a match mode.
 *
 * @param client The client index to whom the menu will be displayed.
 */
void vShowLoadMatchModeMenu(int client, MatchVoteType accessVoteType = MatchVote_Load)
{
	vDisplayMatchModeMenu(client, MatchVote_Load, accessVoteType);
}

int HandleLoadModeMenu(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		char groupName[64];
		menu.GetItem(item, groupName, sizeof(groupName));

		if (!bDisplayConfigSelectionMenu(client, groupName, MatchVote_Load, g_eMenuAccessType[client]))
		{
			CPrintToChat(client, "%t %t", "Tag", "ConfigNotFound");
			vShowLoadMatchModeMenu(client, g_eMenuAccessType[client]);
		}
	}

	return 0;
}

int HandleLoadConfigMenu(Menu menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Select:
		{
			char config[64], displayName[64];

			menu.GetItem(item, config, sizeof(config), _, displayName, sizeof(displayName));
			bStartVoteByTypesResolved(client, config, displayName, MatchVote_Load, g_eMenuAccessType[client]);
		}
	}

	return 0;
}

bool bStartChangeMatchVote(int client, const char[] displayName)
{
	if (GetClientTeam(client) <= TEAM_SPECTATE)
	{
		CPrintToChat(client, "%t %t", "Tag", "NoSpec");
		return false;
	}

	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteInProgress", CheckBuiltinVoteDelay());
		return false;
	}

	int[] players = new int[MaxClients];
	int playerCount = 0;
	int connectingCount = iCollectEligiblePlayers(players, playerCount);

	if (playerCount < g_cvPlayerLimit.IntValue)
	{
		CPrintToChat(client, "%t %t", "Tag", "NotEnoughPlayers");
		return false;
	}

	if (connectingCount > 0)
	{
		CPrintToChat(client, "%t %t", "Tag", "PlayersConnecting");
		return false;
	}

	char title[64];
	Format(title, sizeof(title), "%T", "Title_ChangeConfogl", LANG_SERVER, displayName);

	g_hVote = CreateBuiltinVote(vVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hVote, title);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, vChMatchVoteResultHandler);
	DisplayBuiltinVote(g_hVote, players, playerCount, 20);

	return true;
}

void vChMatchVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				char votePassMessage[24];
				Format(votePassMessage, sizeof(votePassMessage), "%T", "VotePass_Changed", LANG_SERVER);

				DisplayBuiltinVotePass(vote, votePassMessage);
				ServerCommand("sm_forcechangematch %s", g_sCfg);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

void vShowChangeMatchModeMenu(int client, MatchVoteType accessVoteType = MatchVote_Load)
{
	vDisplayMatchModeMenu(client, MatchVote_Change, accessVoteType);
}

int HandleChangeModeMenu(Menu menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Select:
		{
			char groupName[64];
			menu.GetItem(item, groupName, sizeof(groupName));

			if (!bDisplayConfigSelectionMenu(client, groupName, MatchVote_Change, g_eMenuAccessType[client]))
			{
				CPrintToChat(client, "%t %t", "Tag", "ConfigNotFound");
				vShowChangeMatchModeMenu(client, g_eMenuAccessType[client]);
			}
		}
	}

	return 0;
}

int HandleChangeConfigMenu(Menu menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;

		case MenuAction_Select:
		{
			char config[64], displayName[64];

			menu.GetItem(item, config, sizeof(config), _, displayName, sizeof(displayName));

			if (!bStartVoteByTypesResolved(client, config, displayName, MatchVote_Change, g_eMenuAccessType[client]))
				vShowChangeMatchModeMenu(client, g_eMenuAccessType[client]);
		}
	}

	return 0;
}

/**
 * Initiates a match vote process for the given client and configuration name.
 *
 * @param client       The client index of the player initiating the vote.
 * @param displayName  The name of the configuration to be loaded if the vote passes.
 *
 * @return              True if the vote was successfully started, false otherwise.
 *
 * The function performs the following checks before starting the vote:
 * - Ensures the client is not in the spectator team.
 * - Ensures no other built-in vote is currently in progress.
 * - Ensures no players are currently connecting to the server.
 * - Ensures the number of active players meets the required player limit.
 *
 * If all conditions are met, a built-in yes/no vote is created and displayed to eligible players.
 * The vote result is handled by the `MatchVoteResultHandler` callback.
 */
bool bStartMatchVote(int client, const char[] displayName)
{
	if (GetClientTeam(client) <= TEAM_SPECTATE)
	{
		CPrintToChat(client, "%t %t", "Tag", "NoSpec");
		return false;
	}

	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteInProgress", CheckBuiltinVoteDelay());
		return false;
	}

	int[] players = new int[MaxClients];
	int playerCount = 0;
	int connectingCount = iCollectEligiblePlayers(players, playerCount);

	if (connectingCount > 0)
	{
		CPrintToChat(client, "%t %t", "Tag", "PlayersConnecting");
		return false;
	}

	if (playerCount < g_cvPlayerLimit.IntValue)
	{
		CPrintToChat(client, "%t %t", "Tag", "NotEnoughPlayers", playerCount, g_cvPlayerLimit.IntValue);
		return false;
	}

	char title[64];
	Format(title, sizeof(title), "%T", "Title_LoadConfig", LANG_SERVER, displayName);

	g_hVote = CreateBuiltinVote(vVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hVote, title);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, vMatchVoteResultHandler);
	DisplayBuiltinVote(g_hVote, players, playerCount, 20);
	return true;
}

void vMatchVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				char votePassMessage[64];
				Format(votePassMessage, sizeof(votePassMessage), "%T", "VotePass_Loading", LANG_SERVER);

				DisplayBuiltinVotePass(vote, votePassMessage);
				ServerCommand("sm_forcematch %s", g_sCfg);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

/**
 * Initiates a reset match vote for a given client.
 *
 * @param client The client index of the player initiating the vote.
 * @return True if the vote was successfully started, false otherwise.
 */
bool bStartResetMatchVote(int client)
{
	if (GetClientTeam(client) <= TEAM_SPECTATE)
	{
		CPrintToChat(client, "%t %t", "Tag", "NoSpec");
		return false;
	}

	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(client, "%t %t", "Tag", "VoteInProgress", CheckBuiltinVoteDelay());
		return false;
	}

	int[] players = new int[MaxClients];
	int playerCount = 0;
	int connectingCount = iCollectEligiblePlayers(players, playerCount);

	if (connectingCount > 0)
	{
		CPrintToChat(client, "%t %t", "Tag", "PlayersConnecting");
		return false;
	}

	char title[64];
	Format(title, sizeof(title), "%T", "Title_OffConfogl", LANG_SERVER);

	g_hVote = CreateBuiltinVote(vVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hVote, title);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, vResetMatchVoteResultHandler);
	DisplayBuiltinVote(g_hVote, players, playerCount, 20);

	FakeClientCommand(client, "Vote Yes");
	return true;
}

void vResetMatchVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				char votePassMessage[24];
				Format(votePassMessage, sizeof(votePassMessage), "%T", "VotePass_Unloading", LANG_SERVER);

				DisplayBuiltinVotePass(vote, votePassMessage);
				ServerCommand("sm_resetmatch");
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

void vVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			delete vote;
			g_hVote = null;
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

/**
 * Checks if a configuration name exists in the match modes keyvalues.
 *
 * @param config       The configuration name to search for.
 * @param displayName  The name of the configuration (output).
 * @param maxLength    The maximum length of the output name.
 * @return True if the configuration name is found, false otherwise.
 */
bool bFindConfigName(const char[] config, char[] displayName, const int maxLength)
{
	if (!bJumpToConfig(config))
		return false;

	g_kvModesKV.GetString("name", displayName, maxLength);
	return true;
}

bool bJumpToConfig(const char[] config)
{
	g_kvModesKV.Rewind();

	if (!g_kvModesKV.GotoFirstSubKey())
		return false;

	do
	{
		if (g_kvModesKV.JumpToKey(config))
			return true;
	}
	while (g_kvModesKV.GotoNextKey(false));

	return false;
}

bool bCanClientAccessConfig(int client, const char[] config, MatchVoteType voteType, MatchVoteAccessType accessType)
{
	Action aResult = Plugin_Continue;

	Call_StartForward(g_gfCanAccessConfig);
	Call_PushCell(client);
	Call_PushString(config);
	Call_PushCell(voteType);
	Call_PushCell(accessType);
	Call_Finish(aResult);

	return (aResult < Plugin_Handled);
}

bool bShowMenuForType(int client, MatchVoteType voteType)
{
	if (!IsClientInGame(client))
		return false;

	if (!g_cvEnabled.BoolValue || !g_bConfogl)
		return false;

	switch (voteType)
	{
		case MatchVote_Load:
		{
			if (LGO_IsMatchModeLoaded())
				return false;

			vShowLoadMatchModeMenu(client);
		}
		case MatchVote_Change:
		{
			if (!LGO_IsMatchModeLoaded())
				return false;

			vShowChangeMatchModeMenu(client, MatchVote_Load);
		}
		default:
			return false;
	}

	return true;
}

bool bStartVoteByType(int client, const char[] config, MatchVoteType voteType)
{
	if (!g_cvEnabled.BoolValue)
	{
		CPrintToChat(client, "%t %t", "Tag", "Disabled");
		return false;
	}

	if (!IsClientInGame(client))
		return false;

	if (!g_bConfogl)
	{
		CPrintToChat(client, "%t %t", "Tag", "ConfoglNotAvailable");
		return false;
	}

	if (voteType == MatchVote_Reset)
		return bStartResetMatchVote(client);

	char displayName[64];
	if (!bFindConfigName(config, displayName, sizeof(displayName)))
	{
		CPrintToChat(client, "%t %t", "Tag", "ConfigNotFound");
		return false;
	}

	return bStartVoteByTypeResolved(client, config, displayName, voteType, true);
}

bool bStartVoteByTypeResolved(int client, const char[] config, const char[] displayName, MatchVoteType voteType, bool bSkipContextChecks = false)
{
	return bStartVoteByTypesResolved(client, config, displayName, voteType, voteType == MatchVote_Change ? MatchVote_Load : voteType, bSkipContextChecks);
}

bool bStartVoteByTypesResolved(int client, const char[] config, const char[] displayName, MatchVoteType voteType, MatchVoteType accessVoteType, bool bSkipContextChecks = false)
{
	if (!bSkipContextChecks)
	{
		if (!g_cvEnabled.BoolValue)
		{
			CPrintToChat(client, "%t %t", "Tag", "Disabled");
			return false;
		}

		if (!IsClientInGame(client))
			return false;

		if (!g_bConfogl)
		{
			CPrintToChat(client, "%t %t", "Tag", "ConfoglNotAvailable");
			return false;
		}
	}

	if (!bCanClientAccessConfig(client, config, accessVoteType, MatchVoteAccess_Execute))
		return false;

	if (voteType == MatchVote_Load)
	{
		if (LGO_IsMatchModeLoaded())
		{
			CPrintToChat(client, "%t %t", "Tag", "MatchLoaded");
			return false;
		}

		if (!bStartMatchVote(client, displayName))
			return false;
	}
	else if (voteType == MatchVote_Change)
	{
		if (!LGO_IsMatchModeLoaded())
		{
			CPrintToChat(client, "%t %t", "Tag", "MatchNotLoaded");
			return false;
		}

		if (!bStartChangeMatchVote(client, displayName))
			return false;
	}

	strcopy(g_sCfg, sizeof(g_sCfg), config);
	FakeClientCommand(client, "Vote Yes");
	return true;
}

int Native_ShowMenu(Handle hPlugin, int iNumParams)
{
	return bShowMenuForType(GetNativeCell(1), view_as<MatchVoteType>(GetNativeCell(2)));
}

int Native_StartVote(Handle hPlugin, int iNumParams)
{
	char config[64];
	GetNativeString(2, config, sizeof(config));
	return bStartVoteByType(GetNativeCell(1), config, view_as<MatchVoteType>(GetNativeCell(3)));
}

int Native_StartResetVote(Handle hPlugin, int iNumParams)
{
	return bStartVoteByType(GetNativeCell(1), "", MatchVote_Reset);
}

int Native_ConfigExists(Handle hPlugin, int iNumParams)
{
	char config[64];
	GetNativeString(1, config, sizeof(config));
	return bJumpToConfig(config);
}

int Native_GetConfigDisplayName(Handle hPlugin, int iNumParams)
{
	char config[64], displayName[64];
	GetNativeString(1, config, sizeof(config));

	if (!bFindConfigName(config, displayName, sizeof(displayName)))
		return false;

	SetNativeString(2, displayName, GetNativeCell(3), true);
	return true;
}

int Native_GetConfigNum(Handle hPlugin, int iNumParams)
{
	char config[64], key[64];
	GetNativeString(1, config, sizeof(config));
	GetNativeString(2, key, sizeof(key));

	if (!bJumpToConfig(config))
		return GetNativeCell(3);

	return g_kvModesKV.GetNum(key, GetNativeCell(3));
}

int Native_GetConfigString(Handle hPlugin, int iNumParams)
{
	char config[64], key[64], value[128];
	GetNativeString(1, config, sizeof(config));
	GetNativeString(2, key, sizeof(key));

	if (!bJumpToConfig(config))
		return false;

	g_kvModesKV.GetString(key, value, sizeof(value));
	SetNativeString(3, value, GetNativeCell(4), true);
	return true;
}

/**
 * Check if the translation file exists
 *
 * @param translation	Translation name.
 * @noreturn
 */
void vLoadTranslation(const char[] translation)
{
	char
		path[PLATFORM_MAX_PATH],
		fileName[64];

	Format(fileName, sizeof(fileName), "translations/%s.txt", translation);
	BuildPath(Path_SM, path, sizeof(path), fileName);
	if (!FileExists(path))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}

/**
 * Processes the players in the game and populates the given array with their indices.
 *
 * @param players The array to store the indices of the players.
 * @param playerCount A reference to the variable that will hold the number of players.
 * @return The number of connected clients in the game.
 */
int iCollectEligiblePlayers(int[] players, int &playerCount)
{
	int connectingCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			if (IsClientConnected(i))
				connectingCount++;
		}
		else
		{
			if (!IsFakeClient(i) && GetClientTeam(i) > TEAM_SPECTATE)
				players[playerCount++] = i;
		}
	}

	return connectingCount;
}

/**
 * Logs a debug message to a specified log file.
 *
 * @param message    The format string for the debug message.
 * @param ...        Additional arguments to format into the message.
 */
void LogDebug(const char[] message, any...)
{
	if (g_cvDebug == null || !g_cvDebug.BoolValue)
		return;

	static char formattedMessage[1024];
	VFormat(formattedMessage, sizeof(formattedMessage), message, 2);
	LogToFileEx(g_sLogPath, "[Debug] %s", formattedMessage);
}
