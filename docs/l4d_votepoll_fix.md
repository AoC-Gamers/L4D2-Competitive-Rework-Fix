# l4d_votepoll_fix

## Plugin

- `addons/sourcemod/scripting/l4d_votepoll_fix.sp`

## Motivo del Override

Este plugin fue movido a `L4D2-Competitive-Rework-Fix` porque recibió validaciones defensivas para evitar `GetClientTeam()` sobre clientes inválidos en el listener `vote`.

## Cambios Aplicados

### Validación en `VPF_cmdh_Vote()`

Ahora valida:

- `client > 0`
- `client <= MaxClients`
- `IsClientInGame(client)`

Con esto se evita acceso inválido al team del cliente.

### Modernización de sintaxis

- se agregó `#pragma semicolon 1`
- se agregó `#pragma newdecls required`
- se migró a firmas modernas `public Action`, `Event`, `UserMsg` y tipado explícito
- se reemplazó sintaxis legacy como `Handle:` y `String:`

### Limpieza de recursos

- se agregó `OnPluginEnd()`
- se hace `RemoveCommandListener(...)`
- se hace `UnhookEvent(...)` de los hooks registrados
- se resetea el estado de la entidad de voto y del flag de corrección

### Metadata

- se actualizó la `url` del plugin al repositorio `AoC-Gamers/L4D2-Competitive-Rework-Fix`

## Compatibilidad

- no modifica la intención funcional del plugin
- corrige un caso de crash en un flujo de comando
- fuera de eso, la diferencia con el original sigue siendo pequeña
