/**
 * @brief Converts an integer ratio to a percentage value.
 *
 * @param value Numerator value
 * @param max Denominator value
 * @return Percentage in the range 0.0 to 100.0
 */
stock float PercentFloat(int value, int max)
{
	if (max <= 0)
	{
		return 0.0;
	}

	return (float(value) / float(max)) * 100.0;
}

/**
 * @brief Returns the greater of two integers.
 *
 * @param a First value
 * @param b Second value
 * @return The greater integer
 */
stock int MaxInt(int a, int b)
{
	return (a > b) ? a : b;
}

/**
 * @brief Checks whether a client index is within the valid client range.
 *
 * @param client Client index to validate
 * @return True if the index is valid, false otherwise
 */
stock bool IsValidClientIndex(int client)
{
	return (client > 0 && client <= MaxClients);
}

/**
 * @brief Reads the next activation timer for an infected ability.
 *
 * @param client Client index to inspect
 * @param timestamp Receives the ability timer timestamp
 * @param duration Receives the ability timer duration
 * @return True when the client has a valid tracked ability, false otherwise
 */
stock bool GetInfectedAbilityTimer(int client, float &timestamp, float &duration)
{
	switch (L4D2_GetPlayerZombieClass(client))
	{
		case L4D2ZombieClass_Smoker, L4D2ZombieClass_Boomer, L4D2ZombieClass_Hunter, L4D2ZombieClass_Spitter, L4D2ZombieClass_Jockey, L4D2ZombieClass_Charger:
		{
			int ability = L4D_GetPlayerCustomAbility(client);
			if (ability == -1 || !IsValidEntity(ability))
			{
				return false;
			}

			duration = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", 0);
			timestamp = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", 1);
			return true;
		}
	}

	return false;
}

/**
 * @brief Returns whether the round is in the second half.
 *
 * @return True when the current round is in the second half, false otherwise
 */
stock bool InSecondHalfOfRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

/**
 * @brief Returns the revive count for a survivor.
 *
 * @param client Client index to inspect
 * @return Current revive count
 */
