int Native_GetMode(Handle plugin, int numParams)
{
	return view_as<int>(GetScoreMode());
}

int Native_AddExternalBonus(Handle plugin, int numParams)
{
	SMPlusBonusType type = GetNativeCell(1);
	float value = view_as<float>(GetNativeCell(2));
	int client = numParams >= 3 ? GetNativeCell(3) : 0;

	if (type == SMPlusBonusType_Total)
	{
		return ThrowNativeError(SP_ERROR_PARAM, "SMPlusBonusType_Total is read-only; modify Health, Damage, or Pills instead.");
	}

	AddExternalBonus(type, value, client);
	return 0;
}

int Native_SetExternalBonus(Handle plugin, int numParams)
{
	SMPlusBonusType type = GetNativeCell(1);
	float value = view_as<float>(GetNativeCell(2));
	int client = numParams >= 3 ? GetNativeCell(3) : 0;

	if (type == SMPlusBonusType_Total)
	{
		return ThrowNativeError(SP_ERROR_PARAM, "SMPlusBonusType_Total is read-only; modify Health, Damage, or Pills instead.");
	}

	SetExternalBonus(type, value, client);
	return 0;
}

any Native_GetExternalBonus(Handle plugin, int numParams)
{
	SMPlusBonusType type = GetNativeCell(1);
	int client = numParams >= 2 ? GetNativeCell(2) : 0;

	return view_as<any>(GetExternalBonus(type, client));
}

int Native_ResetExternalBonus(Handle plugin, int numParams)
{
	int client = numParams >= 1 ? GetNativeCell(1) : 0;

	ResetExternalBonus(client);
	return 0;
}

int Native_FillSnapshot(Handle plugin, int numParams)
{
	KeyValues kv = GetNativeCell(1);
	FillSnapshotKv(kv);
	return 0;
}

int Native_FillClientSnapshot(Handle plugin, int numParams)
{
	int		  client = GetNativeCell(1);
	KeyValues kv	 = GetNativeCell(2);
	FillClientSnapshotKv(client, kv);
	return 0;
}
