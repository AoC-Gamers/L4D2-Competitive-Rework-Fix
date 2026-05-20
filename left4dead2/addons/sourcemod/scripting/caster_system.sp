#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_client>
#include <adminmenu>
#include <builtinvotes>
#include <colors>
#include <left4dhooks>
#include <steamidtools_stock>

enum eTypeAction
{
	kGet = 0,
	kSet = 1,
	kRem = 2
}

enum eTypeList
{
	kCaster = 0,
	kWhite	= 1,
}

StringMap
	g_smCaster,
	g_smWhitelist,
	g_smSpecImmunity;

ConVar
	g_cvAddonsEnable,
	g_cvDebug,
	g_cvKickSpecImmunity,
	g_cvSefRegEnable,
	g_cvWhitelistEnable;

int
	g_iDummy;

GlobalForward
	g_gfOnCaster,
	g_gfOffCaster;

TopMenu
	g_tmAdminMenu;

TopMenuObject
	g_tmoCasterCategory,
	g_tmoWhitelistCategory;

public Plugin g_myInfo = {
	name		= "L4D2 Caster System",
	author		= "CanadaRox, Forgetest, lechuga",
	description = "Standalone caster handler.",
	version		= "2.0",
	url			= "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrMax)
{
	g_gfOnCaster  = CreateGlobalForward("OnCaster", ET_Ignore, Param_Cell);
	g_gfOffCaster = CreateGlobalForward("OffCaster", ET_Ignore, Param_Cell);

	CreateNative("bCaster", iCasterNative);
	CreateNative("bCasterWhitelist", iWhitelistNative);
	CreateNative("bKickSpecImmunity", iImmunityNative);

	RegPluginLibrary("caster_system");
	return APLRes_Success;
}

public void OnPluginStart()
{
	vLoadTranslation("common.phrases");
	vLoadTranslation("caster_system.phrases");

	g_smCaster			 = new StringMap();
	g_smWhitelist		 = new StringMap();
	g_smSpecImmunity	 = new StringMap();

	g_cvDebug			 = CreateConVar("caster_debug", "0", "Enable caster system debug logging", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvWhitelistEnable	 = CreateConVar("caster_whitelist", "1", "Enable Whitelist, if deactivated, everyone will be able to register as a caster", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvSefRegEnable	 = CreateConVar("caster_selfreg", "1", "Enables self-registration, it is limited to the user being registered on the whitelist.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvKickSpecImmunity = CreateConVar("caster_kickspecs_immunity", "1", "Enable kick spec immunity", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAddonsEnable	 = CreateConVar("caster_addons", "1", "Enable caster addons", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAddonsEnable.AddChangeHook(vOnAddonsSettingChanged);

	RegAdminCmd("sm_caster", aCasterRegCmd, ADMFLAG_BAN, "Registers a player to the caster list");
	RegAdminCmd("sm_caster_ls", aCasterListCmd, ADMFLAG_BAN, "Prints the list of casters");
	RegAdminCmd("sm_caster_rm", aCasterRemoveCmd, ADMFLAG_BAN, "Removes a player from the caster list");
	RegAdminCmd("sm_caster_clear", aCasterClearCmd, ADMFLAG_BAN, "Clears the entire caster list");

	RegAdminCmd("sm_caster_wl", aWhitelistRegCmd, ADMFLAG_BAN, "Adds a player to the whitelist");
	RegAdminCmd("sm_caster_wl_ls", aWhitelistListCmd, ADMFLAG_BAN, "Prints the whitelist");
	RegAdminCmd("sm_caster_wl_rm", aWhitelistRemoveCmd, ADMFLAG_BAN, "Removes a player from the whitelist");
	RegAdminCmd("sm_caster_wl_clear", aWhitelistClearCmd, ADMFLAG_BAN, "Clears the entire whitelist");

	RegConsoleCmd("sm_cast", aSelfRegCastCmd, "Registers the calling player as a caster");
	RegConsoleCmd("sm_uncast", aSelfRemoveCastCmd, "Deregister yourself as a caster or allow admins to deregister other players");
	RegConsoleCmd("sm_kickspecs", aKickSpecsCmd, "Let's vote to kick those Spectators!");

	HookEvent("player_team", vPlayerTeamEvent);

	AutoExecConfig(true, "caster_system");
}

public void OnPluginEnd()
{
	UnhookEvent("player_team", vPlayerTeamEvent);

	if (g_cvAddonsEnable != null)
		g_cvAddonsEnable.RemoveChangeHook(vOnAddonsSettingChanged);

	delete g_smCaster;
	delete g_smWhitelist;
	delete g_smSpecImmunity;

	delete g_gfOnCaster;
	delete g_gfOffCaster;

	g_tmAdminMenu = null;
	g_tmoCasterCategory = INVALID_TOPMENUOBJECT;
	g_tmoWhitelistCategory = INVALID_TOPMENUOBJECT;
}

public void OnAdminMenuReady(Handle hTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(hTopMenu);
	if (topmenu == g_tmAdminMenu)
		return;

	g_tmAdminMenu = topmenu;
	g_tmoCasterCategory = g_tmAdminMenu.AddCategory("CasterSystemCaster", TopMenuHandler_CasterCategory, "sm_caster", ADMFLAG_BAN);
	g_tmoWhitelistCategory = g_tmAdminMenu.AddCategory("CasterSystemWhitelist", TopMenuHandler_WhitelistCategory, "sm_caster_wl", ADMFLAG_BAN);

	if (g_tmoCasterCategory != INVALID_TOPMENUOBJECT)
	{
		g_tmAdminMenu.AddItem("CasterRegister", TopMenuHandler_CasterRegister, g_tmoCasterCategory, "sm_caster", ADMFLAG_BAN);
		g_tmAdminMenu.AddItem("CasterList", TopMenuHandler_CasterList, g_tmoCasterCategory, "sm_caster_ls", ADMFLAG_BAN);
		g_tmAdminMenu.AddItem("CasterRemove", TopMenuHandler_CasterRemove, g_tmoCasterCategory, "sm_caster_rm", ADMFLAG_BAN);
		g_tmAdminMenu.AddItem("CasterClear", TopMenuHandler_CasterClear, g_tmoCasterCategory, "sm_caster_clear", ADMFLAG_BAN);
	}

	if (g_tmoWhitelistCategory != INVALID_TOPMENUOBJECT)
	{
		g_tmAdminMenu.AddItem("WhitelistRegister", TopMenuHandler_WhitelistRegister, g_tmoWhitelistCategory, "sm_caster_wl", ADMFLAG_BAN);
		g_tmAdminMenu.AddItem("WhitelistList", TopMenuHandler_WhitelistList, g_tmoWhitelistCategory, "sm_caster_wl_ls", ADMFLAG_BAN);
		g_tmAdminMenu.AddItem("WhitelistRemove", TopMenuHandler_WhitelistRemove, g_tmoWhitelistCategory, "sm_caster_wl_rm", ADMFLAG_BAN);
		g_tmAdminMenu.AddItem("WhitelistClear", TopMenuHandler_WhitelistClear, g_tmoWhitelistCategory, "sm_caster_wl_clear", ADMFLAG_BAN);
	}
}

void TopMenuHandler_CasterCategory(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayTitle:
			Format(buffer, maxlength, "Caster");
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "Caster");
	}
}

void TopMenuHandler_WhitelistCategory(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayTitle:
			Format(buffer, maxlength, "Whitelist");
		case TopMenuAction_DisplayOption:
			Format(buffer, maxlength, "Whitelist");
	}
}

void TopMenuHandler_CasterRegister(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	HandleTopMenuAction(action, param, buffer, maxlength, "Register", view_as<Function>(TopMenuSelect_CasterRegister));
}

void TopMenuHandler_CasterList(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	HandleTopMenuAction(action, param, buffer, maxlength, "List", view_as<Function>(TopMenuSelect_CasterList));
}

void TopMenuHandler_CasterRemove(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	HandleTopMenuAction(action, param, buffer, maxlength, "Remove", view_as<Function>(TopMenuSelect_CasterRemove));
}

void TopMenuHandler_CasterClear(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	HandleTopMenuAction(action, param, buffer, maxlength, "Clear", view_as<Function>(TopMenuSelect_CasterClear));
}

void TopMenuHandler_WhitelistRegister(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	HandleTopMenuAction(action, param, buffer, maxlength, "Register", view_as<Function>(TopMenuSelect_WhitelistRegister));
}

void TopMenuHandler_WhitelistList(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	HandleTopMenuAction(action, param, buffer, maxlength, "List", view_as<Function>(TopMenuSelect_WhitelistList));
}

void TopMenuHandler_WhitelistRemove(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	HandleTopMenuAction(action, param, buffer, maxlength, "Remove", view_as<Function>(TopMenuSelect_WhitelistRemove));
}

void TopMenuHandler_WhitelistClear(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	HandleTopMenuAction(action, param, buffer, maxlength, "Clear", view_as<Function>(TopMenuSelect_WhitelistClear));
}

void HandleTopMenuAction(TopMenuAction action, int client, char[] buffer, int maxlength, const char[] title, Function fnSelect)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "%s", title);
		}
		case TopMenuAction_SelectOption:
		{
			Call_StartFunction(INVALID_HANDLE, fnSelect);
			Call_PushCell(client);
			Call_Finish();
		}
	}
}

