#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <left4dhooks>
#include <colors>
#include <l4d2util_weapons>
#include <readyup>
#include <pause>
#include <l4d2_boss_percents>
#include <l4d2_hybrid_scoremod_zone>
#include <l4d2_scoremod>
#include <l4d2_health_temp_bonus>
#include <l4d_tank_control_eq>
#include <lerpmonitor>
#include <witch_and_tankifier>

public Plugin myinfo =
{
	name = "Hyper-V HUD Manager",
	author = "Visor, Forgetest",
	description = "Provides different HUDs for spectators",
	version = "3.9.0",
	url = "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

// ======================================================================
//  Macros
// ======================================================================
#define SPECHUD_DRAW_INTERVAL 0.5

#define TRANSLATION_FILE "spechud.phrases"
#define LIBRARY_READYUP "readyup"
#define LIBRARY_PAUSE "pause"
#define LIBRARY_L4D_BOSS_PERCENT "l4d_boss_percent"
#define LIBRARY_L4D2_HYBRID_SCOREMOD_ZONE "l4d2_hybrid_scoremod_zone"
#define LIBRARY_L4D2_HYBRID_SCOREMOD "l4d2_hybrid_scoremod"
#define LIBRARY_L4D2_SCOREMOD "l4d2_scoremod"
#define LIBRARY_L4D2_HEALTH_TEMP_BONUS "l4d2_health_temp_bonus"
#define LIBRARY_L4D_TANK_CONTROL_EQ "l4d_tank_control_eq"
#define LIBRARY_LERP_MONITOR "lerpmonitor"
#define LIBRARY_WITCH_AND_TANKIFIER "witch_and_tankifier"

// ======================================================================
//  Plugin Vars
// ======================================================================
int g_iGamemode;

//int storedClass[MAXPLAYERS+1];

// Game Var
ConVar g_cvSurvivorLimit, g_cvVersusBossBuffer, g_cvMaxPlayers, g_cvTankBurnDuration;
int g_iSurvivorLimit, g_iMaxPlayers;
float g_fVersusBossBuffer, g_fTankBurnDuration;

// Plugin Cvar
ConVar g_cvTankPercent, g_cvWitchPercent, g_hServerNamer, g_cvReadyCfgName;

// Plugin Var
char g_sReadyCfgName[64], g_sHostname[64];
bool g_bRoundLive;

enum struct BossFlowState
{
	int tankPercent;
	int witchPercent;
	bool synced;

	void Reset()
	{
		this.tankPercent = -1;
		this.witchPercent = -1;
		this.synced = false;
	}
}

BossFlowState g_BossFlow;

enum struct BossRoundState
{
	int tankCount;
	int witchCount;
	bool roundHasFlowTank;
	bool roundHasFlowWitch;
	bool flowTankActive;
	bool customBossSys;

	void Reset()
	{
		this.tankCount = 0;
		this.witchCount = 0;
		this.roundHasFlowTank = false;
		this.roundHasFlowWitch = false;
		this.flowTankActive = false;
		this.customBossSys = false;
	}
}

BossRoundState g_BossRound;

// Boss Spawn Scheme
StringMap g_hFirstTankSpawningScheme, g_hSecondTankSpawningScheme;		// eq_finale_tanks (Zonemod, Acemod, etc.)
StringMap g_hFinaleExceptionMaps;									// finale_tank_blocker (Promod and older?)
StringMap g_hCustomTankScriptMaps;									// Handled by this plugin

// Flow Bosses
// Score & Scoremod
//int iFirstHalfScore;
int g_iMaxDistance;

// Witch and Tankifier
bool g_bStaticTank, g_bStaticWitch;

// Hud Toggle & Hint Message
bool g_bSpecHudActive[MAXPLAYERS+1], g_bTankHudActive[MAXPLAYERS+1];
bool g_bSpecHudHintShown[MAXPLAYERS+1], g_bTankHudHintShown[MAXPLAYERS+1];

enum struct TankHudSnapshot
{
	char title[64];
	char control[64];
	char health[64];
	char frustration[64];
	char network[64];
	char fire[64];
	bool hasFire;
}

enum struct WeaponSnapshot
{
	int client;
	int activeWep;
	int primaryWep;
	int secondaryWep;
	int activeWepId;
	int primaryWepId;
	bool dualWield;
	int activeClip;
	int primaryClip;
	int primaryExtra;
}

enum struct SurvivorSnapshot
{
	int client;
	int health;
	int incapCount;
	int tempHealth;
	bool alive;
	bool hanging;
	bool incapacitated;
}

enum struct InfectedSnapshot
{
	int client;
	L4D2ZombieClassType zClass;
	int health;
	int maxHealth;
	int victim;
	int cooldown;
	bool alive;
	bool ghost;
	bool onFire;
	bool hasCooldown;
	char className[10];
}

enum struct RuntimeState
{
	bool lateload;
	bool readyUpAvailable;
	bool pauseAvailable;
	bool l4dBossPercent;
	bool hybridScoremodZone;
	bool hybridScoremod;
	bool scoremod;
	bool healthTempBonus;
	bool tankControlEq;
	bool lerpMonitor;
	bool witchAndTankifier;
	bool tankSelection;

	/**
	 * @brief Resets runtime flags.
	 *
	 * @noreturn
	 */
	void Reset()
	{
		this.lateload = false;
		this.readyUpAvailable = false;
		this.pauseAvailable = false;
		this.l4dBossPercent = false;
		this.hybridScoremodZone = false;
		this.hybridScoremod = false;
		this.scoremod = false;
		this.healthTempBonus = false;
		this.tankControlEq = false;
		this.lerpMonitor = false;
		this.witchAndTankifier = false;
		this.tankSelection = false;
	}

	/**
	 * @brief Refreshes the full runtime snapshot.
	 */
	void Refresh()
	{
		this.readyUpAvailable = LibraryExists(LIBRARY_READYUP);
		this.pauseAvailable = LibraryExists(LIBRARY_PAUSE);
		this.l4dBossPercent = LibraryExists(LIBRARY_L4D_BOSS_PERCENT);
		this.hybridScoremodZone = LibraryExists(LIBRARY_L4D2_HYBRID_SCOREMOD_ZONE);
		this.hybridScoremod = LibraryExists(LIBRARY_L4D2_HYBRID_SCOREMOD);
		this.scoremod = LibraryExists(LIBRARY_L4D2_SCOREMOD);
		this.healthTempBonus = LibraryExists(LIBRARY_L4D2_HEALTH_TEMP_BONUS);
		this.tankControlEq = LibraryExists(LIBRARY_L4D_TANK_CONTROL_EQ);
		this.lerpMonitor = LibraryExists(LIBRARY_LERP_MONITOR);
		this.witchAndTankifier = LibraryExists(LIBRARY_WITCH_AND_TANKIFIER);
		this.tankSelection = (GetFeatureStatus(FeatureType_Native, "GetTankSelection") != FeatureStatus_Unknown);
	}

}


RuntimeState g_Runtime;

// ======================================================================
//  Plugin Start
// ======================================================================
public void OnPluginStart()
{
	LoadPluginTranslations();
	
	(	g_cvSurvivorLimit		= FindConVar("survivor_limit")		).AddChangeHook(GameConVarChanged);
	(	g_cvVersusBossBuffer	= FindConVar("versus_boss_buffer")	).AddChangeHook(GameConVarChanged);
	(	g_cvMaxPlayers			= FindConVar("sv_maxplayers")		).AddChangeHook(GameConVarChanged);
	(	g_cvTankBurnDuration	= FindConVar("tank_burn_duration")	).AddChangeHook(GameConVarChanged);

	RefreshCachedCvars();
	
	RefreshBossPercentHandles();
	RefreshServerNameCache();
	RefreshReadyCfgName();
	g_iGamemode = L4D_GetGameModeType();
	g_BossFlow.Reset();
	InitTankSpawnSchemeMaps();
	
	RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
	RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);
	
	HookEvent("round_start",		Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("player_death",		Event_PlayerDeath,		EventHookMode_Post);
	HookEvent("witch_killed",		Event_WitchDeath,		EventHookMode_PostNoCopy);
	HookEvent("player_team",		Event_PlayerTeam,		EventHookMode_Post);
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		g_bSpecHudActive[i] = false;
		g_bSpecHudHintShown[i] = false;
		g_bTankHudActive[i] = true;
		g_bTankHudHintShown[i] = false;
	}
	
	CreateTimer(SPECHUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errorMax)
{
	g_Runtime.Reset();
	g_Runtime.lateload = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_Runtime.Refresh();
	RefreshBossPercentHandles();
	RefreshServerNameCache();
	RefreshReadyCfgName();
	RefreshBossPercentCache();
	g_BossRound.Reset();
}

public void OnLibraryAdded(const char[] name)
{
	g_Runtime.Refresh();
	if (StrEqual(name, LIBRARY_L4D_BOSS_PERCENT))
	{
		RefreshBossPercentCache();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	g_Runtime.Refresh();
	if (StrEqual(name, LIBRARY_L4D_BOSS_PERCENT))
	{
		g_BossFlow.Reset();
	}
}

public void L4D2_OnBossPercentsUpdated(int tankPercent, int witchPercent)
{
	g_BossFlow.tankPercent = tankPercent;
	g_BossFlow.witchPercent = witchPercent;
	g_BossFlow.synced = true;
}

void RefreshBossPercentCache()
{
	if (!g_Runtime.l4dBossPercent || g_BossFlow.synced)
	{
		return;
	}

	g_BossFlow.tankPercent = (GetFeatureStatus(FeatureType_Native, "GetStoredTankPercent") != FeatureStatus_Unknown)
		? GetStoredTankPercent()
		: -1;

	g_BossFlow.witchPercent = (GetFeatureStatus(FeatureType_Native, "GetStoredWitchPercent") != FeatureStatus_Unknown)
		? GetStoredWitchPercent()
		: -1;

	g_BossFlow.synced = true;
}

void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "translations/"...TRANSLATION_FILE... ".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \""...TRANSLATION_FILE...".txt\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}

// ======================================================================
//  ConVar / Runtime Maintenance
// ======================================================================
void GameConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshCachedCvars();
}

void ServerCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshServerNameCache();
}

void ReadyCfgChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshReadyCfgName();
}

void RefreshCachedCvars()
{
	g_iSurvivorLimit = g_cvSurvivorLimit.IntValue;
	g_fVersusBossBuffer = g_cvVersusBossBuffer.FloatValue;
	g_iMaxPlayers = g_cvMaxPlayers.IntValue;
	g_fTankBurnDuration = g_cvTankBurnDuration.FloatValue;
}

void RefreshBossPercentHandles()
{
	g_cvTankPercent = FindConVar("l4d_tank_percent");
	g_cvWitchPercent = FindConVar("l4d_witch_percent");
}

void RefreshServerNameCache()
{
	ConVar convar = null;
	if ((convar = FindConVar("l4d_ready_server_cvar")) != null)
	{
		char buffer[64];
		convar.GetString(buffer, sizeof(buffer));
		convar = FindConVar(buffer);
	}

	if (convar == null)
	{
		convar = FindConVar("hostname");
	}

	if (g_hServerNamer == null)
	{
		g_hServerNamer = convar;
		g_hServerNamer.AddChangeHook(ServerCvarChanged);
	}
	else if (g_hServerNamer != convar)
	{
		g_hServerNamer.RemoveChangeHook(ServerCvarChanged);
		g_hServerNamer = convar;
		g_hServerNamer.AddChangeHook(ServerCvarChanged);
	}

	g_hServerNamer.GetString(g_sHostname, sizeof(g_sHostname));
}

