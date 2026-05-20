POWERSHELL ?= powershell
PYTHON ?= python
PYTHON3 ?= python3
SPCOMP ?= deps/sourcemod-windows/addons/sourcemod/scripting/spcomp.exe
SOURCEMOD_VERSION ?= 1.12
LINUX_SPCOMP ?= deps/sourcemod-linux/addons/sourcemod/scripting/spcomp

.PHONY: deps-windows deps-linux build-windows build-linux artifact-windows artifact-linux clean clean-all

deps-windows:
	$(PYTHON) ./scripts/fetch-sourcemod.py --root . --platform windows --version "$(SOURCEMOD_VERSION)"

deps-linux:
	$(PYTHON3) ./scripts/fetch-sourcemod.py --root . --platform linux --version "$(SOURCEMOD_VERSION)"

build-windows:
	$(PYTHON) ./scripts/build-local.py --root . --spcomp "$(SPCOMP)" --output-root build-windows --compile-log deps/build-windows-compile.log

build-linux:
	$(PYTHON3) ./scripts/build-local.py --root . --spcomp "$(LINUX_SPCOMP)" --output-root build-linux --compile-log deps/build-linux-compile.log --workspace /tmp/l4d2crf-build

artifact-windows:
	$(MAKE) build-windows
	$(PYTHON) ./scripts/stage-artifact.py . ./build-windows ./deps/build-windows-compile.log

artifact-linux:
	$(MAKE) build-linux
	$(PYTHON3) ./scripts/stage-artifact.py . ./build-linux ./deps/build-linux-compile.log

clean:
	cmd /c "if exist build rmdir /s /q build & if exist build-windows rmdir /s /q build-windows & if exist build-linux rmdir /s /q build-linux"

clean-all:
	cmd /c "if exist build rmdir /s /q build & if exist build-windows rmdir /s /q build-windows & if exist build-linux rmdir /s /q build-linux & if exist dist rmdir /s /q dist & if exist deps rmdir /s /q deps"
