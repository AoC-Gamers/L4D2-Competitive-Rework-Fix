void InvalidateTeamSnapshotCache()
{
	g_TeamSnapshotCache.dirty = true;
}

void InvalidateClientSnapshotCache(int client = 0)
{
	if (client > 0 && client <= MaxClients)
	{
		g_ClientSnapshotCache[client].dirty = true;
		return;
	}

	for (int index = 0; index <= MaxClients; index++)
	{
		g_ClientSnapshotCache[index].dirty = true;
	}
}

void RefreshTeamSnapshotCache()
{
	if (!g_TeamSnapshotCache.dirty)
	{
		return;
	}

	BuildTeamSnapshot(g_TeamSnapshotCache.snapshot);
	g_TeamSnapshotCache.dirty = false;
}

void RefreshClientSnapshotCache(int client)
{
	if (!g_ClientSnapshotCache[client].dirty)
	{
		return;
	}

	BuildClientSnapshot(client, g_ClientSnapshotCache[client].snapshot);
	g_ClientSnapshotCache[client].dirty = false;
}

void FillSnapshotKv(KeyValues kv)
{
	kv.Rewind();
	kv.DeleteKey("bonus");
	kv.DeleteKey("bonus_max");
	kv.DeleteKey("bonus_external");
	kv.DeleteKey("bonus_effective");
	kv.DeleteKey("rounds");
	kv.DeleteKey("legacy");
	kv.DeleteKey("hybrid");
	kv.DeleteKey("clients");
	RefreshTeamSnapshotCache();
	WriteTeamSnapshotToKv(kv, g_TeamSnapshotCache.snapshot);

	kv.JumpToKey("clients", true);
	for (int client = 1; client <= MaxClients; client++)
	{
		char				 key[16];

		if (!IsSurvivor(client))
		{
			continue;
		}

		RefreshClientSnapshotCache(client);
		IntToString(g_ClientSnapshotCache[client].snapshot.userid, key, sizeof(key));
		kv.JumpToKey(key, true);
		WriteClientSnapshotFields(kv, g_ClientSnapshotCache[client].snapshot);
		kv.GoBack();
	}
	kv.GoBack();
}

void FillClientSnapshotKv(int client, KeyValues kv)
{
	char				 scoreModeName[16];

	kv.Rewind();
	kv.DeleteKey("bonus");
	kv.DeleteKey("bonus_max");
	kv.DeleteKey("bonus_external");
	kv.DeleteKey("bonus_effective");
	kv.DeleteKey("rounds");
	kv.DeleteKey("legacy");
	kv.DeleteKey("hybrid");
	kv.DeleteKey("clients");

	RefreshClientSnapshotCache(client);
	GetScoreModeName(scoreModeName, sizeof(scoreModeName));
	kv.SetNum("mode", view_as<int>(GetScoreMode()));
	kv.SetNum("base_mode", g_Runtime.baseMode);
	kv.SetString("score_model", scoreModeName);
	kv.SetNum("round_live", g_Runtime.roundLive);
	kv.SetNum("round_start_signal", view_as<int>(g_Runtime.roundStartSignal));
	kv.SetNum("round_end_signal", view_as<int>(g_Runtime.roundEndSignal));
	kv.SetNum("round_live_signal", view_as<int>(g_Runtime.roundLiveSignal));
	WriteClientSnapshotFields(kv, g_ClientSnapshotCache[client].snapshot);
}

float CalculateBonusPercent(float score, float maxBonus = -1.0)
{
	return score / (maxBonus == -1.0 ? (g_fMapBonus + float(g_iPillWorth * g_iTeamSize)) : maxBonus) * 100.0;
}

