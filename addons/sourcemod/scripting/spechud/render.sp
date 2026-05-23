#include "spechud/helpers.sp"

/**
 * @brief Draws the HUD panels for all eligible clients.
 *
 * @param hTimer Timer handle
 * @return Plugin_Continue
 */
Action HudDrawTimer(Handle hTimer)
{
	if ((g_Runtime.readyUp && IsInReady()) || (g_Runtime.pause && IsInPause()))
		return Plugin_Continue;

	int realClientCount = 0;
	int tankHud_total = 0;
	int tankHud_clients[MAXPLAYERS + 1];
	int specHud_total = 0;
	int specHud_clients[MAXPLAYERS + 1];
	int survivor_total = 0;
	int survivor_clients[MAXPLAYERS + 1];
	int infected_total = 0;
	int infected_clients[MAXPLAYERS + 1];
	int tankClient = -1;
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i))
			continue;

		if (IsClientConnected(i) && !IsFakeClient(i))
			realClientCount++;
		
		if (IsClientSourceTV(i))
		{
			specHud_clients[specHud_total++] = i;
			continue;
		}
		
		switch (GetClientTeam(i))
		{
			case L4DTeam_Spectator:
			{
				if (g_bSpecHudActive[i])
					specHud_clients[specHud_total++] = i;
				else if (g_bTankHudActive[i])
					tankHud_clients[tankHud_total++] = i;
			}
			case L4DTeam_Survivor:
			{
				survivor_clients[survivor_total++] = i;
			}
			case L4DTeam_Infected:
			{
				if (tankClient == -1 && (L4D_GetClientTeam(i) == L4DTeam_Infected && L4D2_GetPlayerZombieClass(i) == L4D2ZombieClass_Tank))
				{
					tankClient = i;
					if (g_bTankHudActive[i])
						tankHud_clients[tankHud_total++] = i;
					continue;
				}

				infected_clients[infected_total++] = i;
				if (g_bTankHudActive[i])
					tankHud_clients[tankHud_total++] = i;
			}

		}
	}
	
	if (specHud_total) // Only bother if someone's watching us
	{
		for (int i = 0; i < specHud_total; ++i)
		{
			int client = specHud_clients[i];
			Panel specHud = new Panel();
			
			FillHeaderInfo(specHud, realClientCount, client);
			FillSurvivorInfo(specHud, survivor_clients, survivor_total, client);
			FillScoreInfo(specHud, client);
			FillInfectedInfo(specHud, infected_clients, infected_total, client);
			FillSpecGameOrTankInfo(specHud, tankClient, client);

			switch (GetClientMenu(client))
			{
				case MenuSource_External, MenuSource_Normal: continue;
			}
			
			specHud.Send(client, DummySpecHudHandler, 3);
			if (!g_bSpecHudHintShown[client])
			{
				g_bSpecHudHintShown[client] = true;
				CPrintToChat(client, "%t", "Notify_SpechudUsage", "Tag");
			}
			delete specHud;
		}
	}
	
	if (!tankHud_total) return Plugin_Continue;
	
	if (tankClient != -1)
	{
		for (int i = 0; i < tankHud_total; ++i)
		{
			int client = tankHud_clients[i];
			Panel tankHud = new Panel();
			if (!FillTankHudInfo(tankHud, tankClient, client))
			{
				delete tankHud;
				continue;
			}

			switch (GetClientMenu(client))
			{
				case MenuSource_External, MenuSource_Normal: continue;
			}
			
			tankHud.Send(client, DummyTankHudHandler, 3);
			if (!g_bTankHudHintShown[client])
			{
				g_bTankHudHintShown[client] = true;
				CPrintToChat(client, "%t", "Notify_TankhudUsage", "Tag");
			}
			delete tankHud;
		}
	}

	return Plugin_Continue;
}

int DummySpecHudHandler(Menu hMenu, MenuAction action, int param1, int param2) { return 1; }
int DummyTankHudHandler(Menu hMenu, MenuAction action, int param1, int param2) { return 1; }

/**
 * @brief Adds the header line to the spectator HUD.
 *
 * @param hSpecHud Panel to write to
 * @param realClientCount Number of connected human players
 * @param target Client receiving the panel
 */
void FillHeaderInfo(Panel hSpecHud, int realClientCount, int target)
{
	static char header[64];
	BuildHeaderInfoLine(realClientCount, target, header, sizeof(header));
	DrawPanelText(hSpecHud, header);
}

