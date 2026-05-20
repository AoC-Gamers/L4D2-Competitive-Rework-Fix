#if defined _caster_system_included
	#endinput
#endif
#define _caster_system_included

#include <steamidtools_stock>

/**
 * Supported actions for caster system natives.
 */
enum CasterSystemAction
{
	CasterSystemAction_Get = 0,
	CasterSystemAction_Set,
	CasterSystemAction_Remove
}


/**
 * Checks, adds or removes an account from the caster list.
 *
 * @param accountId     Steam AccountID.
 * @param action        Action to perform.
 * @return              Result of the requested action.
 */
native bool bCaster(int accountId, CasterSystemAction action);

/**
 * Checks, adds or removes an account from the local whitelist.
 *
 * @param accountId     Steam AccountID.
 * @param action        Action to perform.
 * @return              Result of the requested action.
 */
native bool bCasterWhitelist(int accountId, CasterSystemAction action);

/**
 * Checks, adds or removes an account from the spectator immunity list.
 *
 * @param accountId     Steam AccountID.
 * @param action        Action to perform.
 * @return              Result of the requested action.
 */
native bool bKickSpecImmunity(int accountId, CasterSystemAction action);

/**
 * Fired when a caster entry is created.
 *
 * @param accountId     Steam AccountID of the caster entry.
 */
forward void OnCaster(int accountId);

/**
 * Fired when a caster entry is removed.
 *
 * @param accountId     Steam AccountID of the caster entry.
 */
forward void OffCaster(int accountId);

/**
 * Legacy wrapper for checking whether a connected client is registered as a caster.
 *
 * @deprecated          Use bCaster(GetSteamAccountID(client), CasterSystemAction_Get).
 * @param client        Connected client index.
 * @return              True if the client is a registered caster.
 */
stock bool IsClientCaster(int client)
{
	int accountId = GetSteamAccountID(client);
	return accountId > 0 ? bCaster(accountId, CasterSystemAction_Get) : false;
}

/**
 * Legacy wrapper for checking whether a Steam identifier is registered as a caster.
 *
 * Supported string inputs are SteamID2, SteamID3 and AccountID.
 *
 * @deprecated          Use bCaster(accountId, CasterSystemAction_Get) after converting the identifier to AccountID.
 * @param steamId       Steam identifier string.
 * @return              True if the identifier resolves to a registered caster.
 */
stock bool IsIDCaster(const char[] steamId)
{
	SteamIDFormat eFormat = DetectSteamIDFormat(steamId);
	int accountId = 0;

	switch (eFormat)
	{
		case STEAMID_FORMAT_STEAMID2:
		{
			accountId = SteamID2ToAccountID(steamId);
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			accountId = SteamID3ToAccountID(steamId);
		}
		case STEAMID_FORMAT_ACCOUNTID:
		{
			accountId = StringToInt(steamId);
		}
	}

	return accountId > 0 ? bCaster(accountId, CasterSystemAction_Get) : false;
}

/**
 * Legacy wrapper for spectator immunity access.
 *
 * @deprecated          Use bKickSpecImmunity(accountId, action).
 * @param accountId     Steam AccountID.
 * @param action        Action to perform.
 * @return              Result of the requested action.
 */
stock bool bKickSpecInmunity(int accountId, CasterSystemAction action)
{
	return bKickSpecImmunity(accountId, action);
}


public SharedPlugin __pl_caster_system =
{
	name = "caster_system",
	file = "caster_system.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_caster_system_SetNTVOptional()
{
	MarkNativeAsOptional("bCaster");
	MarkNativeAsOptional("bCasterWhitelist");
	MarkNativeAsOptional("bKickSpecImmunity");
}
#endif
