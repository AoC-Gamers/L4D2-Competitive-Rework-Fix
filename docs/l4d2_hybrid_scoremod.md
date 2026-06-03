# l4d2_hybrid_scoremod

## Plugin

- `addons/sourcemod/scripting/l4d2_hybrid_scoremod.sp`
- `addons/sourcemod/scripting/include/l4d2_hybrid_scoremod.inc`
- `addons/sourcemod/translations/l4d2_hybrid_scoremod.phrases.txt`
- `addons/sourcemod/translations/es/l4d2_hybrid_scoremod.phrases.txt`

## Estado Actual

`l4d2_hybrid_scoremod.sp` es la unica implementacion fuente de esta familia.

La antigua variante `l4d2_hybrid_scoremod_zone.sp` fue absorbida y eliminada.

## Modos de Score

El comportamiento interno del plugin se controla con:

- `smplus_mode 0` = `legacy`
- `smplus_mode 1` = `hybrid`
- `smplus_mode 2` = `zone`

La formula interna de score solo se aplica cuando el modo base detectado por el juego es `Versus`.

En `Coop`, `Scavenge`, `Survival` u otros modos:

- el plugin conserva contexto de lifecycle
- el score base queda en `0`
- la API sigue disponible para bonus externos

## API Publica

El include expone:

- `SMPlus_GetMode()`
- `SMPlus_AddExternalBonus(SMPlusBonusType type, float value, int client = 0)`
- `SMPlus_SetExternalBonus(SMPlusBonusType type, float value, int client = 0)`
- `SMPlus_GetExternalBonus(SMPlusBonusType type, int client = 0)`
- `SMPlus_ResetExternalBonus(int client = 0)`
- `SMPlus_FillSnapshot(KeyValues kv)`
- `SMPlus_FillClientSnapshot(int client, KeyValues kv)`

Forwards:

- `SMPlus_OnScoreUpdated()`
- `SMPlus_OnRoundFinalized(int round)`
- `SMPlus_OnMatchFinalized(int winningTeam)`

## Bonus Base, Externo y Efectivo

El plugin ahora separa tres capas:

- `bonus` = bonus base calculado por el plugin
- `bonus_external` = bonus agregado por otros plugins
- `bonus_effective` = suma final visible

Esto aplica tanto a nivel equipo como a nivel survivor.

### Scope de bonus externo

- `client = 0` modifica bonus externo de equipo
- `client > 0` modifica bonus externo del survivor indicado

## Snapshot KV

El snapshot principal incluye, entre otros:

- `mode`
- `base_mode`
- `score_model`
- `current_round`
- `round_finalized`
- `round_live`
- `match_finalized`
- `round_start_signal`
- `round_end_signal`
- `round_live_signal`

Subarboles principales:

- `bonus`
- `bonus_max`
- `bonus_external`
- `bonus_effective`
- `rounds`
- `legacy` o `hybrid`
- `clients`

Cada survivor en `clients/<userid>` expone:

- `health_bonus`
- `damage_bonus`
- `pills_bonus`
- `total_bonus`
- `external_health_bonus`
- `external_damage_bonus`
- `external_pills_bonus`
- `external_total_bonus`
- `effective_health_bonus`
- `effective_damage_bonus`
- `effective_pills_bonus`
- `effective_total_bonus`

## Lifecycle por Modo

El plugin mantiene una capa de lifecycle inspirada en el trabajo de `L4D2-Player-Stats`.

Actualmente usa contexto por modo para:

- detectar modo base
- resolver señales canonicas de inicio de ronda
- resolver señales canonicas de fin de ronda
- distinguir live inmediato, safe area o readyup

Eso prepara el plugin para extensiones futuras sin forzar formulas de score en modos no soportados.

## Compatibilidad de Configs

Para modos competitivos que usan score tradicional `hybrid`:

- usar `confogl_addcvar smplus_mode 1`

Para modos que antes cargaban `zone`:

- usar `confogl_addcvar smplus_mode 2`
- o dejar el valor por defecto si ese despliegue ya depende de `zone`

## Ejemplo de Uso

Ejemplo simple desde otro plugin:

```sourcepawn
#include <l4d2_hybrid_scoremod>

public void SomeRuleTriggered()
{
    SMPlus_AddExternalBonus(SMPlusBonusType_Total, 25.0);
}

public void RewardSingleSurvivor(int client)
{
    SMPlus_AddExternalBonus(SMPlusBonusType_Total, 10.0, client);
}
```

Leer snapshot:

```sourcepawn
KeyValues kv = new KeyValues("scoremod_snapshot");
SMPlus_FillSnapshot(kv);
```

## Despliegue

Este plugin debe desplegarse junto con:

- su include
- sus traducciones

Si el repositorio original necesita migracion previa a instalacion, el hook correspondiente del flujo de instalacion es el lugar correcto para adaptar configs y nombres de plugin sin tocar upstream.
