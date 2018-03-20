setlocal

IF "%PROCESSOR_ARCHITECTURE%" == "AMD64" goto b64
IF "%PROCESSOR_ARCHITEW6432%" == "AMD64" goto b64

:b32
set SPLUNK_MSI=%~dp0\splunkforwarder-4.2-96430-x86-release.msi
goto endb6432

:b64
set SPLUNK_MSI=%~dp0\splunkforwarder-4.2-96430-x64-release.msi
:endb6432

if not defined ProgramFilesW6432 (    
    set LOC=%ProgramFiles%\Splunk
) else (
    set LOC=%ProgramFilesW6432%\Splunk
)

:: INSTALL THE SPLUNK UNIVERSAL FORWARDER
msiexec.exe /i "%SPLUNK_MSI%" INSTALLDIR="%LOC%" AGREETOLICENSE=Yes MIGRATESPLUNK=1 LAUNCHSPLUNK=0 /QUIET
pause
:: COPY OUR APP FOLDERS TO THE UNIVERSAL FORWARDER
xcopy "%~dp0\etc" "%LOC%\etc" /s /f /y
pause
cd "%LOC%\bin\"
pause

:: START THE UNIVERSAL FORWARDER
splunk restart
pause

:: REMOVE THE OLD SPLUNK FORWARDER
msiexec /x d:\software\Splunk\PrevAgent\splunk-86.msi /passive /lv d:\software\splunk\splunk-uninstall-log.txt
pause

endlocal