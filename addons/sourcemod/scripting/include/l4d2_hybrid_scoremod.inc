#if defined _l4d2_hybrid_scoremod
	#endinput
#endif
#define _l4d2_hybrid_scoremod

enum SMPlusMode
{
    SMPlusMode_Legacy = 0,
    SMPlusMode_Hybrid,
    SMPlusMode_Zone
}

enum SMPlusBonusType
{
    // Total is derived from Health + Damage + Pills and is read-only for writes.
    SMPlusBonusType_Total = 0,
    SMPlusBonusType_Health,
    SMPlusBonusType_Damage,
    SMPlusBonusType_Pills
}

/**
 * Returns the active score model mode.
 *
 * @return 0 = legacy, 1 = hybrid, 2 = zone.
 */
native int SMPlus_GetMode();

/**
 * Adds an external bonus adjustment.
 *
 * Pass client 0 to modify the team-level external bonus. Pass a survivor client
 * index to modify a per-client external bonus.
 *
 * @param type          Bonus type to modify. Total is not writable.
 * @param value         Bonus delta to add.
 * @param client        Survivor client index, or 0 for the team aggregate.
 */
native void SMPlus_AddExternalBonus(SMPlusBonusType type, float value, int client = 0);

/**
 * Sets an external bonus adjustment.
 *
 * Pass client 0 to modify the team-level external bonus. Pass a survivor client
 * index to modify a per-client external bonus.
 *
 * @param type          Bonus type to modify. Total is not writable.
 * @param value         Bonus value to store.
 * @param client        Survivor client index, or 0 for the team aggregate.
 */
native void SMPlus_SetExternalBonus(SMPlusBonusType type, float value, int client = 0);

/**
 * Reads an external bonus adjustment.
 *
 * Pass client 0 to read the team-level external bonus. Pass a survivor client
 * index to read a per-client external bonus.
 *
 * @param type          Bonus type to query.
 * @param client        Survivor client index, or 0 for the team aggregate.
 * @return              External bonus value for the requested scope. Total is derived from Health + Damage + Pills.
 */
native float SMPlus_GetExternalBonus(SMPlusBonusType type, int client = 0);

/**
 * Resets external bonus adjustments.
 *
 * Pass client 0 to reset the team-level external bonus. Pass a survivor client
 * index to reset a per-client external bonus.
 *
 * @param client        Survivor client index, or 0 for the team aggregate.
 */
native void SMPlus_ResetExternalBonus(int client = 0);

/**
 * Fills a full score snapshot.
 *
 * The caller owns the KeyValues handle and remains responsible for closing it.
 * Existing "bonus", "bonus_max", "rounds", "legacy", "hybrid" and "clients"
 * subkeys are replaced.
 *
 * @param kv            Destination KeyValues handle.
 */
native void SMPlus_FillSnapshot(KeyValues kv);

/**
 * Fills a single-client score snapshot.
 *
 * The caller owns the KeyValues handle and remains responsible for closing it.
 *
 * @param client        Survivor client index to inspect.
 * @param kv            Destination KeyValues handle.
 */
native void SMPlus_FillClientSnapshot(int client, KeyValues kv);

/**
 * Fired when score-relevant state changes.
 */
forward void SMPlus_OnScoreUpdated();

/**
 * Fired when a versus round bonus has been finalized.
 *
 * @param round         One-based round index.
 */
forward void SMPlus_OnRoundFinalized(int round);

/**
 * Fired when the match has been finalized at the end of round 2.
 *
 * @param winningTeam       Winning team index: 1, 2, or 0 if tied.
 */
forward void SMPlus_OnMatchFinalized(int winningTeam);

public SharedPlugin __pl_l4d2_hybrid_scoremod =
{
	name = "l4d2_hybrid_scoremod",
	file = "l4d2_hybrid_scoremod.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_hybrid_scoremod_SetNTVOptional()
{
	MarkNativeAsOptional("SMPlus_GetMode");
	MarkNativeAsOptional("SMPlus_AddExternalBonus");
	MarkNativeAsOptional("SMPlus_SetExternalBonus");
	MarkNativeAsOptional("SMPlus_GetExternalBonus");
	MarkNativeAsOptional("SMPlus_ResetExternalBonus");
	MarkNativeAsOptional("SMPlus_FillSnapshot");
	MarkNativeAsOptional("SMPlus_FillClientSnapshot");
}
#endif
