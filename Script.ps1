<#
.Synopsis
   Short description
.DESCRIPTION
   This script downloads, installs and configures the Microsoft Deployment
   Toolkit 2013 Update 2, Automated Deployment Toolkit and commmon applications
   to the Deployment Share.
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>

[CmdletBinding()]
Param (
    # Location to store downloaded files
    [Parameter(Mandatory=$false,
                Position=0,
                HelpMessage='The location to store downloaded files')]
    [String]$DownloadLocation = $env:Temp,

    # Location of the MDT deployment share on the local system
    [Parameter(Mandatory=$true,
                Position=1,
                HelpMessage='The location to create the MDT deployment share')]
    [String]$DSLocation,
    
    # The UNC path of the deployment share
    [Parameter(Mandatory=$false,
                Position=2,
                HelpMessage='The UNC path of the SMB share. Default is $ComputerName\MDTProduction$')]
    [String]$DSNetworkPath = "$env:ComputerName\MDTProduction$"
)
If (-not (Test-Path -Path "$DownloadLocation\MicrosoftDeploymentToolkit2013_x64.msi")) {
    Write-Verbose -Message 'Downloading the Microsoft Deployment Toolkit'
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/3/0/1/3012B93D-C445-44A9-8BFB-F28EB937B060/MicrosoftDeploymentToolkit2013_x64.msi' -Outfile "$DownloadLocation\MicrosoftDeploymentToolkit2013_x64.msi"
}
Else {
    Write-Verbose -Message 'MDT installer already exists, skipping download'
}

If (-not (Test-Path -Path "$DownloadLocation\adksetup.exe")) {
    Write-Verbose -Message 'Downlading the Automated Deployment Kit v1607'
    Invoke-WebRequest -Uri 'http://download.microsoft.com/download/9/A/E/9AE69DD5-BA93-44E0-864E-180F5E700AB4/adk/adksetup.exe' -Outfile "$DownloadLocation\adksetup.exe"
}
Else {
    Write-Verbose -Message 'ADK installer already exists, skipping download'
}
Write-Verbose -Message 'Installing Microsoft Deployment Toolkit'
Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/i $DownloadLocation\MicrosoftDeploymentToolkit2013_x64.msi /qn" -Wait
Write-Verbose -Message 'Installing the Automated Deployment Kit'
Start-Process -FilePath "$DownloadLocation\adksetup.exe" -ArgumentList '/Features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.UserStateMigrationTool /norestart /quiet /ceip off' -Wait

Add-PSSnapin -Name Microsoft.BDD.PSSnapIn
Import-Module -Name "$env:ProgramFiles\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1"

Write-Verbose -Message "Creating MDT deployment share at $DSLocation"
If (-not $DSLocation) {
    Write-Debug -Message "$DSLocation does not exist, creating folder."
    New-Item -Path $DSLocation -ItemType Directory
    New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $DSLocation -Description "MDTProduction" -NetworkPath "\\$env:ComputerName\MDTProduction$"
}
Else {
    Write-Debug -Message "$DSLocation already exists"
    New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $DSLocation -Description "MDTProduction" -NetworkPath "\\$env:ComputerName\MDTProduction$"
}

New-Item -Path "DS001:\Applications" -Name Microsoft -ItemType Directory
New-Item -Path "DS001:\Applications" -Name Other -ItemType Directory
New-Item -Path "DS001:\Operating Systems" -Name Build -ItemType Directory
New-Item -Path "DS001:\Operating Systems" -Name Deploy -ItemType Directory
New-Item -Path "DS001:\Task Sequences" -Name Build -ItemType Directory
New-Item -Path "DS001:\Task Sequences" -Name Deploy -ItemType Directory