/**
 * @brief Builds the header text for the spectator HUD.
 *
 * @param realClientCount Number of connected human players
 * @param target Client receiving the panel
 * @param header Buffer to receive the header text
 * @param length Buffer size
 */
void BuildHeaderInfoLine(int realClientCount, int target, char[] header, int length)
{
	static int iTickrate = 0;
	if (iTickrate == 0 && IsServerProcessing())
		iTickrate = RoundToNearest(1.0 / GetTickInterval());

	FormatEx(header, length, "%T", "Spechud_ServerHeader", target, g_sHostname, realClientCount, g_iMaxPlayers, iTickrate);
}

/**
 * @brief Caches weapon state for a survivor client.
 *
 * @param client Client index to inspect
 * @param snap Snapshot to fill
 */
void BuildWeaponSnapshot(int client, WeaponSnapshot snap)
{
	snap.client = client;
	snap.activeWep = L4D_GetPlayerCurrentWeapon(client);
	snap.primaryWep = GetPlayerWeaponSlot(client, L4DWeaponSlot_Primary);
	snap.secondaryWep = GetPlayerWeaponSlot(client, L4DWeaponSlot_Secondary);
	snap.activeWepId = IdentifyWeapon(snap.activeWep);
	snap.primaryWepId = IdentifyWeapon(snap.primaryWep);
	snap.dualWield = (snap.secondaryWep > 0 && view_as<bool>(GetEntProp(snap.secondaryWep, Prop_Send, "m_isDualWielding")));
	snap.activeClip = (snap.activeWep > 0 ? GetEntProp(snap.activeWep, Prop_Send, "m_iClip1") : -1);
	snap.primaryClip = (snap.primaryWep > 0 ? GetEntProp(snap.primaryWep, Prop_Send, "m_iClip1") : -1);
	snap.primaryExtra = (snap.primaryWep > 0 ? L4D_GetReserveAmmo(client, snap.primaryWep) : -1);
}

/**
 * @brief Caches survivor state for HUD rendering.
 *
 * @param client Client index to inspect
 * @param snap Snapshot to fill
 */
void BuildSurvivorSnapshot(int client, SurvivorSnapshot snap)
{
	snap.client = client;
	snap.health = GetClientHealth(client);
	snap.incapCount = GetSurvivorIncapCount(client);
	snap.alive = IsPlayerAlive(client);
	snap.hanging = snap.alive && IsHangingFromLedge(client);
	snap.incapacitated = snap.alive && L4D_IsPlayerIncapacitated(client);
	snap.tempHealth = snap.alive && !snap.incapacitated ? RoundToCeil(L4D_GetTempHealth(client)) : 0;
}

/**
 * @brief Caches infected state for HUD rendering.
 *
 * @param client Client index to inspect
 * @param snap Snapshot to fill
 */
void BuildInfectedSnapshot(int client, InfectedSnapshot snap)
{
	snap.client = client;
	snap.alive = IsPlayerAlive(client);
	snap.zClass = L4D2_GetPlayerZombieClass(client);
	snap.health = GetClientHealth(client);
	snap.maxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
	snap.ghost = L4D_IsPlayerGhost(client);
	snap.onFire = L4D_IsPlayerOnFire(client);
	snap.victim = L4D2_GetSurvivorVictim(client);
	snap.cooldown = 0;
	snap.hasCooldown = false;
	
	strcopy(snap.className, sizeof(snap.className), L4D2_GetZombieClassname(snap.zClass));
	
	if (!snap.alive || snap.zClass == L4D2ZombieClass_Tank || snap.ghost)
	{
		return;
	}
	
	float timestamp, duration;
	if (!GetInfectedAbilityTimer(client, timestamp, duration))
	{
		return;
	}
	
	snap.cooldown = RoundToCeil(timestamp - GetGameTime());
	snap.hasCooldown = (snap.cooldown > 0
		&& duration > 1.0
		&& duration != 3600
		&& snap.victim <= 0);
}

/**
 * @brief Builds a single survivor line for the spectator HUD.
 *
 * @param survivor Cached survivor snapshot
 * @param target Client receiving the panel
 * @param line Buffer to receive the output line
 * @param length Buffer size
 */
