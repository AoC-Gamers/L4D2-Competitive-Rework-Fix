void RoundStartEvent(Event event, const char[] name, bool dontBroadcast)
{
	if (!SMPlus_ShouldHandleRoundStartEvent(name))
	{
		return;
	}

	for (int client = 0; client <= MAXPLAYERS; client++)
	{
		g_iTempHealth[client] = 0;
	}

	ResetAllExternalBonuses();
	InvalidateSurvivorCountCache();
	InvalidateLegacyEvalCache();
	InvalidateTeamSnapshotCache();
	InvalidateClientSnapshotCache();
	g_Runtime.tiebreakerEligibility[0] = false;
	g_Runtime.tiebreakerEligibility[1] = false;
	g_Runtime.roundOver				   = false;
	g_Runtime.roundLive				   = (g_Runtime.roundLiveSignal == SMPlusRoundLiveSignal_Immediate);

	if (GetScoreMode() == SMPlusMode_Legacy && g_LegacyRound.firstRoundOver)
	{
		g_LegacyRound.secondRoundStarted = true;
	}
}

void ScavengeRoundStartEvent(Event event, const char[] name, bool dontBroadcast)
{
	RoundStartEvent(event, name, dontBroadcast);
}

void DoorCloseEvent(Event event, const char[] name, bool dontBroadcast)
{
	if (!SMPlus_IsScoremodSupported() || GetScoreMode() != SMPlusMode_Legacy || !g_LegacyConfig.enabled)
	{
		return;
	}

	if (event.GetBool("checkpoint"))
	{
		g_cvValveSurvivalBonus.IntValue = CalculateLegacySurvivalBonus();
		NotifyScoreUpdated();
	}
}

void RoundEndEvent(Event event, const char[] name, bool dontBroadcast)
{
	int aliveCount = 0;
	int score	   = 0;

	if (!SMPlus_ShouldHandleRoundEndEvent(name))
	{
		return;
	}

	if (!SMPlus_IsScoremodSupported() || GetScoreMode() != SMPlusMode_Legacy || !g_LegacyConfig.enabled)
	{
		g_Runtime.roundOver = true;
		InvalidateTeamSnapshotCache();
		InvalidateClientSnapshotCache();
		return;
	}

	if (!g_LegacyRound.firstRoundOver)
	{
		g_LegacyRound.firstRoundOver = true;
		g_cvValveSurvivalBonus.IntValue = CalculateLegacySurvivalBonus();
		score					= GetLegacyCurrentRoundFinalBonus();
		g_LegacyRound.firstScore		= score;
		g_Runtime.roundOver = true;
		InvalidateTeamSnapshotCache();
		InvalidateClientSnapshotCache();
		NotifyRoundFinalized(1);
	}
	else if (g_LegacyRound.secondRoundStarted && !g_LegacyRound.secondRoundOver)
	{
		g_LegacyRound.secondRoundOver = true;
		g_cvValveSurvivalBonus.IntValue = CalculateLegacySurvivalBonus();
		score					 = GetLegacyCurrentRoundFinalBonus(aliveCount);
		g_LegacyRound.difference		 = g_LegacyRound.firstScore - score;
		if (score > g_LegacyRound.firstScore)
		{
			g_LegacyRound.difference = (~g_LegacyRound.difference) + 1;
		}

		g_Runtime.roundOver = true;
		InvalidateTeamSnapshotCache();
		InvalidateClientSnapshotCache();
		NotifyRoundFinalized(2);
		NotifyMatchFinalized();
	}
}

void ScavengeRoundFinishedEvent(Event event, const char[] name, bool dontBroadcast)
{
	RoundEndEvent(event, name, dontBroadcast);
}

void ScavengeMatchFinishedEvent(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Runtime.baseMode == GAMEMODE_SCAVENGE)
	{
		g_Runtime.roundOver = true;
		InvalidateTeamSnapshotCache();
		InvalidateClientSnapshotCache();
	}
}

void OnPlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Runtime.roundLiveSignal == SMPlusRoundLiveSignal_SafeArea
		|| g_Runtime.roundLiveSignal == SMPlusRoundLiveSignal_ReadyUpOrSafeArea)
	{
		if (!g_Runtime.hasReadyUp || g_Runtime.roundLiveSignal == SMPlusRoundLiveSignal_SafeArea)
		{
			g_Runtime.roundLive = true;
			InvalidateTeamSnapshotCache();
			InvalidateClientSnapshotCache();
		}
	}
}

void FinaleVehicleLeavingEvent(Event event, const char[] name, bool dontBroadcast)
{
	if (!SMPlus_IsScoremodSupported() || GetScoreMode() != SMPlusMode_Legacy || !g_LegacyConfig.enabled)
	{
		return;
	}

	g_cvValveSurvivalBonus.IntValue = CalculateLegacySurvivalBonus();
	NotifyScoreUpdated();
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType)
{
	int team = GameRules_GetProp("m_bInSecondHalfOfRound");
	int tempHealth = 0;

	if (!SMPlus_IsScoremodSupported() || !IsSurvivor(victim) || L4D_IsPlayerIncapacitated(victim))
	{
		return Plugin_Continue;
	}

	tempHealth = GetSurvivorTemporaryHealth(victim);
	if (tempHealth > 0)
	{
		DebugPrint("%N temp HP: %d (damage: %.1f)", victim, tempHealth, damage);
	}

	g_iTempHealth[victim] = tempHealth;

	if (!IsAnyInfected(attacker))
	{
		g_iSiDamage[team] += (damage <= 100.0) ? RoundFloat(damage) : 100;
	}

	return Plugin_Continue;
}

void OnPlayerLedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
	if (!SMPlus_IsScoremodSupported())
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	InvalidateSurvivorCountCache();
	InvalidateLegacyEvalCache();
	g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += L4D2Direct_GetPreIncapHealthBuffer(client);
	NotifyScoreUpdated();
}

void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	InvalidateSurvivorCountCache();
	InvalidateLegacyEvalCache();

	if (!SMPlus_IsScoremodSupported())
	{
		return;
	}

	if (GetScoreMode() == SMPlusMode_Legacy)
	{
		if (g_LegacyConfig.enabled && IsSurvivor(victim))
		{
			g_cvValveSurvivalBonus.IntValue = CalculateLegacySurvivalBonus();
			NotifyScoreUpdated();
		}
		return;
	}

	if (!IsZoneModeEnabled() || !IsSurvivor(victim) || g_Runtime.roundOver)
	{
		return;
	}

	int incaps			= L4D_GetPlayerReviveCount(victim);
	int standardPenalty = RoundToFloor((g_fMapDamageBonus / 100.0) * 5.0 / g_fTempHpWorth);
	int penalty			= 0;

	for (int loops = 2 - incaps; loops > 0; loops--)
	{
		penalty += standardPenalty + 30;
	}

	g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += penalty;
	DebugPrint("Zone death penalty for %N: incaps=%d penalty=%d", victim, incaps, penalty);
	NotifyScoreUpdated();
}

void OnPlayerIncapped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	InvalidateSurvivorCountCache();
	InvalidateLegacyEvalCache();

	if (!SMPlus_IsScoremodSupported() || GetScoreMode() != SMPlusMode_Zone || !IsSurvivor(client))
	{
		return;
	}

	g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += RoundToFloor((g_fMapDamageBonus / 100.0) * 5.0 / g_fTempHpWorth);
	DebugPrint("Zone incap penalty applied to %N", client);
	NotifyScoreUpdated();
}