public void TopMenuSelect_CasterRegister(int client)
{
	vDisplayRegMenu(client, kCaster);
}

public void TopMenuSelect_CasterList(int client)
{
	aCasterListCmd(client, 0);
}

public void TopMenuSelect_CasterRemove(int client)
{
	vDisplayRemoveMenu(client, kCaster);
}

public void TopMenuSelect_CasterClear(int client)
{
	aCasterClearCmd(client, 0);
}

public void TopMenuSelect_WhitelistRegister(int client)
{
	vDisplayRegMenu(client, kWhite);
}

public void TopMenuSelect_WhitelistList(int client)
{
	aWhitelistListCmd(client, 0);
}

public void TopMenuSelect_WhitelistRemove(int client)
{
	vDisplayRemoveMenu(client, kWhite);
}

public void TopMenuSelect_WhitelistClear(int client)
{
	aWhitelistClearCmd(client, 0);
}

// ========================
//  Natives
// ========================

/**
 * @brief Add, checks or remove a user from the Casters list.
 *
 * @param eTypeAction   What action will be taken.
 * @param accountId     Steam AccountID.
 * @return              True if the client or AuthID is a caster (for Get action), false otherwise.
 */
int iCasterNative(Handle hPlugin, int iNumParams)
{
	int			accountId = GetNativeCell(1);
	eTypeAction eAction	  = GetNativeCell(2);

	DebugLog("[iCasterNative] accountId: %d | eTypeAction: %d", accountId, eAction);

	return HandleStringMapAccountIdAction(g_smCaster, accountId, eAction);
}

/**
 * @brief Add, checks or remove a user from the Casters whitelist.
 *
 * @param eTypeAction   What action will be taken.
 * @param accountId     Steam AccountID.
 * @return              True if the action was successful, false otherwise.
 */
int iWhitelistNative(Handle hPlugin, int iNumParams)
{
	int			accountId = GetNativeCell(1);
	eTypeAction eAction	  = GetNativeCell(2);

	DebugLog("[iWhitelistNative] accountId: %d | eTypeAction: %d", accountId, eAction);

	return HandleStringMapAccountIdAction(g_smWhitelist, accountId, eAction);
}

/**
 * @brief Add, checks or remove a user from the spectator immunity list.
 *
 * @param eTypeAction   What action will be taken.
 * @param accountId     Steam AccountID.
 * @return              True if the client has spectator immunity, false otherwise.
 */