void BuildTeamSnapshot(SMPlusTeamSnapshot snapshot)
{
	snapshot.mode			  = GetScoreMode();
	snapshot.teamSize		  = g_iTeamSize;
	snapshot.mapDistance	  = g_iMapDistance;
	snapshot.currentRound	  = GetScoreMode() == SMPlusMode_Legacy ? GetLegacyCurrentRoundNumber() : (GameRules_GetProp("m_bInSecondHalfOfRound") + 1);
	snapshot.roundFinalized	  = GetScoreMode() == SMPlusMode_Legacy ? (g_LegacyRound.firstRoundOver && (snapshot.currentRound == 1 || g_LegacyRound.secondRoundOver)) : g_Runtime.roundOver;
	snapshot.matchFinalized	  = GetScoreMode() == SMPlusMode_Legacy ? g_LegacyRound.secondRoundOver : (g_Runtime.roundOver && GameRules_GetProp("m_bInSecondHalfOfRound"));
	snapshot.aliveSurvivors	  = GetAliveSurvivorCount(false);
	snapshot.uprightSurvivors = GetAliveSurvivorCount();

	if (snapshot.mode == SMPlusMode_Legacy)
	{
		snapshot.pillWorth		  = g_LegacyConfig.pillsHealthValue;
		snapshot.adrenalineWorth  = g_LegacyConfig.adrenalineHealthBuffer;
		snapshot.healthBonus	  = float(CalculateLegacySurvivalBonus());
		snapshot.damageBonus	  = 0.0;
		snapshot.pillsBonus		  = 0.0;
		snapshot.totalBonus		  = snapshot.healthBonus;
		snapshot.maxHealthBonus	  = float(GetLegacyMaxBonus());
		snapshot.maxDamageBonus	  = 0.0;
		snapshot.maxPillsBonus	  = 0.0;
		snapshot.maxTotalBonus	  = snapshot.maxHealthBonus;
		snapshot.roundBonus[0]	  = float(g_LegacyRound.firstScore);
		snapshot.roundBonus[1]	  = g_LegacyRound.secondRoundOver ? float(GetLegacyCurrentRoundFinalBonus()) : 0.0;
		snapshot.roundSIDamage[0] = 0;
		snapshot.roundSIDamage[1] = 0;
		Format(snapshot.roundState1, sizeof(snapshot.roundState1), "%d", g_LegacyRound.firstScore);
		Format(snapshot.roundState2, sizeof(snapshot.roundState2), "%d", g_LegacyRound.secondRoundOver ? RoundToFloor(snapshot.roundBonus[1]) : 0);
	}
	else
	{
		snapshot.pillWorth		 = g_iPillWorth;
		snapshot.adrenalineWorth = 0;
		snapshot.healthBonus	 = GetSurvivorHealthBonus();
		snapshot.damageBonus	 = GetSurvivorDamageBonus();
		snapshot.pillsBonus		 = GetSurvivorPillBonus();
		snapshot.totalBonus		 = snapshot.healthBonus + snapshot.damageBonus + snapshot.pillsBonus;
		snapshot.maxHealthBonus	 = g_fMapHealthBonus;
		snapshot.maxDamageBonus	 = g_fMapDamageBonus;
		snapshot.maxPillsBonus	 = float(g_iPillWorth * g_iTeamSize);
		snapshot.maxTotalBonus	 = GetRoundMaxBonus();

		for (int team = 0; team < 2; team++)
		{
			snapshot.roundBonus[team]	 = g_fSurvivorBonus[team];
			snapshot.roundSIDamage[team] = g_iSiDamage[team];
		}
		strcopy(snapshot.roundState1, sizeof(snapshot.roundState1), g_sSurvivorState[0]);
		strcopy(snapshot.roundState2, sizeof(snapshot.roundState2), g_sSurvivorState[1]);
	}

	snapshot.externalHealthBonus = GetExternalBonus(SMPlusBonusType_Health);
	snapshot.externalDamageBonus = GetExternalBonus(SMPlusBonusType_Damage);
	snapshot.externalPillsBonus = GetExternalBonus(SMPlusBonusType_Pills);
	snapshot.externalTotalBonus = GetExternalBonus(SMPlusBonusType_Total);
	snapshot.effectiveHealthBonus = snapshot.healthBonus + snapshot.externalHealthBonus;
	snapshot.effectiveDamageBonus = snapshot.damageBonus + snapshot.externalDamageBonus;
	snapshot.effectivePillsBonus = snapshot.pillsBonus + snapshot.externalPillsBonus;
	snapshot.effectiveTotalBonus = snapshot.totalBonus + snapshot.externalTotalBonus;
}

