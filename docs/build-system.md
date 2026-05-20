# Sistema de Build

## Objetivo

Este repositorio usa un flujo `smx` transversal, igual al que se aplicó en otros repos de SourceMod del stack:

- mismo flujo lógico para local y CI
- mismo script Python para Windows y Linux
- `make` como interfaz corta
- soporte automático para WSL cuando el repo vive bajo `/mnt/`

## Archivos principales

- `Makefile`
- `plugin-package-map.json`
- `scripts/fetch-sourcemod.py`
- `scripts/build-local.py`
- `scripts/stage-artifact.py`
- `scripts/package-release.py`
- `scripts/ci-build-sourcemod.sh`
- `scripts/ci-validate-artifact.sh`
- `scripts/ci-package-release-assets.sh`
- `.github/workflows/sourcemod-build.yml`

## Targets

- `make deps-smx`
- `make build-smx`
- `make package-smx`
- `make release`
- `make clean`
- `make clean-all`

## Manifiesto

`plugin-package-map.json` define dos capas:

- `build.plugins`
- `artifact.addons.sourcemod`

### Build

`build.plugins` se organiza por bucket:

- `root`
- `anticheat`
- `fixes`

Todo plugin no listado cae por defecto en `optional`.

### Artifact

`artifact.addons.sourcemod` define qué runtime entra al paquete final.

Cada sección puede usar:

- `files`
- `dirs`
- `all: true`

Actualmente este repo publica:

- `addons/sourcemod/scripting`
- `addons/sourcemod/translations`

## Flujo

Separación operativa:

- `deps-smx`: descarga el `sourcemod-package` para la plataforma actual
- `build-smx`: compila plugins `.sp` a `.smx`
- `package-smx`: arma el árbol runtime compartido
- `release`: genera `dist/sourcemod/artifact/` y el ZIP final

## WSL

Si el repositorio está bajo `/mnt/`, `build-local.py` usa automáticamente un workspace temporal en `/tmp/l4d2crf-build` para evitar la penalización de I/O sobre discos montados de Windows.

## CI

El workflow usa jobs explícitos:

- `deps-smx`
- `build-smx`
- `release`

`release` absorbe el empaquetado liviano y luego:

- valida el artifact
- genera el ZIP final
- publica artifact temporal de Actions
- publica release asset persistente en `channel/latest` y `channel/develop`