int iImmunityNative(Handle hPlugin, int iNumParams)
{
	if (!g_cvKickSpecImmunity.BoolValue)
		return 0;

	int			accountId = GetNativeCell(1);
	eTypeAction eAction	  = GetNativeCell(2);

	DebugLog("[iImmunityNative] accountId: %d | eTypeAction: %d", accountId, eAction);

	return HandleStringMapAccountIdAction(g_smSpecImmunity, accountId, eAction);
}

// ========================
//  Caster Addons
// ========================

void vOnAddonsSettingChanged(ConVar cvar, const char[] szOldValue, const char[] szNewValue)
{
	bool bDisable  = (StringToInt(szNewValue) != 0);
	bool bPrevious = (StringToInt(szOldValue) != 0);

	if (bDisable == bPrevious)
		return;

	ArrayList hCastersList = (bDisable) ? new ArrayList() : null;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (!bCaster(GetSteamAccountID(i)))
			continue;

		if (bDisable)
		{
			CPrintToChat(i, "%t %t", "Prefix", "ForbidAddons");
			CPrintToChat(i, "%t %t", "Prefix", "Reconnect");
			hCastersList.Push(GetClientUserId(i));
		}
		else
		{
			CPrintToChat(i, "%t %t", "Prefix", "AllowAddons");
			CPrintToChat(i, "%t %t", "Prefix", "CasterReconnect");
		}
	}

	if (bDisable)
	{
		if (hCastersList.Length > 0)
			CreateTimer(3.0, aReconnectCastersTimer, hCastersList, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
		else
			delete hCastersList;
	}
}

Action aReconnectCastersTimer(Handle hTimer, ArrayList aCasterList)
{
	int iSize = aCasterList.Length;
	for (int i = 0; i < iSize; i++)
	{
		int iClient = GetClientOfUserId(aCasterList.Get(i));
		if (iClient > SERVER_INDEX)
			ReconnectClient(iClient);
	}

	return Plugin_Stop;
}

public Action L4D2_OnClientDisableAddons(const char[] szAuthId)
{
	int accountId = 0;
	if (!NormalizeSteamIdentifierToAccountID(szAuthId, accountId))
		return Plugin_Continue;

	return (g_cvAddonsEnable.BoolValue && bCaster(accountId)) ? Plugin_Handled : Plugin_Continue;
}

void vPlayerTeamEvent(Event event, const char[] szName, bool bDontBroadcast)
{
	if (view_as<L4DTeam>(event.GetInt("team")) == L4DTeam_Spectator)
		return;

	int iUserId = event.GetInt("userid");
	CreateTimer(1.0, aCasterCheck, iUserId, TIMER_FLAG_NO_MAPCHANGE);
}

Action aCasterCheck(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (!iClient || !IsClientInGame(iClient))
		return Plugin_Stop;

	if (!bCaster(GetSteamAccountID(iClient)))
		return Plugin_Stop;

	if (L4D_GetClientTeam(iClient) == L4DTeam_Spectator)
		return Plugin_Stop;

	CPrintToChat(iClient, "%t %t", "Prefix", "CasterPlay");
	CPrintToChat(iClient, "%t %t", "Prefix", "UseNoCast");
	ChangeClientTeam(iClient, view_as<int>(L4DTeam_Spectator));

	return Plugin_Stop;
}

// ========================
//  Caster
// ========================

Action aCasterRegCmd(int iClient, int iArgs)
{
	if (iArgs == 0)
	{
		CReplyToCommand(iClient, "%t %t: sm_caster <#userid|name|steamid>", "Prefix", "Use");
		return Plugin_Handled;
	}

	char szArguments[64];
	GetCmdArgString(szArguments, sizeof(szArguments));

	char szArg[ACCOUNTID_LENGTH];
	BreakString(szArguments, szArg, sizeof(szArg));

	vProcessReg(iClient, szArg, kCaster);

	return Plugin_Handled;
}

void vProcessReg(int iClient, const char[] szArg, eTypeList eList)
{
	char szNormalizedAuthId[ACCOUNTID_LENGTH];
	if (NormalizeSteamIdentifier(szArg, szNormalizedAuthId, sizeof(szNormalizedAuthId)))
	{
		int accountId = StringToInt(szNormalizedAuthId);
		int iTarget	  = FindConnectedClientBySteamIdentifier(szArg, szNormalizedAuthId);
		if (iTarget > 0)
		{
			char szName[16];
			GetClientName(iTarget, szName, sizeof(szName));
			vRegister(iClient, iTarget, accountId, szName, eList);
		}
		else
		{
			vRegister(iClient, NO_INDEX, accountId, szNormalizedAuthId, eList);
		}
		return;
	}

	int iTarget = FindTarget(iClient, szArg, true, false);
	if (iTarget == NO_INDEX)
		return;

	char szAuthId[ACCOUNTID_LENGTH];
	if (!GetClientAccountIDString(iTarget, szAuthId, sizeof(szAuthId)))
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "AuthIdError", szAuthId);
		return;
	}

	char szName[16];
	GetClientName(iTarget, szName, sizeof(szName));
	vRegister(iClient, iTarget, StringToInt(szAuthId), szName, eList);
}

/**
 * Registers a client as a caster or whitelist member.
 *
 * @param iClient       The client index of the player issuing the command.
 * @param iTarget       The client index of the target player.
 * @param accountId     The Steam AccountID of the target player.
 * @param szDisplayName The display name of the target player.
 * @param eList         The type of list to register the player.
 */
