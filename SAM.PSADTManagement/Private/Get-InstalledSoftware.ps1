function Get-InstalledSoftware {

    param (

        [String]
        $ComputerName = [System.Environment]::MachineName,

        [String]
        $DisplayName,

        [String]
        $Publisher

    )

    begin {

        [Array]$uninstallPaths = @("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")

        if ((Get-CimInstance Win32_OperatingSystem).OSArchitecture -eq "64-Bit") {
            $uninstallPaths += "SOFTWARE\Wow6432node\Microsoft\Windows\CurrentVersion\Uninstall"
        }

        function Convert-KeyToObject {

            param (

                [String]
                $ComputerName,

                [microsoft.win32.registrykey]
                $SubKey

            )

            [PSCustomObject]@{
                'Computer'        = $Computername
                'DisplayName'     = $SubKey.getValue( "DisplayName" )
                'DisplayVersion'  = $SubKey.getValue( "DisplayVersion" )
                'Publisher'       = $SubKey.getValue( "Publisher" )
                'InstallDate'     = $SubKey.getValue( "InstallDate" )
                'UninstallString' = $SubKey.getValue( "UninstallString" )
            }

        }

    }

    process {

        foreach ( $uninstallPath in $uninstallPaths ) {

            $regConnect = [microsoft.win32.registrykey]::OpenRemoteBaseKey( 'LocalMachine', $ComputerName )
            $regKey     = $regConnect.OpenSubKey( $uninstallPath )
            $subKeys    = $regKey.GetSubKeyNames()

            for ($i = 0; $i -lt $subKeys.Count; $i++) {

                $key = "{0}\{1}" -f $uninstallPath, $subKeys[$i]
                $keyInfo = $RegConnect.OpenSubKey($key)

                [string]$keyDisplayName = $keyInfo.getValue("DisplayName")

                if ( $keyDisplayName -and $keyDisplayName -notmatch "Security|Update") {

                    if ( $PSBoundParameters['DisplayName'] ) {

                        if ( $keyDisplayName -match $DisplayName ){
                            Convert-KeyToObject -Computername $ComputerName -SubKey $keyInfo
                        }

                    }
                    elseif( $PSBoundParameters['Publisher'] ) {

                        [string]$keyPublisher = "$($keyInfo.getValue( "Publisher" ))"

                        if ( $keyPublisher -match $Publisher ){
                            Convert-KeyToObject -Computername $ComputerName -SubKey $keyInfo
                        }

                    }
                    else {

                        Convert-KeyToObject -Computername $ComputerName -SubKey $keyInfo

                    }

                }
            }

        }

    }

}
