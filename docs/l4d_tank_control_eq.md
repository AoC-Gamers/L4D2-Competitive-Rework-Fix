# `l4d_tank_control_eq`

## Alcance

Este documento describe la API pública y los cambios internos actuales de:

- [l4d_tank_control_eq.sp](C:/GitHub/L4D2-Competitive-Rework-Fix/addons/sourcemod/scripting/l4d_tank_control_eq.sp)
- [l4d_tank_control_eq.inc](C:/GitHub/L4D2-Competitive-Rework-Fix/addons/sourcemod/scripting/include/l4d_tank_control_eq.inc)

El objetivo es exponer un `tankId` estable para el mismo Tank durante toda su vida en la ronda, distinguir Tanks `primary` y `substitute`, y entregar señales confirmadas de cambio de control.

## Motivación

La API histórica de este plugin era suficiente para:

- elegir quién sería el Tank
- inspeccionar o sobreescribir la cola

Pero no bastaba para modelar bien:

- `bot -> humano -> bot -> humano`
- cambios reales de control
- identidad estable del mismo Tank a través de reasignaciones

La API actual se centra en `tankId` y mantiene las señales de selección existentes.

## Modelo semántico

El plugin distingue dos tipos de Tank:

- `primary`
  - Tank original de la cadena actual
  - `parentTankId = 0`
- `substitute`
  - Tank nuevo que reemplaza a otro Tank terminado
  - `parentTankId = <tankId previo>`

Esto permite a consumidores distinguir de forma explícita continuidad de control y reemplazo semántico de Tank, sin depender de heurísticas de reconnect o handoff.

## Enum público

```sourcepawn
enum TankControlEndReason
{
	TankControlEnd_None = 0,
	TankControlEnd_TankDied,
	TankControlEnd_RoundEnded
}
```

```sourcepawn
enum TankControlStartReason
{
	TankControlStart_Unknown = 0,
	TankControlStart_Primary,
	TankControlStart_Substitute
}
```

## Natives públicos

### `GetTankSelection()`

Devuelve el cliente seleccionado para recibir el Tank.

- devuelve `-1` si no hay nadie seleccionado

### `TankControl_GetActiveTankId()`

Devuelve el `tankId` activo.

- devuelve `0` si no hay un Tank activo

### `TankControl_GetCurrentTankClient()`

Devuelve el cliente que controla actualmente el Tank.

- devuelve `-1` si no hay un Tank activo

### `TankControl_GetPendingTankClient()`

Devuelve el cliente en cola para recibir el Tank.

- devuelve `-1` si no hay un jugador en cola válido

### `TankControl_GetClientTankId(int client)`

Devuelve el `tankId` activo asociado a un cliente.

Un cliente queda asociado cuando coincide con:

- el controlador actual del Tank
- el jugador actualmente en cola para recibirlo

- devuelve `0` si el cliente no está asociado al Tank activo

### `TankControl_IsSubstituteTank(int tankId)`

Devuelve si el `tankId` activo representa un Tank sustituto.

### `TankControl_GetParentTankId(int tankId)`

Devuelve el `tankId` padre de un Tank sustituto.

- devuelve `0` si el Tank no tiene padre

### `TankControl_GetTankStartReason(int tankId)`

Devuelve la razón semántica de inicio del Tank:

- `TankControlStart_Primary`
- `TankControlStart_Substitute`

## Forwards públicos

### `TankControl_OnTryOfferingTankBot(char sQueuedTank[64])`

Se dispara antes de finalizar a quién se intentará dar el Tank desde la IA.

### `TankControl_OnTankSelection(char sQueuedTank[64])`

Se dispara cuando el plugin selecciona a un jugador en cola para el Tank.

### `TankControl_OnTankStarted(int tankId, int client, bool isBot)`

Se dispara cuando comienza un Tank rastreado nuevo.

Implementación actual:

- nace desde `L4D_OnTryOfferingTankBot(...)`
- el primer controlador suele ser la IA

