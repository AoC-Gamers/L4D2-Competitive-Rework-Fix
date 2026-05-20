# specrates

## Plugin

- `left4dead2/addons/sourcemod/scripting/specrates.sp`

## Motivo del Override

`specrates` fue trasladado a `L4D2-Competitive-Rework-Fix` como parte de la consolidación de overrides mantenidos sobre plugins del proyecto competitivo.

## Cambios Aplicados

La variante actual introduce diferencias funcionales respecto del `specrates.sp` original de `L4D2-Competitive-Rework`.

### Fixes claros

- `player_team` ahora agenda el ajuste usando `userid` y no el índice de cliente directo
  - evita que el timer termine afectando un slot reciclado tras disconnect/reconnect
- se ignoran eventos `player_team` marcados como `disconnect`
  - evita timers innecesarios o tardíos
- el estado por jugador reinicia también el perfil replicado aplicado
  - reduce riesgo de estado stale al reconectar o al recalcular en caliente
- además de `cl_updaterate` y `cl_cmdrate`, ahora también se sincroniza `rate`
  - deja el perfil de rates del cliente más consistente con la replicación del servidor
- se conserva el endurecimiento global de `sv_mincmdrate` y `sv_minupdaterate` en `OnConfigsExecuted()`
  - esto preserva el mecanismo original de enforcement del plugin tras el `autoexec` y recargas de configuración del servidor

### Mejoras operativas

- se agrega `sm_specrates_debug`
  - permite inspeccionar desde runtime qué perfil se aplicó y qué valores se replicaron
- se agrega `sm_specrates_replicate_always`
  - permite decidir si se debe re-replicar siempre o solo cuando el perfil cambia
- se introduce seguimiento del perfil aplicado por jugador
  - `LIMIT`
  - `RESET`
  - `NONE`
- se agrega debug del llamador de `SetStatusRates`
  - útil para rastrear qué plugin fuerza cambios de estado

### Recolección de basura

- `OnPluginEnd()` hace cleanup explícito del hook `player_team`
- también restaura `sv_mincmdrate` y `sv_minupdaterate` al valor capturado antes del endurecimiento aplicado en `OnConfigsExecuted()`

## Diferencia Actual Respecto del Original

El plugin actual debe considerarse un override funcional del `specrates.sp` upstream, no una copia idéntica.

Diferencias principales:

- más estado por jugador
- nuevas `ConVar` para debug y política de replicación
- más validaciones alrededor de cambios de equipo
- más instrumentación de debug
- lógica adicional para evitar replicaciones redundantes
- preservación del modelo original de ajuste global mínimo, combinada con mejor control de replicación por cliente

## Compatibilidad

- el include público y los natives principales se mantienen
- los cambios afectan sobre todo la política de aplicación de rates y la observabilidad del plugin
- el plugin sigue dependiendo de modificar `sv_mincmdrate` y `sv_minupdaterate` después de ejecutar configuración del servidor
- si se ajusta nuevamente esa semántica global, debe documentarse aquí
