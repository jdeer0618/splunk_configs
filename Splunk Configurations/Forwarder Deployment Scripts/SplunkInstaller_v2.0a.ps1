<#
  Author:		Jon Donahue, Randy Trobock
  Date:			9/8/2014
  Description:	This script will deploy Splunk remotely to a list of computers.
  
  Requirements:
  	- WinRM:	Windows Remote Management is required to execute script remotely.
				Configure WinRM:
					- winrm quickconfig -q
				Disble WinRM:
					- winrm delete winrm/config/Listener?Address=*+Transport=HTTP
	- Computer List:
		This script REQUIRES a file 'ComputerList.txt'.
					
  Notes:
  	- Capture Output
		Run: .\SplunkInstaller_v2.0.ps1 4> "report.txt"
	
	
	
  Version:
  	2.0:
		- Working version!
		- Remote copy command fails due to a permission issue called "Double-Hop", see 
		  'http://blogs.msdn.com/b/clustering/archive/2009/06/25/9803001.aspx' for more 
		  information.
	1.2:
		- Added function to simplify and reduce code.
		
#>

Clear-Host;


# Debug Mode
$DEBUG = $true;

# Production flag, determines Splunk installation DEPLOYMENT_SERVER property value.
$IsProd = $false;

# Check if a passed parameter(s) contains prod (not case sensitve).
if ($args -contains "Prod") {
	$IsProd = $true;
	Write-Host "Production Deployment";
}




# Clears current PowerShell errors (used for debugging)
$Error.Clear();

$MaxThreads 		= 10;													# Maximum concurrent jobs
$JobTimeout			= 300;													# Job wait timeout.
$MsiSourcePath		= "\\austin\infosec\Software\Splunk\Forwarders\";					# Network share were Splunk MSIs are located
$MsiFilename_x64	= "splunkforwarder-6.0.6-228831-x64-release.msi";		# Name of 64-bit Splunk MSI
$MsiFilename_x86	= "splunkforwarder-6.0.6-228831-x86-release.msi";		# Name of 32-bit Splunk MSI
# !!! NOTE: UPDATE THE $LatestVersion varibale in the 'DeployCurrentForwarder' Function !!!
$ComputerList 		= ((split-path -parent $MyInvocation.MyCommand.Definition) + "\ComputerList.txt");

if (Test-Path -Path $ComputerList) {
	$Computers			= Get-Content -Path $ComputerList | Where-Object {$_ -notmatch "''|`n|`t|`r"};
} else {
	Write-Host ("Unable to read/access '" + $ComputerList + "', please verify the path and/or permissions.");
	return 1;
}


if ($DEBUG) {
	#$VerbosePreference preference variable. The default value, "SilentlyContinue", suppresses verbose messages. The second command writes a verbose message.
	$VerbosePreference = "Continue";
}



Function WriteLog {
	param (
		[String]$Type,
		[String]$Message
	)
	
	if ($DEBUG) {
		switch ($Type) {
			"Warn" {
						
					}
			"Verb"	{
						Write-Verbose -Message $Message;
					}
			default	{
						Write-Host ("WriteLog: Unknow Message Type (" +$Type+"):" +$Message);
					}
		}
	}
}

<#
	Removes specified directory iff exists
#>
Function RemoveDir {
	param (
		[String]$DirPath
	)
	# Check if directory exist
	if (Test-Path -Path $DirPath) {
		WriteLog "Verb" ("`tRemoving directory '" + $DirPath + "' ... ");
		Remove-Item -Path $DirPath -Force -Recurse;			
		WriteLog "Verb" ("`tDone.");
	}
}

