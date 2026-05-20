# l4d2_hybrid_scoremod_zone

## Plugin

- `left4dead2/addons/sourcemod/scripting/l4d2_hybrid_scoremod_zone.sp`
- `left4dead2/addons/sourcemod/scripting/include/l4d2_hybrid_scoremod_zone.inc`
- `left4dead2/addons/sourcemod/translations/l4d2_hybrid_scoremod.phrases.txt`
- `left4dead2/addons/sourcemod/translations/es/l4d2_hybrid_scoremod.phrases.txt`

## Motivo del Override

Este plugin fue movido a `L4D2-Competitive-Rework-Fix` porque recibió un rework técnico equivalente al `hybrid` principal, con cambios de sintaxis, API pública, traducciones y cleanup, y debe mantenerse como override del proyecto competitivo.

## Cambios Aplicados

### Sintaxis y tipado

- migración a sintaxis moderna de SourcePawn
- uso de `#pragma newdecls required`
- reemplazo de sintaxis legacy por tipos explícitos
- reutilización de `L4DTeam`, `L4DWeaponSlot` y helpers de `left4dhooks_stocks.inc`

### API pública

- creación del include `l4d2_hybrid_scoremod_zone.inc`
- incorporación de `SMPlusBonusType`
- incorporación de:
  - `SMPlus_GetBonus(SMPlusBonusType type, int client = 0)`
  - `SMPlus_GetMaxBonus(SMPlusBonusType type)`
  - `SMPlus_FillBonusSnapshotKv(KeyValues kv)`
  - `forward void SMPlus_OnMatchFinalized(int winningTeam)`

### Snapshot y datos expuestos

- snapshot por `KeyValues`
- estructura `clients/<userid>`
- bonus por health, damage, pills y total
- estado de rondas y tiebreaker en el snapshot

### Traducciones y chat

- reutiliza el mismo archivo de frases del hybrid principal
- uso de `colors.inc`
- adopción de `CPrintToChat` y `CPrintToChatAll`

### Limpieza y flujo

- cleanup explícito en `OnPluginEnd()`
- unhook de eventos, ConVars y SDKHooks
- liberación del `GlobalForward`
- corrección del reset de elegibilidad de tiebreaker al inicio de ronda

## Compatibilidad

- mantiene el modelo competitivo de la variante `zone`
- expone una API alineada con `l4d2_hybrid_scoremod`, pero en include y librería separados

## Archivos Asociados

- include propio
- traducciones compartidas con `l4d2_hybrid_scoremod`

Este plugin debe desplegarse junto con su include y el archivo de frases compartido.