void BuildClientSnapshot(int client, SMPlusClientSnapshot snapshot)
{
	SMPlusMode mode			 = GetScoreMode();

	snapshot.client			 = client;
	snapshot.userid			 = GetClientUserId(client);
	snapshot.alive			 = IsPlayerAlive(client);
	snapshot.incapped		 = L4D_IsPlayerIncapacitated(client);
	snapshot.ledged			 = IsPlayerLedged(client);
	snapshot.hasPills		 = HasPills(client);
	snapshot.hasAdrenaline	 = HasAdrenaline(client);
	snapshot.permanentHealth = GetSurvivorPermanentHealth(client);
	snapshot.temporaryHealth = GetSurvivorTemporaryHealth(client);
	snapshot.reviveCount	 = L4D_GetPlayerReviveCount(client);

	if (mode == SMPlusMode_Legacy)
	{
		snapshot.healthBonus = GetClientLegacyBonus(client);
		snapshot.damageBonus = 0.0;
		snapshot.pillsBonus	 = 0.0;
		snapshot.totalBonus	 = snapshot.healthBonus;
	}
	else
	{
		snapshot.healthBonus = GetClientHealthBonus(client);
		snapshot.damageBonus = GetClientDamageBonus(client);
		snapshot.pillsBonus	 = GetClientPillsBonus(client);
		snapshot.totalBonus	 = GetClientTotalBonus(client);
	}

	snapshot.externalHealthBonus = GetExternalBonus(SMPlusBonusType_Health, client);
	snapshot.externalDamageBonus = GetExternalBonus(SMPlusBonusType_Damage, client);
	snapshot.externalPillsBonus = GetExternalBonus(SMPlusBonusType_Pills, client);
	snapshot.externalTotalBonus = GetExternalBonus(SMPlusBonusType_Total, client);
	snapshot.effectiveHealthBonus = snapshot.healthBonus + snapshot.externalHealthBonus;
	snapshot.effectiveDamageBonus = snapshot.damageBonus + snapshot.externalDamageBonus;
	snapshot.effectivePillsBonus = snapshot.pillsBonus + snapshot.externalPillsBonus;
	snapshot.effectiveTotalBonus = snapshot.totalBonus + snapshot.externalTotalBonus;
}

