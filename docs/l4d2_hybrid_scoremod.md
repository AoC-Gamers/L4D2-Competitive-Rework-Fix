# l4d2_hybrid_scoremod

## Plugin

- `addons/sourcemod/scripting/l4d2_hybrid_scoremod.sp`
- `addons/sourcemod/scripting/include/l4d2_hybrid_scoremod.inc`
- `addons/sourcemod/translations/l4d2_hybrid_scoremod.phrases.txt`
- `addons/sourcemod/translations/es/l4d2_hybrid_scoremod.phrases.txt`

## Motivo del Override

Este plugin vive en `L4D2-Competitive-Rework-Fix` porque recibió un rework técnico amplio sobre sintaxis, API pública, traducciones y cleanup, y necesita mantenerse como override documentado del plugin competitivo base.

## Cambios Aplicados

### Sintaxis y tipado

- migración a sintaxis moderna de SourcePawn
- uso de `#pragma newdecls required`
- reemplazo de declaraciones legacy por `int`, `float`, `bool` y `char[]`
- reutilización de tipos y helpers de `left4dhooks_stocks.inc`

### API pública

- creación del include `l4d2_hybrid_scoremod.inc`
- incorporación de `SMPlusBonusType`
- incorporación de:
  - `SMPlus_GetBonus(SMPlusBonusType type, int client = 0)`
  - `SMPlus_GetMaxBonus(SMPlusBonusType type)`
  - `SMPlus_FillBonusSnapshotKv(KeyValues kv)`
  - `forward void SMPlus_OnMatchFinalized(int winningTeam)`

### Snapshot y datos expuestos

- snapshot por `KeyValues`
- nodo `clients` indexado por `userid`
- desglose de bonus por health, damage, pills y total

### Traducciones y chat

- mensajes visibles movidos a traducciones
- uso de `colors.inc`
- adopción de `CPrintToChat` y `CPrintToChatAll`

### Limpieza y flujo

- cleanup explícito en `OnPluginEnd()`
- `UnhookConVarChange(...)`
- `UnhookEvent(...)`
- `SDKUnhook(...)` de clientes conectados
- `delete` del `GlobalForward`
- corrección de estado transitorio de tiebreaker entre rondas

## Compatibilidad

- se mantuvieron las fórmulas competitivas como objetivo de compatibilidad
- la superficie API legacy fue reducida en favor de la API nueva y tipada

## Archivos Asociados

- include propio
- traducciones en inglés base y español

Este plugin debe desplegarse junto con esos archivos asociados para mantener su contrato público y mensajes traducibles.
