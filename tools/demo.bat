@echo off
rem Demo launch presets (docs/demo-2026-11-07.md). Usage: tools\demo.bat N [bot]
rem   1  plain room, full kit              (strings, elements, states, breakers)
rem   2  room with pieces, full kit, warrior spar   (counter, Pinwheel on a pillar, Anvil, Powder Keg, Frost Wall, gallows)
rem   3  flooded cistern, full kit         (down the channel: Dash L H, pause, L)
rem   4  forge hall, full kit              (powder line L L L H H; bonded plates L H H, L in the window)
rem   5  room with pieces, full kit, archer spar    (parry bolts back)
rem   6  plain room, full kit, warrior spar
rem Add "bot" after the number to watch the autotest bot play every string in that preset (3-4 min, quits by itself).
rem Add "show" after 3 or 4 to watch the bot play that room's showcase combos (string_film --showcase, quits by itself).
setlocal
set "ROOT=%~dp0.."
set "GODOT=godot"
where godot >nul 2>nul || set "GODOT=%LOCALAPPDATA%\Programs\Godot\godot.exe"
set "FLAGS="
if "%~1"=="1" set "FLAGS=--kit=full --room=plain"
if "%~1"=="2" set "FLAGS=--kit=full --room=pieces --spar=warrior"
if "%~1"=="3" set "FLAGS=--kit=full --room=cistern"
if "%~1"=="4" set "FLAGS=--kit=full --room=forge"
if "%~1"=="5" set "FLAGS=--kit=full --room=pieces --spar=archer"
if "%~1"=="6" set "FLAGS=--kit=full --room=plain --spar=warrior"
if not defined FLAGS (
	echo usage: tools\demo.bat N [bot]   ^(N = 1..6, see the top of this file^)
	exit /b 1
)
if /i "%~2"=="bot" set "FLAGS=%FLAGS% --autotest"
set "SCRIPT="
if /i "%~2"=="show" set "SCRIPT=-s tests/string_film.gd"
if /i "%~2"=="show" set "FLAGS=%FLAGS% --showcase --dir=demo_show"
echo demo %~1: "%GODOT%" --path "%ROOT%" %SCRIPT% -- %FLAGS%
"%GODOT%" --path "%ROOT%" %SCRIPT% -- %FLAGS%