void WriteTeamSnapshotToKv(KeyValues kv, SMPlusTeamSnapshot snapshot)
{
	char scoreModeName[16];

	kv.Rewind();
	kv.DeleteKey("bonus");
	kv.DeleteKey("bonus_max");
	kv.DeleteKey("bonus_external");
	kv.DeleteKey("bonus_effective");
	kv.DeleteKey("rounds");
	kv.DeleteKey("legacy");
	kv.DeleteKey("hybrid");
	kv.DeleteKey("clients");

	GetScoreModeName(scoreModeName, sizeof(scoreModeName));
	kv.SetNum("mode", view_as<int>(snapshot.mode));
	kv.SetNum("base_mode", g_Runtime.baseMode);
	kv.SetString("score_model", scoreModeName);
	kv.SetNum("current_round", snapshot.currentRound);
	kv.SetNum("round_finalized", snapshot.roundFinalized);
	kv.SetNum("round_live", g_Runtime.roundLive);
	kv.SetNum("match_finalized", snapshot.matchFinalized);
	kv.SetNum("round_start_signal", view_as<int>(g_Runtime.roundStartSignal));
	kv.SetNum("round_end_signal", view_as<int>(g_Runtime.roundEndSignal));
	kv.SetNum("round_live_signal", view_as<int>(g_Runtime.roundLiveSignal));
	kv.SetNum("team_size", snapshot.teamSize);
	kv.SetNum("map_distance", snapshot.mapDistance);
	kv.SetNum("alive_survivors", snapshot.aliveSurvivors);
	kv.SetNum("upright_survivors", snapshot.uprightSurvivors);
	kv.SetNum("pill_worth", snapshot.pillWorth);
	kv.SetNum("adrenaline_worth", snapshot.adrenalineWorth);

	kv.JumpToKey("bonus", true);
	kv.SetFloat("health", snapshot.healthBonus);
	kv.SetFloat("damage", snapshot.damageBonus);
	kv.SetFloat("pills", snapshot.pillsBonus);
	kv.SetFloat("total", snapshot.totalBonus);
	kv.GoBack();

	kv.JumpToKey("bonus_max", true);
	kv.SetFloat("health", snapshot.maxHealthBonus);
	kv.SetFloat("damage", snapshot.maxDamageBonus);
	kv.SetFloat("pills", snapshot.maxPillsBonus);
	kv.SetFloat("total", snapshot.maxTotalBonus);
	kv.GoBack();

	kv.JumpToKey("bonus_external", true);
	kv.SetFloat("health", snapshot.externalHealthBonus);
	kv.SetFloat("damage", snapshot.externalDamageBonus);
	kv.SetFloat("pills", snapshot.externalPillsBonus);
	kv.SetFloat("total", snapshot.externalTotalBonus);
	kv.GoBack();

	kv.JumpToKey("bonus_effective", true);
	kv.SetFloat("health", snapshot.effectiveHealthBonus);
	kv.SetFloat("damage", snapshot.effectiveDamageBonus);
	kv.SetFloat("pills", snapshot.effectivePillsBonus);
	kv.SetFloat("total", snapshot.effectiveTotalBonus);
	kv.GoBack();

	kv.JumpToKey("rounds", true);
	kv.SetFloat("round1_bonus", snapshot.roundBonus[0]);
	kv.SetFloat("round2_bonus", snapshot.roundBonus[1]);
	kv.SetString("round1_state", snapshot.roundState1);
	kv.SetString("round2_state", snapshot.roundState2);
	kv.SetNum("round1_si_damage", snapshot.roundSIDamage[0]);
	kv.SetNum("round2_si_damage", snapshot.roundSIDamage[1]);
	kv.GoBack();

	if (snapshot.mode == SMPlusMode_Legacy)
	{
		kv.JumpToKey("legacy", true);
		kv.SetFloat("health_bonus_ratio", g_LegacyConfig.healthBonusRatio);
		kv.SetFloat("survival_bonus_ratio", g_LegacyConfig.survivalBonusRatio);
		kv.SetFloat("temp_multi_0", g_LegacyConfig.tempMulti[0]);
		kv.SetFloat("temp_multi_1", g_LegacyConfig.tempMulti[1]);
		kv.SetFloat("temp_multi_2", g_LegacyConfig.tempMulti[2]);
		kv.SetNum("custom_max_distance", g_LegacyConfig.customMaxDistance);
		kv.GoBack();
	}
	else
	{
		kv.JumpToKey("hybrid", true);
		kv.SetFloat("bonus_per_survivor_multiplier", g_cvBonusPerSurvivorMultiplier.FloatValue);
		kv.SetFloat("permanent_health_proportion", g_cvPermanentHealthProportion.FloatValue);
		kv.SetFloat("pills_hp_factor", g_cvPillsHpFactor.FloatValue);
		kv.SetNum("pills_max_bonus", g_cvPillsMaxBonus.IntValue);
		kv.SetNum("zone_penalties_enabled", snapshot.mode == SMPlusMode_Zone);
		kv.GoBack();
	}

	DebugPrint("Snapshot fill: mode=%d round=%d alive=%d total=%.1f max=%.1f", view_as<int>(snapshot.mode), snapshot.currentRound, snapshot.aliveSurvivors, snapshot.totalBonus, snapshot.maxTotalBonus);
}

void WriteClientSnapshotFields(KeyValues kv, SMPlusClientSnapshot snapshot)
{
	kv.SetNum("client", snapshot.client);
	kv.SetNum("userid", snapshot.userid);
	kv.SetNum("alive", snapshot.alive);
	kv.SetNum("incapped", snapshot.incapped);
	kv.SetNum("ledged", snapshot.ledged);
	kv.SetNum("has_pills", snapshot.hasPills);
	kv.SetNum("has_adrenaline", snapshot.hasAdrenaline);
	kv.SetNum("permanent_health", snapshot.permanentHealth);
	kv.SetNum("temporary_health", snapshot.temporaryHealth);
	kv.SetNum("revive_count", snapshot.reviveCount);
	kv.SetFloat("health_bonus", snapshot.healthBonus);
	kv.SetFloat("damage_bonus", snapshot.damageBonus);
	kv.SetFloat("pills_bonus", snapshot.pillsBonus);
	kv.SetFloat("total_bonus", snapshot.totalBonus);
	kv.SetFloat("external_health_bonus", snapshot.externalHealthBonus);
	kv.SetFloat("external_damage_bonus", snapshot.externalDamageBonus);
	kv.SetFloat("external_pills_bonus", snapshot.externalPillsBonus);
	kv.SetFloat("external_total_bonus", snapshot.externalTotalBonus);
	kv.SetFloat("effective_health_bonus", snapshot.effectiveHealthBonus);
	kv.SetFloat("effective_damage_bonus", snapshot.effectiveDamageBonus);
	kv.SetFloat("effective_pills_bonus", snapshot.effectivePillsBonus);
	kv.SetFloat("effective_total_bonus", snapshot.effectiveTotalBonus);
}
