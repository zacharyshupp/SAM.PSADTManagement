<#
	.SYNOPSIS
		This script performs the installation or uninstallation of <%=$PLASTER_PARAM_ApplicationName%>.

    .DESCRIPTION
        <%=$PLASTER_PARAM_ApplicationDescription%>

    .LINK
        <%=$PLASTER_PARAM_ApplicationWebsite%>

	.NOTES
		Change Record:
            1.0 - <%=$PLASTER_Date%> - Initial script development
#>

[CmdletBinding()]
Param (

    # Specifies the type of deployment to perform. Default is: Install.
	[Parameter(Mandatory = $false)]
	[ValidateSet('Install', 'Uninstall', 'Repair')]
    [string]
    $DeploymentType = 'Install',

    # Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
	[Parameter(Mandatory = $false)]
	[ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [string]
    $DeployMode = 'Interactive',

    # Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
	[Parameter(Mandatory = $false)]
    [switch]
    $AllowRebootPassThru = $false,

    # Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
	[Parameter(Mandatory = $false)]
    [switch]
    $TerminalServerMode = $false,

    # Disables logging to file for the script. Default is: $false.
	[Parameter(Mandatory = $false)]
    [switch]
    $DisableLogging = $false,

    # Specifies if the end user can defer the action.
	[Parameter(Mandatory = $false)]
    [switch]
    $AllowDefer,

    # Specifies to the end user the number of times they can defer. Default is: 3 times.
	[Parameter(Mandatory = $false)]
    [int]
    $DeferTimes = 3
)

# [Initialisations] -----------------------------------------------------------------------------------------------------------------

# Set the script execution policy for this process
Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

# [Declarations] --------------------------------------------------------------------------------------------------------------------

# Variables: PSADT Framework
[string]$appVendor = '<%=$PLASTER_PARAM_Vendor%>'
[string]$appName = '<%=$PLASTER_PARAM_ApplicationName%>'
[string]$appVersion = '<%=$PLASTER_PARAM_ApplicationVersion%>'
[string]$appArch = '<%=$PLASTER_PARAM_ApplicationArch%>'
[string]$appLang = 'EN'
[string]$appRevision = '01'
[string]$appScriptVersion = '1.0.0'
[string]$appScriptDate = '<%=$PLASTER_Date%>'
[string]$appScriptAuthor = '<%=$PLASTER_PARAM_PackageCreator%>'

# Variables: Custom Package
[string]$appRegDisplayName = ""
[string]$appRegInstallPath = ""
[string]$appProcesses = ""
[int]$appCloseAppsCountDown = 300
[int]$appRequiredDiskSpace = 10

# *** Do Not Modify below Variables. These are provided by PSADT ***
[string]$installName = "$appName - $appVersion"
[string]$installTitle = "$appName - $appVersion"

# Variables: Exit Code
[int32]$mainExitCode = 0

# Variables: Script
[string]$deployAppScriptFriendlyName = 'Deploy Application'
[version]$deployAppScriptVersion = [version]'3.8.4'
[string]$deployAppScriptDate = '26/01/2021'
[hashtable]$deployAppScriptParameters = $psBoundParameters

# Variables: Environment
If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }

[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

# [Load PSADT Functions] -------------------------------------------------------------------------------------------------------------

# Dot source the required App Deploy Toolkit Functions
Try {

    [string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"

    If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }

    If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }

}
Catch {

    If ($mainExitCode -eq 0) { [int32]$mainExitCode = 60008 }

    Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'

    ## Exit the script, returning the exit code to SCCM
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }

}

# [Execution] -----------------------------------------------------------------------------------------------------------------------

