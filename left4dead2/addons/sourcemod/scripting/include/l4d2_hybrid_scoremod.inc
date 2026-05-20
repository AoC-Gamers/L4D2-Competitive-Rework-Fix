#if defined _l4d2_hybrid_scoremod
	#endinput
#endif
#define _l4d2_hybrid_scoremod

enum SMPlusBonusType
{
    SMPlusBonusType_Total = 0,
    SMPlusBonusType_Health,
    SMPlusBonusType_Damage,
    SMPlusBonusType_Pills
}

/**
 * Returns a survivor bonus value by type.
 *
 * The bonus type is required. The client is optional.
 * Pass client 0 to return the current team-wide value for that type.
 * Pass a survivor client index to return that survivor's individual contribution.
 * Ineligible survivors return 0.
 *
 * @param type          Bonus type to query.
 * @param client        Survivor client index, or 0 for the team aggregate.
 * @return              Current bonus value for the requested type.
 */
native int SMPlus_GetBonus(SMPlusBonusType type, int client = 0);

/**
 * Returns a maximum survivor bonus value by type.
 *
 * @param type          Bonus type to query.
 * @return              Maximum bonus value for the requested type.
 */
native int SMPlus_GetMaxBonus(SMPlusBonusType type);

/**
 * Returns the maximum permanent health bonus for the round.
 *
 * @return              Maximum health bonus.
 */
stock int SMPlus_GetMaxHealthBonus()
{
    return SMPlus_GetMaxBonus(SMPlusBonusType_Health);
}

/**
 * Returns the maximum temporary health or damage bonus for the round.
 *
 * @return              Maximum damage bonus.
 */
stock int SMPlus_GetMaxDamageBonus()
{
    return SMPlus_GetMaxBonus(SMPlusBonusType_Damage);
}

/**
 * Returns the maximum pills bonus for the round.
 *
 * @return              Maximum pills bonus.
 */
stock int SMPlus_GetMaxPillsBonus()
{
    return SMPlus_GetMaxBonus(SMPlusBonusType_Pills);
}

/**
 * Returns the maximum total bonus for the round.
 *
 * @return              Maximum total round bonus.
 */
stock int SMPlus_GetRoundMaxBonus()
{
    return SMPlus_GetMaxBonus(SMPlusBonusType_Total);
}

/**
 * Fills a KeyValues snapshot with current round and client bonus data.
 *
 * The caller owns the KeyValues handle and remains responsible for closing it.
 * Existing "rounds" and "clients" subkeys are replaced.
 *
 * Example snapshot:
 * "scoremod_bonus_snapshot"
 * {
 *     "current_round"      "2"
 *     "total_bonus"        "812"
 *     "round_max_bonus"    "920"
 *     "clients"
 *     {
 *         "123"
 *         {
 *             "health_bonus"  "210"
 *             "damage_bonus"  "48"
 *             "pills_bonus"   "30"
 *             "total_bonus"   "288"
 *         }
 *     }
 * }
 *
 * @param kv            Destination KeyValues handle.
 */
native void SMPlus_FillBonusSnapshotKv(KeyValues kv);

/**
 * Fired when the match has been finalized at the end of round 2.
 *
 * Consumers can call SMPlus_FillBonusSnapshotKv() inside this forward to read
 * the final detailed score snapshot.
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
	MarkNativeAsOptional("SMPlus_GetBonus");
	MarkNativeAsOptional("SMPlus_GetMaxBonus");
	MarkNativeAsOptional("SMPlus_FillBonusSnapshotKv");
}
#endif