void BuildSurvivorLine(SurvivorSnapshot survivor, int target, char[] line, int length)
{
	static char name[MAX_NAME_LENGTH];
	GetClientFixedName(survivor.client, name, sizeof(name), true);

	if (!survivor.alive)
	{
		FormatEx(line, length, "%T", "Spechud_SurvivorDead", target, name);
		return;
	}

	if (survivor.hanging)
	{
		FormatEx(line, length, "%T", "Spechud_SurvivorHanging", target, name, survivor.health);
		return;
	}

	WeaponSnapshot weapon;
	BuildWeaponSnapshot(survivor.client, weapon);

	if (survivor.incapacitated)
	{
		static char ordinal[8];
		FormatEx(ordinal, sizeof(ordinal), "%T", (survivor.incapCount == 1 ? "Spechud_Ordinal2" : "Spechud_Ordinal1"), target);
		GetLongWeaponName(weapon.activeWepId, line, length);
		FormatEx(line, length, "%T", "Spechud_SurvivorIncap", target, name, survivor.health, ordinal, line, weapon.activeClip);
		return;
	}

	GetWeaponInfo(weapon, line, length);
	
	int healthTotal = survivor.health + survivor.tempHealth;
	if (survivor.incapCount == 0)
	{
		FormatEx(line, length, "%T", "Spechud_SurvivorBleeding", target, name, healthTotal, (survivor.tempHealth > 0 ? "#" : ""), line);
	}
	else
	{
		static char ordinal[8];
		FormatEx(ordinal, sizeof(ordinal), "%T", (survivor.incapCount == 2 ? "Spechud_Ordinal2" : "Spechud_Ordinal1"), target);
		FormatEx(line, length, "%T", "Spechud_SurvivorBleedingIncap", target, name, healthTotal, ordinal, line);
	}
}

/**
 * @brief Builds a single infected line for the spectator HUD.
 *
 * @param infected Cached infected snapshot
 * @param target Client receiving the panel
 * @param line Buffer to receive the output line
 * @param length Buffer size
 * @return True when a line should be shown, false otherwise
 */
bool BuildInfectedLine(InfectedSnapshot infected, int target, char[] line, int length)
{
	static char name[MAX_NAME_LENGTH];
	static char buffer[16];

	if (!IsClientInGame(infected.client) || L4D_GetClientTeam(infected.client) != L4DTeam_Infected)
		return false;

	if (infected.zClass == L4D2ZombieClass_Tank)
		return false;

	GetClientFixedName(infected.client, name, sizeof(name), true);
	if (!infected.alive)
	{
		int timeLeft = RoundToFloor(L4D_GetPlayerSpawnTime(infected.client));
		if (timeLeft < 0)
		{
			FormatEx(line, length, "%T", "Spechud_InfectedDead", target, name);
		}
		else
		{
			FormatEx(buffer, sizeof(buffer), "%is", timeLeft);
			static char spawningText[32];
			FormatEx(spawningText, sizeof(spawningText), "%T", "Spechud_Spawning", target);
			FormatEx(line, length, "%T", "Spechud_InfectedDeadSpawn", target, name, (timeLeft ? buffer : spawningText));
		}

		return true;
	}

	if (infected.ghost)
	{
		if (infected.health < infected.maxHealth)
		{
			FormatEx(line, length, "%T", "Spechud_InfectedGhostHealth", target, name, infected.className, infected.health);
		}
		else
		{
			FormatEx(line, length, "%T", "Spechud_InfectedGhost", target, name, infected.className);
		}

		return true;
	}

	buffer[0] = '\0';
	if (infected.hasCooldown)
	{
		FormatEx(buffer, sizeof(buffer), " [%T]", target, "Spechud_CooldownSuffix", infected.cooldown);
	}
	
	if (infected.onFire)
	{
		FormatEx(line, length, "%T", "Spechud_InfectedOnFire", target, name, infected.className, infected.health, buffer);
	}
	else
	{
		FormatEx(line, length, "%T", "Spechud_InfectedAlive", target, name, infected.className, infected.health, buffer);
	}

	return true;
}

/**
 * @brief Builds the melee weapon prefix for the weapon HUD block.
 *
 * @param snap Cached weapon snapshot
 * @param prefix Buffer to receive the prefix
 * @param length Buffer size
 */
void GetMeleePrefix(WeaponSnapshot snap, char[] prefix, int length)
{
	if (snap.secondaryWep == -1)
		return;
	
	static char buf[4];
	switch (IdentifyWeapon(snap.secondaryWep))
	{
		case WEPID_NONE: buf = "N";
		case WEPID_PISTOL: buf = (snap.dualWield ? "DP" : "P");
		case WEPID_PISTOL_MAGNUM: buf = "DE";
		case WEPID_MELEE: buf = "M";
		default: buf = "?";
	}

	strcopy(prefix, length, buf);
}

