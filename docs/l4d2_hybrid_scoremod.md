# l4d2_hybrid_scoremod

## Plugin

- `addons/sourcemod/scripting/l4d2_hybrid_scoremod.sp`
- `addons/sourcemod/scripting/include/l4d2_hybrid_scoremod.inc`
- `addons/sourcemod/translations/l4d2_hybrid_scoremod.phrases.txt`
- `addons/sourcemod/translations/es/l4d2_hybrid_scoremod.phrases.txt`

## Motivo del Override

Este plugin vive en `L4D2-Competitive-Rework-Fix` porque recibió un rework técnico amplio sobre sintaxis, API pública, traducciones, cleanup y unificación funcional con la antigua variante `zone`.

## Cambios Aplicados

### Sintaxis y tipado

- migración a sintaxis moderna de SourcePawn
- uso de `#pragma newdecls required`
- reemplazo de declaraciones legacy por `int`, `float`, `bool` y `char[]`
- reutilización de tipos y helpers de `left4dhooks_stocks.inc`

### API pública

- creación del include `l4d2_hybrid_scoremod.inc`
- incorporación de `SMPlusBonusType`
- incorporación de `SMPlus_GetBonus(SMPlusBonusType type, int client = 0)`
- incorporación de `SMPlus_GetMaxBonus(SMPlusBonusType type)`
- incorporación de `SMPlus_FillBonusSnapshotKv(KeyValues kv)`
- incorporación de `forward void SMPlus_OnMatchFinalized(int winningTeam)`

### Snapshot y datos expuestos

- snapshot por `KeyValues`
- nodo `clients` indexado por `userid`
- desglose de bonus por health, damage, pills y total

### Unificación de modos

- `l4d2_hybrid_scoremod.sp` pasó a ser la única implementación fuente
- la lógica de la antigua variante `zone` ahora se controla con `smplus_zone_mode`
- `smplus_zone_mode 0` mantiene el comportamiento tradicional
- `smplus_zone_mode 1` habilita las penalizaciones extra por incap y death de la variante `zone`
- se eliminaron consumidores internos que dependían de una librería `zone` separada

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
- `spechud` fue actualizado para consumir sólo `l4d2_hybrid_scoremod`
- en despliegues que antes cargaban `l4d2_hybrid_scoremod_zone.smx`, ahora debe cargarse `l4d2_hybrid_scoremod.smx`
- los modos `eq` y `acemodrv` requieren `smplus_zone_mode 0` en sus configs; los modos que usaban `zone` pueden seguir con el valor por defecto `1`

## Archivos Asociados

- include propio
- traducciones en inglés base y español

Este plugin debe desplegarse junto con esos archivos asociados para mantener su contrato público y mensajes traducibles.