Function DeployCurrentForwarder {
	Param(
		[String]$MsiCommandParamsInstall
	)
	
	[Boolean]$DEBUG = $true;
	
	# Return Codes
	$RC_SUCCESS = 0;
	$RC_ERROR_INSTALL = 1;
	$RC_ERROR_UNINSTALL = 2;



	$MsiCommand = "MsiExec.exe";
	#6.0.6.228831
	$LatestVersion = "6.0.6.228831";
		
	<#
		Installs Splunk
	#>
	Function InstallSplunk {

		if ($DEBUG) { Write-Output ("Installing Splunk (version " + $LatestVersion + "), command '" + $MsiCommand + $MsiCommandParamsInstall + "' ... ");}
				
		# Install Splunk process
		$InstallRC = Start-Process -FilePath $MsiCommand -ArgumentList $MsiCommandParamsInstall -PassThru -Wait;
		
		# Wait for process to finish.  NOTE: Need for remote calls
		while (!$InstallRC.HasExited) {
			Start-Sleep -Milliseconds 500;
		}
		
		# Check if install was successful
		if ($InstallRC.ExitCode -eq 0) {
			if ($DEBUG) { Write-Output ("Install Successful, RC: " + $InstallRC.ExitCode);}
		} else {
			if ($DEBUG) { Write-Output ("Install Failed, RC: " + $InstallRC.ExitCode);}
		}
		return $InstallRC.ExitCode;
	}
	
	<#
		Uninstalls Splunk
	#>
	Function UninstallSplunk {
		if ($DEBUG) { Write-Output ("Uninstalled Splunk, command '" + $MsiCommand + $MsiCommandParamsUninstall + "' ... ");}
		
		# Create Uninstall parameters
		$MsiCommandParamsUninstall = (" /qn /x" + $CurrentVersion.IdentifyingNumber);
	
	
		# Uninstall Splunk process
		$UninstallRC = Start-Process -FilePath $MsiCommand -ArgumentList $MsiCommandParamsUninstall -PassThru -Wait;
		
		# Wait for process to finish.  NOTE: Need for remote calls
		while (!$UninstallRC.HasExited) {
			Start-Sleep -Milliseconds 500;
		}
		
		# Check if uninstall was successful
		if ($UninstallRC.ExitCode -eq 0) {
			if ($DEBUG) { Write-Output ("Successful. RC: " + $UninstallRC.ExitCode);}
		} else {
			if ($DEBUG) { Write-Output ("Failed. RC: " + $UninstallRC.ExitCode);}
		}
		
		return $UninstallRC.ExitCode;
	}
	
	
	
	# Detect Splunk installations.  NOTE: Performance illusion from WMI cache, 1st run will be true time duration.
	# TODO: Create a registry lookup function to replace, this is dated and slow.
	$CurrentVersion = Get-WmiObject -Class Win32_Product -Filter "Name like '%UniversalForwarder%'";
	

	if ($CurrentVersion) {
		# Detect installation of Splunk
		
		# Check version of Splunk
		if ($CurrentVersion.Version -eq $LatestVersion) {
			# Splunk is up-to-date
			if ($DEBUG) { Write-Output ("Splunk is up-to-date, CurrentVerison: " + $CurrentVersion.Version + ", LatestVersion: " + $LatestVersion + ", exiting with RC: 0");}
		} else {
			# Splunk is out-of-date
			if ($DEBUG) { Write-Output ("Splunk is NOT up-to-date, uninstalling current version (" + $CurrentVersion.Version + ") ...");}
			
			# Uninstall current version of Splunk
			$UninstallRC = UninstallSplunk;
			
			if ($DEBUG) {
				Write-Output ("Uninstall Splunk Details:");
				foreach ($Entry in $UninstallRC) {
					Write-Output ("`t" + $Entry);
				}
			}
			
			# Check if uninstall failed
			if ($UninstallRC[$UninstallRC.count-1] -ne 0) {
				return $RC_ERROR_UNINSTALL;
			}
			
			
			# Install latest version of Splunk
			$InstallRC = InstallSplunk;
			
			if ($DEBUG) {
				Write-Output ("Install Splunk Details:");
				foreach ($Entry in $InstallRC) {
					Write-Output ("`t" + $Entry);
				}
			}
			# Check if install failed
			#if ($InstallRC -ne 0) {
			if ($InstallRC[$InstallRC.Count -1 ] -ne 0) {
				return $RC_ERROR_INSTALL;
			}
			
			
			
		}
	} else {
		# No version of Splunk was detected (Splunk is NOT installed)
		if ($DEBUG) { Write-Output ("No version of splunk found." );}
		
		# Install latest version of Splunk
		$InstallRC = InstallSplunk;
		
		if ($DEBUG) {
			Write-Output ("Install Splunk Details:");
			foreach ($Entry in $InstallRC) {
				Write-Output ("`t" + $Entry);
			}
		}
		
		# Check if install failed
		if ($InstallRC[$InstallRC.Count-1] -ne 0) {
			return $RC_ERROR_INSTALL;
		}
		
	}
	
	return $RC_SUCCESS;
}



$ErrorCount = 0;

#$Computers = ("V0100510");
$Jobs = @();




