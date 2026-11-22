# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# build.ps1 is the build (make.bat wraps it too, for cmd.exe); never runs an emulator.
PS := pwsh -NoProfile -ExecutionPolicy Bypass -File build.ps1

.PHONY: all build release cpc nula run help

all: build

build:
	$(PS)

release:
	$(PS) -Release

cpc:
	$(PS) -Cpc

nula:
	$(PS) -Nula

# Launches b-em: only when asked for by name.
run:
	$(PS) -Run

help:
	@echo make          - build build\EDGE.SSD (build.ps1)
	@echo make release  - every DEBUG_ flag off (build.ps1 -Release)
	@echo make cpc      - drawn with the Amstrad CPC artwork, build\EDGE-CPC.SSD
	@echo make nula     - VideoNuLA test build, build\EDGE-NULA.SSD
	@echo make run      - build and launch b-em as a Master 128 (build.ps1 -Run)
	@echo make help     - this list
