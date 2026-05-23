# l4d_boss_percent

## Plugin

- `addons/sourcemod/scripting/l4d_boss_percent.sp`
- `addons/sourcemod/scripting/include/l4d2_boss_percents.inc`
- `addons/sourcemod/translations/l4d_boss_percent.phrases.txt`
- `addons/sourcemod/translations/es/l4d_boss_percent.phrases.txt`

## Motivo del cambio

Este plugin dejó de ser solo una copia de soporte y pasó a exponer cambios de boss percents mediante un forward público.
La meta fue permitir que otros plugins consuman el estado sin depender de polling directo de natives.

## Cambios aplicados

### Forward agregado

Se añadió el forward:

- `L4D2_OnBossPercentsUpdated(int tankPercent, int witchPercent)`

Ese forward notifica cambios en los porcentajes almacenados del tank y la witch.

### Emisión del forward

El plugin ahora emite la notificación desde los puntos donde realmente cambia el estado:

- `OnMapEnd()`
- `DKRWorkaround()`
- `GetBossPercents()`

### Evitar emisiones redundantes

Se mantiene el último par de valores enviados al forward.
Si los porcentajes no cambiaron, el forward no se vuelve a disparar.

### Include actualizado

El include `l4d2_boss_percents.inc` ahora declara el forward para que otros plugins puedan suscribirse.

## Compatibilidad

- el plugin sigue pudiendo desplegarse como módulo independiente
- no cambia la interfaz de sus natives existentes
- ahora también publica estado reactivo para consumidores como `spechud`

## Resultado

`l4d_boss_percent` ahora actúa como fuente de verdad para los porcentajes almacenados y notifica los cambios en vez de obligar a otros plugins a consultarlos en bucle.