void vRegister(int iClient, int iTarget, int accountId, const char[] szDisplayName, eTypeList eList)
{
	DebugLog("[vRegister] iClient: %d | iTarget: %d | accountId: %d | szDisplayName: %s | eTypeList: %d", iClient, iTarget, accountId, szDisplayName, eList);
	bool bTargetConnected = (iTarget > NO_INDEX);

	char
		szRegMsg[128],
		szRegFromMsg[128];

	switch (eList)
	{
		case kCaster:
		{
			if (HasStringMapAccountId(g_smCaster, accountId))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "CasterFound", szDisplayName);
				return;
			}
			Format(szRegMsg, sizeof(szRegMsg), "%T", "CasterReg", iClient, szDisplayName);
			if (bTargetConnected)
				Format(szRegFromMsg, sizeof(szRegFromMsg), "%T", "CasterRegFrom", iTarget, iClient);
		}
		case kWhite:
		{
			if (HasStringMapAccountId(g_smWhitelist, accountId))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "WhitelistFound", szDisplayName);
				return;
			}
			Format(szRegMsg, sizeof(szRegMsg), "%T", "WhitelistReg", iClient, szDisplayName);
			if (bTargetConnected)
				Format(szRegFromMsg, sizeof(szRegFromMsg), "%T", "WhitelistRegFrom", iTarget, iClient);
		}
	}

	switch (eList)
	{
		case kCaster:
		{
			if (!SetStringMapAccountId(g_smCaster, accountId))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "CasterRegError", accountId);
				return;
			}
			FireCasterForward(g_gfOnCaster, accountId);
		}
		case kWhite:
		{
			if (!SetStringMapAccountId(g_smWhitelist, accountId))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "WhitelistRegError", accountId);
				return;
			}
		}
	}

	CReplyToCommand(iClient, "%t %s", "Prefix", szRegMsg);

	if (!bTargetConnected)
		return;

	if ((L4D_GetClientTeam(iTarget) != L4DTeam_Spectator) && (eList == kCaster))
		ChangeClientTeam(iTarget, view_as<int>(L4DTeam_Spectator));

	CPrintToChat(iTarget, "%t %s", "Prefix", szRegFromMsg);

	if (eList == kCaster)
		CPrintToChat(iTarget, "%t %t", "Prefix", "CasterReconnect");
}

void vDisplayRegMenu(int iClient, eTypeList eList)
{
	char szTitle[100];
	Format(szTitle, sizeof(szTitle), "%t", "MenuPlayersList");
	Menu hMenu = new Menu(iRegMenuHandler);
	hMenu.SetTitle(szTitle);
	vListTargets(hMenu, eList);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

/**
 * Populates a menu with a list of targets based on the specified list type.
 *
 * @param hMenu        The menu handle to which the targets will be added.
 * @param eTypeList    The type of list to determine the target selection criteria.
 *
 * The function iterates through all connected clients and adds them to the menu.
 * It skips fake clients and clients that cannot be identified by name or Steam ID.
 * Depending on the list type, it checks if the client is in the caster or whitelist.
 * If the client is found in the respective list, the menu item is added as disabled.
 * Otherwise, the menu item is added as enabled.
 */
void vListTargets(Menu hMenu, eTypeList eList)
{
	char
		szName[64],
		szInfo[16],
		szAuthId[ACCOUNTID_LENGTH];

	bool
		bFound;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		if (!GetClientName(i, szName, sizeof(szName)))
			continue;

		if (!GetClientAccountIDString(i, szAuthId, sizeof(szAuthId)))
			continue;

		Format(szInfo, sizeof(szInfo), "%d:%d", GetClientUserId(i), view_as<int>(eList));

		int accountId = StringToInt(szAuthId);
		switch (eList)
		{
			case kCaster:
				bFound = HasStringMapAccountId(g_smCaster, accountId);
			case kWhite:
				bFound = HasStringMapAccountId(g_smWhitelist, accountId);
		}

		if (bFound)
			hMenu.AddItem(szInfo, szName, ITEMDRAW_DISABLED);
		else
			hMenu.AddItem(szInfo, szName);
	}
}

public int iRegMenuHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char
				szInfo[32],
				szName[32];

			int
				iUserId,
				iTarget;

			eTypeList eList;

			hMenu.GetItem(iItem, szInfo, sizeof(szInfo), _, szName, sizeof(szName));

			char szParts[2][8];
			ExplodeString(szInfo, ":", szParts, 2, 4);

			iUserId = StringToInt(szParts[0]);
			eList	= view_as<eTypeList>(StringToInt(szParts[1]));

			if ((iTarget = GetClientOfUserId(iUserId)) == SERVER_INDEX)
				CPrintToChat(iClient, "%t %t", "Prefix", "Player no longer available");
			else
			{
				char szAuthId[ACCOUNTID_LENGTH];
				if (!GetClientAccountIDString(iTarget, szAuthId, sizeof(szAuthId)))
				{
					CReplyToCommand(iClient, "%t %t", "Prefix", "AuthIdError", szAuthId);
					return 0;
				}

				vRegister(iClient, iTarget, StringToInt(szAuthId), szName, eList);
			}
		}
		case MenuAction_End:
			delete hMenu;
	}
	return 0;
}

Action aCasterListCmd(int iClient, int iArgs)
{
	return aListCmd(iClient, kCaster);
}

Action aListCmd(int iClient, eTypeList type)
{
	PrintListPrinted(iClient);

	switch (type)
	{
		case kCaster:
		{
			StringMapSnapshot hSnapshot = g_smCaster.Snapshot();
			PrintSnapshotList(iClient, hSnapshot, "/***********[Casters]***********\\", ">* Total Casters: %i");
		}
		case kWhite:
		{
			StringMapSnapshot hSnapshot = g_smWhitelist.Snapshot();
			PrintSnapshotList(iClient, hSnapshot, "/***********[Whitelist]***********\\", ">* Total Whitelist: %i");
		}
	}

	return Plugin_Handled;
}

void PrintSnapshotList(int iClient, StringMapSnapshot hSnapshot, const char[] sHeader, const char[] sTotalLabel)
{
	PrintToConsole(iClient, sHeader);

	char szAuthID[128];
	int
		iLen = hSnapshot.Length,
		iTarget;
	for (int i = 0; i < iLen; i++)
	{
		hSnapshot.GetKey(i, szAuthID, sizeof(szAuthID));
		iTarget = GetClientOfAccountIDString(szAuthID);

		if (iTarget == NO_INDEX)
			PrintToConsole(iClient, "AuthID: %s", szAuthID);
		else
			PrintToConsole(iClient, "AuthID: %s [%N]", szAuthID, iTarget);
	}
	PrintToConsole(iClient, sTotalLabel, iLen);

	delete hSnapshot;
}