stock int GetSurvivorIncapCount(int client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

/**
 * @brief Checks whether a survivor is hanging from a ledge.
 *
 * @param client Client index to inspect
 * @return True if the survivor is hanging from a ledge, false otherwise
 */
stock bool IsHangingFromLedge(int client)
{
	return (L4D_IsPlayerHangingFromLedge(client)
		|| view_as<bool>(GetEntProp(client, Prop_Send, "m_isFallingFromLedge", 1)));
}

/**
 * @brief Identifies the playable survivor by model gender index.
 *
 * @param client Client index to inspect
 * @return Survivor identity index, or 8 when unknown
 */
stock int IdentifySurvivor(int client)
{
	if (!IsValidClientIndex(client) || !IsClientInGame(client))
	{
		return 8;
	}

	switch (GetEntProp(client, Prop_Send, "m_Gender"))
	{
		case 7:  return 0; // Nick
		case 8:  return 1; // Rochelle
		case 9:  return 2; // Coach
		case 10: return 3; // Ellis
		case 3:  return 4; // Bill
		case 4:  return 5; // Zoey
		case 5:  return 6; // Francis
		case 6:  return 7; // Louis
	}

	return 8;
}

/**
 * @brief Returns reserve ammo for a weapon.
 *
 * @param client Client index owning the weapon
 * @param weapon Weapon entity index
 * @return Reserve ammo, or -1 when the weapon is invalid
 */
stock int GetWeaponExtraAmmo(int client, int weapon)
{
	if (weapon <= 0)
	{
		return -1;
	}

	return L4D_GetReserveAmmo(client, weapon);
}

/**
 * @brief Returns the current clip ammo for a weapon.
 *
 * @param weapon Weapon entity index
 * @return Clip ammo, or -1 when the weapon is invalid
 */
stock int GetWeaponClipAmmo(int weapon)
{
	return (weapon > 0 ? GetEntProp(weapon, Prop_Send, "m_iClip1") : -1);
}

/**
 * @brief Reads and normalizes a client name for HUD output.
 *
 * @param client Client index to read
 * @param name Buffer to receive the name
 * @param length Buffer size
 */
stock void GetClientFixedName(int client, char[] name, int length)
{
	GetClientName(client, name, length);

	ValvePanel_ShiftInvalidString(name, length);

	if (strlen(name) > 18)
	{
		name[15] = name[16] = name[17] = '.';
		name[18] = 0;
	}
}

/**
 * @brief Normalizes strings that start with invalid panel characters.
 *
 * @param str String buffer to fix in-place
 * @param maxlen Buffer size
 * @return True when the string was adjusted, false otherwise
 */
stock bool ValvePanel_ShiftInvalidString(char[] str, int maxlen)
{
	switch (str[0])
	{
	case '[':
		{
			char[] temp = new char[maxlen];
			strcopy(temp, maxlen, str) + 1;
			
			int size = strcopy(str[1], maxlen-1, temp) + 1;
			
			str[0] = ' ';
			str[size < maxlen ? size : maxlen-1] = '\0';
			
			return true;
		}
	}
	
	return false;
}

/**
 * @brief Returns the accumulated versus progress distance for a team.
 *
 * @param teamIndex Team index to inspect
 * @return Total versus progress distance
 */
stock int GetVersusProgressDistance(int teamIndex)
{
	int distance = 0;
	for (int i = 0; i < 4; ++i)
	{
		distance += GameRules_GetProp("m_iVersusDistancePerSurvivor", _, i + 4 * teamIndex);
	}
	return distance;
}

/**
 * @brief Fills the round-by-round scavenge score table.
 *
 * @param arr Output score table indexed by team and round
 */
stock void FillScavengeScores(int arr[2][5])
{
	for (int i = 1; i <= GetScavengeRoundLimit(); ++i)
	{
		arr[0][i-1] = GetScavengeTeamScore(0, i);
		arr[1][i-1] = GetScavengeTeamScore(1, i);
	}
}

/**
 * @brief Formats a scavenge round duration for display.
 *
 * @param buffer Buffer to receive the formatted time
 * @param maxlen Buffer size
 * @param teamIndex Team index to inspect
 * @param nodecimalpoint True to omit decimal places
 * @return Number of characters written
 */
stock int FormatScavengeRoundTime(char[] buffer, int maxlen, int teamIndex, bool nodecimalpoint = false)
{
	float seconds = GetScavengeRoundDuration(teamIndex);
	int minutes = RoundToFloor(seconds) / 60;
	seconds -= 60 * minutes;
	
	return nodecimalpoint ?
				Format(buffer, maxlen, "%d:%02.0f", minutes, seconds) :
				Format(buffer, maxlen, "%d:%05.2f", minutes, seconds);
}

/**
 * @brief Returns the current scavenge round duration for a team.
 *
 * @param teamIndex Team index to inspect
 * @return Round duration in seconds
 */
stock float GetScavengeRoundDuration(int teamIndex)
{
	float flRoundStartTime = GameRules_GetPropFloat("m_flRoundStartTime");
	if (teamIndex == view_as<int>(GameRules_GetProp("m_bAreTeamsFlipped")) && flRoundStartTime != 0.0 && GameRules_GetPropFloat("m_flRoundEndTime") == 0.0)
	{
		return GetGameTime() - flRoundStartTime;
	}
	return GameRules_GetPropFloat("m_flRoundDuration", teamIndex);
}

/**
 * @brief Returns a scavenge team's score for a specific round.
 *
 * @param teamIndex Team index to inspect
 * @param round Round number, or current round when omitted
 * @return Round score for the selected team
 */
stock int GetScavengeTeamScore(int teamIndex, int round=-1)
{
	if (!(1 <= round <= 5))
	{
		round = GameRules_GetProp("m_nRoundNumber");
	}
	return GameRules_GetProp("m_iScavengeTeamScore", _, (2*(round-1)) + teamIndex);
}

/**
 * @brief Returns the current scavenge match score for a team.
 *
 * @param teamIndex Team index to inspect
 * @return Match score for the selected team
 */
stock int GetScavengeMatchScore(int teamIndex)
{
	return GameRules_GetProp("m_iScavengeMatchScore", _, teamIndex);
}

/**
 * @brief Returns the current scavenge round number.
 *
 * @return Current round number
 */
stock int GetScavengeRoundNumber()
{
	return GameRules_GetProp("m_nRoundNumber");
}

/**
 * @brief Returns the configured scavenge round limit.
 *
 * @return Round limit
 */
stock int GetScavengeRoundLimit()
{
	return GameRules_GetProp("m_nRoundLimit");
}

/**
 * @brief Returns the furthest survivor flow as a percentage.
 *
 * @return Furthest survivor flow percent
 */
stock int GetFurthestSurvivorFlow()
{
	int flow = RoundToNearest(100.0 * (L4D2_GetFurthestSurvivorFlow() + g_fVersusBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	return flow < 100 ? flow : 100;
}

/**
 * @brief Returns the highest survivor flow among living survivors.
 *
 * @return Highest survivor flow percent, or -1 when unavailable
 */
stock int GetHighestSurvivorFlow()
{
	int flow = -1;
	
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0)
	{
		flow = RoundToNearest(100.0 * (L4D2Direct_GetFlowDistance(client) + g_fVersusBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	}
	
	return flow < 100 ? flow : 100;
}

/**
 * @brief Returns the round tank flow percent.
 *
 * @return Tank flow percent for the current round
 */
stock int GetRoundTankFlow()
{
	return RoundToNearest(L4D2Direct_GetVSTankFlowPercent(view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"))) + g_fVersusBossBuffer / L4D2Direct_GetMapMaxFlowDistance());
}

/**
 * @brief Returns the round witch flow percent.
 *
 * @return Witch flow percent for the current round
 */
stock int GetRoundWitchFlow()
{
	return RoundToNearest(L4D2Direct_GetVSWitchFlowPercent(view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"))) + g_fVersusBossBuffer / L4D2Direct_GetMapMaxFlowDistance());
}

/**
 * @brief Checks whether the current round can spawn a flow tank.
 *
 * @return True if a flow tank can spawn this round, false otherwise
 */
stock bool RoundHasFlowTank()
{
	return L4D2Direct_GetVSTankToSpawnThisRound(view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound")));
}

/**
 * @brief Checks whether the current round can spawn a flow witch.
 *
 * @return True if a flow witch can spawn this round, false otherwise
 */
stock bool RoundHasFlowWitch()
{
	return L4D2Direct_GetVSWitchToSpawnThisRound(view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound")));
}