try {

    switch ($DeploymentType) {

        "Install" {

            # [Pre-Installation] -----------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Pre-Installation'

            $app = Get-InstalledApplication -Name $appRegDisplayName

            if ($app) {

                [version]$displayVersion = $app.DisplayVersion

                if($displayVersion -eq $appRegDisplayVersion){

                    $message = "$appName is already installed with version: '$displayVersion'. Exiting Install."

                    Show-InstallationPrompt -Message $message -ButtonRightText 'OK'
                    Write-Log -Message $message -Source ${CmdletName}
                    Exit-Script -ExitCode $mainExitCode

                }elseif ($displayVersion -gt $appRegDisplayVersion) {

                    $message = "$appName is already installed with version: '$displayVersion'. Its version is newer than this package. Exiting Install."

                    Show-InstallationPrompt -Message $message -ButtonRightText 'OK'
                    Write-Log -Message $message -Source ${CmdletName}
                    Exit-Script -ExitCode $mainExitCode

                }elseif ($displayVersion -lt $appRegDisplayVersion) {

                    $message = "$appName is already installed with version: '$displayVersion'. Its version is older than this package. Continuing Install."
                    Write-Log -Message $message -Source ${CmdletName}

                    if($app.InstallLocation -ne $appRegInstallPath){
                        $appRegInstallPath = $app.InstallLocation
                    }

                }

            }

            ## Show Welcome Message
            $siwParams = @{
                CloseApps          = $appProcesses
                CloseAppsCountDown = $CloseAppsCountDown
                CheckDiskSpace     = $true
                RequiredDiskSpace  = $appRequiredDiskSpace
            }

            if($AllowDefer){
                $siwParams.add('AllowDefer', $true)
                $siwParams.add('DeferTimes', $DeferTimes)
            }

            Show-InstallationWelcome @siwParams

            ## Show Progress Message (with the default message)
            Show-InstallationProgress

            # <Perform Pre-Installation tasks here>

            # [Installation] ---------------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Installation'

            # <Perform Installation tasks here>

            # [Post-Installation] ----------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Post-Installation'

            # <Perform Post-Installation tasks here>

            # End Installation
        }

        "Uninstall" {

            # [Pre-Uninstallation] ---------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Pre-Uninstallation'

            ## Check if application is currently installed
            $app = Get-InstalledApplication -Name $appRegDisplayName

            if(!$app){

                Show-InstallationPrompt -Message "$appName is already uninstalled." -ButtonRightText 'OK'
                Write-Log -Message "$appName is already uninstalled" -Source ${CmdletName}
                Exit-Script -ExitCode $mainExitCode

            }

            ## Show Welcome Message
            $siwParams = @{
                CloseApps          = $appProcesses
                CloseAppsCountDown = 600
            }

            if($AllowDefer){
                $siwParams.add('AllowDefer', $true)
                $siwParams.add('DeferTimes', $DeferTimes)
            }

            Show-InstallationWelcome @siwParams

            ## Show Progress Message (with the default message)
            Show-InstallationProgress

			# <Perform Pre-Uninstallation tasks here>

            # [Uninstallation] -------------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Uninstallation'

            # <Perform Uninstallation tasks here>

            # [Post-Uninstallation] --------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Post-Uninstallation'

            # <Perform Post-Uninstallation tasks here>

            # End Uninstallation
        }

        "Repair" {

            # [Pre-Repair] ------------------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Pre-Repair'

            $app = Get-InstalledApplication -Name $appRegDisplayName

            if ($app) {

                [version]$displayVersion = $app.DisplayVersion

                if($displayVersion -eq $appRegDisplayVersion){

                    $message = "$appName is already installed with version: '$displayVersion'. Exiting Install."

                    Show-InstallationPrompt -Message $message -ButtonRightText 'OK'
                    Write-Log -Message $message -Source ${CmdletName}
                    Exit-Script -ExitCode $mainExitCode

                }elseif ($displayVersion -gt $appRegDisplayVersion) {

                    $message = "$appName is already installed with version: '$displayVersion'. Its version is newer than this package. Exiting Install."

                    Show-InstallationPrompt -Message $message -ButtonRightText 'OK'
                    Write-Log -Message $message -Source ${CmdletName}
                    Exit-Script -ExitCode $mainExitCode

                }elseif ($displayVersion -lt $appRegDisplayVersion) {

                    $message = "$appName is already installed with version: '$displayVersion'. Its version is older than this package. Continuing Install."

                    Write-Log -Message $message -Source ${CmdletName}
                    if($app.InstallLocation -ne $appRegInstallPath){
                        $appRegInstallPath = $app.InstallLocation
                    }
                }

            }

            ## Show Welcome Message
            $siwParams = @{
                CloseApps          = $appProcesses
                CloseAppsCountDown = $CloseAppsCountDown
                CheckDiskSpace     = $true
            }

            if($AllowDefer){
                $siwParams.add('AllowDefer', $true)
                $siwParams.add('DeferTimes', $DeferTimes)
            }

            Show-InstallationWelcome @siwParams

            ## Show Progress Message (with the default message)
            Show-InstallationProgress

            # <Perform Pre-Repair tasks here>

            # [Repair] ----------------------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Repair'

            # <Perform Repair tasks here>

            # [Post-Repair] -----------------------------------------------------------------------------------------------------------
            [string]$installPhase = 'Post-Repair'

            # <Perform Post-Repair tasks here>

			# End Repair
        }

    }

}
catch {

    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"

	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'

    Exit-Script -ExitCode $mainExitCode

}
