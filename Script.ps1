<#
.Synopsis
   Script automatically installs and configures an MDT deployment share and
   imports common packages.
.DESCRIPTION
   This script downloads, installs and configures the Microsoft Deployment
   Toolkit 2013 Update 2, Automated Deployment Toolkit and imports the 
   Microsoft Visual C++ binaries that are common for image creation.
.EXAMPLE
   .\MDTDownloader.ps1 -DownloadLocation C:\Downloads -DSLocation C:\DS
   -DSNetworkPath "\\MyComputer\MDTProduction$"
.PARAMETER DownloadLocation
   Specifies the location to download files for use in the creation of the
   MDT deployment share. Default location is "$env:Temp".
.PARAMETER DSLocation
   Specifies the location of the MDT deployment share.
.PARAMETER DSNetworkPath
   Specifies the network UNC path for the MDT deployment share. Default value
   is "$env:ComputerName\MDTProduction$"
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
                HelpMessage='The UNC path of the SMB share. Default is LOCALHOST\MDTProduction$')]
    [String]$DSNetworkPath = "$env:ComputerName\MDTProduction$"
)

Write-Debug -Message 'Creating hashtable of download artifacts and URLs'
$DownLoadArtifacts = Import-PowerShellDataFile -Path .\DownloadArtifacts.psd1

Write-Verbose -Message "Downloading all artifacts"
Foreach ($PSItem in $DownLoadArtifacts.GetEnumerator()) {
    Write-Debug -Message "Current item is: $($PSItem.Key)"
    Start-Job -Name "$($PSItem.Name)" -ArgumentList $PSItem,$DownloadLocation -ScriptBlock {
        $DownloadArtifact = $args[0]
        Write-Debug -Message "Current value of DownloadArtifact Key is: $($DownloadArtifact.Key)"
        Write-Debug -Message "Current Value of DownloadArtifact Value is: $($DownloadArtifact.Value)"
        $DownloadLocation = $args[1]

        Write-Debug -Message "Creating directory for download"
        New-Item -Path "$DownloadLocation" -Name "$($DownloadArtifact.Key)" -ItemType Directory
        Write-Debug -Message "Executing line: $DownloadLocation\$($DownloadArtifact.Key)\$(Split-Path -Path $DownloadArtifact.Value -Leaf)"
        Invoke-WebRequest -Uri "$($($DownloadArtifact.Value).Url)" -Outfile "$DownloadLocation\$($DownloadArtifact.Key)\$(Split-Path -Path $($($DownloadArtifact.Value).Url) -Leaf)"
        } | Out-Null
}
Write-Verbose -Message "Waiting for download artifact jobs to finish"
Get-Job | Wait-Job | Out-Null

Write-Debug -Message 'Checking to see if MDT is already installed'
If (-not (Get-CimInstance -ClassName 'Win32_Product' -Filter "IdentifyingNumber='{F172B6C7-45DD-4C22-A5BF-1B2C084CADEF}'")) {
    Write-Debug -Message 'MDT is not currently installed'
    Write-Verbose -Message 'Installing Microsoft Deployment Toolkit'
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/i $DownloadLocation\MDT2013U2\MicrosoftDeploymentToolkit2013_x64.msi /qn" -Wait
}
Else {
    Write-Debug -Message 'MDT is already installed'
}

Write-Debug -Message 'Checking to see if the ADK is already installed'
If (-not (Get-CimInstance -ClassName 'Win32_Product' -Filter "IdentifyingNumber='{52EA560E-E50F-DC8F-146D-1B631548BA29}'")) {
    Write-Debug -Message 'The ADK is not currently installed'
    Write-Verbose -Message 'Installing the Automated Deployment Kit'
    Start-Process -FilePath "$DownloadLocation\ADKv1607\adksetup.exe" -ArgumentList '/Features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.UserStateMigrationTool /norestart /quiet /ceip off' -Wait

}
Else {
    Write-Debug -Message 'The ADK is already installed'
}

Add-PSSnapin -Name Microsoft.BDD.PSSnapIn
Import-Module -Name "$env:ProgramFiles\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1"

Write-Verbose -Message "Creating MDT deployment share at $DSLocation"
If (-not (Test-Path -Path $DSLocation)) {
    Write-Debug -Message "$DSLocation does not exist, creating folder."
    New-Item -Path $DSLocation -ItemType Directory  | Out-Null
    New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $DSLocation -Description "MDTProduction" -NetworkPath $DSNetworkPath | Out-Null
}
Else {
    Write-Debug -Message "$DSLocation already exists, checking if it is empty"
    If ((Get-ChildItem -Path $DSLocation | Measure-Object).Count -eq 0) {
        New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $DSLocation -Description "MDTProduction" -NetworkPath $DSNetworkPath | Out-Null
    }
}

New-Item -Path "DS001:\Applications" -Name Microsoft -ItemType Directory | Out-Null
New-Item -Path "DS001:\Applications" -Name Other -ItemType Directory | Out-Null
New-Item -Path "DS001:\Operating Systems" -Name Build -ItemType Directory | Out-Null
New-Item -Path "DS001:\Operating Systems" -Name Deploy -ItemType Directory | Out-Null
New-Item -Path "DS001:\Task Sequences" -Name Build -ItemType Directory | Out-Null
New-Item -Path "DS001:\Task Sequences" -Name Deploy -ItemType Directory | Out-Null

Foreach ($i in $DownLoadArtifacts.GetEnumerator()) {
    Write-Debug -Message "Creating application: $($i.Key)"
    Import-MDTApplication -Path "DS001:\Applications\Microsoft" -Name $i.Key -ApplicationSourcePath "$DownloadLocation\$($i.Key)" -DestinationFolder $i.Key -CommandLine (Split-Path -Path $i.Value -Leaf) -ShortName $i.Key | Out-Null
}