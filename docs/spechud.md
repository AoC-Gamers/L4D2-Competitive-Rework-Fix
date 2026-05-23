# spechud

## Plugin

- `addons/sourcemod/scripting/spechud.sp`

## Motivo del cambio

`spechud` dependía de consultar varios estados opcionales en runtime, incluyendo los boss percents almacenados.
Eso generaba acoplamiento innecesario con bibliotecas y obligaba al panel a asumir que ciertas APIs siempre estaban listas.

## Cambios aplicados

### Consumo por forward

`spechud` ahora recibe los boss percents por:

- `L4D2_OnBossPercentsUpdated(int tankPercent, int witchPercent)`

Ese callback alimenta el estado interno del HUD y evita el polling directo de `GetStoredTankPercent()` y `GetStoredWitchPercent()` en el flujo principal del round.

### Estado tipado

Se agregaron estructuras para concentrar estado relacionado:

- `BossFlowState`
  - `tankPercent`
  - `witchPercent`
  - `synced`
- `BossRoundState`
  - `tankCount`
  - `witchCount`
  - `roundHasFlowTank`
  - `roundHasFlowWitch`
  - `flowTankActive`
  - `customBossSys`

### Sincronización inicial

Se conserva una sincronización inicial única para carga tardía o arranque sin forward previo.
Después de eso, el estado se mantiene por eventos.

### Panel más declarativo

La construcción del HUD quedó más segmentada:

- `HudDrawTimer()` orquesta
- las funciones de contenido deciden internamente si pintan algo
- el estado de bosses y round se consume desde structs en lugar de globals sueltos

### Localización

El panel sigue construyéndose por cliente, así que cada receptor obtiene el HUD en su idioma.
Los nombres propios y clases del juego se conservan en inglés donde corresponde.

## Compatibilidad

- si `l4d_boss_percent` está presente, `spechud` consume el forward
- si la biblioteca no está disponible, `spechud` mantiene fallback seguro para la sincronización inicial
- el build actual compila limpio

## Resultado

`spechud` quedó menos acoplado a natives opcionales y más guiado por estado reactivo.
Eso reduce consultas repetidas y deja más clara la responsabilidad de cada plugin.
