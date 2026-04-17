@echo off
title SmartMedia Search - Lancement
echo ================================
echo  Lancement de SmartMedia Search
echo ================================

echo [1/2] Demarrage du backend...
start "Backend FastAPI" cmd /k "cd /d "%~dp0backend_python" && "%~dp0backend_python\.venv_win\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port 5000"

timeout /t 3 /nobreak >nul

echo [2/2] Demarrage du serveur web...
start "Serveur Web" cmd /k "cd /d "%~dp0appwebsmart\build\web" && "%~dp0backend_python\.venv_win\Scripts\python.exe" -m http.server 7357"

timeout /t 2 /nobreak >nul

echo [3/3] Ouverture dans Edge...
start msedge --new-window --disable-web-security --user-data-dir=C:\temp\edge-dev http://localhost:7357

echo.
echo App lancee sur http://localhost:7357
echo Backend sur   http://localhost:5000
echo.
echo Fermez cette fenetre quand vous avez fini.
pause