/**
 * @brief Builds the formatted weapon information string.
 *
 * @param snap Cached weapon snapshot
 * @param info Buffer to receive the weapon text
 * @param length Buffer size
 */
void GetWeaponInfo(WeaponSnapshot snap, char[] info, int length)
{
	static char buffer[32];
	
	// Let's begin with what player is holding,
	// but cares only pistols if holding secondary.
	switch (snap.activeWepId)
	{
		case WEPID_PISTOL, WEPID_PISTOL_MAGNUM:
		{
			if (snap.activeWepId == WEPID_PISTOL && snap.dualWield)
			{
				// Dual Pistols Scenario
				// Straight use the prefix since full name is a bit long.
				Format(buffer, sizeof(buffer), "DP");
			}
			else GetLongWeaponName(snap.activeWepId, buffer, sizeof(buffer));
			
			FormatEx(info, length, "%s %i", buffer, snap.activeClip);
		}
		default:
		{
			GetLongWeaponName(snap.primaryWepId, buffer, sizeof(buffer));
			FormatEx(info, length, "%s %i/%i", buffer, snap.primaryClip, snap.primaryExtra);
		}
	}
	
	// Format our result info
	if (snap.primaryWep == -1)
	{
		// In case with no primary,
		// show the melee full name.
		if (snap.activeWepId == WEPID_MELEE || snap.activeWepId == WEPID_CHAINSAW)
		{
			int meleeWepId = IdentifyMeleeWeapon(snap.activeWep);
			GetLongMeleeWeaponName(meleeWepId, info, length);
		}
	}
	else
	{
		// Default display -> [Primary <In Detail> | Secondary <Prefix>]
		// Holding melee included in this way
		// i.e. [Chrome 8/56 | M]
		if (GetSlotFromWeaponId(snap.activeWepId) != view_as<int>(L4DWeaponSlot_Secondary) || snap.activeWepId == WEPID_MELEE || snap.activeWepId == WEPID_CHAINSAW)
		{
			GetMeleePrefix(snap, buffer, sizeof(buffer));
			Format(info, length, "%s | %s", info, buffer);
		}

		// Secondary active -> [Secondary <In Detail> | Primary <Ammo Sum>]
		// i.e. [Deagle 8 | Mac 700]
		else
		{
			GetLongWeaponName(snap.primaryWepId, buffer, sizeof(buffer));
			Format(info, length, "%s | %s %i", info, buffer, snap.primaryClip + snap.primaryExtra);
		}
	}
}

/**
 * @brief Adds survivor lines to the spectator HUD.
 *
 * @param hSpecHud Panel to write to
 * @param clients Survivor client indices
 * @param total Number of survivor clients
 * @param target Client receiving the panel
 */
void FillSurvivorInfo(Panel hSpecHud, int clients[MAXPLAYERS + 1], int total, int target)
{
	static char line[100];

	int survivorTeamIndex = GameRules_GetProp("m_bAreTeamsFlipped");

	switch (g_iGamemode)
	{
		case GAMEMODE_SCAVENGE:
		{
			int score = GetScavengeMatchScore(survivorTeamIndex);
			FormatEx(line, sizeof(line), "%T", "Spechud_SurvivorsScavenge", target, score, GetScavengeRoundLimit());
		}
		case GAMEMODE_VERSUS:
		{
			if (g_bRoundLive)
			{
				FormatEx(line, sizeof(line), "%T", "Spechud_SurvivorsVersusLive", target,
							L4D2Direct_GetVSCampaignScore(survivorTeamIndex) + GetVersusProgressDistance(survivorTeamIndex));
			}
			else
			{
				FormatEx(line, sizeof(line), "%T", "Spechud_SurvivorsVersus", target,
							L4D2Direct_GetVSCampaignScore(survivorTeamIndex));
			}
		}
	}
	
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, line);
	
	SortCustom1D(clients, total, SortSurvByCharacter);
	
	for (int i = 0; i < total; ++i)
	{
		SurvivorSnapshot survivor;
		BuildSurvivorSnapshot(clients[i], survivor);
		BuildSurvivorLine(survivor, target, line, sizeof(line));
		
		DrawPanelText(hSpecHud, line);
	}
}

/**
 * @brief Adds score information to the spectator HUD when available.
 *
 * @param hSpecHud Panel to write to
 * @param target Client receiving the panel
 * @return True when at least one score block was added, false otherwise
 */
