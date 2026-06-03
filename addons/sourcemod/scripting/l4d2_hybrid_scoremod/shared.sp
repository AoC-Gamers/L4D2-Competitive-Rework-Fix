void SMPlus_BuildCurrentModeContext(SMPlusModeContextData context)
{
	context.Reset();
	context.baseMode = L4D_GetGameModeType();
	context.hasReadyUp = g_Runtime.hasReadyUp;
	context.isVersusMode = context.baseMode == GAMEMODE_VERSUS || context.baseMode == GAMEMODE_SCAVENGE;
}

void SMPlus_GetLifecyclePolicyForContext(SMPlusModeContextData context, SMPlusLifecyclePolicyData policy)
{
	policy.Reset();
	policy.baseMode = context.baseMode;

	switch (context.baseMode)
	{
		case GAMEMODE_COOP:
		{
			policy.roundStartSignal = SMPlusRoundStartSignal_GenericRoundStart;
			policy.roundEndSignal = SMPlusRoundEndSignal_GenericRoundEnd;
			policy.roundLiveSignal = SMPlusRoundLiveSignal_SafeArea;
		}
		case GAMEMODE_VERSUS:
		{
			policy.roundStartSignal = SMPlusRoundStartSignal_GenericRoundStart;
			policy.roundEndSignal = SMPlusRoundEndSignal_GenericRoundEnd;
			policy.roundLiveSignal = context.hasReadyUp ? SMPlusRoundLiveSignal_ReadyUpOrSafeArea : SMPlusRoundLiveSignal_SafeArea;
		}
		case GAMEMODE_SCAVENGE:
		{
			policy.roundStartSignal = SMPlusRoundStartSignal_ScavengeRoundStart;
			policy.roundEndSignal = SMPlusRoundEndSignal_ScavengeRoundFinished;
			policy.roundLiveSignal = SMPlusRoundLiveSignal_Immediate;
		}
		case GAMEMODE_SURVIVAL:
		{
			policy.roundStartSignal = SMPlusRoundStartSignal_GenericRoundStart;
			policy.roundEndSignal = SMPlusRoundEndSignal_GenericRoundEnd;
			policy.roundLiveSignal = SMPlusRoundLiveSignal_Immediate;
		}
		default:
		{
			policy.roundStartSignal = SMPlusRoundStartSignal_GenericRoundStart;
			policy.roundEndSignal = SMPlusRoundEndSignal_GenericRoundEnd;
			policy.roundLiveSignal = SMPlusRoundLiveSignal_Immediate;
		}
	}
}

void SMPlus_RefreshModeContext()
{
	SMPlusModeContextData context;
	SMPlusLifecyclePolicyData policy;
	SMPlus_BuildCurrentModeContext(context);
	SMPlus_GetLifecyclePolicyForContext(context, policy);
	g_Runtime.baseMode = context.baseMode;
	g_Runtime.roundStartSignal = policy.roundStartSignal;
	g_Runtime.roundEndSignal = policy.roundEndSignal;
	g_Runtime.roundLiveSignal = policy.roundLiveSignal;
	InvalidateTeamSnapshotCache();
	InvalidateClientSnapshotCache();
}

bool SMPlus_IsScoremodSupported()
{
	return g_Runtime.baseMode == GAMEMODE_VERSUS;
}

bool SMPlus_ShouldHandleRoundStartEvent(const char[] eventName)
{
	switch (g_Runtime.roundStartSignal)
	{
		case SMPlusRoundStartSignal_ScavengeRoundStart:
		{
			return StrEqual(eventName, "scavenge_round_start", false);
		}
		case SMPlusRoundStartSignal_GenericRoundStart:
		{
			return StrEqual(eventName, "round_start", false);
		}
	}

	return false;
}

bool SMPlus_ShouldHandleRoundEndEvent(const char[] eventName)
{
	switch (g_Runtime.roundEndSignal)
	{
		case SMPlusRoundEndSignal_ScavengeRoundFinished:
		{
			return StrEqual(eventName, "scavenge_round_finished", false);
		}
		case SMPlusRoundEndSignal_GenericRoundEnd:
		{
			return StrEqual(eventName, "round_end", false);
		}
	}

	return false;
}

void DebugPrint(const char[] format, any...)
{
	if (!g_cvDebug.BoolValue)
	{
		return;
	}

	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);
	CPrintToChatAll("{olive}[Hybrid Bonus Debug]{default} %s", buffer);
}

SMPlusMode GetScoreMode()
{
	int mode = g_cvMode.IntValue;

	if (mode <= view_as<int>(SMPlusMode_Legacy))
	{
		return SMPlusMode_Legacy;
	}

	if (mode >= view_as<int>(SMPlusMode_Zone))
	{
		return SMPlusMode_Zone;
	}

	return SMPlusMode_Hybrid;
}

