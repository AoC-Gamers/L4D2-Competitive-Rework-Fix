# L4D2-Competitive-Rework-Fix

Repositorio de fixes y overrides para plugins provenientes de `L4D2-Competitive-Rework`.

## Objetivo

Este repo existe para ofrecer una capa mantenida de correcciones, ajustes y documentación sobre plugins usados en servidores competitivos basados en `L4D2-Competitive-Rework`.

La idea es mantener aquí:

- overrides sobre plugins del proyecto competitivo
- fixes de estabilidad
- mejoras de tipado, API o mantenimiento
- traducciones y assets asociados cuando forman parte del override

## Estructura

Se replica la misma estructura esperada por SourceMod:

- `addons/sourcemod/scripting/`
- `addons/sourcemod/scripting/include/`
- `addons/sourcemod/translations/`
- `docs/`

Para los binarios compilados, el CI empaqueta los plugins en:

- `addons/sourcemod/plugins/anticheat/`
- `addons/sourcemod/plugins/fixes/`
- `addons/sourcemod/plugins/optional/`

`disabled/` no se gestiona desde este repo porque corresponde a una convención de despliegue de SourceMod y no a una categoría funcional del proyecto.

## Mapeo de Binarios

El archivo `plugin-package-map.json` define qué plugins deben salir fuera de `optional/`.

- `anticheat`: plugins que deben empaquetarse en `plugins/anticheat/`
- `fixes`: plugins que deben empaquetarse en `plugins/fixes/`
- `root`: plugins que deben empaquetarse directamente en `plugins/`
- cualquier plugin no listado cae por defecto en `plugins/optional/`

Actualmente:

- `match_vote` se empaqueta en `plugins/`
- `l4d2_fix_team_shuffle` se empaqueta en `plugins/fixes/`

## Build Local

Targets disponibles:

- `make deps-smx`
- `make build-smx`
- `make package-smx`
- `make release`
- `make clean`
- `make clean-all`

Comportamiento:

- `make deps-smx` descarga el compilador de SourceMod para la plataforma actual
- `make build-smx` genera salida en `.build/smx/`
- `make package-smx` prepara `.build/package-smx/`
- `make release` genera `dist/sourcemod/artifact/` y `dist/release/*.zip`

`build-smx` no descarga dependencias automáticamente.
Primero hay que ejecutar `make deps-smx`.

En Windows los targets usan `python`.
En Linux/WSL los targets usan `python3`.
En Linux/WSL, `build-smx` compila desde un workspace temporal en `/tmp/l4d2crf-build` cuando el repo está bajo `/mnt/`, para evitar la lentitud de I/O sobre discos montados.

Los builds locales incluyen solo el contenido desplegable bajo:

- `addons/sourcemod/plugins/`
- `addons/sourcemod/scripting/`
- `addons/sourcemod/translations/`

Documentación del sistema de build:

- [docs/build-system.md](docs/build-system.md)

## Documentacion

Los cambios que justifican que un plugin viva en esta capa se documentan en `docs/` usando un archivo por plugin.

Documentos actuales:

- `docs/autopause.md`
- `docs/caster_system.md`
- `docs/l4d_tank_damage_announce.md`
- `docs/l4d_votepoll_fix.md`
- `docs/l4d2_character_fix.md`
- `docs/l4d2_fix_team_shuffle.md`
- `docs/l4d2_hybrid_scoremod.md`
- `docs/l4d2_hybrid_scoremod_zone.md`
- `docs/l4d2_scoremod.md`
- `docs/l4d2_skill_detect.md`
- `docs/match_vote.md`
- `docs/readyup.md`
- `docs/specrates.md`

## Plugins y Assets Incluidos

Plugins y assets actualmente incluidos en esta capa:

- `readyup.sp`
- `readyup/`
- `include/readyup.inc`
- `autopause.sp`
- `caster_system.sp`
- `l4d_tank_damage_announce.sp`
- `l4d_votepoll_fix.sp`
- `l4d2_character_fix.sp`
- `l4d2_fix_team_shuffle.sp`
- `match_vote.sp`
- `specrates.sp`
- `l4d2_skill_detect.sp`
- `l4d2_skill_detect/`
- `l4d2_hybrid_scoremod.sp`
- `l4d2_hybrid_scoremod_zone.sp`
- `l4d2_scoremod.sp`
- `include/l4d2_hybrid_scoremod.inc`
- `include/l4d2_hybrid_scoremod_zone.inc`
- `include/l4d2_scoremod.inc`
- `translations/l4d2_hybrid_scoremod.phrases.txt`
- `translations/es/l4d2_hybrid_scoremod.phrases.txt`
- `translations/l4d2_scoremod.phrases.txt`
- `translations/es/l4d2_scoremod.phrases.txt`
- `translations/l4d2_fix_team_shuffle.phrases.txt`
- `translations/match_vote.phrases.txt`
- `translations/es/autopause.phrases.txt`
- `translations/es/caster_system.phrases.txt`
- `translations/es/match_vote.phrases.txt`

## Alcance

Este repo está orientado a plugins y recursos que funcionen como fixes u overrides del ecosistema competitivo base.

No busca ser:

- un paquete completo de servidor
- una colección de plugins específicos de un proyecto privado
- un reemplazo total del repo upstream