void OnPlayerRevived(Event event, const char[] name, bool dontBroadcast)
{
	int client = 0;

	if (!event.GetBool("ledge_hang"))
	{
		return;
	}

	client = GetClientOfUserId(event.GetInt("subject"));
	if (!IsSurvivor(client))
	{
		return;
	}
	InvalidateSurvivorCountCache();
	InvalidateLegacyEvalCache();

	if (!SMPlus_IsScoremodSupported())
	{
		return;
	}

	if (GetScoreMode() == SMPlusMode_Legacy)
	{
		NotifyScoreUpdated();
		return;
	}

	RequestFrame(Revival, client);
}

void Revival(int client)
{
	InvalidateSurvivorCountCache();
	InvalidateLegacyEvalCache();
	g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] -= GetSurvivorTemporaryHealth(client);
	NotifyScoreUpdated();
}

void OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim	   = GetClientOfUserId(event.GetInt("userid"));
	int attacker   = GetClientOfUserId(event.GetInt("attacker"));
	int damage	   = event.GetInt("dmg_health");
	int damageType = event.GetInt("type");
	int fakeDamage = damage;
	int tempHealth = 0;

	if (!SMPlus_IsScoremodSupported() || GetScoreMode() == SMPlusMode_Legacy)
	{
		return;
	}

	if (!IsSurvivor(victim) || !IsSurvivor(attacker) || L4D_IsPlayerIncapacitated(victim) || damageType != DMG_PLASMA || fakeDamage < GetSurvivorPermanentHealth(victim))
	{
		return;
	}

	tempHealth = GetSurvivorTemporaryHealth(victim);
	g_iTempHealth[victim] = tempHealth;
	if (fakeDamage > tempHealth)
	{
		fakeDamage = tempHealth;
	}

	g_iLostTempHealth[GameRules_GetProp("m_bInSecondHalfOfRound")] += fakeDamage;
	g_iTempHealth[victim] = tempHealth - fakeDamage;
	NotifyScoreUpdated();
}

void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damageType)
{
	int team = 0;
	int currentTempHealth = 0;
	int lostTempHealth = 0;

	if (!SMPlus_IsScoremodSupported() || GetScoreMode() == SMPlusMode_Legacy || !IsSurvivor(victim))
	{
		return;
	}

	team = GameRules_GetProp("m_bInSecondHalfOfRound");
	currentTempHealth = IsPlayerAlive(victim) ? GetSurvivorTemporaryHealth(victim) : 0;
	lostTempHealth = g_iTempHealth[victim] - currentTempHealth;

	DebugPrint("%N lost %i temp HP after being attacked (damage: %.1f)", victim, lostTempHealth, damage);

	if (!IsPlayerAlive(victim) || (L4D_IsPlayerIncapacitated(victim) && !IsPlayerLedged(victim)))
	{
		g_iLostTempHealth[team] += g_iTempHealth[victim];
	}
	else if (!IsPlayerLedged(victim))
	{
		g_iLostTempHealth[team] += g_iTempHealth[victim] ? lostTempHealth : 0;
	}

	g_iTempHealth[victim] = L4D_IsPlayerIncapacitated(victim) ? 0 : currentTempHealth;
	NotifyScoreUpdated();
}

