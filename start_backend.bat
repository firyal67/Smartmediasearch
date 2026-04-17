@echo off
title SmartMedia Backend
echo ================================
echo  SmartMedia Backend - Port 5000
echo ================================
cd /d "%~dp0backend_python"
"%~dp0backend_python\.venv_win\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port 5000
pause
