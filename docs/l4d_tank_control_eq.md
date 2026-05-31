# Cambios de `l4d_tank_control_eq`

## Alcance

Este documento describe las nuevas adiciones a la API pública realizadas en:

- [l4d_tank_control_eq.sp](C:/GitHub/L4D2-Competitive-Rework-Fix/addons/sourcemod/scripting/l4d_tank_control_eq.sp)
- [l4d_tank_control_eq.inc](C:/GitHub/L4D2-Competitive-Rework-Fix/addons/sourcemod/scripting/include/l4d_tank_control_eq.inc)

El objetivo de estos cambios es exponer un ciclo de vida estable del Tank y señales reales de cambio de control, para que los plugins externos puedan consumir la propiedad del Tank con menos suposiciones en tiempo de ejecución.

## Motivación

La API pública anterior solo exponía:

- `GetTankSelection()`
- `TankControl_OnTryOfferingTankBot(char sQueuedTank[64])`
- `TankControl_OnTankSelection(char sQueuedTank[64])`

Eso bastaba para anular o inspeccionar la selección de la cola, pero no era suficiente para modelar:

- un único ciclo de vida del Tank a través de `bot -> human -> bot -> human`
- cambios reales de control
- el jugador actualmente en espera para reemplazo
- la continuidad a nivel de ronda del mismo Tank

Esta nueva API mantiene el comportamiento anterior y añade señales conscientes del ciclo de vida.

## Nuevo enum público

```sourcepawn
enum TankControlLifecycleEndReason
{
	TankControlLifecycleEnd_None = 0,
	TankControlLifecycleEnd_TankDied,
	TankControlLifecycleEnd_RoundEnded
}
```

## Nuevos natives

### `TankControl_GetActiveTankLifecycleId()`

Devuelve el id del ciclo de vida del Tank que está siendo rastreado activamente.

- devuelve `0` si no hay un ciclo de vida activo del Tank

### `TankControl_GetCurrentTankClient()`

Devuelve el índice del cliente que controla actualmente al Tank.

- devuelve `-1` si no hay un ciclo de vida activo del Tank

### `TankControl_GetPendingTankClient()`

Devuelve el índice del cliente actualmente en cola para el Tank.

- devuelve `-1` si no hay un jugador de Tank en cola disponible

### `TankControl_GetClientTankLifecycleId(int client)`

Devuelve el id del ciclo de vida del Tank activo asociado a un cliente.

Un cliente queda asociado cuando coincide con:

- el controlador actual del Tank
- o el jugador de reemplazo actualmente en cola

- devuelve `0` si el cliente no está asociado al ciclo de vida activo del Tank

## Nuevos forwards

### `TankControl_OnTankLifecycleStarted(int lifecycleId, int client, bool isBot)`

Se dispara cuando comienza un nuevo ciclo de vida rastreado del Tank.

Implementación actual:

- comienza desde `L4D_OnTryOfferingTankBot(...)`
- el controlador inicial suele ser el Tank IA

### `TankControl_OnTankControlChanged(int lifecycleId, int oldClient, int newClient, bool oldWasBot, bool newWasBot)`

Se dispara cuando cambia el control del Tank rastreado.

Implementación actual:

- se activa desde `L4D2_OnTankPassControl(...)`

Este es el forward principal para plugins externos que necesiten seguir cambios reales de propiedad del Tank.

### `TankControl_OnTankLifecycleEnded(int lifecycleId, TankControlLifecycleEndReason reason)`

Se dispara cuando termina el ciclo de vida rastreado del Tank.

Implementación actual:

- `TankControlLifecycleEnd_TankDied`
  - desde `player_death` cuando el Tank muere
- `TankControlLifecycleEnd_RoundEnded`
  - desde `round_end`

## Nuevo estado interno en tiempo de ejecución

Ahora el plugin rastrea el estado del Tank mediante contenedores tipados en lugar de globals planos.

### `TankLifecycleState`

Contenedor interno del ciclo de vida:

- `id`
- `currentClient`
- `pendingClient`
- `disconnectFrustration`
- `graceTime`
- `gotTankAt`

Respaldado por:

- `g_TankLifecycle`

### `TankSelectionState`

Contenedor interno de la selección:

- `queuedSteamId`
- `initialSteamId`
- `initialTankLeft`

Respaldado por:

- `g_TankSelection`

El estado global relacionado todavía se mantiene por separado:

- `g_iTankLifecycleSerial`

Estos son detalles de implementación interna que soportan la API pública.

## Limpieza del tipado en runtime

El plugin ahora reutiliza helpers tipados de:

- [left4dhooks_stocks.inc](C:/GitHub/L4D2-Competitive-Rework-Fix/addons/sourcemod/scripting/include/left4dhooks_stocks.inc)

En lugar de usar definiciones locales `#define` para team/class.

El runtime actual usa:

- `L4DTeam`
- `L4D2ZombieClassType`
- `L4D_GetClientTeam(...)`
- `L4D2_GetPlayerZombieClass(...)`

Se introdujeron helpers booleanos locales:

- `bIsSpectator(...)`
- `bIsInfected(...)`
- `bIsValidInfected(...)`
- `bIsValidSpectator(...)`
- `bIsTankPlayer(...)`

Esto eliminó definiciones locales del plugin como:

- `TEAM_SPECTATOR`
- `TEAM_INFECTED`
- `ZOMBIECLASS_TANK`
- `IS_*`

## Autoconsumo de la API pública

El plugin ahora incluye su propia biblioteca pública:

- [l4d_tank_control_eq.inc](C:/GitHub/L4D2-Competitive-Rework-Fix/addons/sourcemod/scripting/include/l4d_tank_control_eq.inc)

Esto permite que el runtime reutilice tipos públicos directamente.

Ejemplo actual:

- `TankControlLifecycleEndReason`

El archivo `.sp` ya no duplica valores locales `#define` para los motivos de fin de ciclo de vida.

## Limpieza al descargar el plugin

El plugin ahora realiza limpieza explícita en `OnPluginEnd()`.

Limpieza actual al descargarse:

- `ResetTankLifecycleState()`
- `g_TankSelection.Reset()`
- `delete g_hWhosHadTank`
- `delete g_hTankQueue`

Esto busca mantener explícito el apagado del estado en tiempo de ejecución y evitar estado lógico obsoleto durante escenarios de descarga o recarga del plugin.

No pretende reemplazar la limpieza propia de SourceMod, sino definir un contrato explícito de apagado para el estado interno de este plugin.

## API existente preservada

La API anterior sigue disponible:

- `GetTankSelection()`
- `TankControl_OnTryOfferingTankBot(...)`
- `TankControl_OnTankSelection(...)`

Esto mantiene funcionando a los consumidores antiguos mientras permite que los nuevos consuman señales conscientes del ciclo de vida.

## Cableado actual en runtime

La primera implementación usa estos hooks:

- inicio del ciclo de vida:
  - `L4D_OnTryOfferingTankBot(...)`
- cambio de control:
  - `L4D2_OnTankPassControl(...)`
- fin del ciclo de vida:
  - `player_death`
  - `round_end`
- actualización del jugador en cola:
  - rutas de selección/anulación del Tank
