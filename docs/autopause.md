# autopause

## Plugin

- `left4dead2/addons/sourcemod/scripting/autopause.sp`
- `left4dead2/addons/sourcemod/translations/es/autopause.phrases.txt`

## Motivo del Override

`autopause` fue movido a `L4D2-Competitive-Rework-Fix` porque recibió una corrección de flujo en `player_disconnect` para evitar crashes al consultar el equipo de un cliente durante disconnect `Pre`.

## Cambios Aplicados

### Disconnect seguro

En `Event_PlayerDisconnect()`:

- se eliminó la dependencia de `GetClientTeam(client)` durante el evento `player_disconnect`
- ahora se usa el team cacheado en `teamPlayers`

### Caso survivor muerto

- si el cache indica survivor, el flujo trata al jugador como survivor válido aunque ya no esté en juego o ya no esté vivo

Esto evita fallas durante la resolución del evento de desconexión.

## Compatibilidad

- no cambia el comportamiento esperado de autopause
- corrige un caso de crash en una ruta de evento sensible

## Archivos Asociados

- fuente principal
- override local de traducción en español
- el resto de las traducciones puede seguir viniendo del repo base `L4D2-Competitive-Rework`
