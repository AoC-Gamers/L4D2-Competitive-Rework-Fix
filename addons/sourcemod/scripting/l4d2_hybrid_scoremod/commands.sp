Action CmdBonus(int client, int args)
{
	char	   sCmdType[64];
	char	   sCustomAmount[32];
	char	   sCustomPercent[32];
	int		   author		  = 0;
	SMPlusMode scoreMode	  = GetScoreMode();
	float	   fHealthBonus	  = 0.0;
	float	   fDamageBonus	  = 0.0;
	float	   fPillsBonus	  = 0.0;
	float	   fMaxPillsBonus = 0.0;
	float	   fBaseTotalBonus = 0.0;
	float	   fExternalTotalBonus = 0.0;
	float	   fEffectiveTotalBonus = 0.0;
	float	   fMaxTotalBonus = 0.0;

	if (!SMPlus_IsScoremodSupported() || g_Runtime.roundOver || !client)
	{
		return Plugin_Handled;
	}

	GetCmdArg(1, sCmdType, sizeof(sCmdType));
	author = GetBonusMessageAuthor();

	if (scoreMode == SMPlusMode_Legacy)
	{
		int currentRound = GetLegacyCurrentRoundNumber();
		int maxBonus	 = GetLegacyMaxBonus();
		int currentBonus = GetLegacyCurrentRoundFinalBonus();
		fExternalTotalBonus = GetExternalBonus(SMPlusBonusType_Total);
		FormatSignedBonusValue(sCustomPercent, sizeof(sCustomPercent), CalculateBonusPercent(fExternalTotalBonus, float(maxBonus)), true);

		if (currentRound == 2)
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusSimplePrevious", 1, g_LegacyRound.firstScore, maxBonus, CalculateBonusPercent(float(g_LegacyRound.firstScore), float(maxBonus)));
		}

		currentBonus += RoundToFloor(fExternalTotalBonus);
		if (fExternalTotalBonus != 0.0)
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusLiteCustom", currentRound, currentBonus, maxBonus, CalculateBonusPercent(float(currentBonus), float(maxBonus)), sCustomPercent);
		}
		else
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusLite", currentRound, currentBonus, maxBonus, CalculateBonusPercent(float(currentBonus), float(maxBonus)));
		}
		return Plugin_Handled;
	}

	fHealthBonus   = GetSurvivorHealthBonus();
	fDamageBonus   = GetSurvivorDamageBonus();
	fPillsBonus	   = GetSurvivorPillBonus();
	fMaxPillsBonus = float(g_iPillWorth * g_iTeamSize);
	fBaseTotalBonus = fHealthBonus + fDamageBonus + fPillsBonus;
	fExternalTotalBonus = GetExternalBonus(SMPlusBonusType_Total);
	fEffectiveTotalBonus = fBaseTotalBonus + fExternalTotalBonus;
	fMaxTotalBonus = g_fMapHealthBonus + g_fMapDamageBonus + fMaxPillsBonus;
	FormatSignedBonusValue(sCustomAmount, sizeof(sCustomAmount), fExternalTotalBonus);
	FormatSignedBonusValue(sCustomPercent, sizeof(sCustomPercent), CalculateBonusPercent(fExternalTotalBonus, fMaxTotalBonus), true);

	if (StrEqual(sCmdType, "full"))
	{
		if (GameRules_GetProp("m_bInSecondHalfOfRound"))
		{
			if (fExternalTotalBonus != 0.0)
			{
				PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusSummaryCustom", 1, RoundToFloor(g_fSurvivorBonus[0] + fExternalTotalBonus), RoundToFloor(g_fMapBonus + fMaxPillsBonus), CalculateBonusPercent(g_fSurvivorBonus[0] + fExternalTotalBonus), g_sSurvivorState[0], sCustomPercent);
			}
			else
			{
				PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusSummary", 1, RoundToFloor(g_fSurvivorBonus[0]), RoundToFloor(g_fMapBonus + fMaxPillsBonus), CalculateBonusPercent(g_fSurvivorBonus[0]), g_sSurvivorState[0]);
			}
		}

		if (fExternalTotalBonus != 0.0)
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusFullCustom", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fEffectiveTotalBonus), CalculateBonusPercent(fEffectiveTotalBonus, fMaxTotalBonus), RoundToFloor(fHealthBonus), CalculateBonusPercent(fHealthBonus, g_fMapHealthBonus), RoundToFloor(fDamageBonus), CalculateBonusPercent(fDamageBonus, g_fMapDamageBonus), RoundToFloor(fPillsBonus), CalculateBonusPercent(fPillsBonus, fMaxPillsBonus), sCustomAmount, sCustomPercent);
		}
		else
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusFull", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fBaseTotalBonus), CalculateBonusPercent(fBaseTotalBonus, fMaxTotalBonus), RoundToFloor(fHealthBonus), CalculateBonusPercent(fHealthBonus, g_fMapHealthBonus), RoundToFloor(fDamageBonus), CalculateBonusPercent(fDamageBonus, g_fMapDamageBonus), RoundToFloor(fPillsBonus), CalculateBonusPercent(fPillsBonus, fMaxPillsBonus));
		}
	}
	else if (StrEqual(sCmdType, "lite"))
	{
		if (fExternalTotalBonus != 0.0)
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusLiteCustom", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fEffectiveTotalBonus), RoundToFloor(fMaxTotalBonus), CalculateBonusPercent(fEffectiveTotalBonus, fMaxTotalBonus), sCustomPercent);
		}
		else
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusLite", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fBaseTotalBonus), RoundToFloor(fMaxTotalBonus), CalculateBonusPercent(fBaseTotalBonus, fMaxTotalBonus));
		}
	}
	else
	{
		if (GameRules_GetProp("m_bInSecondHalfOfRound"))
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusSimplePrevious", 1, RoundToFloor(g_fSurvivorBonus[0]), RoundToFloor(g_fMapBonus + fMaxPillsBonus), CalculateBonusPercent(g_fSurvivorBonus[0]));
		}

		if (fExternalTotalBonus != 0.0)
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusSimpleCustom", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fEffectiveTotalBonus), RoundToFloor(fMaxTotalBonus), CalculateBonusPercent(fEffectiveTotalBonus, fMaxTotalBonus), CalculateBonusPercent(fHealthBonus, g_fMapHealthBonus), CalculateBonusPercent(fDamageBonus, g_fMapDamageBonus), CalculateBonusPercent(fPillsBonus, fMaxPillsBonus), sCustomPercent);
		}
		else
		{
			PrintBonusMessage(client, author, "%t %t", "Tag", "RoundBonusSimple", GameRules_GetProp("m_bInSecondHalfOfRound") + 1, RoundToFloor(fBaseTotalBonus), RoundToFloor(fMaxTotalBonus), CalculateBonusPercent(fBaseTotalBonus, fMaxTotalBonus), CalculateBonusPercent(fHealthBonus, g_fMapHealthBonus), CalculateBonusPercent(fDamageBonus, g_fMapDamageBonus), CalculateBonusPercent(fPillsBonus, fMaxPillsBonus));
		}
	}

	return Plugin_Handled;
}