void RefreshReadyCfgName()
{
	if (g_cvReadyCfgName == null && (g_cvReadyCfgName = FindConVar("l4d_ready_cfg_name")) != null)
	{
		g_cvReadyCfgName.AddChangeHook(ReadyCfgChanged);
	}

	if (g_cvReadyCfgName != null)
	{
		g_cvReadyCfgName.GetString(g_sReadyCfgName, sizeof(g_sReadyCfgName));
	}
}

public void L4D_OnGameModeChange(int gamemode)
{
	g_iGamemode = gamemode;
}

// ======================================================================
//  Bosses Caching
// ======================================================================
void AddStaticTankMapEntries()
{
	// Haunted Forest 3
	g_hCustomTankScriptMaps.SetValue("hf03_themansion", true);
}

void InitTankSpawnSchemeMaps()
{
	g_hFirstTankSpawningScheme	= new StringMap();
	g_hSecondTankSpawningScheme	= new StringMap();
	g_hFinaleExceptionMaps		= new StringMap();
	g_hCustomTankScriptMaps		= new StringMap();
	
	RegServerCmd("tank_map_flow_and_second_event",	SetMapFirstTankSpawningScheme);
	RegServerCmd("tank_map_only_first_event",		SetMapSecondTankSpawningScheme);
	RegServerCmd("finale_tank_default",				SetFinaleExceptionMap);
	
	AddStaticTankMapEntries();
}

