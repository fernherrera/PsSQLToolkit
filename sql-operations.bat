@echo off
set PowerShellScriptPath=%~dpn0.ps1
set Args=%*
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File """"%PowerShellScriptPath%"""" %Args% ' -Verb RunAs}";