void PrintListPrinted(int iClient)
{
	if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE || iClient == SERVER_INDEX)
		return;

	CPrintToChat(iClient, "%t %t", "Prefix", "ListPrinted");
}

Action aCasterClearCmd(int iClient, int iArgs)
{
	g_smCaster.Clear();
	CReplyToCommand(iClient, "%t %t", "Prefix", "CasterReset");
	return Plugin_Handled;
}

Action aCasterRemoveCmd(int iClient, int iArgs)
{
	if (iArgs == 0)
	{
		CReplyToCommand(iClient, "%t %t: sm_caster_rm <#userid|name|steamid>", "Prefix", "Use");
		return Plugin_Handled;
	}

	char szArguments[64];
	GetCmdArgString(szArguments, sizeof(szArguments));

	char szArg[ACCOUNTID_LENGTH];
	BreakString(szArguments, szArg, sizeof(szArg));

	vProcessRemove(iClient, szArg, kCaster);
	return Plugin_Handled;
}

/**
 * Processes the removal of a client from a specified list.
 *
 * @param iClient The client index initiating the removal.
 * @param szArg The argument provided, which can be a Steam ID or a target name.
 * @param eList The list type from which the client should be removed.
 * @param eRsCmd The reply source for the command.
 */
void vProcessRemove(int iClient, const char[] szArg, eTypeList eList)
{
	char szNormalizedAuthId[ACCOUNTID_LENGTH];
	if (NormalizeSteamIdentifier(szArg, szNormalizedAuthId, sizeof(szNormalizedAuthId)))
	{
		int accountId = StringToInt(szNormalizedAuthId);
		int iTarget	  = FindConnectedClientBySteamIdentifier(szArg, szNormalizedAuthId);
		if (iTarget > 0)
		{
			char szName[16];
			GetClientName(iTarget, szName, sizeof(szName));
			vRemove(iClient, iTarget, accountId, szName, eList);
		}
		else
		{
			vRemove(iClient, NO_INDEX, accountId, szNormalizedAuthId, eList);
		}
		return;
	}

	int iTarget = FindTarget(iClient, szArg, true, false);
	if (iTarget == NO_INDEX)
		return;

	char szAuthId[ACCOUNTID_LENGTH];
	if (!GetClientAccountIDString(iTarget, szAuthId, sizeof(szAuthId)))
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "AuthIdError", szAuthId);
		return;
	}

	char szName[16];
	GetClientName(iTarget, szName, sizeof(szName));
	vRemove(iClient, iTarget, StringToInt(szAuthId), szName, eList);
}

/**
 * Removes a client from a specified list and sends appropriate messages.
 *
 * @param iClient       The client index who initiated the removal.
 * @param iTarget       The target client index to be removed.
 * @param accountId     The Steam AccountID of the target client.
 * @param szDisplayName The display name of the target client.
 * @param eList         The list type from which the client is to be removed.
 */
void vRemove(int iClient, int iTarget, int accountId, const char[] szDisplayName, eTypeList eList)
{
	DebugLog("[vRemove] iClient: %d | iTarget: %d | accountId: %d | szDisplayName: %s | eTypeList: %d", iClient, iTarget, accountId, szDisplayName, eList);
	bool bTargetConnected = (iTarget > NO_INDEX);

	char
		szRemoveMsg[128],
		szRemoveFromMsg[128];

	switch (eList)
	{
		case kCaster:
		{
			if (!HasStringMapAccountId(g_smCaster, accountId))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "CasterNoFound", szDisplayName);
				return;
			}
			Format(szRemoveMsg, sizeof(szRemoveMsg), "%T", "CasterRemove", iClient, szDisplayName);
			if (bTargetConnected)
				Format(szRemoveFromMsg, sizeof(szRemoveFromMsg), "%T", "CasterRemoveFrom", iTarget, iClient);
		}
		case kWhite:
		{
			if (!HasStringMapAccountId(g_smWhitelist, accountId))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "WhitelistNoFound", szDisplayName);
				return;
			}
			Format(szRemoveMsg, sizeof(szRemoveMsg), "%T", "WhitelistRemove", iClient, szDisplayName);
			if (bTargetConnected)
				Format(szRemoveFromMsg, sizeof(szRemoveFromMsg), "%T", "WhitelistRemoveFrom", iTarget, iClient);
		}
	}

	switch (eList)
	{
		case kCaster:
		{
			if (!RemoveStringMapAccountId(g_smCaster, accountId))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "CasterRemoveError", accountId);
				return;
			}
			FireCasterForward(g_gfOffCaster, accountId);

			if (bTargetConnected)
				CreateTimer(3.0, aReconnectTimer, iTarget);
		}
		case kWhite:
		{
			if (!RemoveStringMapAccountId(g_smWhitelist, accountId))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "WhitelistRemoveError", accountId);
				return;
			}
		}
	}

	CReplyToCommand(iClient, "%t %s", "Prefix", szRemoveMsg);

	if (!bTargetConnected)
		return;

	CPrintToChat(iTarget, "%t %s", "Prefix", szRemoveFromMsg);
}

