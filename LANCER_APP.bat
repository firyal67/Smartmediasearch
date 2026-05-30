@echo off
title SmartMedia Search
echo Demarrage de SmartMedia Search...

start "Backend" cmd /k "cd /d "%~dp0backend_python" && "%~dp0backend_python\.venv_win\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port 5000"

timeout /t 3 /nobreak >nul

start "Web" cmd /k "cd /d "%~dp0appwebsmart\build\web" && "%~dp0backend_python\.venv_win\Scripts\python.exe" -m http.server 7357 --bind 0.0.0.0"

timeout /t 2 /nobreak >nul

start msedge --new-window --disable-web-security --user-data-dir=C:\temp\edge-dev3 http://localhost:7357

echo App lancee sur http://localhost:7357