public void L4D2_ADM_OnTemporaryHealthSubtracted(int client, int oldHealth, int newHealth)
{
	int healthLost = oldHealth - newHealth;
	int team	   = GameRules_GetProp("m_bInSecondHalfOfRound");

	if (!SMPlus_IsScoremodSupported() || GetScoreMode() == SMPlusMode_Legacy)
	{
		return;
	}

	g_iTempHealth[client] = newHealth;
	g_iLostTempHealth[team] += healthLost;
	g_iSiDamage[team] += healthLost;
	NotifyScoreUpdated();
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	int team			   = 0;
	int survivalMultiplier = 0;

	if (!SMPlus_IsScoremodSupported() || GetScoreMode() == SMPlusMode_Legacy)
	{
		return Plugin_Continue;
	}

	DebugPrint("CDirector::OnEndVersusModeRound() called. InSecondHalfOfRound(): %d, countSurvivors: %d", GameRules_GetProp("m_bInSecondHalfOfRound"), countSurvivors);

	if (g_Runtime.roundOver)
	{
		return Plugin_Continue;
	}

	team				   = GameRules_GetProp("m_bInSecondHalfOfRound");
	survivalMultiplier	   = countSurvivors ? GetAliveSurvivorCount(false) : 0;
	g_fSurvivorBonus[team] = GetSurvivorHealthBonus() + GetSurvivorDamageBonus() + GetSurvivorPillBonus();
	g_fSurvivorBonus[team] = float(RoundToFloor(g_fSurvivorBonus[team] / float(g_iTeamSize)) * g_iTeamSize);

	if (survivalMultiplier > 0 && RoundToFloor(g_fSurvivorBonus[team] / survivalMultiplier) >= g_iTeamSize)
	{
		g_cvValveSurvivalBonus.IntValue = RoundToFloor(g_fSurvivorBonus[team] / survivalMultiplier);
		g_fSurvivorBonus[team]			= float(g_cvValveSurvivalBonus.IntValue * survivalMultiplier);
		Format(g_sSurvivorState[team], sizeof(g_sSurvivorState[]), "%s%i{default}/{green}%i{default}", (survivalMultiplier == g_iTeamSize ? "{green}" : "{olive}"), survivalMultiplier, g_iTeamSize);
		DebugPrint("Survival bonus cvar updated. Value: %i [multiplier: %i]", g_cvValveSurvivalBonus.IntValue, survivalMultiplier);
	}
	else
	{
		g_fSurvivorBonus[team]			= 0.0;
		g_cvValveSurvivalBonus.IntValue = 0;
		Format(g_sSurvivorState[team], sizeof(g_sSurvivorState[]), "%s", (survivalMultiplier == 0 ? "{olive}wiped out{default}" : "{olive}bonus depleted{default}"));
		g_Runtime.tiebreakerEligibility[team] = (survivalMultiplier == g_iTeamSize);
	}

	if (team > 0 && g_Runtime.tiebreakerEligibility[0] && g_Runtime.tiebreakerEligibility[1])
	{
		GameRules_SetProp("m_iChapterDamage", g_iSiDamage[0], _, 0, true);
		GameRules_SetProp("m_iChapterDamage", g_iSiDamage[1], _, 1, true);

		if (g_iSiDamage[0] != g_iSiDamage[1])
		{
			g_cvValveTieBreaker.IntValue = g_iPillWorth;
		}
	}

	if (team > 0)
	{
		NotifyRoundFinalized(team + 1);
		NotifyMatchFinalized();
	}

	CreateTimer(3.0, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
	g_Runtime.roundOver = true;
	return Plugin_Continue;
}

Action PrintRoundEndStats(Handle timer)
{
	for (int team = 0; team <= GameRules_GetProp("m_bInSecondHalfOfRound"); team++)
	{
		CPrintToChatAll("%t %t", "Tag", "RoundBonusSummary", team + 1, RoundToFloor(g_fSurvivorBonus[team]), RoundToFloor(g_fMapBonus + float(g_iPillWorth * g_iTeamSize)), CalculateBonusPercent(g_fSurvivorBonus[team]), g_sSurvivorState[team]);
	}

	if (GameRules_GetProp("m_bInSecondHalfOfRound") && g_Runtime.tiebreakerEligibility[0] && g_Runtime.tiebreakerEligibility[1])
	{
		CPrintToChatAll("%t %t", "Tag", "TiebreakerScores", g_iSiDamage[0], g_iSiDamage[1]);
		if (g_iSiDamage[0] == g_iSiDamage[1])
		{
			CPrintToChatAll("%t %t", "Tag", "TiebreakerEqual");
		}
	}

	return Plugin_Stop;
}