void PrintBonusMessage(int client, int author, const char[] format, any ...)
{
	char message[256];
	VFormat(message, sizeof(message), format, 4);

	if (!ShouldPrintBonusToTeam(client))
	{
		CPrintToChatEx(client, author, "%s", message);
		return;
	}

	L4DTeam team = L4D_GetClientTeam(client);

	for (int teammate = 1; teammate <= MaxClients; teammate++)
	{
		if (!IsClientInGame(teammate) || IsFakeClient(teammate) || L4D_GetClientTeam(teammate) != team)
		{
			continue;
		}

		CPrintToChatEx(teammate, author, "%s", message);
	}
}

bool ShouldPrintBonusToTeam(int client)
{
	if (!g_cvBonusTeamPrint.BoolValue || !IsClientInGame(client) || IsFakeClient(client))
	{
		return false;
	}

	L4DTeam team = L4D_GetClientTeam(client);
	return team == L4DTeam_Survivor || team == L4DTeam_Infected;
}

void FormatSignedBonusValue(char[] buffer, int maxlen, float value, bool asPercent = false)
{
	float absValue = FloatAbs(value);

	if (asPercent)
	{
		FormatEx(buffer, maxlen, "%s%.1f%%", value >= 0.0 ? "+" : "-", absValue);
		return;
	}

	FormatEx(buffer, maxlen, "%s%d", value >= 0.0 ? "+" : "-", RoundToFloor(absValue));
}

Action CmdMapInfo(int client, int args)
{
	int author = 0;

	if (!SMPlus_IsScoremodSupported())
	{
		return Plugin_Handled;
	}

	if (GetScoreMode() == SMPlusMode_Legacy)
	{
		float fTotalBonus = float(GetLegacyMaxBonus());

		author = GetBonusMessageAuthor();
		CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoTitle", g_iTeamSize, g_iTeamSize);
		CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoDistance", g_iMapDistance);
		CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoTotalBonus", RoundToFloor(fTotalBonus));
		CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoTiebreaker", g_iPillWorth);
		return Plugin_Handled;
	}

	float fMaxPillsBonus = float(g_iPillWorth * g_iTeamSize);
	float fTotalBonus	 = g_fMapBonus + fMaxPillsBonus;
	author			   = GetBonusMessageAuthor();

	CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoTitle", g_iTeamSize, g_iTeamSize);
	CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoDistance", g_iMapDistance);
	CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoTotalBonus", RoundToFloor(fTotalBonus));
	CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoHealthBonus", RoundToFloor(g_fMapHealthBonus), CalculateBonusPercent(g_fMapHealthBonus, fTotalBonus));
	CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoDamageBonus", RoundToFloor(g_fMapDamageBonus), CalculateBonusPercent(g_fMapDamageBonus, fTotalBonus));
	CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoPillsBonus", g_iPillWorth, RoundToFloor(fMaxPillsBonus), CalculateBonusPercent(fMaxPillsBonus, fTotalBonus));
	CPrintToChatEx(client, author, "%t %t", "Tag", "MapInfoTiebreaker", g_iPillWorth);

	return Plugin_Handled;
}
