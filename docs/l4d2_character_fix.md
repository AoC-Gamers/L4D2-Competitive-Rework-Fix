# l4d2_character_fix

## Plugin

- `addons/sourcemod/scripting/l4d2_character_fix.sp`

## Motivo del Override

Este plugin fue movido a `L4D2-Competitive-Rework-Fix` porque recibió una corrección defensiva en el listener `jointeam` para evitar llamadas inválidas a `GetClientTeam()`.

## Cambios Aplicados

### Validación en `TeamCmd()`

Ahora valida:

- `iClient > 0`
- `iClient <= MaxClients`
- `IsClientInGame(iClient)`

Con eso se evita consultar equipo sobre clientes fuera de juego.

### Limpieza menor

- se ajustó el naming interno de la cvar cacheada a `g_cvMaxZombies`
- no cambia comportamiento, solo consistencia con tipado moderno

## Compatibilidad

- no cambia la lógica funcional del fix de personajes
- corrige robustez en el listener de cambio de equipo
- sigue siendo un override pequeño y defensivo respecto del original