bool FillScoreInfo(Panel hSpecHud, int target)
{
	static char line[64];
	
	switch (g_iGamemode)
	{
		case GAMEMODE_SCAVENGE:
		{
			bool isSecondHalf = view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
			bool teamFlipped = !!GameRules_GetProp("m_bAreTeamsFlipped");
			
			float duration = GetScavengeRoundDuration(teamFlipped);
			int minutes = RoundToFloor(duration / 60);
			
			DrawPanelText(hSpecHud, " ");
				
			FormatEx(line, sizeof(line), "%T [%02d:%02.0f]", target, "Spechud_AccumulatedTime", minutes, duration - 60 * minutes);
			DrawPanelText(hSpecHud, line);
			
			if (isSecondHalf)
			{
				duration = GetScavengeRoundDuration(!teamFlipped);
				minutes = RoundToFloor(duration / 60);
				
				FormatEx(line, sizeof(line), "%T [%02d:%05.2f]", target, "Spechud_OpponentDuration", minutes, duration - 60 * minutes);
				DrawPanelText(hSpecHud, line);
			}
		}
		
		case GAMEMODE_VERSUS:
		{
			if (g_Runtime.hybridScoremod || g_Runtime.hybridScoremodZone)
			{
				int healthBonus = SMPlus_GetBonus(SMPlusBonusType_Health);
				int maxHealthBonus = SMPlus_GetMaxBonus(SMPlusBonusType_Health);
				int damageBonus = SMPlus_GetBonus(SMPlusBonusType_Damage);
				int maxDamageBonus = SMPlus_GetMaxBonus(SMPlusBonusType_Damage);
				int pillsBonus = SMPlus_GetBonus(SMPlusBonusType_Pills);
				int maxPillsBonus = SMPlus_GetMaxBonus(SMPlusBonusType_Pills);
				
				int totalBonus = SMPlus_GetBonus(SMPlusBonusType_Total);
				int maxTotalBonus = SMPlus_GetMaxBonus(SMPlusBonusType_Total);
				
				DrawPanelText(hSpecHud, " ");
				
				FormatEx(	line,
							sizeof(line),
							"%T",
							target,
							"Spechud_HybridStats",
							PercentFloat(healthBonus, maxHealthBonus),
							PercentFloat(damageBonus, maxDamageBonus),
							pillsBonus, PercentFloat(pillsBonus, maxPillsBonus));
				DrawPanelText(hSpecHud, line);
				
				FormatEx(line, sizeof(line), "%T", target, "Spechud_BonusValue", totalBonus, PercentFloat(totalBonus, maxTotalBonus));
				DrawPanelText(hSpecHud, line);
				
				FormatEx(line, sizeof(line), "%T", target, "Spechud_DistanceValue", g_iMaxDistance);
				DrawPanelText(hSpecHud, line);
			}
			
			else if (g_Runtime.scoremod)
			{
				int totalBonus = SMClassic_GetBonus(SMClassicBonusType_Total);
				int maxTotalBonus = SMClassic_GetMaxBonus(SMClassicBonusType_Total);
				
				DrawPanelText(hSpecHud, " ");
				
				FormatEx(line, sizeof(line), "%T", target, "Spechud_BonusValue", totalBonus, PercentFloat(totalBonus, maxTotalBonus));
				DrawPanelText(hSpecHud, line);
				
				FormatEx(line, sizeof(line), "%T", target, "Spechud_DistanceValue", g_iMaxDistance);
				DrawPanelText(hSpecHud, line);
			}
			
			else if (g_Runtime.healthTempBonus)
			{
				int permBonus = SMNext_GetPermBonus();
				int maxPermBonus = SMNext_GetMaxPermBonus();
				int tempBonus = SMNext_GetTempBonus();
				int maxTempBonus = SMNext_GetMaxTempBonus();
				int pillsBonus = SMNext_GetPillsBonus();
				int maxPillsBonus = SMNext_GetMaxPillsBonus();
				
				int totalBonus = permBonus + tempBonus + pillsBonus;
				int maxTotalBonus = maxPermBonus + maxTempBonus + maxPillsBonus;
				
				DrawPanelText(hSpecHud, " ");
				
				FormatEx(	line,
							sizeof(line),
							"%T",
							target,
							"Spechud_NextStats",
							permBonus, tempBonus, pillsBonus);
				DrawPanelText(hSpecHud, line);
				
				FormatEx(line, sizeof(line), "%T", target, "Spechud_BonusValue", totalBonus, PercentFloat(totalBonus, maxTotalBonus));
				DrawPanelText(hSpecHud, line);
				
				FormatEx(line, sizeof(line), "%T", target, "Spechud_DistanceValue", g_iMaxDistance);
				DrawPanelText(hSpecHud, line);
			}
		}
	}

	return false;
}

