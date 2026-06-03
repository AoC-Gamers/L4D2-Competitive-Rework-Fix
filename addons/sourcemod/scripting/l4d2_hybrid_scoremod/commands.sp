Action CmdBonus(int client, int args)
{
	char  sCmdType[64];
	float fHealthBonus	 = 0.0;
	float fDamageBonus	 = 0.0;
	float fPillsBonus	 = 0.0;
	float fMaxPillsBonus = 0.0;

	if (!SMPlus_IsScoremodSupported() || g_Runtime.roundOver || !client)
	{
		return Plugin_Handled;
	}

	GetCmdArg(1, sCmdType, sizeof(sCmdType));

	fHealthBonus   = GetSurvivorHealthBonus();
	fDamageBonus   = GetSurvivorDamageBonus();
	fPillsBonus	   = GetSurvivorPillBonus();
	fMaxPillsBonus = float(g_iPillWorth * g_iTeamSize);

	if (StrEqual(sCmdType, "full"))
	{
		if (GameRules_GetProp("m_bInSecondHalfOfRound"))
		{
			CPrintToChat(client, "%t %t", "Tag", "RoundBonusSummary", 1, RoundToFloor(g_fSurvivorBonus[0]), RoundToFloor(g_fMapBonus + fMaxPillsBonus), CalculateBonusPercent(g_fSurvivorBonus[0]), g_sSurvivorState[0]);
		}

		CPrintToChat(client, "%t %t", "Tag", "RoundBonusFull", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus), CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, g_fMapHealthBonus + g_fMapDamageBonus + fMaxPillsBonus), RoundToFloor(fHealthBonus), CalculateBonusPercent(fHealthBonus, g_fMapHealthBonus), RoundToFloor(fDamageBonus), CalculateBonusPercent(fDamageBonus, g_fMapDamageBonus), RoundToFloor(fPillsBonus), CalculateBonusPercent(fPillsBonus, fMaxPillsBonus));
	}
	else if (StrEqual(sCmdType, "lite"))
	{
		CPrintToChat(client, "%t %t", "Tag", "RoundBonusLite", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus), CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, g_fMapHealthBonus + g_fMapDamageBonus + fMaxPillsBonus));
	}
	else
	{
		if (GameRules_GetProp("m_bInSecondHalfOfRound"))
		{
			CPrintToChat(client, "%t %t", "Tag", "RoundBonusSimplePrevious", 1, RoundToFloor(g_fSurvivorBonus[0]), CalculateBonusPercent(g_fSurvivorBonus[0]));
		}

		CPrintToChat(client, "%t %t", "Tag", "RoundBonusSimple", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus), CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, g_fMapHealthBonus + g_fMapDamageBonus + fMaxPillsBonus), CalculateBonusPercent(fHealthBonus, g_fMapHealthBonus), CalculateBonusPercent(fDamageBonus, g_fMapDamageBonus), CalculateBonusPercent(fPillsBonus, fMaxPillsBonus));
	}

	return Plugin_Handled;
}

Action CmdMapInfo(int client, int args)
{
	if (!SMPlus_IsScoremodSupported())
	{
		return Plugin_Handled;
	}

	float fMaxPillsBonus = float(g_iPillWorth * g_iTeamSize);
	float fTotalBonus	 = g_fMapBonus + fMaxPillsBonus;

	CPrintToChat(client, "%t %t", "Tag", "MapInfoTitle", g_iTeamSize, g_iTeamSize);
	CPrintToChat(client, "%t %t", "Tag", "MapInfoDistance", g_iMapDistance);
	CPrintToChat(client, "%t %t", "Tag", "MapInfoTotalBonus", RoundToFloor(fTotalBonus));
	CPrintToChat(client, "%t %t", "Tag", "MapInfoHealthBonus", RoundToFloor(g_fMapHealthBonus), CalculateBonusPercent(g_fMapHealthBonus, fTotalBonus));
	CPrintToChat(client, "%t %t", "Tag", "MapInfoDamageBonus", RoundToFloor(g_fMapDamageBonus), CalculateBonusPercent(g_fMapDamageBonus, fTotalBonus));
	CPrintToChat(client, "%t %t", "Tag", "MapInfoPillsBonus", g_iPillWorth, RoundToFloor(fMaxPillsBonus), CalculateBonusPercent(fMaxPillsBonus, fTotalBonus));
	CPrintToChat(client, "%t %t", "Tag", "MapInfoTiebreaker", g_iPillWorth);

	return Plugin_Handled;
}
