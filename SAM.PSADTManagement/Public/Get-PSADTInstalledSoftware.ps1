function Get-PSADTInstalledSoftware {

	<#
		.SYNOPSIS
			Retrieve Software information

		.DESCRIPTION
			Retrieve Software information from the Registry and export data to CSV file.

		.EXAMPLE
			PS C:\> <example usage>

			Explanation of what the example does
	#>

	[CmdletBinding()]
	[OutputType([System.Void])]
	param (

		# Specifies the Destination to save the results
		[Parameter(Mandatory)]
		[String]
		$Destination,

		# Specifies the search type.
		[Parameter()]
		[ValidateSet('BeforeInstall', 'AfterInstall', 'AfterUninstall')]
		[String]
		$SearchType,

		# Specifies if it should overwrite a file if it already exists
		[Parameter()]
		[Switch]
		$Force

	)

	end {

		$fileName = "{0}.csv" -f $SearchType

		$exportTo = Join-Path -Path $Destination -ChildPath $fileName

		Get-InstalledSoftware | ForEach-Object {

			$software = $_

			Export-Csv -Path $exportTo -InputObject $software -NoTypeInformation -Append

		}

	}

}
