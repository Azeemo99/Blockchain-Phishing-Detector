@echo off
chcp 65001 >nul
title Blockchain Social Engineering Detector
color 0A
cls

:: Set working directory to location of this batch file
cd /d "%~dp0"

:: Check Python availability
python --version >nul 2>&1
if %errorlevel% == 0 (
    echo Python found.
    set PYTHON=python
    goto :check_packages
)

echo Python not found.
echo.
pause
exit /b 1

:check_packages
echo.
echo Checking required packages...
%PYTHON% -c "import flask, transformers, sklearn, torch, pandas, numpy" >nul 2>&1
if %errorlevel% == 0 (
    echo All packages already installed. Skipping installation.
    goto :start_server
)

echo Packages not found. Attempting installation...
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
    echo ERROR Installation failed.
    echo.
    pause
    exit /b 1
)

:verify_packages
%PYTHON% -c "import flask, transformers, sklearn, torch" >nul 2>&1
if %errorlevel% neq 0 (
    echo Package verification failed after installation.
    pause
    exit /b 1
)
echo All packages installed and verified.

:start_server
echo Starting server...
echo Loading models

:: Kill any existing process on port 5000
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":5000"') do (
    taskkill /f /pid %%a >nul 2>&1
)

:: Start Flask server in background
start /B %PYTHON% "%~dp0app.py" > "%~dp0server.log" 2>&1

:: Wait for server to come up
echo Waiting for server to start...
:wait_loop
timeout /t 3 /nobreak >nul
%PYTHON% -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/status', timeout=2)" >nul 2>&1
if %errorlevel% neq 0 goto :wait_loop
echo [OK] Server is running.

echo.
echo Opening browser...
start http://localhost:5000

echo.
echo Demo running at http://localhost:5000
echo.
echo Press any key to stop the demo
echo.
pause >nul

:: Clean shutdown
echo Stopping server...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":5000"') do (
    taskkill /f /pid %%a >nul 2>&1
)
taskkill /f /im python.exe >nul 2>&1
echo Goodbye.
timeout /t 2 /nobreak >nul
exit /b 0