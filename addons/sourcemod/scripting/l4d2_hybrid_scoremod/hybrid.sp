float GetSurvivorHealthBonus()
{
	if (!SMPlus_IsScoremodSupported())
	{
		return 0.0;
	}

	float fHealthBonus		 = 0.0;
	int	  survivorCount		 = 0;
	int	  survivalMultiplier = 0;

	for (int client = 1; client <= MaxClients && survivorCount < g_iTeamSize; client++)
	{
		if (!IsSurvivor(client))
		{
			continue;
		}

		survivorCount++;
		if (IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client) && !IsPlayerLedged(client))
		{
			survivalMultiplier++;
			fHealthBonus += GetSurvivorPermanentHealth(client) * g_fPermHpWorth;
			DebugPrint("Adding %N perm HP contribution: %d perm HP -> %.1f bonus; total: %.1f", client, GetSurvivorPermanentHealth(client), GetSurvivorPermanentHealth(client) * g_fPermHpWorth, fHealthBonus);
		}
	}

	return fHealthBonus / g_iTeamSize * survivalMultiplier;
}

float GetSurvivorDamageBonus()
{
	if (!SMPlus_IsScoremodSupported())
	{
		return 0.0;
	}

	int	  survivalMultiplier = GetAliveSurvivorCount();
	float fDamageBonus		 = (g_fMapTempHealthBonus - float(g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")])) * g_fTempHpWorth / g_iTeamSize * survivalMultiplier;
	DebugPrint("Adding temp HP bonus: %.1f (eligible survivors: %d)", fDamageBonus, survivalMultiplier);
	return (fDamageBonus > 0.0 && survivalMultiplier > 0) ? fDamageBonus : 0.0;
}

float GetSurvivorPillBonus()
{
	if (!SMPlus_IsScoremodSupported())
	{
		return 0.0;
	}

	int pillsBonus	  = 0;
	int survivorCount = 0;

	for (int client = 1; client <= MaxClients && survivorCount < g_iTeamSize; client++)
	{
		if (!IsSurvivor(client))
		{
			continue;
		}

		survivorCount++;
		if (IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client) && HasPills(client))
		{
			pillsBonus += g_iPillWorth;
			DebugPrint("Adding %N pills contribution, total pills bonus: %d pts", client, pillsBonus);
		}
	}

	return float(pillsBonus);
}

float GetRoundMaxBonus()
{
	if (!SMPlus_IsScoremodSupported())
	{
		return 0.0;
	}

	return g_fMapHealthBonus + g_fMapDamageBonus + float(g_iPillWorth * g_iTeamSize);
}

float GetClientTotalBonus(int client)
{
	return GetClientHealthBonus(client) + GetClientDamageBonus(client) + GetClientPillsBonus(client);
}

float GetClientHealthBonus(int client)
{
	int survivalMultiplier = 0;

	if (!IsClientEligibleForBonus(client))
	{
		return 0.0;
	}

	survivalMultiplier = GetAliveSurvivorCount();
	return GetSurvivorPermanentHealth(client) * g_fPermHpWorth / g_iTeamSize * survivalMultiplier;
}

float GetClientDamageBonus(int client)
{
	int survivalMultiplier = 0;

	if (!IsClientEligibleForBonus(client))
	{
		return 0.0;
	}

	survivalMultiplier = GetAliveSurvivorCount();
	if (survivalMultiplier < 1)
	{
		return 0.0;
	}

	return GetSurvivorDamageBonus() / survivalMultiplier;
}

float GetClientPillsBonus(int client)
{
	if (!IsClientEligibleForBonus(client) || !HasPills(client))
	{
		return 0.0;
	}

	return float(g_iPillWorth);
}
