# caster_system

## Plugin

- `addons/sourcemod/scripting/caster_system.sp`
- `addons/sourcemod/scripting/include/caster_system.inc`
- `addons/sourcemod/translations/es/caster_system.phrases.txt`

## Motivo del Override

`caster_system` fue incorporado a `L4D2-Competitive-Rework-Fix` como parte de la consolidación de overrides mantenidos sobre plugins del proyecto competitivo.

## Cambios Aplicados

Este override elimina la capa de integración con SQL porque no es necesaria para el flujo mantenido en este repo.

Cambios principales:

- fuente principal
- include público alineado con la API actual del plugin
- override local de traducción en español
- incorporación de `steamidtools_stock.inc` para normalizar identificadores Steam
- API pública simplificada para trabajar solo con `int accountId`
- `AccountID` como identificador interno y externo por defecto para caster, whitelist e inmunidad de spec
- soporte más flexible para registro/remoción por SteamID2, SteamID3 y AccountID
- uso de `int accountId` en la lógica interna, dejando la conversión a string solo como borde para `StringMap`
- corrección de nombres `Immunity` en código y API pública
- debug runtime por `ConVar` en vez de `#define`
- integración con `adminmenu` / `topmenus` para navegación administrativa
- comandos administrativos sin apertura automática de menú cuando se usan sin argumentos
- remoción de ConVars relacionadas a SQL
- remoción de comandos `sm_caster_sql*`
- remoción de conexión, cache y sincronización de whitelist por base de datos
- conservación del manejo local en memoria para caster y whitelist

## Diferencia Actual Respecto del Original

La variante actual difiere de forma visible del `caster_system.sp` original de `L4D2-Competitive-Rework`.

Diferencias principales:

- sintaxis y estructura más modernas
- tipado explícito y reorganización de enums, globals y helpers
- uso de `StringMap`, `ConVar` y `GlobalForward` con un estilo distinto al original
- comandos administrativos ampliados y reorganizados para caster y whitelist local
- carga de traducciones encapsulada en `vLoadTranslation(...)`
- uso de `left4dhooks` para team checks y flujo de spectator
- eliminación completa del backend SQL que sí existe en el original
- include público diferente al original, centrado en `AccountID`

En términos prácticos, este plugin debe considerarse un override amplio o fork mantenido, no un parche mínimo sobre upstream.

## Navegación Administrativa

El plugin ahora integra acciones administrativas en el `adminmenu` de SourceMod usando `topmenus`.

Árbol actual:

```text
Admin Menu
├─ Caster
│  ├─ Register
│  ├─ List
│  ├─ Remove
│  └─ Clear
└─ Whitelist
   ├─ Register
   ├─ List
   ├─ Remove
   └─ Clear
```

Notas:

- `TopMenu` solo soporta dos niveles prácticos: categoría e ítems
- por esa limitación no se implementó un árbol `Caster System -> Caster/Whitelist -> Action` dentro del admin menu estándar
- los menús de selección de targets siguen existiendo, pero ahora se abren desde `topmenu` y no desde comandos vacíos

## ConVars Relevantes

- `caster_debug`
  - activa logging de debug en runtime sin recompilar el plugin
- `caster_kickspecs_immunity`
  - habilita o deshabilita la lista de inmunidad para el voto/flujo de expulsión de espectadores
- `caster_whitelist`
  - controla si el self-register requiere whitelist
- `caster_selfreg`
  - controla si los jugadores pueden registrarse a sí mismos como casters
- `caster_addons`
  - controla la lógica de addons para casters

## Comandos

- `sm_caster <target|steamid>`
- `sm_caster_rm <target|steamid>`
- `sm_caster_ls`
- `sm_caster_clear`
- `sm_caster_wl <target|steamid>`
- `sm_caster_wl_rm <target|steamid>`
- `sm_caster_wl_ls`
- `sm_caster_wl_clear`

Los comandos de registro/remoción ya no abren menús cuando se ejecutan sin argumentos; en ese caso muestran su forma de uso. La navegación por menú queda centralizada en `topmenu`.

## Compatibilidad

- el plugin también depende de `common.phrases` y de su archivo base `caster_system.phrases`
- el comportamiento soportado queda centrado en listas locales, no en backend SQL
- el include público expone `bKickSpecImmunity(...)` como nombre principal y deja `bKickSpecInmunity(...)` como wrapper legacy
- si en el futuro se agregan fixes locales concretos, deben documentarse aquí
