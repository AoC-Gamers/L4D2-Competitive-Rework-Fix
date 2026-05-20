POWERSHELL ?= powershell
SPCOMP ?= ./.tmp/sourcemod-windows/addons/sourcemod/scripting/spcomp.exe
SOURCEMOD_VERSION ?= 1.12
LINUX_SPCOMP ?= ./.tmp/sourcemod-linux/addons/sourcemod/scripting/spcomp

.PHONY: deps-windows deps-linux build build-windows build-linux clean clean-all

deps-windows:
	$(POWERSHELL) -ExecutionPolicy Bypass -Command "& './scripts/deps-windows.ps1' -SourceModVersion '$(SOURCEMOD_VERSION)'"

deps-linux:
	bash -lc "SOURCEMOD_VERSION='$(SOURCEMOD_VERSION)' ./scripts/deps-linux.sh"

build:
	$(MAKE) build-windows

build-windows:
	$(POWERSHELL) -ExecutionPolicy Bypass -Command "& './scripts/build-local.ps1' -SpCompPath '$(SPCOMP)' -OutputRoot 'build-windows'"

build-linux:
	bash -lc "SPCOMP_BIN='$(LINUX_SPCOMP)' OUTPUT_ROOT='build-linux' ./scripts/build-local-linux.sh"

clean:
	$(POWERSHELL) -ExecutionPolicy Bypass -Command "if (Test-Path './build') { Remove-Item -Recurse -Force './build' }; if (Test-Path './build-windows') { Remove-Item -Recurse -Force './build-windows' }; if (Test-Path './build-linux') { Remove-Item -Recurse -Force './build-linux' }"

clean-all:
	$(POWERSHELL) -ExecutionPolicy Bypass -Command "if (Test-Path './build') { Remove-Item -Recurse -Force './build' }; if (Test-Path './build-windows') { Remove-Item -Recurse -Force './build-windows' }; if (Test-Path './build-linux') { Remove-Item -Recurse -Force './build-linux' }; if (Test-Path './dist') { Remove-Item -Recurse -Force './dist' }; if (Test-Path './.tmp') { Remove-Item -Recurse -Force './.tmp' }"