/**
 * @brief Adds infected lines to the spectator HUD.
 *
 * @param hSpecHud Panel to write to
 * @param clients Infected client indices
 * @param total Number of infected clients
 * @param target Client receiving the panel
 */
void FillInfectedInfo(Panel hSpecHud, int clients[MAXPLAYERS + 1], int total, int target)
{
	static char line[80];

	int infectedTeamIndex = !GameRules_GetProp("m_bAreTeamsFlipped");
	
	switch (g_iGamemode)
	{
		case GAMEMODE_SCAVENGE:
		{
			int score = GetScavengeMatchScore(infectedTeamIndex);
			FormatEx(line, sizeof(line), "%T", "Spechud_InfectedScavenge", target, score, GetScavengeRoundLimit());
		}
		case GAMEMODE_VERSUS:
		{
			FormatEx(line, sizeof(line), "%T", "Spechud_InfectedVersus", target, L4D2Direct_GetVSCampaignScore(infectedTeamIndex));
		}
	}
	
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, line);

	int infectedTotal = 0;
	for (int i = 0; i < total; ++i)
	{
		InfectedSnapshot infected;
		BuildInfectedSnapshot(clients[i], infected);

		if (BuildInfectedLine(infected, target, line, sizeof(line)))
		{
			infectedTotal++;
			DrawPanelText(hSpecHud, line);
		}
	}
	
	if (!infectedTotal)
	{
		FormatEx(line, sizeof(line), "%T", "Spechud_NoSI", target);
		DrawPanelText(hSpecHud, line);
	}
}

/**
 * @brief Builds the tank HUD snapshot.
 *
 * @param tank Tank client index
 * @param snap Snapshot to fill
 * @param target Client receiving the panel
 * @return True when the snapshot contains visible output, false otherwise
 */
bool BuildTankInfoSnapshot(int tank, TankHudSnapshot snap, int target)
{
	if (tank == -1 || !IsPlayerAlive(tank))
		return false;

	static char ordinal[64];
	static char name[MAX_NAME_LENGTH];

	FormatEx(snap.title, sizeof(snap.title), "%T", "Spechud_TankHudTitle", target, g_sReadyCfgName);
	ValvePanel_ShiftInvalidString(snap.title, sizeof(snap.title));

	int passCount = L4D2Direct_GetTankPassedCount();
	switch (passCount)
	{
		case 0: FormatEx(ordinal, sizeof(ordinal), "%T", "Spechud_TankPassNative", target);
		case 1: FormatEx(ordinal, sizeof(ordinal), "%T", "Spechud_TankPass1", target);
		case 2: FormatEx(ordinal, sizeof(ordinal), "%T", "Spechud_TankPass2", target);
		case 3: FormatEx(ordinal, sizeof(ordinal), "%T", "Spechud_TankPass3", target);
		default: FormatEx(ordinal, sizeof(ordinal), "%T", "Spechud_TankPassN", target, passCount);
	}

	if (!IsFakeClient(tank))
	{
		GetClientFixedName(tank, name, sizeof(name), true);
		FormatEx(snap.control, sizeof(snap.control), "%T", "Spechud_ControlPlayer", target, name, ordinal);
	}
	else
	{
		FormatEx(snap.control, sizeof(snap.control), "%T", "Spechud_ControlAI", target, ordinal);
	}

	int health = GetClientHealth(tank);
	int maxhealth = GetEntProp(tank, Prop_Send, "m_iMaxHealth");
	float healthPercent = PercentFloat(health, maxhealth);
	bool isIncapacitated = L4D_IsPlayerIncapacitated(tank);
	
	if (health <= 0 || isIncapacitated)
	{
		FormatEx(snap.health, sizeof(snap.health), "%T", "Spechud_HealthDead", target);
	}
	else
	{
		FormatEx(snap.health, sizeof(snap.health), "%T", "Spechud_HealthValue", target, health, MaxInt(1, RoundFloat(healthPercent)));
	}

	if (!IsFakeClient(tank))
	{
		FormatEx(snap.frustration, sizeof(snap.frustration), "%T", "Spechud_FrustrationValue", target, L4D_GetTankFrustration(tank));
	}
	else
	{
		FormatEx(snap.frustration, sizeof(snap.frustration), "%T", "Spechud_FrustrationAI", target);
	}

	if (!IsFakeClient(tank))
	{
		int latencyMs = RoundToNearest(GetClientAvgLatency(tank, NetFlow_Both) * 1000.0);
		if (g_Runtime.lerpMonitor)
		{
			FormatEx(snap.network, sizeof(snap.network), "%T", "Spechud_NetworkValue", target, latencyMs, LM_GetLerpTime(tank) * 1000.0);
		}
		else
		{
			FormatEx(snap.network, sizeof(snap.network), "%T", "Spechud_NetworkValueNoLerp", target, latencyMs);
		}
	}
	else
	{
		FormatEx(snap.network, sizeof(snap.network), "%T", "Spechud_NetworkAI", target);
	}

	if (!isIncapacitated && L4D_IsPlayerOnFire(tank))
	{
		int timeleft = RoundToCeil(healthPercent / 100.0 * g_fTankBurnDuration);
		FormatEx(snap.fire, sizeof(snap.fire), "%T", "Spechud_OnFireValue", target, timeleft);
		snap.hasFire = true;
	}
	else
	{
		snap.hasFire = false;
	}
	
	return true;
}

