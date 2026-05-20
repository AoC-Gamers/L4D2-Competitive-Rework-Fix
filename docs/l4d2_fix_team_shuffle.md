# l4d2_fix_team_shuffle

## Plugin

- `left4dead2/addons/sourcemod/scripting/l4d2_fix_team_shuffle.sp`
- `left4dead2/addons/sourcemod/translations/l4d2_fix_team_shuffle.phrases.txt`

## Motivo del Override

Este plugin fue incorporado a `L4D2-Competitive-Rework-Fix` porque recibió una revisión más amplia que una corrección puntual: tipado, flujo de organización de equipos, ConVars nuevas y traducciones propias.

## Cambios Aplicados

### Tipado y modernización

- reemplazo de comparaciones hardcodeadas de teams por `L4DTeam`
- modernización con `#pragma semicolon 1`
- modernización con `#pragma newdecls required`
- limpieza de naming interno como `g_bFixTeam` para reflejar tipo real

### Encapsulación

- introducción del methodmap `TeamSnapshot` para encapsular captura y validación de jugadores por equipo

### ConVars nuevas

- `l4d2_fix_team_shuffle_enabled`
- `l4d2_fix_team_shuffle_announcer`

Esto permite separar:

- lógica de shuffle
- avisos visibles del plugin

### Flujo de organización

El aviso de espera dejó de depender de un timer repetitivo y pasó a un flujo reactivo:

- si un jugador intenta entrar a un equipo incorrecto durante la reorganización, vuelve a spectators y recibe contexto por chat
- al terminar la ventana de organización, se imprime un mensaje global

### API pública y estado persistido

- agrega natives `L4D2FixTeamShuffle_*`
- agrega forwards `L4D2FixTeamShuffle_On*`
- persiste jugadores por `accountId` en vez de `client`
- mantiene cache de nombres y jugadores abandonados para interoperabilidad

### Recolección de basura

- `OnPluginEnd()` hace cleanup explícito
- desengancha `HookEvent(...)`
- remueve `AddChangeHook(...)`
- libera `GlobalForward`, `StringMap`, `ArrayList` y snapshots

### Traducciones

- se agregaron traducciones propias del plugin en `l4d2_fix_team_shuffle.phrases.txt`

## Compatibilidad

- mantiene el objetivo del plugin
- mejora control operacional y claridad del flujo durante reorganización de equipos
- hoy debe considerarse un override amplio respecto del original, no una corrección pequeña

## Archivos Asociados

- fuente principal
- archivo de traducciones propio