Action SetMapFirstTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	g_hFirstTankSpawningScheme.SetValue(mapname, true);

	return Plugin_Handled;
}

Action SetMapSecondTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	g_hSecondTankSpawningScheme.SetValue(mapname, true);
	return Plugin_Handled;
}

Action SetFinaleExceptionMap(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	g_hFinaleExceptionMaps.SetValue(mapname, true);
	return Plugin_Handled;
}

// ======================================================================
//  Forwards
// ======================================================================
public void OnClientDisconnect(int client)
{
	g_bSpecHudHintShown[client] = false;
	g_bTankHudHintShown[client] = false;
}

public void OnMapStart() { g_bRoundLive = false; }
public void OnRoundIsLive()
{
	RefreshReadyCfgName();
	RefreshBossPercentCache();
	
	g_bRoundLive = true;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && L4D_GetClientTeam(i) == L4DTeam_Spectator && !IsClientSourceTV(i))
			FakeClientCommand(i, "sm_spectate");
	}
	
	if (g_iGamemode == GAMEMODE_VERSUS)
	{
		g_BossRound.roundHasFlowTank = RoundHasFlowTank();
		g_BossRound.roundHasFlowWitch = RoundHasFlowWitch();
		g_BossRound.flowTankActive = g_BossRound.roundHasFlowTank;
		
		g_BossRound.customBossSys = IsDarkCarniRemix();
		
		g_bStaticTank = g_Runtime.witchAndTankifier && IsStaticTankMap();
		g_bStaticWitch = g_Runtime.witchAndTankifier && IsStaticWitchMap();
		
		g_iMaxDistance = L4D_GetVersusMaxCompletionScore() / 4 * g_iSurvivorLimit;
		
		g_BossRound.tankCount = 0;
		g_BossRound.witchCount = 0;
		
		if (g_cvTankPercent != null && g_cvTankPercent.BoolValue)
		{
			g_BossRound.tankCount = 1;
			
			char mapname[64];
			bool dummy;
			GetCurrentMap(mapname, sizeof(mapname));
			
			// TODO: individual plugin served as an interface to tank counts?
			if (g_hCustomTankScriptMaps.GetValue(mapname, dummy)) g_BossRound.tankCount += 1;
			
			else if (!g_BossRound.customBossSys && L4D_IsMissionFinalMap())
			{
				g_BossRound.tankCount = 3
							- view_as<int>(g_hFirstTankSpawningScheme.GetValue(mapname, dummy))
							- view_as<int>(g_hSecondTankSpawningScheme.GetValue(mapname, dummy))
							- view_as<int>(g_hFinaleExceptionMaps.Size > 0 && !g_hFinaleExceptionMaps.GetValue(mapname, dummy))
							- view_as<int>(g_bStaticTank);
			}
		}
		
		if (g_cvWitchPercent != null && g_cvWitchPercent.BoolValue)
		{
			g_BossRound.witchCount = 1;
		}
	}
}

//public void L4D2_OnEndVersusModeRound_Post() { if (!InSecondHalfOfRound()) iFirstHalfScore = L4D_GetTeamScore(GetRealTeam(0) + 1); }

// ======================================================================
//  Events
// ======================================================================
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundLive = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundLive = false;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || L4D_GetClientTeam(client) != L4DTeam_Infected) return;
	
	if (GetInfectedClass(client) == L4D2ZombieClass_Tank)
	{
		if (g_BossRound.tankCount > 0) g_BossRound.tankCount--;
		if (!RoundHasFlowTank()) g_BossRound.flowTankActive = false;
	}
}

void Event_WitchDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (g_BossRound.witchCount > 0) g_BossRound.witchCount--;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client) return;
	
	int team = event.GetInt("team");
	
	if (view_as<L4DTeam>(team) == L4DTeam_Unassigned) // Player disconnecting
	{
		g_bSpecHudActive[client] = false;
		g_bTankHudActive[client] = true;
	}
	
	//if (team == L4DTeam_Infected) storedClass[client] = ZC_None;
}