### `TankControl_OnTankStartedEx(int tankId, int client, bool isBot, TankControlStartReason startReason, int parentTankId)`

Se dispara junto al forward histórico, pero además expone:

- si el Tank es `primary` o `substitute`
- el `parentTankId` cuando el Tank es sustituto

### `TankControl_OnTankControlChanged(int tankId, int oldClient, int newClient, bool oldWasBot, bool newWasBot)`

Se dispara cuando cambia el control del Tank rastreado.

Implementación actual:

- se activa desde `L4D2_OnTankPassControl(...)`

Este es el forward principal para consumidores que necesiten seguir handoffs reales del Tank.

### `TankControl_OnTankEnded(int tankId, TankControlEndReason reason)`

Se dispara cuando termina el Tank rastreado.

Implementación actual:

- `TankControlEnd_TankDied`
  - desde `player_death`
- `TankControlEnd_RoundEnded`
  - desde `round_end`

## Estado interno

El runtime ya no usa globals sueltas para el estado principal del Tank. Ahora encapsula el estado en `enum struct`.

### `TankControlState`

Contenedor interno del Tank activo:

- `id`
- `parentTankId`
- `startReason`
- `isSubstitute`
- `currentClient`
- `pendingClient`
- `disconnectFrustration`
- `graceTime`
- `gotTankAt`

Respaldado por:

- `g_TankControl`

### `TankSelectionState`

Contenedor interno de selección:

- `queuedSteamId`
- `initialSteamId`
- `initialTankLeft`

Respaldado por:

- `g_TankSelection`

Además, el serial incremental del `tankId` se mantiene en:

- `g_iTankIdSerial`
- `g_iPendingSubstituteParentTankId`

## Tipado y helpers

El plugin reutiliza tipado de:

- [left4dhooks_stocks.inc](C:/GitHub/L4D2-Competitive-Rework-Fix/addons/sourcemod/scripting/include/left4dhooks_stocks.inc)

En lugar de `#define` locales para team/class.

El runtime actual usa:

- `L4DTeam`
- `L4D2ZombieClassType`
- `L4D_GetClientTeam(...)`
- `L4D2_GetPlayerZombieClass(...)`

Helpers locales actuales:

- `bIsSpectator(...)`
- `bIsInfected(...)`
- `bIsValidInfected(...)`
- `bIsValidSpectator(...)`
- `bIsTankPlayer(...)`

## Autoconsumo de la biblioteca

El `.sp` incluye su propia biblioteca pública:

- [l4d_tank_control_eq.inc](C:/GitHub/L4D2-Competitive-Rework-Fix/addons/sourcemod/scripting/include/l4d_tank_control_eq.inc)

Eso evita duplicar tipos públicos dentro del runtime. Actualmente el caso visible es:

- `TankControlEndReason`

## Limpieza al descargar el plugin

`OnPluginEnd()` realiza limpieza explícita de estado:

- `ResetTankControlState()`
- `g_TankSelection.Reset()`
- `delete g_hWhosHadTank`
- `delete g_hTankQueue`

Esto no reemplaza la limpieza propia de SourceMod; deja explícito el contrato de apagado del estado interno.

## Cableado actual del runtime

La implementación actual se apoya en:

- inicio de Tank:
  - `L4D_OnTryOfferingTankBot(...)`
- cambio de control:
  - `L4D2_OnTankPassControl(...)`
- fin del Tank:
  - `player_death`
  - `round_end`
- selección y cola:
  - rutas de selección/anulación del Tank

## Reglas de inicio

- si no existe un Tank previo encadenable, nace un Tank `primary`
- si un Tank termina y el sistema competitivo continúa la cadena con otro Tank, nace un Tank `substitute`
- un cambio de controller del mismo Tank no crea un `tankId` nuevo

## Uso esperado por consumidores

- seguir continuidad por `tankId`
- usar `TankControl_OnTankControlChanged(...)` para cambios reales de controller
- usar `TankControl_OnTankStartedEx(...)` para distinguir:
  - continuidad del mismo Tank
  - inicio de un Tank sustituto con `parentTankId`
