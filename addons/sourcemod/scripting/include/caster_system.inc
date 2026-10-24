#if defined _caster_system_included
	#endinput
#endif
#define _caster_system_included

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
