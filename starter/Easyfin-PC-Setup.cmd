@echo off
rem Easyfin PC Setup starter. Double-click: asks for administrator, then opens the setup window.
rem It holds no scripts itself - it always fetches the newest ones from GitHub.
title Easyfin PC Setup
fltmc >nul 2>&1
if errorlevel 1 (
  echo Asking Windows for administrator rights - click Yes...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WindowStyle Minimized"
  exit /b
)
echo Easyfin PC Setup is starting. Leave this window open - it closes by itself at the end.
powershell -NoProfile -ExecutionPolicy Bypass -STA -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { irm https://raw.githubusercontent.com/Otakukun1/easyfin-pc-setup/main/gui/start-gui.ps1 | iex } catch { Write-Host $_.Exception.Message -ForegroundColor Red; Write-Host 'Could not start. Check the internet connection.' -ForegroundColor Red; pause }"
