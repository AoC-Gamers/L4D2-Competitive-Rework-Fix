# match_vote

## Plugin

- `left4dead2/addons/sourcemod/scripting/match_vote.sp`
- `left4dead2/addons/sourcemod/translations/match_vote.phrases.txt`
- `left4dead2/addons/sourcemod/translations/es/match_vote.phrases.txt`

## Motivo del Override

`match_vote` fue incorporado a `L4D2-Competitive-Rework-Fix` como parte de la consolidación de overrides mantenidos sobre plugins del proyecto competitivo.

## Cambios Aplicados

La variante actual de `match_vote` ya no es una copia mínima del original. Introduce una capa pública y varios cambios de flujo para integrarse mejor con otros plugins del repo.

Cambios principales:

- fuente principal modernizada y reorganizada
- traducciones base
- traducciones en español
- API pública con natives `MatchVote_*`
- forward `MatchVote_OnCanAccessConfig`
- validación externa por config para mostrar/ejecutar votos
- manejo más flexible de `mv_maxplayers`
  - soporta `-1` para volver al valor configurado por defecto del servidor
- debug runtime por `ConVar`
- cleanup explícito de `KeyValues`, vote handle y `GlobalForward` al descargar el plugin

## API Pública

Natives expuestos:

- `MatchVote_ShowMenu(client, MatchVoteType voteType)`
- `MatchVote_StartVote(client, const char[] config, MatchVoteType voteType)`
- `MatchVote_StartResetVote(client)`
- `MatchVote_ConfigExists(const char[] config)`
- `MatchVote_GetConfigDisplayName(const char[] config, char[] displayName, int maxlen)`
- `MatchVote_GetConfigNum(const char[] config, const char[] key, int defaultValue)`
- `MatchVote_GetConfigString(const char[] config, const char[] key, char[] value, int maxlen)`

Forward expuesto:

- `MatchVote_OnCanAccessConfig(int client, const char[] config, MatchVoteType voteType, MatchVoteAccessType accessType)`

Uso del forward:

- permite a otros plugins aprobar o bloquear acceso a una config específica
- se invoca tanto al construir menús como al ejecutar un voto

## ConVars Relevantes

- `sm_match_vote_enabled`
  - habilita o deshabilita el plugin
- `mv_maxplayers`
  - cantidad de slots a aplicar al cargar o descargar match config
  - `-1` restaura el valor por defecto configurado del servidor
- `sm_match_player_limit`
  - mínimo de jugadores activos para iniciar un voto
- `match_vote_debug`
  - habilita logging de debug en `logs/matchmodes.log`

## Diferencia Actual Respecto del Original

Diferencias principales respecto a upstream:

- el plugin expone una API pública nueva
- permite control externo por config mediante forward
- ya no está orientado solo a comandos de chat, sino también a integración entre plugins
- tiene mejor manejo del valor default de `sv_maxplayers`
- incluye debug runtime y mejor separación de helpers

En términos prácticos, este archivo debe considerarse un override funcional ampliado, no un parche mínimo sobre el original.

## Compatibilidad

- mantiene el flujo base de `!match`, `!chmatch` y `!rmatch`
- sigue dependiendo de `confogl`
- el forward de acceso puede cambiar qué configs son visibles o ejecutables para un cliente dado
