@echo off

REM - script to remove etc/system/local .conf files to give app control of forwarder

REM - if deploymentclient.conf file is gone from etc/system/local script has already run so exit

if not exist "C:\Program Files\SplunkUniversalForwarder\etc\system\local\deploymentclient.conf" exit

REM - create a junk directory to save files 

SET COPYCMD=/Y
md "C:\Program Files\SplunkUniversalForwarder\junk"

REM - copy to junk then delete etc/system/local .conf files

copy "C:\Program Files\SplunkUniversalForwarder\etc\system\local\deploymentclient.conf" "C:\Program Files\SplunkUniversalForwarder\junk"
del /q "C:\Program Files\SplunkUniversalForwarder\etc\system\local\deploymentclient.conf"
copy "C:\Program Files\SplunkUniversalForwarder\etc\system\local\outputs.conf" "C:\Program Files\SplunkUniversalForwarder\junk"
del /q "C:\Program Files\SplunkUniversalForwarder\etc\system\local\outputs.conf" 

REM - copy to junk then remove the MSICreated app

xcopy "C:\Program Files\SplunkUniversalForwarder\etc\apps\MSICreated" "C:\Program Files\SplunkUniversalForwarder\junk" /S
del /q "C:\Program Files\SplunkUniversalForwarder\etc\apps\MSICreated\*.*"
rd "C:\Program Files\SplunkUniversalForwarder\etc\apps\MSICreated" /s /q

