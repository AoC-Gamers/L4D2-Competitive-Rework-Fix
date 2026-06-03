void NotifyMatchFinalized()
{
	int winningTeam = 0;
	int round1Bonus = 0;
	int round2Bonus = 0;

	if (GetScoreMode() == SMPlusMode_Legacy)
	{
		round1Bonus = g_LegacyRound.firstScore;
		round2Bonus = g_LegacyRound.secondRoundOver ? GetLegacyCurrentRoundFinalBonus() : 0;

		if (round1Bonus > round2Bonus)
		{
			winningTeam = 1;
		}
		else if (round2Bonus > round1Bonus)
		{
			winningTeam = 2;
		}

		DebugPrint("Legacy match finalized. winner=%d round1=%d round2=%d", winningTeam, round1Bonus, round2Bonus);
		Call_StartForward(g_fwOnMatchFinalized);
		Call_PushCell(winningTeam);
		Call_Finish();
		return;
	}

	round1Bonus = RoundToFloor(g_fSurvivorBonus[0]);
	round2Bonus = RoundToFloor(g_fSurvivorBonus[1]);

	if (round1Bonus > round2Bonus)
	{
		winningTeam = 1;
	}
	else if (round2Bonus > round1Bonus)
	{
		winningTeam = 2;
	}
	else if (g_iSiDamage[0] < g_iSiDamage[1])
	{
		winningTeam = 1;
	}
	else if (g_iSiDamage[1] < g_iSiDamage[0])
	{
		winningTeam = 2;
	}
	DebugPrint("Match finalized. winner=%d round1=%d round2=%d si1=%d si2=%d", winningTeam, round1Bonus, round2Bonus, g_iSiDamage[0], g_iSiDamage[1]);

	Call_StartForward(g_fwOnMatchFinalized);
	Call_PushCell(winningTeam);
	Call_Finish();
}

void NotifyScoreUpdated()
{
	InvalidateTeamSnapshotCache();
	InvalidateClientSnapshotCache();
	Call_StartForward(g_fwOnScoreUpdated);
	Call_Finish();
}

void NotifyRoundFinalized(int round)
{
	Call_StartForward(g_fwOnRoundFinalized);
	Call_PushCell(round);
	Call_Finish();
}

void ResetAllExternalBonuses()
{
	for (int type = 0; type <= view_as<int>(SMPlusBonusType_Pills); type++)
	{
		g_fExternalTeamBonus[type] = 0.0;
	}

	for (int client = 0; client <= MaxClients; client++)
	{
		for (int type = 0; type <= view_as<int>(SMPlusBonusType_Pills); type++)
		{
			g_fExternalClientBonus[client][type] = 0.0;
		}
	}
}

void ResetExternalBonus(int client = 0)
{
	if (client > 0 && client <= MaxClients)
	{
		for (int type = 0; type <= view_as<int>(SMPlusBonusType_Pills); type++)
		{
			g_fExternalClientBonus[client][type] = 0.0;
		}
	}
	else
	{
		for (int type = 0; type <= view_as<int>(SMPlusBonusType_Pills); type++)
		{
			g_fExternalTeamBonus[type] = 0.0;
		}
	}

	NotifyScoreUpdated();
}

void AddExternalBonus(SMPlusBonusType type, float value, int client = 0)
{
	if (client > 0 && client <= MaxClients)
	{
		g_fExternalClientBonus[client][view_as<int>(type)] += value;
	}
	else
	{
		g_fExternalTeamBonus[view_as<int>(type)] += value;
	}

	NotifyScoreUpdated();
}

void SetExternalBonus(SMPlusBonusType type, float value, int client = 0)
{
	if (client > 0 && client <= MaxClients)
	{
		g_fExternalClientBonus[client][view_as<int>(type)] = value;
	}
	else
	{
		g_fExternalTeamBonus[view_as<int>(type)] = value;
	}

	NotifyScoreUpdated();
}

float GetExternalBonus(SMPlusBonusType type, int client = 0)
{
	if (type == SMPlusBonusType_Total)
	{
		if (client > 0 && client <= MaxClients)
		{
			return g_fExternalClientBonus[client][view_as<int>(SMPlusBonusType_Health)]
				+ g_fExternalClientBonus[client][view_as<int>(SMPlusBonusType_Damage)]
				+ g_fExternalClientBonus[client][view_as<int>(SMPlusBonusType_Pills)];
		}

		return g_fExternalTeamBonus[view_as<int>(SMPlusBonusType_Health)]
			+ g_fExternalTeamBonus[view_as<int>(SMPlusBonusType_Damage)]
			+ g_fExternalTeamBonus[view_as<int>(SMPlusBonusType_Pills)];
	}

	if (client > 0 && client <= MaxClients)
	{
		return g_fExternalClientBonus[client][view_as<int>(type)];
	}

	return g_fExternalTeamBonus[view_as<int>(type)];
}