foreach ($ComputerName in $Computers) {
	
	# Check if running maxium number of jobs (threads)
	While (@(Get-Job | Where { $_.State -eq "Running" }).Count -ge $MaxThreads) {
	   Write-Verbose -Message "Waiting for open thread...($MaxThreads Maximum)";
	   Start-Sleep -Seconds 3;
	}
	
	WriteLog "Verb" ("Processing " + $ComputerName + "...");
	
	
	# Temp directory dynamic name
	$TempGUID = [Guid]::NewGuid();
	$MsiTempDir = ("C:\" + $TempGUID + "\");
	
	
	# Temp directory path on remote computer
	$MsiRemoteTempDir = ("\\" + $ComputerName + "\C$\" + $TempGUID + "\");
	
	# Create new temp directory on remote computer
	WriteLog "Verb" ("`tCreating new TempDir (" + $MsiRemoteTempDir + ")  on remote computer (" + $ComputerName + ").");
	$null = New-Item -Path ($MsiRemoteTempDir) -ItemType Directory -Force;
	if ($Error.Count -gt 0) {
		WriteLog "Verb" ("Error: " +$Error);
	}
			
	
	# Determine Computer's arch
	$ComputerArch = (Get-WmiObject Win32_OperatingSystem -ComputerName $ComputerName).OSArchitecture;
	if ($ComputerArch -eq "64-bit") {
		$MsiFilename = $MsiFilename_x64;
	} else {
		$MsiFilename = $MsiFilename_x86;
	}
		
	
	$MsiSourceFilename = ($MsiSourcePath + $MsiFilename);
	$MsiTempFilename = ($MsiTempDir + $MsiFilename);
	
	if ($IsProd) {
		$MsiCommandParamsInstall = (" /i " + $MsiTempFilename + " /qn AGREETOLICENSE=YES DEPLOYMENT_SERVER=172.16.230.25:8089");
	} else {
		$MsiCommandParamsInstall = (" /i " + $MsiTempFilename + " /qn AGREETOLICENSE=YES DEPLOYMENT_SERVER=172.23.30.54:8089");
	}
	
	# Copy Splunk MSI installer to newly created temp directory
	WriteLog "Verb" ("`tCopying Splunk from '" + $MsiSourceFilename + "' to '" + ($MsiRemoteTempDir + $MsiFilename) + "'.");
	Copy-Item -Path $MsiSourceFilename -Destination ($MsiRemoteTempDir + $MsiFilename) -Force;
	if ($Error.Count -gt 0) {
		WriteLog "Verb" ("Error: " + $Error);
	}
	
	
	# Deploy Splunk on remote computer
	$args =  $MsiCommandParamsInstall;
	$Job = Invoke-Command -ComputerName $ComputerName -ScriptBlock $Function:DeployCurrentForwarder -ArgumentList $args -AsJob -JobName $ComputerName;
	
	# Add new Job to Jobs array
	$Jobs += $Job;
	
	WriteLog "Verb" ("");
}


Start-Sleep -Seconds 15;

# Wait for all jobs (threads) to finish
WriteLog "Verb" ("Waiting for jobs to finish ...");
Get-Job | Wait-Job -Timeout $JobTimeout | Out-Null;
WriteLog "Verb" ("All Jobs have finished.");
WriteLog "Verb" ("");





# Process jobs
foreach ($Job in $Jobs) {
	WriteLog "Verb" ("Processing results for " + $Job.Name + " ... ");
	# Get job result
	$JobResult = Receive-Job -Job $Job -ErrorAction SilentlyContinue;
	
	
	
	# Remove temp dir
	RemoveDir ("\\" + $Job.Name + "\C$\" + $TempGUID + "\");
	
	if ($Job.ChildJobs) {
		$ChildJob = $Job.ChildJobs.Item(0);
		$JobOutput = $ChildJob.Output;
		$JobStateInfo = $ChildJob.JobStateInfo;
	}
	
	if ($DEBUG) {
		# Job Properties
		$JobDuration = ($job.PSEndTime - $Job.PSBeginTime);
		
		Write-Verbose -Message ("`tDetailed output from Job:");
		foreach ($JobOutputMessage in $JobOutput) {
			Write-Verbose -Message ("`t`t" + $JobOutputMessage);
		}
	}
	
	
	if ($JobStateInfo.State -eq "Failed") {
		$ErrorCount++;
		
		if ($JobStateInfo.Reason.ErrorCode -eq -2144108526) {
			# WinRM Error
			WriteLog "Verb" ("`tJob FAILED for " + $Job.Name + ", ErrorCode: " + $JobStateInfo.Reason.ErrorCode + ", Reason: " + $JobStateInfo.Reason);
			# TODO:  Implement mech to inform InfoSec that WinRM is NOT enabled.
		}
		
	} elseif ($Job.State -eq "Completed") {
		
		WriteLog "Verb" ("`tJob was SUCCESSFUL for " + $Job.Name + ", Result: " + $JobResult[$JobResult.Count-1]  + ", RunTime: " + $JobDuration);
		
		if ($JobResult[$JobResult.Count-1] -ne 0) {
			# Install Failure
			WriteLog "Verb" ("`tJob Process FAILED!");
			$ErrorCount++;
		}
	}
	
	WriteLog "Verb" ("");
}

Get-Job | Remove-Job;



return $ErrorCount;

