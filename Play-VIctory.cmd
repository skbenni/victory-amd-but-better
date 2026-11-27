@echo off
setlocal EnableExtensions DisableDelayedExpansion
if not "%~1"=="" if /i not "%~1"=="pareto-residency" (
  echo Usage: Play-VIctory.cmd [pareto-residency] 1>&2
  exit /b 2
)
if not defined VICTORY_GAME_DIR set "VICTORY_GAME_DIR=%~dp0..\GTA6.Xbox.v1.0.2.1"
if not exist "%VICTORY_GAME_DIR%\game_scarlett_master.exe" (
  echo Set VICTORY_GAME_DIR to your own dump folder containing game_scarlett_master.exe. 1>&2
  exit /b 2
)
if not defined VICTORY_CACHE_DIR set "VICTORY_CACHE_DIR=%LOCALAPPDATA%\VIctory\cache-fusion"
if not exist "%~dp0target\release\victory.exe" (
  echo Run cargo build --release --locked -p victory first. 1>&2
  exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\play.ps1" -Exe "%VICTORY_GAME_DIR%\game_scarlett_master.exe" -Build release -Console series-s
exit /b %errorlevel%
