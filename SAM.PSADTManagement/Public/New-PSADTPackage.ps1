function New-PSADTPackage {

	<#
		.SYNOPSIS
			Create a new PSADT Pacakage

		.DESCRIPTION
			Create a new PSADT Pacakage using Plaster

		.EXAMPLE
			PS C:\> New-PSADTPackage -Name 'MS-OfficePro-2016-WIN' -Destination "E:\_Temp\Packages"

	#>

	[CmdletBinding()]
	[OutputType([System.Void])]
	param (

		# Specifies the Package Name.
		[Parameter(Mandatory)]
		[String]
		$Name,

		# Specifies the location to save the new module to.
		[Parameter(Mandatory)]
		[String]
		$Destination

	)

	$plasterParmas = @{
		TemplatePath      = $templatePath
		DestinationPath   = $(Join-Path -Path $Destination -ChildPath $Name)
		Force             = $true
	}

	if ($PSBoundParameters.Verbose) { $plasterParmas.Add("Verbose", $true) }

	Invoke-Plaster @plasterParmas

}
