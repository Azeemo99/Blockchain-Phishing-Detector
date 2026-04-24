@echo off
title ZPhisher - Blockchain Social Engineering Detector
color 0A
cls

echo ============================================================
echo   ZPhisher - Blockchain Social Engineering Detection Demo
echo   CMP-6013Y Final Year Project - Azeem Abdul-Rahim
echo ============================================================
echo.

:: Set working directory to location of this batch file
cd /d "%~dp0"

:: Check Python availability
python --version >nul 2>&1
if %errorlevel% == 0 (
    echo [OK] Python found on this machine.
    set PYTHON=python
    goto :check_packages
)

echo [ERROR] Python not found.
echo Please run this on a machine with Python installed.
echo.
pause
exit /b 1

:check_packages
echo.
echo [1/3] Checking required packages...
%PYTHON% -c "import flask, transformers, sklearn, torch, pandas, numpy" >nul 2>&1
if %errorlevel% == 0 (
    echo [OK] All packages already installed. Skipping installation.
    goto :start_server
)

echo [INFO] Packages not found. Attempting installation...
echo.

:: Try offline installation from bundled wheels first
if exist "%~dp0packages\" (
    echo [INFO] Found local package cache. Installing offline...
    %PYTHON% -m pip install --no-index --find-links="%~dp0packages" flask flask-cors transformers torch scikit-learn pandas numpy --quiet
    if %errorlevel% == 0 (
        echo [OK] Offline installation successful.
        goto :verify_packages
    )
    echo [WARN] Offline install failed. Trying online...
)

:: Fall back to online installation
echo [INFO] Installing from internet (requires connection)...
echo       This may take 2-3 minutes. Please wait.
echo.
%PYTHON% -m pip install flask flask-cors "transformers==4.40.0" "torch==2.2.0" "numpy<2" scikit-learn pandas --quiet
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Installation failed.
    echo         Please check internet connection or contact supervisor.
    echo.
    pause
    exit /b 1
)

:verify_packages
%PYTHON% -c "import flask, transformers, sklearn, torch" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Package verification failed after installation.
    echo         Please contact supervisor for assistance.
    pause
    exit /b 1
)
echo [OK] All packages installed and verified.

:start_server
echo.
echo [2/3] Starting ZPhisher server...
echo       Loading 3 models - please wait 60-90 seconds.
echo       (A green dot will appear in the browser when ready)
echo.

:: Kill any existing process on port 5000
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":5000"') do (
    taskkill /f /pid %%a >nul 2>&1
)

:: Start Flask server in background
start /B %PYTHON% "%~dp0app.py" > "%~dp0server.log" 2>&1

:: Wait for server to come up
echo [INFO] Waiting for server to start...
:wait_loop
timeout /t 3 /nobreak >nul
%PYTHON% -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/status', timeout=2)" >nul 2>&1
if %errorlevel% neq 0 goto :wait_loop
echo [OK] Server is running.

echo.
echo [3/3] Opening browser...
start http://localhost:5000

echo.
echo ============================================================
echo   DEMO RUNNING at http://localhost:5000
echo.
echo   Models loading in background (~60 seconds)
echo   AMBER dot = still loading
echo   GREEN dot = all 3 models ready
echo.
echo   Press any key in THIS window to STOP the demo
echo ============================================================
echo.
pause >nul

:: Clean shutdown
echo Stopping server...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":5000"') do (
    taskkill /f /pid %%a >nul 2>&1
)
taskkill /f /im python.exe >nul 2>&1
echo Done. Goodbye.
timeout /t 2 /nobreak >nul
exit /b 0