/**
 * @brief Renders a prebuilt tank HUD snapshot.
 *
 * @param hSpecHud Panel to write to
 * @param snap Tank HUD snapshot
 * @param bTankHUD True when drawing the tank-specific HUD
 */
void DrawTankInfoSnapshot(Panel hSpecHud, TankHudSnapshot snap, bool bTankHUD = false)
{
	if (bTankHUD)
	{
		DrawPanelText(hSpecHud, snap.title);
		static char separator[64];
		strcopy(separator, sizeof(separator), snap.title);
		int len = strlen(separator);
		for (int i = 0; i < len; ++i) separator[i] = '_';
		DrawPanelText(hSpecHud, separator);
	}
	else
	{
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, snap.title);
	}

	DrawPanelText(hSpecHud, snap.control);
	DrawPanelText(hSpecHud, snap.health);
	DrawPanelText(hSpecHud, snap.frustration);
	DrawPanelText(hSpecHud, snap.network);
	if (snap.hasFire)
	{
		DrawPanelText(hSpecHud, snap.fire);
	}
}

/**
 * @brief Chooses between game info and tank info for the spectator HUD.
 *
 * @param hSpecHud Panel to write to
 * @param tankClient Current tank client, or -1 when none is active
 * @param target Client receiving the panel
 */
void FillSpecGameOrTankInfo(Panel hSpecHud, int tankClient, int target)
{
	TankHudSnapshot tankSnapshot;
	if (tankClient != -1 && BuildTankInfoSnapshot(tankClient, tankSnapshot, target))
	{
		DrawTankInfoSnapshot(hSpecHud, tankSnapshot, false);
		return;
	}

	FillGameInfo(hSpecHud, target);
}

/**
 * @brief Adds tank HUD information for a specific client.
 *
 * @param tankHud Panel to write to
 * @param tankClient Current tank client
 * @param target Client receiving the panel
 * @return True when the HUD should be shown, false otherwise
 */
bool FillTankHudInfo(Panel tankHud, int tankClient, int target)
{
	TankHudSnapshot tankSnapshot;
	if (tankClient == -1 || !BuildTankInfoSnapshot(tankClient, tankSnapshot, target))
		return false;

	DrawTankInfoSnapshot(tankHud, tankSnapshot, true);
	return true;
}

/**
 * @brief Adds the game status block to the spectator HUD.
 *
 * @param hSpecHud Panel to write to
 * @param target Client receiving the panel
 * @return True when game info was added, false otherwise
 */
bool FillGameInfo(Panel hSpecHud, int target)
{
	switch (g_iGamemode)
	{
		case GAMEMODE_SCAVENGE: return FillGameInfoScavenge(hSpecHud, target);
		case GAMEMODE_VERSUS: return FillGameInfoVersus(hSpecHud, target);
	}

	return false;
}

/**
 * @brief Adds the scavenge game status block.
 *
 * @param hSpecHud Panel to write to
 * @param target Client receiving the panel
 * @return True when the block was added, false otherwise
 */
bool FillGameInfoScavenge(Panel hSpecHud, int target)
{
	static char line[64];

	FormatEx(line, sizeof(line), "%T", "Spechud_GameRoundScavenge", target, g_sReadyCfgName, GetScavengeRoundNumber());
	
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, line);
	
	FormatEx(line, sizeof(line), "%T", "Spechud_BestOf", target, GetScavengeRoundLimit());
	DrawPanelText(hSpecHud, line);
	return true;
}