void vDisplayRemoveMenu(int iClient, eTypeList eList)
{
	char szTitle[100];
	switch (eList)
	{
		case kCaster:
			Format(szTitle, sizeof(szTitle), "%T", "MenuCastersList", iClient);
		case kWhite:
			Format(szTitle, sizeof(szTitle), "%T", "MenuWhitelistList", iClient);
	}

	Menu hMenu = new Menu(iMenuRemoveHandler);
	hMenu.SetTitle(szTitle);
	vRemoveTargets(hMenu, eList, iClient);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

/**
 * Removes targets from the specified menu based on the given type list.
 *
 * @param hMenu        The menu handle to which the targets will be added.
 * @param eList        The type list to determine which targets to remove.
 * @param iClient      The client index who initiated the removal.
 *
 * This function iterates through all connected clients, checks if they match
 * the criteria specified by the type list, and adds them to the menu if they do.
 * If no targets are found, a message indicating no targets to remove is added
 * to the menu.
 */
void vRemoveTargets(Menu hMenu, eTypeList eList, int iClient)
{
	char
		szName[64],
		szInfo[16],
		szAuthId[ACCOUNTID_LENGTH];

	bool
		bFound;

	int
		iTargets = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
			continue;

		if (!GetClientName(i, szName, sizeof(szName)))
			continue;

		if (!GetClientAccountIDString(i, szAuthId, sizeof(szAuthId)))
			continue;

		Format(szInfo, sizeof(szInfo), "%d:%d", GetClientUserId(i), view_as<int>(eList));

		int accountId = StringToInt(szAuthId);
		switch (eList)
		{
			case kCaster:
				bFound = HasStringMapAccountId(g_smCaster, accountId);
			case kWhite:
				bFound = HasStringMapAccountId(g_smWhitelist, accountId);
		}

		if (bFound)
		{
			hMenu.AddItem(szInfo, szName);
			iTargets++;
		}
	}

	if (iTargets == 0)
	{
		char szMsj[64];
		Format(szMsj, sizeof(szMsj), "%T", "NoTargetsToRemove", iClient);
		hMenu.AddItem("", szMsj, ITEMDRAW_DISABLED);
	}
}

public int iMenuRemoveHandler(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	if (eAction == MenuAction_Select)
	{
		char
			szInfo[32],
			szName[32];

		int
			iUserId,
			iTarget;

		eTypeList eList;

		hMenu.GetItem(iItem, szInfo, sizeof(szInfo), _, szName, sizeof(szName));

		char szParts[2][8];
		ExplodeString(szInfo, ":", szParts, 2, 4);

		iUserId = StringToInt(szParts[0]);
		eList	= view_as<eTypeList>(StringToInt(szParts[1]));

		if ((iTarget = GetClientOfUserId(iUserId)) == SERVER_INDEX)
			CPrintToChat(iClient, "%t %t", "Prefix", "Player no longer available");
		else
		{
			char szAuthId[ACCOUNTID_LENGTH];
			if (!GetClientAccountIDString(iTarget, szAuthId, sizeof(szAuthId)))
			{
				CReplyToCommand(iClient, "%t %t", "Prefix", "AuthIdError", szAuthId);
				return 0;
			}

			vRemove(iClient, iTarget, StringToInt(szAuthId), szName, eList);
		}
	}
	else if (eAction == MenuAction_End)
		delete hMenu;
	return 0;
}

// ========================
//  Whitelist
// ========================

Action aWhitelistRegCmd(int iClient, int iArgs)
{
	if (iArgs == 0)
	{
		CReplyToCommand(iClient, "%t %t: sm_caster_wl <#userid|name|steamid>", "Prefix", "Use");
		return Plugin_Handled;
	}

	char szArguments[64];
	GetCmdArgString(szArguments, sizeof(szArguments));

	char szArg[ACCOUNTID_LENGTH];
	BreakString(szArguments, szArg, sizeof(szArg));

	vProcessReg(iClient, szArg, kWhite);

	return Plugin_Handled;
}

Action aWhitelistListCmd(int iClient, int iArgs)
{
	return aListCmd(iClient, kWhite);
}

Action aWhitelistClearCmd(int iClient, int iArgs)
{
	g_smWhitelist.Clear();
	CReplyToCommand(iClient, "%t %t", "Prefix", "WhitelistReset");
	return Plugin_Handled;
}

Action aWhitelistRemoveCmd(int iClient, int iArgs)
{
	if (iArgs == 0)
	{
		CReplyToCommand(iClient, "%t %t: sm_caster_wl_rm <#userid|name|steamid>", "Prefix", "Use");
		return Plugin_Handled;
	}

	char szArguments[64];
	GetCmdArgString(szArguments, sizeof(szArguments));

	char szArg[ACCOUNTID_LENGTH];
	BreakString(szArguments, szArg, sizeof(szArg));

	vProcessRemove(iClient, szArg, kWhite);
	return Plugin_Handled;
}

// ========================
//  Self
// ========================

Action aSelfRegCastCmd(int iClient, int iArgs)
{
	bool bIsAdmin = (GetUserAdmin(iClient) != INVALID_ADMIN_ID);
	if (iArgs != 0)
	{
		if (!bIsAdmin)
		{
			CReplyToCommand(iClient, "%t %t", "Prefix", "SelfRegNoAdmin");
			return Plugin_Handled;
		}

		char szArguments[256];
		GetCmdArgString(szArguments, sizeof(szArguments));
		FakeClientCommandEx(iClient, "sm_caster %s", szArguments);
		return Plugin_Handled;
	}

	if (iClient == SERVER_INDEX)
	{
		CReplyToCommand(iClient, "%t %t: sm_cast <#userid|name|steamid>", "Prefix", "Use");
		return Plugin_Handled;
	}

	if (!g_cvSefRegEnable.BoolValue && !bIsAdmin)
	{
		CPrintToChat(iClient, "%t %t", "Prefix", "SelfRegDisabled");
		return Plugin_Handled;
	}

	char szAuthId[ACCOUNTID_LENGTH];
	GetClientAccountIDString(iClient, szAuthId, sizeof(szAuthId));
	int accountId = StringToInt(szAuthId);

	if (g_cvWhitelistEnable)
	{
		if (g_smWhitelist.Size == 0 && !bIsAdmin)
		{
			CPrintToChat(iClient, "%t %t", "Prefix", "WhitelistEmpty");
			return Plugin_Handled;
		}

		if (!HasStringMapAccountId(g_smWhitelist, accountId) && !bIsAdmin)
		{
			CPrintToChat(iClient, "%t %t", "Prefix", "SelfRegWhitelistNotFound");
			return Plugin_Handled;
		}
	}

	if (bCaster(accountId))
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "SelfRegCasterFound");
		return Plugin_Handled;
	}

	if (!SetStringMapAccountId(g_smCaster, accountId))
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "CasterRegError", accountId);
		return Plugin_Handled;
	}

	if (L4D_GetClientTeam(iClient) != L4DTeam_Spectator)
		ChangeClientTeam(iClient, view_as<int>(L4DTeam_Spectator));

	FireCasterForward(g_gfOnCaster, accountId);

	CPrintToChat(iClient, "%t %t", "Prefix", "SelfRegSuccess");
	CPrintToChat(iClient, "%t %t", "Prefix", "CasterReconnect");
	return Plugin_Handled;
}

