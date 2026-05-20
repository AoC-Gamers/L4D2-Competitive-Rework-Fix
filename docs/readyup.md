# readyup

## Plugin

- `addons/sourcemod/scripting/readyup.sp`
- `addons/sourcemod/scripting/readyup/`
- `addons/sourcemod/scripting/include/readyup.inc`

## Motivo del Override

`readyup` fue movido a `L4D2-Competitive-Rework-Fix` porque recibió correcciones locales para evitar crashes en flujos de voto y errores por índices inválidos en el footer.

## Cambios Aplicados

### Validación de clientes

En `readyup/player.inc`:

- `IsPlayer()` ahora valida:
  - `client > 0`
  - rango válido
  - `IsClientInGame(client)`

Esto evita llamadas inválidas a `GetClientTeam()` sobre clientes no válidos.

### Flujo de voto

En `readyup.sp`:

- `Vote_Callback()` ahora sale temprano si el cliente no está en juego

Esto corrige el flujo reportado desde:

- `Vote_Callback -> Ready_Cmd -> IsPlayer`

### Footer

En `readyup/footer.inc`:

- `Footer.Edit()` ahora exige `index >= 0` antes de `SetString`
- `FooterGet()` ahora exige `index >= 0` antes de `GetString`

Esto evita errores tipo:

- `Invalid index -1`

cuando otro plugin intenta editar un footer aún no agregado.

### Recolección de basura

En `readyup.sp`:

- `OnPluginEnd()` ahora hace cleanup explícito del módulo principal
- desengancha `HookEvent(...)`
- remueve `AddChangeHook(...)`
- desactiva command listeners de voto rápido
- libera timers visibles del plugin principal
- libera `Footer` y `GlobalForward`

### Estructura del override

- `readyup` debe tratarse como un plugin multiarchivo
- el comportamiento del override no vive solo en `readyup.sp`, sino también en:
  - `readyup/action.inc`
  - `readyup/command.inc`
  - `readyup/game.inc`
  - `readyup/native.inc`
  - `readyup/panel.inc`
  - `readyup/player.inc`
  - `readyup/setup.inc`
  - `readyup/sound.inc`
  - `readyup/util.inc`

## Compatibilidad

- no cambia el propósito funcional del plugin
- las correcciones apuntan a robustez y prevención de crashes
- el override actual sigue siendo cercano al original en `readyup.sp`, pero el módulo completo ya incorpora hardening operativo

## Archivos Asociados

- fuente principal
- carpeta `readyup/`
- include `readyup.inc`
- depende además de las traducciones base del proyecto competitivo
