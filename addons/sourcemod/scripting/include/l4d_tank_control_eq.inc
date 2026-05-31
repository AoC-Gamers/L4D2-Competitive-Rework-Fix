#if defined _l4d_tank_control_eq_included
	#endinput
#endif
#define _l4d_tank_control_eq_included

#define LIBRARY_L4D_TANK_CONTROL_EQ "l4d_tank_control_eq"

/**
 * @brief Terminal reasons for a tracked Tank.
 */
enum TankControlEndReason
{
	TankControlEnd_None = 0,
	TankControlEnd_TankDied,
	TankControlEnd_RoundEnded
}

/**
 * @brief Semantic reasons for a tracked Tank starting.
 */
enum TankControlStartReason
{
	TankControlStart_Unknown = 0,
	TankControlStart_Primary,
	TankControlStart_Substitute
}

/**
 * @brief Retrieves the selected tank's client index.
 *
 * @return			Client id of the selected tank, -1 if no one is selected.
 */
native int GetTankSelection();

/**
 * @brief Retrieves the active tracked Tank id.
 *
 * @return			Active Tank id, or 0 if none is active.
 */
native int TankControl_GetActiveTankId();

/**
 * @brief Retrieves the current Tank controller client index.
 *
 * @return			Current Tank client index, or -1 if no Tank is active.
 */
native int TankControl_GetCurrentTankClient();

/**
 * @brief Retrieves the pending queued Tank client index.
 *
 * @return			Pending queued Tank client index, or -1 if no queued player is available.
 */
native int TankControl_GetPendingTankClient();

/**
 * @brief Retrieves the active Tank id associated with a client.
 *
 * A client is associated if it is the current Tank controller or the queued player
 * for the active Tank.
 *
 * @param client	Client index to query.
 * @return			Active Tank id for this client, or 0 if none matches.
 */
native int TankControl_GetClientTankId(int client);

/**
 * @brief Returns whether a tracked Tank id represents a substitute Tank.
 *
 * @param tankId	Tracked Tank id to query.
 * @return			True if the Tank is a substitute, false otherwise.
 */
native bool TankControl_IsSubstituteTank(int tankId);

/**
 * @brief Retrieves the parent Tank id for a tracked substitute Tank.
 *
 * @param tankId	Tracked Tank id to query.
 * @return			Parent Tank id, or 0 if this Tank has no parent.
 */
native int TankControl_GetParentTankId(int tankId);

/**
 * @brief Retrieves the semantic start reason for a tracked Tank.
 *
 * @param tankId	Tracked Tank id to query.
 * @return			Start reason for this Tank, or TankControlStart_Unknown if it does not match.
 */
native TankControlStartReason TankControl_GetTankStartReason(int tankId);

/**
 * @brief Called before the plugin finalizes who should receive the Tank from the AI.
 *
 * @param sQueuedTank	Steam2 id override buffer for the queued Tank player.
 */
forward void TankControl_OnTryOfferingTankBot(char sQueuedTank[64]);

/**
 * @brief Called when the plugin selects a queued Tank player.
 *
 * @param sQueuedTank	Steam2 id override buffer for the queued Tank player.
 */
forward void TankControl_OnTankSelection(char sQueuedTank[64]);

/**
 * @brief Called when a new tracked Tank starts.
 *
 * @param tankId		Stable tracked id for this Tank.
 * @param client		Client index currently holding the Tank.
 * @param isBot			True if the Tank controller is AI.
 */
forward void TankControl_OnTankStarted(int tankId, int client, bool isBot);

/**
 * @brief Called when a new tracked Tank starts, including substitute metadata.
 *
 * @param tankId		Stable tracked id for this Tank.
 * @param client		Client index currently holding the Tank.
 * @param isBot			True if the Tank controller is AI.
 * @param startReason	Semantic start reason for this Tank.
 * @param parentTankId	Parent Tank id if this Tank is a substitute, otherwise 0.
 */
forward void TankControl_OnTankStartedEx(int tankId, int client, bool isBot, TankControlStartReason startReason, int parentTankId);

/**
 * @brief Called when control of the tracked Tank changes.
 *
 * @param tankId		Stable tracked id for this Tank.
 * @param oldClient		Previous Tank controller client index, or -1 if none.
 * @param newClient		New Tank controller client index, or -1 if none.
 * @param oldWasBot		True if the previous controller was AI.
 * @param newWasBot		True if the new controller was AI.
 */
forward void TankControl_OnTankControlChanged(int tankId, int oldClient, int newClient, bool oldWasBot, bool newWasBot);

/**
 * @brief Called when the tracked Tank ends.
 *
 * @param tankId		Stable tracked id for this Tank.
 * @param reason		Terminal reason for the Tank ending.
 */
forward void TankControl_OnTankEnded(int tankId, TankControlEndReason reason);

public SharedPlugin __pl_l4d_tank_control_eq =
{
	name = LIBRARY_L4D_TANK_CONTROL_EQ,
	file = "l4d_tank_control_eq.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d_tank_control_eq_SetNTVOptional()
{
	MarkNativeAsOptional("GetTankSelection");
	MarkNativeAsOptional("TankControl_GetActiveTankId");
	MarkNativeAsOptional("TankControl_GetCurrentTankClient");
	MarkNativeAsOptional("TankControl_GetPendingTankClient");
	MarkNativeAsOptional("TankControl_GetClientTankId");
	MarkNativeAsOptional("TankControl_IsSubstituteTank");
	MarkNativeAsOptional("TankControl_GetParentTankId");
	MarkNativeAsOptional("TankControl_GetTankStartReason");
}
#endif