// ======================================================================
//  HUD Command Callbacks
// ======================================================================
Action ToggleSpecHudCmd(int client, int args)
{
	if (!IsValidClientIndex(client) || !IsClientInGame(client))
		return Plugin_Handled;
	
	if (L4D_GetClientTeam(client) != L4DTeam_Spectator)
		return Plugin_Handled;
	
	g_bSpecHudActive[client] = !g_bSpecHudActive[client];
	
	CPrintToChat(client, "%t", "Notify_SpechudState", "Tag", (g_bSpecHudActive[client] ? "on" : "off"));
	return Plugin_Handled;
}

Action ToggleTankHudCmd(int client, int args)
{
	if (!IsValidClientIndex(client) || !IsClientInGame(client))
		return Plugin_Handled;
	
	if (L4D_GetClientTeam(client) == L4DTeam_Survivor)
		return Plugin_Handled;
	
	g_bTankHudActive[client] = !g_bTankHudActive[client];
	
	CPrintToChat(client, "%t", "Notify_TankhudState", "Tag", (g_bTankHudActive[client] ? "on" : "off"));
	return Plugin_Handled;
}

// ======================================================================
//  HUD Handle
// ======================================================================
Action HudDrawTimer(Handle hTimer)
{
	if ((g_Runtime.readyUpAvailable && IsInReady()) || (g_Runtime.pauseAvailable && IsInPause()))
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
				if (tankClient == -1 && IsTank(i))
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

// ======================================================================
//  HUD Content
// ======================================================================
void FillHeaderInfo(Panel hSpecHud, int realClientCount, int target)
{
	static char header[64];
	BuildHeaderInfoLine(realClientCount, target, header, sizeof(header));
	DrawPanelText(hSpecHud, header);
}

void BuildHeaderInfoLine(int realClientCount, int target, char[] header, int length)
{
	static int iTickrate = 0;
	if (iTickrate == 0 && IsServerProcessing())
		iTickrate = RoundToNearest(1.0 / GetTickInterval());

	FormatEx(header, length, "%T", "Spechud_ServerHeader", target, g_sHostname, realClientCount, g_iMaxPlayers, iTickrate);
}

void BuildWeaponSnapshot(int client, WeaponSnapshot snap)
{
	snap.client = client;
	snap.activeWep = L4D_GetPlayerCurrentWeapon(client);
	snap.primaryWep = GetPlayerWeaponSlot(client, L4DWeaponSlot_Primary);
	snap.secondaryWep = GetPlayerWeaponSlot(client, L4DWeaponSlot_Secondary);
	snap.activeWepId = IdentifyWeapon(snap.activeWep);
	snap.primaryWepId = IdentifyWeapon(snap.primaryWep);
	snap.dualWield = (snap.secondaryWep > 0 && view_as<bool>(GetEntProp(snap.secondaryWep, Prop_Send, "m_isDualWielding")));
	snap.activeClip = GetWeaponClipAmmo(snap.activeWep);
	snap.primaryClip = GetWeaponClipAmmo(snap.primaryWep);
	snap.primaryExtra = GetWeaponExtraAmmo(client, snap.primaryWep);
}

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

void BuildInfectedSnapshot(int client, InfectedSnapshot snap)
{
	snap.client = client;
	snap.alive = IsPlayerAlive(client);
	snap.zClass = GetInfectedClass(client);
	snap.health = GetClientHealth(client);
	snap.maxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
	snap.ghost = IsInfectedGhost(client);
	snap.onFire = L4D_IsPlayerOnFire(client);
	snap.victim = GetInfectedVictim(client);
	snap.cooldown = 0;
	snap.hasCooldown = false;
	
	GetInfectedClassName(snap.zClass, snap.className, sizeof(snap.className));
	
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

void BuildSurvivorLine(SurvivorSnapshot survivor, int target, char[] line, int length)
{
	static char name[MAX_NAME_LENGTH];
	GetClientFixedName(survivor.client, name, sizeof(name));

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

bool BuildInfectedLine(InfectedSnapshot infected, int target, char[] line, int length)
{
	static char name[MAX_NAME_LENGTH];
	static char buffer[16];

	if (!IsClientInGame(infected.client) || L4D_GetClientTeam(infected.client) != L4DTeam_Infected)
		return false;

	if (infected.zClass == L4D2ZombieClass_Tank)
		return false;

	GetClientFixedName(infected.client, name, sizeof(name));
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

int SortSurvByCharacter(int elem1, int elem2, const int[] array, Handle hndl)
{
	int sc1 = IdentifySurvivor(elem1);
	int sc2 = IdentifySurvivor(elem2);

	if (sc1 > sc2) { return 1; }
	else if (sc1 < sc2) { return -1; }
	else { return 0; }
}

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

bool FillScoreInfo(Panel hSpecHud, int target)
{
	static char line[64];
	
	switch (g_iGamemode)
	{
		case GAMEMODE_SCAVENGE:
		{
			bool isSecondHalf = InSecondHalfOfRound();
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
				
				// > HB: 100% | DB: 100% | Pills: 60 / 100%
				// > Bonus: 860 <100.0%>
				// > Distance: 400
				
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
				//if (InSecondHalfOfRound())
				//{
				//	Format(line, sizeof(line), "%s | R#1: %i <%.1f%%>", line, iFirstHalfScore, PercentFloat(iFirstHalfScore, L4D_GetVersusMaxCompletionScore() + maxTotalBonus));
				//}
				DrawPanelText(hSpecHud, line);
			}
			
			else if (g_Runtime.scoremod)
			{
				int totalBonus = SMClassic_GetBonus(SMClassicBonusType_Total);
				int maxTotalBonus = SMClassic_GetMaxBonus(SMClassicBonusType_Total);
				
				DrawPanelText(hSpecHud, " ");
				
				// > Bonus: 860
				// > Distance: 400
				
				FormatEx(line, sizeof(line), "%T", target, "Spechud_BonusValue", totalBonus, PercentFloat(totalBonus, maxTotalBonus));
				DrawPanelText(hSpecHud, line);
				
				FormatEx(line, sizeof(line), "%T", target, "Spechud_DistanceValue", g_iMaxDistance);
				//if (InSecondHalfOfRound())
				//{
				//	Format(line, sizeof(line), "%s | R#1: %i", line, iFirstHalfScore);
				//}
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
				
				// > Perm: 114 | Temp: 514 | Pills: 810
				// > Bonus: 114514 <100.0%>
				// > Distance: 191
				// never ever played on Next so take it easy.
				
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
				//if (InSecondHalfOfRound())
				//{
				//	Format(line, sizeof(line), "%s | R#1: %i <%.1f%%>", line, iFirstHalfScore, ToPercent(iFirstHalfScore, L4D_GetVersusMaxCompletionScore() + maxTotalBonus));
				//}
				DrawPanelText(hSpecHud, line);
			}
		}
	}

	return false;
}

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

bool BuildTankInfoSnapshot(int tank, TankHudSnapshot snap, int target)
{
	if (tank == -1 || !IsPlayerAlive(tank))
		return false;

	static char ordinal[64];
	static char name[MAX_NAME_LENGTH];

	FormatEx(snap.title, sizeof(snap.title), "%T", "Spechud_TankHudTitle", target, g_sReadyCfgName);
	ValvePanel_ShiftInvalidString(snap.title, sizeof(snap.title));

	// Draw owner & pass counter
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
		GetClientFixedName(tank, name, sizeof(name));
		FormatEx(snap.control, sizeof(snap.control), "%T", "Spechud_ControlPlayer", target, name, ordinal);
	}
	else
	{
		FormatEx(snap.control, sizeof(snap.control), "%T", "Spechud_ControlAI", target, ordinal);
	}

	// Draw health
	int health = GetClientHealth(tank);
	int maxhealth = GetEntProp(tank, Prop_Send, "m_iMaxHealth");
	float healthPercent = PercentFloat(health, maxhealth); // * 100 already
	bool isIncapacitated = L4D_IsPlayerIncapacitated(tank);
	
	if (health <= 0 || isIncapacitated)
	{
		FormatEx(snap.health, sizeof(snap.health), "%T", "Spechud_HealthDead", target);
	}
	else
	{
		FormatEx(snap.health, sizeof(snap.health), "%T", "Spechud_HealthValue", target, health, MaxInt(1, RoundFloat(healthPercent)));
	}

	// Draw frustration
	if (!IsFakeClient(tank))
	{
		FormatEx(snap.frustration, sizeof(snap.frustration), "%T", "Spechud_FrustrationValue", target, L4D_GetTankFrustration(tank));
	}
	else
	{
		FormatEx(snap.frustration, sizeof(snap.frustration), "%T", "Spechud_FrustrationAI", target);
	}

	// Draw network
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

	// Draw fire status
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

bool FillTankHudInfo(Panel tankHud, int tankClient, int target)
{
	TankHudSnapshot tankSnapshot;
	if (tankClient == -1 || !BuildTankInfoSnapshot(tankClient, tankSnapshot, target))
		return false;

	DrawTankInfoSnapshot(tankHud, tankSnapshot, true);
	return true;
}

bool FillGameInfo(Panel hSpecHud, int target)
{
	switch (g_iGamemode)
	{
		case GAMEMODE_SCAVENGE: return FillGameInfoScavenge(hSpecHud, target);
		case GAMEMODE_VERSUS: return FillGameInfoVersus(hSpecHud, target);
	}

	return false;
}

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

bool FillGameInfoVersus(Panel hSpecHud, int target)
{
	if (!g_Runtime.scoremod && !g_Runtime.hybridScoremod && !g_Runtime.hybridScoremodZone && !g_Runtime.healthTempBonus)
	{
		return false;
	}

	static char line[64];
	FormatEx(line, sizeof(line), "%T", "Spechud_GameRoundVersus", target, g_sReadyCfgName, 1 + view_as<int>(InSecondHalfOfRound()));
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
		Format(line, length, "%s | %T", line, target, "Spechud_BossFlowCurrent", survivorFlow);
	}

	return hasLine;
}

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
	GetClientFixedName(tankClient, name, sizeof(name));
	FormatEx(line, length, "%T", "Spechud_TankSelection", target, name);
	return true;
}

/**
 *	Stocks
**/
stock float PercentFloat(int value, int max)
{
	if (max <= 0)
	{
		return 0.0;
	}

	return (float(value) / float(max)) * 100.0;
}

stock int MaxInt(int a, int b)
{
	return (a > b) ? a : b;
}

stock bool IsValidClientIndex(int client)
{
	return (client > 0 && client <= MaxClients);
}

stock L4D2ZombieClassType GetInfectedClass(int client)
{
	return L4D2_GetPlayerZombieClass(client);
}

stock bool IsInfectedGhost(int client)
{
	return L4D_IsPlayerGhost(client);
}

stock void GetInfectedClassName(L4D2ZombieClassType zClass, char[] buffer, int length)
{
	strcopy(buffer, length, L4D2_GetZombieClassname(zClass));
}

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

stock int GetInfectedVictim(int client)
{
	return L4D2_GetSurvivorVictim(client);
}

stock bool IsTank(int client)
{
	return (L4D_GetClientTeam(client) == L4DTeam_Infected && L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank);
}

stock bool InSecondHalfOfRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

stock bool IsHangingFromLedge(int client)
{
	return (L4D_IsPlayerHangingFromLedge(client)
		|| view_as<bool>(GetEntProp(client, Prop_Send, "m_isFallingFromLedge", 1)));
}

stock int GetSurvivorIncapCount(int client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

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
 *	Datamap m_iAmmo
 *	offset to add - gun(s) - control cvar
 *	
 *	+12: M4A1, AK74, Desert Rifle, also SG552 - ammo_assaultrifle_max
 *	+20: both SMGs, also the MP5 - ammo_smg_max
 *	+28: both Pump Shotguns - ammo_shotgun_max
 *	+32: both autoshotguns - ammo_autoshotgun_max
 *	+36: Hunting Rifle - ammo_huntingrifle_max
 *	+40: Military Sniper, AWP, Scout - ammo_sniperrifle_max
 *	+68: Grenade Launcher - ammo_grenadelauncher_max
 */

stock int GetWeaponExtraAmmo(int client, int weapon)
{
	if (weapon <= 0)
	{
		return -1;
	}

	return L4D_GetReserveAmmo(client, weapon);
}

stock int GetWeaponClipAmmo(int weapon)
{
	return (weapon > 0 ? GetEntProp(weapon, Prop_Send, "m_iClip1") : -1);
}

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

//stock int GetRealTeam(int team)
//{
//	return team ^ view_as<int>(InSecondHalfOfRound() != GameRules_GetProp("m_bAreTeamsFlipped"));
//}

stock int GetVersusProgressDistance(int teamIndex)
{
	int distance = 0;
	for (int i = 0; i < 4; ++i)
	{
		distance += GameRules_GetProp("m_iVersusDistancePerSurvivor", _, i + 4 * teamIndex);
	}
	return distance;
}

/*
 * Future use
 */
stock void FillScavengeScores(int arr[2][5])
{
	for (int i = 1; i <= GetScavengeRoundLimit(); ++i)
	{
		arr[0][i-1] = GetScavengeTeamScore(0, i);
		arr[1][i-1] = GetScavengeTeamScore(1, i);
	}
}

stock int FormatScavengeRoundTime(char[] buffer, int maxlen, int teamIndex, bool nodecimalpoint = false)
{
	float seconds = GetScavengeRoundDuration(teamIndex);
	int minutes = RoundToFloor(seconds) / 60;
	seconds -= 60 * minutes;
	
	return nodecimalpoint ?
				Format(buffer, maxlen, "%d:%02.0f", minutes, seconds) :
				Format(buffer, maxlen, "%d:%05.2f", minutes, seconds);
}

/*
 * GetScavengeRoundDuration & GetScavengeTeamScore
 * credit to ProdigySim
 */
stock float GetScavengeRoundDuration(int teamIndex)
{
	float flRoundStartTime = GameRules_GetPropFloat("m_flRoundStartTime");
	if (teamIndex == view_as<int>(GameRules_GetProp("m_bAreTeamsFlipped")) && flRoundStartTime != 0.0 && GameRules_GetPropFloat("m_flRoundEndTime") == 0.0)
	{
		// Survivor team still playing round.
		return GetGameTime() - flRoundStartTime;
	}
	return GameRules_GetPropFloat("m_flRoundDuration", teamIndex);
}

stock int GetScavengeTeamScore(int teamIndex, int round=-1)
{
	if (!(1 <= round <= 5))
	{
		round = GameRules_GetProp("m_nRoundNumber");
	}
	return GameRules_GetProp("m_iScavengeTeamScore", _, (2*(round-1)) + teamIndex);
}

stock int GetScavengeMatchScore(int teamIndex)
{
	return GameRules_GetProp("m_iScavengeMatchScore", _, teamIndex);
}

stock int GetScavengeRoundNumber()
{
	return GameRules_GetProp("m_nRoundNumber");
}

stock int GetScavengeRoundLimit()
{
	return GameRules_GetProp("m_nRoundLimit");
}

stock int GetFurthestSurvivorFlow()
{
	int flow = RoundToNearest(100.0 * (L4D2_GetFurthestSurvivorFlow() + g_fVersusBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	return flow < 100 ? flow : 100;
}

//stock float GetClientFlow(int client)
//{
//	return (L4D2Direct_GetFlowDistance(client) / L4D2Direct_GetMapMaxFlowDistance());
//}

stock int GetHighestSurvivorFlow()
{
	int flow = -1;
	
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0) {
		flow = RoundToNearest(100.0 * (L4D2Direct_GetFlowDistance(client) + g_fVersusBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	}
	
	return flow < 100 ? flow : 100;
}

stock int GetRoundTankFlow()
{
	return RoundToNearest(L4D2Direct_GetVSTankFlowPercent(InSecondHalfOfRound()) + g_fVersusBossBuffer / L4D2Direct_GetMapMaxFlowDistance());
}

stock int GetRoundWitchFlow()
{
	return RoundToNearest(L4D2Direct_GetVSWitchFlowPercent(InSecondHalfOfRound()) + g_fVersusBossBuffer / L4D2Direct_GetMapMaxFlowDistance());
}

stock bool RoundHasFlowTank()
{
	return L4D2Direct_GetVSTankToSpawnThisRound(InSecondHalfOfRound());
}

stock bool RoundHasFlowWitch()
{
	return L4D2Direct_GetVSWitchToSpawnThisRound(InSecondHalfOfRound());
}
