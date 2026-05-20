# l4d_tank_damage_announce

## Plugin

- `left4dead2/addons/sourcemod/scripting/l4d_tank_damage_announce.sp`

## Motivo del Override

Este plugin fue movido a `L4D2-Competitive-Rework-Fix` porque recibió correcciones para evitar `Invalid memory access` en el reporte de daño al tank.

## Cambios Aplicados

### Manejo de arrays

- `PrintTankDamage()` ya no usa un array local dimensionado por `survivor_limit`
- ahora usa un array de `MAXPLAYERS + 1`
- se agregó un contador real `survivor_count`

### Ordenamiento y loops

- `SortCustom1D()` ahora ordena solo las entradas válidas cargadas
- el loop final itera solo `survivor_count`

### Fallback de nombre

- si el antiguo tank ya no sigue en juego, usa fallback `Player <id>`
- evita llamar `GetClientName()` sobre un cliente inválido

### Modernización de sintaxis

- se agregó `#pragma newdecls required`
- se migró a tipado explícito con `ConVar`, `GlobalForward`, `bool`, `int` y `float`
- se eliminó sintaxis legacy como `new`, `Handle:` y `Float:`
- se separaron helpers para cálculo de vida, búsqueda del tank, ordenamiento y limpieza de estado

### Recolección de basura

- se agregó `OnPluginEnd()`
- se hace `UnhookEvent(...)` de los eventos registrados por el plugin
- se hace `UnhookConVarChange(...)` de los cambios de cvars usados
- se libera el `GlobalForward` `OnTankDeath`

### Metadata

- se actualizó la `url` del plugin a `https://github.com/AoC-Gamers/L4D2-Competitive-Rework-Fix`

## Compatibilidad

- no cambia el objetivo del plugin
- corrige robustez del flujo de impresión al finalizar o cambiar el tank
- mantiene la semántica general del original, pero con implementación más segura y consistente
