setlocal

:: 32-bit
:: set SPLUNK_MSI=%~dp0\splunkforwarder-4.2-96430-x86-release.msi
:: 64-bit
::set SPLUNK_MSI=%~dp0\splunkforwarder-4.2-96430-x64-release.msi
set LOC=c:\Program Files\SplunkUniversalForwarder
::set OLDLOC=c:\Program Files\Splunk

:: INSTALL THE SPLUNK UNIVERSAL FORWARDER
pause
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
 
:: msiexec /x "%OLDLOC%\AAAA.msi" /passive /lv "%LOC%\splunk-uninstall-log.txt"
:: pause
 
Endlocal