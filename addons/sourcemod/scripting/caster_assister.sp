#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <caster_system>

#define MAX_SPEED 2

bool g_bCasterSystem;

public Plugin myinfo =
{
	name = "Caster Assister",
	author = "CanadaRox, Sir, Forgetest",
	description = "Allows spectators to control their own specspeed and move vertically",
	version = "2.3.1",
	url = "https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix"
};

float g_fCurrentMulti[MAXPLAYERS + 1] = { 1.0, ... };
float g_fCurrentIncrement[MAXPLAYERS + 1] = { 0.1, ... };
float g_fVerticalIncrement[MAXPLAYERS + 1] = { 450.0, ... };

public void OnPluginStart()
{
	RegConsoleCmd("sm_set_specspeed_multi", SetSpecspeed_Cmd);
	RegConsoleCmd("sm_set_specspeed_increment", SetSpecspeedIncrement_Cmd);
	RegConsoleCmd("sm_increase_specspeed", IncreaseSpecspeed_Cmd);
	RegConsoleCmd("sm_decrease_specspeed", DecreaseSpecspeed_Cmd);
	RegConsoleCmd("sm_set_vertical_increment", SetVerticalIncrement_Cmd);

	HookEvent("player_team", PlayerTeam_Event);

	g_bCasterSystem = LibraryExists("caster_system");
}

public void OnAllPluginsLoaded()
{
	g_bCasterSystem = LibraryExists("caster_system");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "caster_system"))
	{
		g_bCasterSystem = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "caster_system"))
	{
		g_bCasterSystem = false;
	}
}

public void OnClientPutInServer(int client)
{
	if (!g_bCasterSystem || !IsClientInGame(client))
		return;

	int accountId = GetSteamAccountID(client);
	if (accountId <= 0)
		return;

	if (bCaster(accountId, CasterSystemAction_Get))
	{
		FakeClientCommand(client, "sm_spechud");
	}
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int team = event.GetInt("team");
	if (team == 1)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if (client > 0 && IsClientInGame(client))
			SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_fCurrentMulti[client]);
	}
}

Action SetSpecspeed_Cmd(int client, int args)
{
	if (GetClientTeam(client) != 1)
	{
		return Plugin_Handled;
	}

	if (args != 1)
	{
		ReplyToCommand(client, "Usage: sm_set_specspeed_multi # (default: 1.0)");
		return Plugin_Handled;
	}

	char buffer[10];
	GetCmdArg(1, buffer, sizeof(buffer));
	float newVal = StringToFloat(buffer);
	if (IsSpeedValid(newVal))
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", newVal);
		g_fCurrentMulti[client] = newVal;
	}

	return Plugin_Handled;
}

Action SetSpecspeedIncrement_Cmd(int client, int args)
{
	if (GetClientTeam(client) != 1)
	{
		return Plugin_Handled;
	}

	if (args != 1)
	{
		ReplyToCommand(client, "Usage: sm_set_specspeed_increment # (default: 0.1)");
		return Plugin_Handled;
	}

	char buffer[10];
	GetCmdArg(1, buffer, sizeof(buffer));
	g_fCurrentIncrement[client] = StringToFloat(buffer);
	return Plugin_Handled;
}

Action IncreaseSpecspeed_Cmd(int client, int args)
{
	if (GetClientTeam(client) != 1)
	{
		return Plugin_Handled;
	}

	IncreaseSpecspeed(client, g_fCurrentIncrement[client]);
	return Plugin_Handled;
}

Action DecreaseSpecspeed_Cmd(int client, int args)
{
	if (GetClientTeam(client) != 1)
	{
		return Plugin_Handled;
	}

	IncreaseSpecspeed(client, -g_fCurrentIncrement[client]);
	return Plugin_Handled;
}

void IncreaseSpecspeed(int client, float difference)
{
	float curVal = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
	if (IsSpeedValid(curVal + difference))
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", curVal + difference);
		g_fCurrentMulti[client] = curVal + difference;
	}
}

Action SetVerticalIncrement_Cmd(int client, int args)
{
	if (GetClientTeam(client) != 1)
	{
		return Plugin_Handled;
	}

	if (args != 1)
	{
		ReplyToCommand(client, "Usage: sm_set_vertical_increment # (default: 450.0)");
		return Plugin_Handled;
	}

	char buffer[10];
	GetCmdArg(1, buffer, sizeof(buffer));
	g_fVerticalIncrement[client] = StringToFloat(buffer);
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client) && GetClientTeam(client) == 1)
	{
		if (buttons & IN_USE)
		{
			vel[2] += g_fVerticalIncrement[client];
			return Plugin_Changed;
		}
		else if (buttons & IN_RELOAD)
		{
			vel[2] -= g_fVerticalIncrement[client];
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

bool IsSpeedValid(float speed)
{
	return (speed >= 0.0 && speed <= MAX_SPEED);
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
