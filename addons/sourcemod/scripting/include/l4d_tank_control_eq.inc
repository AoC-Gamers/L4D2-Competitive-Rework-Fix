#if defined _l4d_tank_control_eq_included
	#endinput
#endif
#define _l4d_tank_control_eq_included

#define LIBRARY_L4D_TANK_CONTROL_EQ "l4d_tank_control_eq"

/**
 * @brief Terminal reasons for a tracked Tank lifecycle.
 */
enum TankControlLifecycleEndReason
{
	TankControlLifecycleEnd_None = 0,
	TankControlLifecycleEnd_TankDied,
	TankControlLifecycleEnd_RoundEnded
}

/**
 * @brief Retrieves the selected tank's client index.
 *
 * @return			Client id of the selected tank, -1 if no one is selected.
 */
native int GetTankSelection();

/**
 * @brief Retrieves the active tracked Tank lifecycle id.
 *
 * @return			Active Tank lifecycle id, or 0 if none is active.
 */
native int TankControl_GetActiveTankLifecycleId();

/**
 * @brief Retrieves the current Tank controller client index.
 *
 * @return			Current Tank client index, or -1 if no lifecycle is active.
 */
native int TankControl_GetCurrentTankClient();

/**
 * @brief Retrieves the pending queued Tank client index.
 *
 * @return			Pending queued Tank client index, or -1 if no queued player is available.
 */
native int TankControl_GetPendingTankClient();

/**
 * @brief Retrieves the active Tank lifecycle id associated with a client.
 *
 * A client is associated if it is the current Tank controller or the queued player
 * for the active lifecycle.
 *
 * @param client	Client index to query.
 * @return			Active Tank lifecycle id for this client, or 0 if none matches.
 */
native int TankControl_GetClientTankLifecycleId(int client);

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
 * @brief Called when a new tracked Tank lifecycle starts.
 *
 * @param lifecycleId	Internal lifecycle id for this Tank.
 * @param client		Client index currently holding the Tank.
 * @param isBot			True if the Tank controller is AI.
 */
forward void TankControl_OnTankLifecycleStarted(int lifecycleId, int client, bool isBot);

/**
 * @brief Called when control of the tracked Tank changes.
 *
 * @param lifecycleId	Internal lifecycle id for this Tank.
 * @param oldClient		Previous Tank controller client index, or -1 if none.
 * @param newClient		New Tank controller client index, or -1 if none.
 * @param oldWasBot		True if the previous controller was AI.
 * @param newWasBot		True if the new controller was AI.
 */
forward void TankControl_OnTankControlChanged(int lifecycleId, int oldClient, int newClient, bool oldWasBot, bool newWasBot);

/**
 * @brief Called when the tracked Tank lifecycle ends.
 *
 * @param lifecycleId	Internal lifecycle id for this Tank.
 * @param reason		Terminal reason for the lifecycle ending.
 */
forward void TankControl_OnTankLifecycleEnded(int lifecycleId, TankControlLifecycleEndReason reason);

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
	MarkNativeAsOptional("TankControl_GetActiveTankLifecycleId");
	MarkNativeAsOptional("TankControl_GetCurrentTankClient");
	MarkNativeAsOptional("TankControl_GetPendingTankClient");
	MarkNativeAsOptional("TankControl_GetClientTankLifecycleId");
}
#endif