Action aSelfRemoveCastCmd(int iClient, int iArgs)
{
	if (iArgs == 0)
	{
		if (iClient == SERVER_INDEX)
		{
			CReplyToCommand(iClient, "%t %t: sm_uncast <#userid|name|steamid>", "Prefix", "Use");
			return Plugin_Handled;
		}

		char szAuthId[ACCOUNTID_LENGTH];
		GetClientAccountIDString(iClient, szAuthId, sizeof(szAuthId));
		int	 accountId = StringToInt(szAuthId);

		char szName[16];
		GetClientName(iClient, szName, sizeof(szName));

		if (!bCaster(accountId))
		{
			CReplyToCommand(iClient, "%t %t", "Prefix", "CasterNoFound", szName);
			return Plugin_Handled;
		}

		CPrintToChat(iClient, "%t %t", "Prefix", "Reconnect");
		RemoveStringMapAccountId(g_smCaster, accountId);
		FireCasterForward(g_gfOffCaster, accountId);

		CreateTimer(3.0, aReconnectTimer, iClient);
		return Plugin_Handled;
	}

	if (g_smCaster.Size == 0)
	{
		CPrintToChat(iClient, "%t %t", "Prefix", "CasterEmpty");
		return Plugin_Handled;
	}

	AdminId aAdminId = GetUserAdmin(iClient);
	if (aAdminId == INVALID_ADMIN_ID || !GetAdminFlag(aAdminId, Admin_Ban))	   // Check for specific admin flag
	{
		CReplyToCommand(iClient, "%t %t", "Prefix", "UnRegCasterNonAdmin");
		return Plugin_Handled;
	}

	char szArguments[256];
	GetCmdArgString(szArguments, sizeof(szArguments));
	FakeClientCommandEx(iClient, "sm_caster_rm %s", szArguments);
	return Plugin_Handled;
}

Action aReconnectTimer(Handle timer, int client)
{
	if (IsClientConnected(client))
		ReconnectClient(client);

	return Plugin_Stop;
}

// ========================
//  Kick Specs
// ========================

Action aKickSpecsCmd(int iClient, int iArgs)
{
	AdminId aAdminId = GetUserAdmin(iClient);
	if (aAdminId != INVALID_ADMIN_ID && GetAdminFlag(aAdminId, Admin_Ban))
	{
		CreateTimer(2.0, aTimerKickSpecs);
		CPrintToChatAll("%t %t", "Prefix", "KickSpecsAdmin", iClient);
		return Plugin_Handled;
	}

	if (L4D_GetClientTeam(iClient) == L4DTeam_Spectator)
	{
		CPrintToChat(iClient, "%t %t", "Prefix", "KickSpecsVoteSpec");
		return Plugin_Handled;
	}

	vStartKickSpecsVote(iClient);
	return Plugin_Handled;
}

// ========================
//  Vote
// ========================

void vStartKickSpecsVote(int iClient)
{
	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(iClient, "%t %t", "Prefix", "VoteInProgress");
		return;
	}
	if (CheckBuiltinVoteDelay() > 0)
	{
		CPrintToChat(iClient, "%t %t", "Prefix", "VoteDelay", CheckBuiltinVoteDelay());
		return;
	}

	Handle hVote = CreateBuiltinVote(vVoteActionHandler, BuiltinVoteType_Custom_YesNo,
									 BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

	char   szBuffer[128];
	FormatEx(szBuffer, sizeof(szBuffer), "%T", "KickSpecsVoteTitle", LANG_SERVER);
	SetBuiltinVoteArgument(hVote, szBuffer);
	SetBuiltinVoteInitiator(hVote, iClient);
	SetBuiltinVoteResultCallback(hVote, vKickSpecsVoteResultHandler);

	int iTotal		= 0;
	int[] aiPlayers = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || L4D_GetClientTeam(iClient) == L4DTeam_Spectator)
			continue;
		aiPlayers[iTotal++] = i;
	}
	DisplayBuiltinVote(hVote, aiPlayers, iTotal, FindConVar("sv_vote_timer_duration").IntValue);

	FakeClientCommand(iClient, "Vote Yes");
}

void vVoteActionHandler(Handle hVote, BuiltinVoteAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case BuiltinVoteAction_End:
		{
			CloseHandle(hVote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(hVote, BuiltinVoteFail_Generic);
		}
	}
}

