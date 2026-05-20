# l4d2_scoremod

## Plugin

- `left4dead2/addons/sourcemod/scripting/l4d2_scoremod.sp`
- `left4dead2/addons/sourcemod/scripting/include/l4d2_scoremod.inc`
- `left4dead2/addons/sourcemod/translations/l4d2_scoremod.phrases.txt`
- `left4dead2/addons/sourcemod/translations/es/l4d2_scoremod.phrases.txt`

## Motivo del Override

Este plugin fue movido a `L4D2-Competitive-Rework-Fix` porque dejó de ser una simple copia local y pasó a tener un rework técnico propio sobre API, sintaxis, traducciones, cleanup y flujo de activación.

## Cambios Aplicados

### Sintaxis y tipado

- migración a sintaxis moderna de SourcePawn
- uso de `#pragma newdecls required`
- tipado explícito en globals, firmas y helpers

### API pública

- creación del include `l4d2_scoremod.inc`
- incorporación de `SMClassicBonusType`
- incorporación de:
  - `SMClassic_GetBonus(SMClassicBonusType type, int client = 0)`
  - `SMClassic_GetMaxBonus(SMClassicBonusType type)`
  - `SMClassic_FillBonusSnapshotKv(KeyValues kv)`
  - `forward void SMClassic_OnMatchFinalized(int winningTeam)`

### Snapshot y datos expuestos

- snapshot por `KeyValues`
- estructura `clients/<userid>`
- bonus total por cliente
- datos de salud permanente, temporal e incap count

### Traducciones y chat

- mensajes movidos a traducciones
- uso de `colors.inc`
- adopción de `CPrintToChat` y `CPrintToChatAll`

### Limpieza y flujo

- cleanup explícito al finalizar el plugin
- `PluginDisable()` ahora desengancha eventos del módulo
- `say` y `say_team` quedan registrados una sola vez en `OnPluginStart()`
- limpieza de `GlobalForward`

## Compatibilidad

- el plugin clásico mantiene un modelo de bonus total, no un desglose equivalente al hybrid
- la API fue simplificada para reflejar ese modelo

## Archivos Asociados

- include propio
- traducciones en inglés base y español

Este plugin debe desplegarse junto con su include y archivos de frases.