void GetScoreModeName(char[] buffer, int maxlen)
{
	switch (GetScoreMode())
	{
		case SMPlusMode_Zone:
		{
			strcopy(buffer, maxlen, "zone");
			return;
		}
		case SMPlusMode_Hybrid:
		{
			strcopy(buffer, maxlen, "hybrid");
			return;
		}
	}

	strcopy(buffer, maxlen, "legacy");
}

bool IsZoneModeEnabled()
{
	return GetScoreMode() == SMPlusMode_Zone;
}

int GetLegacyCurrentRoundNumber()
{
	if (!g_LegacyRound.firstRoundOver)
	{
		return 1;
	}

	return g_LegacyRound.secondRoundStarted ? 2 : 1;
}

int GetBonusMessageAuthor()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsSurvivor(client) && !IsFakeClient(client))
		{
			return client;
		}
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsSurvivor(client))
		{
			return client;
		}
	}

	return 0;
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && L4D_GetClientTeam(client) == L4DTeam_Survivor;
}

bool IsAnyInfected(int entity)
{
	char className[64];

	if (entity > 0 && entity <= MaxClients)
	{
		return IsClientInGame(entity) && L4D_GetClientTeam(entity) == L4DTeam_Infected;
	}

	if (entity > MaxClients)
	{
		GetEdictClassname(entity, className, sizeof(className));
		if (StrEqual(className, "infected") || StrEqual(className, "witch"))
		{
			return true;
		}
	}

	return false;
}

bool IsPlayerLedged(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

bool IsClientEligibleForBonus(int client)
{
	return IsSurvivor(client) && IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client) && !IsPlayerLedged(client);
}

void InvalidateSurvivorCountCache()
{
	g_SurvivorCountCache.dirty = true;
}

void RefreshSurvivorCountCache()
{
	if (!g_SurvivorCountCache.dirty)
	{
		return;
	}

	int survivorCount = 0;
	int aliveCount	  = 0;
	int uprightCount  = 0;

	for (int client = 1; client <= MaxClients && survivorCount < g_iTeamSize; client++)
	{
		if (!IsSurvivor(client))
		{
			continue;
		}

		survivorCount++;

		if (IsPlayerAlive(client))
		{
			aliveCount++;
		}

		if (!L4D_IsPlayerIncapacitated(client) && !IsPlayerLedged(client))
		{
			uprightCount++;
		}
	}

	g_SurvivorCountCache.alive = aliveCount;
	g_SurvivorCountCache.upright = uprightCount;
	g_SurvivorCountCache.dirty = false;
}

int GetAliveSurvivorCount(bool uprightOnly = true)
{
	RefreshSurvivorCountCache();
	return uprightOnly ? g_SurvivorCountCache.upright : g_SurvivorCountCache.alive;
}

int GetSurvivorTemporaryHealth(int client)
{
	int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_cvPainPillsDecayRate.FloatValue)) - 1;
	return tempHealth > 0 ? tempHealth : 0;
}

int ClampInt(int value, int minValue, int maxValue)
{
	if (value > maxValue)
	{
		return maxValue;
	}

	if (value < minValue)
	{
		return minValue;
	}

	return value;
}

int GetSurvivorPermanentHealth(int client)
{
	return L4D_GetPlayerReviveCount(client) > 0 ? 0 : (GetEntProp(client, Prop_Send, "m_iHealth") > 0 ? GetEntProp(client, Prop_Send, "m_iHealth") : 0);
}

bool HasPills(int client)
{
	int	 item = GetPlayerWeaponSlot(client, L4DWeaponSlot_Pills);
	char className[64];

	if (!IsValidEdict(item))
	{
		return false;
	}

	GetEdictClassname(item, className, sizeof(className));
	return StrEqual(className, "weapon_pain_pills");
}

bool HasAdrenaline(int client)
{
	int	 item = GetPlayerWeaponSlot(client, L4DWeaponSlot_Pills);
	char className[64];

	if (!IsValidEdict(item))
	{
		return false;
	}

	GetEdictClassname(item, className, sizeof(className));
	return StrEqual(className, "weapon_adrenaline");
}

bool HasMedkit(int client)
{
	int	 item = GetPlayerWeaponSlot(client, L4DWeaponSlot_FirstAid);
	char className[64];

	if (!IsValidEdict(item))
	{
		return false;
	}

	GetEdictClassname(item, className, sizeof(className));
	return StrEqual(className, "weapon_first_aid_kit");
}

bool IsClientEligibleForLegacyBonus(int client)
{
	return IsSurvivor(client) && IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client);
}