void vKickSpecsVoteResultHandler(Handle hVote, int iNumVotes, int iNumClients, const int[][] aiClientInfo, int iNumItems, const int[][] aiItemInfo)
{
	for (int i = 0; i < iNumItems; i++)
	{
		if (aiItemInfo[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (aiItemInfo[i][BUILTINVOTEINFO_ITEM_VOTES] > (iNumClients / 2))
			{
				char szBuffer[64];
				FormatEx(szBuffer, sizeof(szBuffer), "%T", "KickSpecsVoteSuccess", LANG_SERVER);
				DisplayBuiltinVotePass(hVote, szBuffer);

				float fDelay = FindConVar("sv_vote_command_delay").FloatValue;
				CreateTimer(fDelay, aTimerKickSpecs);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(hVote, BuiltinVoteFail_Loses);
}

Action aTimerKickSpecs(Handle hTimer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		if (L4D_GetClientTeam(i) != L4DTeam_Spectator)
			continue;
		if (bCaster(GetSteamAccountID(i)))
			continue;
		if (GetUserAdmin(i) != INVALID_ADMIN_ID)
			continue;
		if (bSpecImmunity(GetSteamAccountID(i)))
			continue;
		KickClient(i, "%t", "KickSpecsReason");
	}

	return Plugin_Stop;
}

/**
 * Check if the translation file exists
 *
 * @param szTranslation   Translation name.
 * @noreturn
 */
stock void vLoadTranslation(const char[] szTranslation)
{
	char szPath[PLATFORM_MAX_PATH],
		szName[64];

	Format(szName, sizeof(szName), "translations/%s.txt", szTranslation);
	BuildPath(Path_SM, szPath, sizeof(szPath), szName);
	if (!FileExists(szPath))
		SetFailState("Missing translation file %s.txt", szTranslation);

	LoadTranslations(szTranslation);
}

/**
 * Checks if an account is a caster.
 *
 * @param accountId    Steam AccountID.
 * @return             True if the account is a caster, false otherwise.
 */
bool bCaster(int accountId)
{
	return HasStringMapAccountId(g_smCaster, accountId);
}

/**
 * Checks if an account has spectator immunity.
 *
 * @param accountId   Steam AccountID.
 * @return            True if the account has spectator immunity, false otherwise.
 */
bool bSpecImmunity(int accountId)
{
	return HasStringMapAccountId(g_smSpecImmunity, accountId);
}

/**
 * @brief Checks if a given string is a valid Steam ID.
 *
 * This function verifies if the provided string follows the format of a Steam ID.
 * A valid Steam ID should start with "STEAM_" and contain two colons separating
 * three numerical components.
 *
 * @param szAuthId The string to be checked.
 * @return True if the string is a valid Steam ID, false otherwise.
 */
bool NormalizeSteamIdentifier(const char[] szInput, char[] szAccountId, int iMaxLen)
{
	int accountId = 0;
	if (!NormalizeSteamIdentifierToAccountID(szInput, accountId))
		return false;

	IntToString(accountId, szAccountId, iMaxLen);
	return true;
}

bool NormalizeSteamIdentifierToAccountID(const char[] szInput, int &accountId)
{
	SteamIDFormat eFormat = DetectSteamIDFormat(szInput);
	switch (eFormat)
	{
		case STEAMID_FORMAT_STEAMID2:
		{
			accountId = SteamID2ToAccountID(szInput);
			if (accountId <= 0)
				return false;
			return true;
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			accountId = SteamID3ToAccountID(szInput);
			if (accountId <= 0)
				return false;
			return true;
		}
		case STEAMID_FORMAT_ACCOUNTID:
		{
			accountId = StringToInt(szInput);
			if (accountId <= 0)
				return false;
			return true;
		}
	}

	return false;
}

/**
 * @brief Checks if the given string represents an integer.
 *
 * This function iterates through each character of the input string and
 * verifies if all characters are numeric.
 *
 * @param szString The string to be checked.
 * @return True if the string represents an integer, false otherwise.
 */
int FindConnectedClientBySteamIdentifier(const char[] szOriginalInput, const char[] szAccountId)
{
	SteamIDFormat eFormat = DetectSteamIDFormat(szOriginalInput);
	switch (eFormat)
	{
		case STEAMID_FORMAT_STEAMID2, STEAMID_FORMAT_STEAMID3, STEAMID_FORMAT_ACCOUNTID:
			return GetClientOfAccountIDString(szAccountId);
	}

	return NO_INDEX;
}

bool GetClientAccountIDString(int iClient, char[] szBuffer, int iMaxLen)
{
	int iAccountId = GetSteamAccountID(iClient);
	if (iAccountId <= 0)
	{
		szBuffer[0] = '\0';
		return false;
	}

	IntToString(iAccountId, szBuffer, iMaxLen);
	return true;
}

int GetClientOfAccountIDString(const char[] szAccountId)
{
	int iAccountId = StringToInt(szAccountId);
	if (iAccountId <= 0)
		return NO_INDEX;

	int iClient = FindClientByAccountID(iAccountId);
	return iClient > 0 ? iClient : NO_INDEX;
}

int HandleStringMapAccountIdAction(StringMap hMap, int accountId, eTypeAction eAction)
{
	bool bExists = HasStringMapAccountId(hMap, accountId);
	switch (eAction)
	{
		case kGet:
			return bExists ? 1 : 0;
		case kSet:
			return bExists ? 0 : (SetStringMapAccountId(hMap, accountId) ? 1 : 0);
		case kRem:
			return bExists ? (RemoveStringMapAccountId(hMap, accountId) ? 1 : 0) : 0;
	}

	return 0;
}

void FireCasterForward(GlobalForward hForward, int accountId)
{
	DebugLog("[FireCasterForward] accountId: %d", accountId);
	Call_StartForward(hForward);
	Call_PushCell(accountId);
	Call_Finish();
}

void DebugLog(const char[] szFormat, any...)
{
	if (!g_cvDebug.BoolValue)
		return;

	char szMessage[256];
	VFormat(szMessage, sizeof(szMessage), szFormat, 2);
	LogMessage("%s", szMessage);
}

bool HasStringMapAccountId(StringMap hMap, int accountId)
{
	if (accountId <= 0)
		return false;

	char szKey[ACCOUNTID_LENGTH];
	IntToString(accountId, szKey, sizeof(szKey));
	return hMap.GetValue(szKey, g_iDummy);
}

bool SetStringMapAccountId(StringMap hMap, int accountId)
{
	if (accountId <= 0)
		return false;

	char szKey[ACCOUNTID_LENGTH];
	IntToString(accountId, szKey, sizeof(szKey));
	return hMap.SetValue(szKey, true);
}

bool RemoveStringMapAccountId(StringMap hMap, int accountId)
{
	if (accountId <= 0)
		return false;

	char szKey[ACCOUNTID_LENGTH];
	IntToString(accountId, szKey, sizeof(szKey));
	return hMap.Remove(szKey);
}
