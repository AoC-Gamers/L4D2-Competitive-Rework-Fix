void InvalidateLegacyEvalCache()
{
	g_LegacyEvalCache.dirty = true;
}

void RefreshLegacyEvalCache()
{
	if (!g_LegacyEvalCache.dirty)
	{
		return;
	}

	if (!SMPlus_IsScoremodSupported())
	{
		g_LegacyEvalCache.aliveCount = 0;
		g_LegacyEvalCache.averageHealth = 0.0;
		g_LegacyEvalCache.survivalBonus = 0;
		g_LegacyEvalCache.dirty = false;
		return;
	}

	int	  totalHealth = 0;
	int	  totalTempHealth[3] = {0, 0, 0};
	float totalAdjustedTempHealth = 0.0;
	bool  isFinale				  = L4D_IsMissionFinalMap();
	int	  currentHealth			  = 0;
	int	  currentTemp			  = 0;
	int	  incapCount			  = 0;
	int	  survivorCount			  = 0;
	int	  aliveCount			  = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsSurvivor(client))
		{
			continue;
		}

		survivorCount++;
		if (!IsPlayerAlive(client))
		{
			continue;
		}

		if (!L4D_IsPlayerIncapacitated(client))
		{
			currentHealth = GetSurvivorPermanentHealth(client);
			currentTemp	  = GetSurvivorTemporaryHealth(client);
			incapCount	  = ClampInt(L4D_GetPlayerReviveCount(client), 0, 2);

			if (HasMedkit(client))
			{
				currentHealth = RoundToFloor(currentHealth + ((100 - currentHealth) * g_LegacyConfig.firstAidHealPercent));
				currentTemp	  = 0;
				incapCount	  = 0;
			}

			if (HasPills(client))
			{
				currentTemp += g_LegacyConfig.pillsHealthValue;
			}
			else if (HasAdrenaline(client))
			{
				currentTemp += g_LegacyConfig.adrenalineHealthBuffer;
			}

			if ((currentTemp + currentHealth) > 100)
			{
				currentTemp = 100 - currentHealth;
			}

			aliveCount++;
			totalHealth += currentHealth;
			totalTempHealth[incapCount] += currentTemp;
		}
		else if (!isFinale)
		{
			aliveCount++;
		}
	}

	for (int i = 0; i < sizeof(totalTempHealth); i++)
	{
		totalAdjustedTempHealth += totalTempHealth[i] * g_LegacyConfig.tempMulti[i];
	}

	g_LegacyEvalCache.aliveCount = aliveCount;
	g_LegacyEvalCache.averageHealth = survivorCount < 1 ? 0.0 : (float(totalHealth) + totalAdjustedTempHealth) / float(survivorCount);
	g_LegacyEvalCache.survivalBonus = RoundToFloor(g_LegacyEvalCache.averageHealth * g_LegacyConfig.mapMulti * g_LegacyConfig.healthBonusRatio + 400.0 * g_LegacyConfig.mapMulti * g_LegacyConfig.survivalBonusRatio);
	g_LegacyEvalCache.dirty = false;
}

int CalculateLegacySurvivalBonus()
{
	if (!SMPlus_IsScoremodSupported())
	{
		return 0;
	}

	RefreshLegacyEvalCache();
	return g_LegacyEvalCache.survivalBonus;
}

float GetClientLegacyBonus(int client)
{
	if (!SMPlus_IsScoremodSupported())
	{
		return 0.0;
	}

	int aliveCount = 0;

	if (!IsClientEligibleForLegacyBonus(client))
	{
		return 0.0;
	}

	RefreshLegacyEvalCache();
	aliveCount = g_LegacyEvalCache.aliveCount;
	if (aliveCount < 1)
	{
		return 0.0;
	}

	return float(g_LegacyEvalCache.survivalBonus) / float(aliveCount);
}

int GetLegacyMaxBonus()
{
	if (!SMPlus_IsScoremodSupported())
	{
		return 0;
	}

	return RoundToFloor(400.0 * g_LegacyConfig.mapMulti * (g_LegacyConfig.healthBonusRatio + g_LegacyConfig.survivalBonusRatio));
}

int GetLegacyCurrentRoundFinalBonus(int &aliveCount = 0)
{
	if (!SMPlus_IsScoremodSupported())
	{
		aliveCount = 0;
		return 0;
	}

	RefreshLegacyEvalCache();
	aliveCount = g_LegacyEvalCache.aliveCount;
	int score = g_LegacyEvalCache.survivalBonus;
	return score ? score * aliveCount : 0;
}

int GetLegacyCustomMapMaxScore()
{
	return g_Runtime.hasL4D2Lib ? L4D2_GetMapValueInt("max_distance", -1) : -1;
}
