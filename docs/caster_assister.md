# caster_assister

## Plugin

- `addons/sourcemod/scripting/caster_assister.sp`

## Motivo del cambio

El plugin original dependía del wrapper legacy `IsClientCaster(...)`.
En este repo la API activa de caster está expuesta por `caster_system` mediante el native `bCaster(accountId, CasterSystemAction_Get)`, así que el asistente debía consumir esa interfaz en vez de asumir el wrapper viejo.

## Cambios aplicados

### API actualizada

`caster_assister` ahora consulta el estado de caster con:

- `bCaster(accountId, CasterSystemAction_Get)`

Eso evita depender del wrapper legacy y alinea el plugin con la API actual de `caster_system`.

### Guardia de runtime

Se agregó un flag local para saber si `caster_system` está cargado antes de consultar el native.
Si la biblioteca no está presente, el plugin no intenta usar esa API.

### Comportamiento conservado

El flujo principal se mantiene:

- los casters siguen pudiendo abrir `sm_spechud` al entrar
- los comandos de specspeed siguen funcionando igual
- el control vertical por `IN_USE` y `IN_RELOAD` no cambió

## Compatibilidad

- compatible con la API actual de `caster_system`
- no depende del wrapper legacy `IsClientCaster(...)`
- el build actual compila limpio

## Resultado

`caster_assister` quedó desacoplado del wrapper viejo y alineado con la forma actual de consultar caster status en el repositorio.