/**
 * @brief Adds the versus game status block.
 *
 * @param hSpecHud Panel to write to
 * @param target Client receiving the panel
 * @return True when the block was added, false otherwise
 */
bool FillGameInfoVersus(Panel hSpecHud, int target)
{
	static char line[64];
	bool hasScoreBlock = (g_Runtime.scoremod || g_Runtime.hybridScoremod || g_Runtime.hybridScoremodZone || g_Runtime.healthTempBonus);
	bool hasBossBlock = (g_Runtime.l4dBossPercent && g_BossRound.tankCount > 0);
	bool hasTankSelection = (g_Runtime.tankSelection && g_BossRound.tankCount > 0);

	if (!hasScoreBlock && !hasBossBlock && !hasTankSelection)
	{
		return false;
	}

	FormatEx(line, sizeof(line), "%T", "Spechud_GameRoundVersus", target, g_sReadyCfgName, 1 + view_as<int>(GameRules_GetProp("m_bInSecondHalfOfRound")));
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, line);

	if (BuildBossFlowInfo(line, sizeof(line), target))
	{
		DrawPanelText(hSpecHud, line);
	}

	if (BuildTankSelectionInfo(line, sizeof(line), target))
	{
		DrawPanelText(hSpecHud, line);
	}

	return true;
}

/**
 * @brief Builds the boss flow summary line.
 *
 * @param line Buffer to receive the output line
 * @param length Buffer size
 * @param target Client receiving the panel
 * @return True when a line was written, false otherwise
 */
bool BuildBossFlowInfo(char[] line, int length, int target)
{
	if (!g_Runtime.l4dBossPercent || g_cvTankPercent == null || g_cvWitchPercent == null)
	{
		return false;
	}

	int survivorFlow = GetHighestSurvivorFlow();
	if (survivorFlow == -1)
		survivorFlow = GetFurthestSurvivorFlow();

	bool hasLine = false;
	line[0] = '\0';

	static char buffer[16];
	if (g_BossRound.tankCount > 0)
	{
		if ((g_BossRound.flowTankActive && g_BossRound.roundHasFlowTank) || g_BossRound.customBossSys)
		{
			FormatEx(buffer, sizeof(buffer), "%i%%", g_BossFlow.tankPercent);
		}
		else
		{
			FormatEx(buffer, sizeof(buffer), "%T", g_bStaticTank ? "Spechud_BossFlowStatic" : "Spechud_BossFlowEvent", target);
		}

		FormatEx(line, length, "%T", "Spechud_BossFlowTank", target, buffer);
		hasLine = true;
	}

	if (g_BossRound.witchCount > 0)
	{
		if ((g_BossRound.roundHasFlowWitch || g_BossRound.customBossSys))
		{
			FormatEx(buffer, sizeof(buffer), "%i%%", g_BossFlow.witchPercent);
		}
		else
		{
			FormatEx(buffer, sizeof(buffer), "%T", g_bStaticWitch ? "Spechud_BossFlowStatic" : "Spechud_BossFlowEvent", target);
		}

		if (hasLine)
		{
			Format(line, length, "%s | %T", line, target, "Spechud_BossFlowWitch", buffer);
		}
		else
		{
			FormatEx(line, length, "%T", "Spechud_BossFlowWitch", target, buffer);
			hasLine = true;
		}
	}

	if (hasLine)
	{
		static char merged[128];
		FormatEx(merged, sizeof(merged), "%s | %T", line, target, "Spechud_BossFlowCurrent", survivorFlow);
		strcopy(line, length, merged);
	}

	return hasLine;
}

/**
 * @brief Builds the tank selection summary line.
 *
 * @param line Buffer to receive the output line
 * @param length Buffer size
 * @param target Client receiving the panel
 * @return True when a line was written, false otherwise
 */
bool BuildTankSelectionInfo(char[] line, int length, int target)
{
	if (!g_Runtime.tankSelection || g_BossRound.tankCount <= 0)
	{
		return false;
	}

	int tankClient = GetTankSelection();
	if (tankClient <= 0 || !IsClientInGame(tankClient))
	{
		return false;
	}

	static char name[MAX_NAME_LENGTH];
	GetClientFixedName(tankClient, name, sizeof(name), true);
	FormatEx(line, length, "%T", "Spechud_TankSelection", target, name);
	return true;
}
