@echo off
:: Set variables
set IP_ADDRESS=192.168.12.1
set SERVICE_NAME=ZeroTierOneService
set SERVICE_DISPLAY_NAME=ZeroTier
set LOG_FILE=service_restarts.csv
set MAX_RETRIES=3
set RETRY_DELAY=10
set RTO_THRESHOLD=3

:: Create log file if it doesn't exist
if not exist %LOG_FILE% (
    echo Date,Time,Service,Status > %LOG_FILE%
) else (
    if not exist %LOG_FILE%.lock (
        echo [%date% %time%] Log file already exists, appending to it...
    ) else (
        echo [%date% %time%] Error: Log file is locked, cannot write to it.
        pause
        exit /b 1
    )
)

:: Initialize RTO counter
set RTO_COUNT=0

:: Loop indefinitely
:loop
:: Ping IP address
echo [%date% %time%] Pinging %IP_ADDRESS%...
ping -n 3 -w 5000 %IP_ADDRESS% | find "Request timed out" > nul
if %errorlevel% == 0 (
    set /a RTO_COUNT+=1
    echo [%date% %time%] Ping to %IP_ADDRESS% timed out. RTO count: %RTO_COUNT%
    if %RTO_COUNT% geq %RTO_THRESHOLD% (
        echo [%date% %time%] RTO threshold reached. Restarting %SERVICE_DISPLAY_NAME% service...
        :: Stop service
        call :stop_service
        set RTO_COUNT=0
    ) else (
        timeout /t 3 /nobreak > nul
        goto :loop
    )
) else (
    echo [%date% %time%] Ping to %IP_ADDRESS% successful.
    set RTO_COUNT=0
    timeout /t 10 /nobreak > nul
    goto :loop
)

:: Stop service subroutine
:stop_service
echo [%date% %time%] Stopping %SERVICE_DISPLAY_NAME% service...
sc query %SERVICE_NAME% | find "STATE" | find "RUNNING" > nul
if %errorlevel% == 0 (
    sc stop %SERVICE_NAME% > nul
    if %errorlevel% neq 0 (
        echo [%date% %time%] Failed to stop %SERVICE_DISPLAY_NAME% service. Error: %errorlevel%
        goto :loop
    )
) else (
    echo [%date% %time%] %SERVICE_DISPLAY_NAME% service is already stopped.
)
timeout /t 10 /nobreak > nul
:: Start service
call :start_service

:: Start service subroutine
:start_service
set retry_count=0
:start_service_retry
echo [%date% %time%] Starting %SERVICE_DISPLAY_NAME% service...
sc start %SERVICE_NAME% > nul
if %errorlevel% neq 0 (
    echo [%date% %time%] Failed to start %SERVICE_DISPLAY_NAME% service. Error: %errorlevel%
    set /a retry_count+=1
    if %retry_count% lss %MAX_RETRIES% (
        echo [%date% %time%] Retry %retry_count% of %MAX_RETRIES%. Waiting %RETRY_DELAY% seconds...
        timeout /t %RETRY_DELAY% /nobreak > nul
        goto :start_service_retry
    ) else (
        echo [%date% %time%] Maximum retries reached. Giving up.
        goto :loop
    )
) else (
    echo [%date% %time%] %SERVICE_DISPLAY_NAME% service restarted successfully.
    echo %date%,%time%,%SERVICE_DISPLAY_NAME%,Restarted >> %LOG_FILE%
    timeout /t 15 /nobreak > nul
    set RTO_COUNT=0
    goto :loop
)

:: Exit cleanly (not reached)
goto :eof