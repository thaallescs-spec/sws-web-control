@echo off
title SWS Web Control - Desinstalar
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0arquivos\instalador.ps1" -Desinstalar
