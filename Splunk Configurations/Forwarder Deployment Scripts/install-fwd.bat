::
:: Splunk Universal Forwarder (UF) installer script
::
:: August/2015 ateixeira@splunk.com
:: Tested on Windows 2008 R2, should work on other versions
::
:: What to customize here?
::
:: - UFMSI (Universal FWD package/installer location)
:: - DS (Hostname:Port of Deployment Server)
:: - SUBDIR (default install subdirectory under %ProgramFiles%)
:: - INSTALLOPS (Installer options for msiexec command)
:: - VMIMG (set to 1 in case preparing a VM/OS image)
::

setlocal enabledelayedexpansion

:: UF msi file (UAC enabled defaults to System32), safer: set to an absolute path
set UFMSI=c:\temp\splunkforwarder-X.Y.Z-build-arch.msi

:: DS hostname and port (leave empty if no DS available)
set DS=your.ds.server:8089

:: Default install subdir (from Splunk docs)
set FWDDIR=%ProgramFiles%\SplunkUniversalForwarder

:: For removing any unique identifiers from the instance, set the value to 1
set VMIMG=0

:: Installer default options
:: - Accepts the license
:: - Set Splunk service to start right after installation
:: - Set Splunk service to start after boot process
:: - Collect only Security events
:: - NO receivers/indexers defined

:: Append "/L*V C:\path\to\output\log.txt" for enabling msiexec's log
set INSTALLOPTS=LAUNCHSPLUNK=1 AGREETOLICENSE=Yes SERVICESTARTTYPE=auto WINEVENTLOG_SEC_ENABLE=1 /QUIET
