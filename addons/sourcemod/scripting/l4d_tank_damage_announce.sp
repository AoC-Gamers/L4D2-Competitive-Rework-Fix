/*        L4D_TANK_DAMAGE_ANNOUNCE
*         L4D_TANK_DAMAGE_ANNOUNCE
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>

static const int TEAM_SURVIVOR = 2;
static const int TEAM_INFECTED = 3;
static const int ZOMBIECLASS_TANK = 8;

bool g_bEnabled = true;
bool g_bAnnounceTankDamage = false;
bool g_bIsTankInPlay = false;
bool g_bPrintedHealth = false;

int g_iWasTank[MAXPLAYERS + 1];
int g_iWasTankAI = 0;
int g_iOffsetIncapacitated = 0;
int g_iTankClient = 0;
int g_iLastTankHealth = 0;
int g_iDamage[MAXPLAYERS + 1];

float g_fMaxTankHealth = 6000.0;

ConVar g_cvEnabled = null;
ConVar g_cvTankHealth = null;
ConVar g_cvDifficulty = null;

GlobalForward g_fwdOnTankDeath = null;

public Plugin myinfo =
{
	name = "Tank Damage Announce L4D2",
	author = "Griffin and Blade",
	description = "Announce damage dealt to tanks by survivors",
	version = "0.6.7",
	url = "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

public void OnPluginStart()
{
	g_bIsTankInPlay = false;
	g_bAnnounceTankDamage = false;
	g_iTankClient = 0;
	ClearTankDamage();

	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_death", Event_PlayerKilled);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_hurt", Event_PlayerHurt);

	g_cvEnabled = CreateConVar("l4d_tankdamage_enabled", "1", "Announce damage done to tanks when enabled", FCVAR_NONE | FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvTankHealth = FindConVar("z_tank_health");
	g_cvDifficulty = FindConVar("z_difficulty");

	HookConVarChange(g_cvEnabled, Cvar_Enabled);
	HookConVarChange(g_cvTankHealth, Cvar_TankHealth);
	HookConVarChange(g_cvDifficulty, Cvar_TankHealth);
	HookConVarChange(FindConVar("mp_gamemode"), Cvar_TankHealth);

	g_bEnabled = g_cvEnabled.BoolValue;
	CalculateTankHealth();

	g_iOffsetIncapacitated = FindSendPropInfo("Tank", "m_isIncapacitated");
	g_fwdOnTankDeath = new GlobalForward("OnTankDeath", ET_Event);
}

public void OnPluginEnd()
{
	UnhookEvent("tank_spawn", Event_TankSpawn);
	UnhookEvent("player_death", Event_PlayerKilled);
	UnhookEvent("round_start", Event_RoundStart);
	UnhookEvent("round_end", Event_RoundEnd);
	UnhookEvent("player_hurt", Event_PlayerHurt);

	if (g_cvEnabled != null)
		UnhookConVarChange(g_cvEnabled, Cvar_Enabled);
	if (g_cvTankHealth != null)
		UnhookConVarChange(g_cvTankHealth, Cvar_TankHealth);
	if (g_cvDifficulty != null)
		UnhookConVarChange(g_cvDifficulty, Cvar_TankHealth);

	delete g_fwdOnTankDeath;
}

public void OnMapStart()
{
	ClearTankDamage();
	PrecacheSound("ui/pickup_secret01.wav");
}

public void OnClientDisconnect_Post(int client)
{
	if (!g_bIsTankInPlay || client != g_iTankClient)
		return;

	CreateTimer(0.1, Timer_CheckTank, client);
}

void Cvar_Enabled(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bEnabled = StringToInt(newValue) > 0;
}

void Cvar_TankHealth(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CalculateTankHealth();
}

void CalculateTankHealth()
{
	char gameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));

	g_fMaxTankHealth = g_cvTankHealth.FloatValue;
	if (g_fMaxTankHealth <= 0.0)
		g_fMaxTankHealth = 1.0;

	if (StrEqual(gameMode, "versus") || StrEqual(gameMode, "mutation12"))
	{
		g_fMaxTankHealth *= 1.5;
	}
	else
	{
		char difficulty[16];
		GetConVarString(g_cvDifficulty, difficulty, sizeof(difficulty));

		if (difficulty[0] == 'E')
			g_fMaxTankHealth *= 0.75;
		else if (difficulty[0] == 'H' || difficulty[0] == 'I')
			g_fMaxTankHealth *= 2.0;
	}
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (victim != GetTankClient() || IsTankDying())
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker == 0 || !IsClientInGame(attacker) || GetClientTeam(attacker) != TEAM_SURVIVOR)
		return;

	g_iDamage[attacker] += event.GetInt("dmg_health");
	g_iLastTankHealth = event.GetInt("health");
}

void Event_PlayerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (victim != g_iTankClient)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker && IsClientInGame(attacker))
		g_iDamage[attacker] += g_iLastTankHealth;

	if (!IsFakeClient(victim))
		g_iWasTank[victim] = 1;
	else
		g_iWasTankAI = 1;

	CreateTimer(0.1, Timer_CheckTank, victim);
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iTankClient = client;

	if (g_bIsTankInPlay)
		return;

	EmitSoundToAll("ui/pickup_secret01.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
	g_bAnnounceTankDamage = true;
	g_bIsTankInPlay = true;
	g_iLastTankHealth = GetClientHealth(client);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bPrintedHealth = false;
	g_bIsTankInPlay = false;
	g_iTankClient = 0;
	ClearTankDamage();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bAnnounceTankDamage)
	{
		PrintRemainingHealth();
		PrintTankDamage();
	}

	ClearTankDamage();
}

Action Timer_CheckTank(Handle timer, int oldTankClient)
{
	if (g_iTankClient != oldTankClient)
		return Plugin_Stop;

	int tankClient = FindTankClient();
	if (tankClient && tankClient != oldTankClient)
	{
		g_iTankClient = tankClient;
		return Plugin_Stop;
	}

	if (g_bAnnounceTankDamage)
		PrintTankDamage();

	ClearTankDamage();
	g_bIsTankInPlay = false;

	Call_StartForward(g_fwdOnTankDeath);
	Call_Finish();
	return Plugin_Stop;
}

bool IsTankDying()
{
	int tankClient = GetTankClient();
	if (!tankClient)
		return false;

	return view_as<bool>(GetEntData(tankClient, g_iOffsetIncapacitated));
}

void PrintRemainingHealth()
{
	g_bPrintedHealth = true;
	if (!g_bEnabled)
		return;

	int tankClient = GetTankClient();
	if (!tankClient)
		return;

	char tankName[MAX_NAME_LENGTH];
	if (IsFakeClient(tankClient))
		strcopy(tankName, sizeof(tankName), "AI");
	else
		GetClientName(tankClient, tankName, sizeof(tankName));

	CPrintToChatAll("{default}[{green}!{default}] {blue}Tank {default}({olive}%s{default}) had {green}%d {default}health remaining", tankName, g_iLastTankHealth);
}

void PrintTankDamage()
{
	if (!g_bEnabled)
		return;

	if (!g_bPrintedHealth)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (g_iWasTank[i] > 0)
			{
				char tankName[MAX_NAME_LENGTH];
				if (IsClientInGame(i))
					GetClientName(i, tankName, sizeof(tankName));
				else
					Format(tankName, sizeof(tankName), "Player %d", i);

				CPrintToChatAll("{default}[{green}!{default}] {blue}Damage {default}dealt to {blue}Tank {default}({olive}%s{default})", tankName);
				g_iWasTank[i] = 0;
			}
			else if (g_iWasTankAI > 0)
			{
				CPrintToChatAll("{default}[{green}!{default}] {blue}Damage {default}dealt to {blue}Tank {default}({olive}AI{default})");
			}

			g_iWasTankAI = 0;
		}
	}

	int survivorClients[MAXPLAYERS + 1];
	int survivorCount = 0;
	int percentTotal = 0;
	int damageTotal = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || g_iDamage[client] == 0)
			continue;

		survivorClients[survivorCount++] = client;
		damageTotal += g_iDamage[client];
		percentTotal += GetDamageAsPercent(g_iDamage[client]);
	}

	if (survivorCount <= 0)
		return;

	SortCustom1D(survivorClients, survivorCount, SortByDamageDesc);

	int percentAdjustment = 0;
	if (percentTotal < 100 && float(damageTotal) > (g_fMaxTankHealth - (g_fMaxTankHealth / 200.0)))
		percentAdjustment = 100 - percentTotal;

	int lastPercent = 100;
	for (int k = 0; k < survivorCount; k++)
	{
		int client = survivorClients[k];
		int damage = g_iDamage[client];
		int percentDamage = GetDamageAsPercent(damage);

		if (percentAdjustment != 0 && damage > 0 && !IsExactPercent(damage))
		{
			int adjustedPercentDamage = percentDamage + percentAdjustment;
			if (adjustedPercentDamage <= lastPercent)
			{
				percentDamage = adjustedPercentDamage;
				percentAdjustment = 0;
			}
		}

		lastPercent = percentDamage;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				CPrintToChat(i, "{blue}[{default}%d{blue}] ({default}%i%%{blue}) {olive}%N", damage, percentDamage, client);
		}
	}
}

void ClearTankDamage()
{
	g_iLastTankHealth = 0;
	g_iWasTankAI = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iDamage[i] = 0;
		g_iWasTank[i] = 0;
	}
	g_bAnnounceTankDamage = false;
}

int GetTankClient()
{
	if (!g_bIsTankInPlay)
		return 0;

	int tankClient = g_iTankClient;
	if (!IsClientInGame(tankClient))
	{
		tankClient = FindTankClient();
		if (!tankClient)
			return 0;

		g_iTankClient = tankClient;
	}

	return tankClient;
}

int FindTankClient()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)
			|| GetClientTeam(client) != TEAM_INFECTED
			|| !IsPlayerAlive(client)
			|| GetEntProp(client, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK)
		{
			continue;
		}

		return client;
	}

	return 0;
}

int GetDamageAsPercent(int damage)
{
	return RoundToNearest((damage / g_fMaxTankHealth) * 100.0);
}

bool IsExactPercent(int damage)
{
	float damageAsPercent = (damage / g_fMaxTankHealth) * 100.0;
	float difference = float(GetDamageAsPercent(damage)) - damageAsPercent;
	return FloatAbs(difference) < 0.001;
}

int SortByDamageDesc(int elem1, int elem2, const int[] array, Handle hndl)
{
	if (g_iDamage[elem1] > g_iDamage[elem2])
		return -1;
	if (g_iDamage[elem2] > g_iDamage[elem1])
		return 1;
	if (elem1 > elem2)
		return -1;
	if (elem2 > elem1)
		return 1;
	return 0;
}
