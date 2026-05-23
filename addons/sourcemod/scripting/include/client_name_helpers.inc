#if defined _client_name_helpers_included
 #endinput
#endif
#define _client_name_helpers_included

/**
 * @brief Normalizes strings that start with invalid panel characters.
 *
 * @param str String buffer to fix in-place
 * @param maxlen Buffer size
 * @return True when the string was adjusted, false otherwise
 */
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

/**
 * @brief Reads and normalizes a client name for HUD output.
 *
 * @param client Client index to read
 * @param name Buffer to receive the name
 * @param length Buffer size
 * @param truncate True to truncate names longer than 18 characters
 */
stock void GetClientFixedName(int client, char[] name, int length, bool truncate = false)
{
	GetClientName(client, name, length);

	ValvePanel_ShiftInvalidString(name, length);

	if (truncate && strlen(name) > 18)
	{
		name[15] = name[16] = name[17] = '.';
		name[18] = 0;
	}
}
