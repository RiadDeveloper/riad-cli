#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

if ($env:OS -ne "Windows_NT") {
  Write-Error "This script is only for Windows"
  Exit 1
}

if ($null -ne $env:Riad_HOME) {
  $RiadHome = $env:Riad_HOME
}
else {
  if (Get-Command "Riad.exe" -ErrorAction SilentlyContinue) {
    $RiadHome = (Get-Item (Get-Command "Riad.exe").Path).Directory.Parent.FullName
  }
  else {
    $RiadHome = "$Home\.Riad"
    if (!(Test-Path $RiadHome)) {
      New-Item $RiadHome -ItemType Directory | Out-Null
    }
  }
}

$ZipUrl = "https://github.com/RiadDeveloper/Riad-cli/releases/latest/download/Riad-x86_64-windows.zip"
$ZipLocation = "$RiadHome\Riad-x86_64-windows.zip"

# GitHub requires TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Download $ZipUrl to $ZipLocation
Invoke-WebRequest -OutFile $ZipLocation $ZipUrl -UseBasicParsing

# Extract it
if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
  Expand-Archive $ZipLocation -DestinationPath "$RiadHome" -Force
}
else {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::ExtractToDirectory($ZipLocation, $RiadHome)
}
Remove-Item $ZipLocation

Write-Output "Successfully downloaded the Riad CLI binary at $RiadHome\bin\Riad.exe"

# Prompt user if they want to download dev dependencies now
$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$Options = [System.Management.Automation.Host.ChoiceDescription[]]($Yes, $No)

$Title = "Now, proceeding to download necessary Java libraries (approx size: 170 MB)."
$Message = "Do you want to continue?"
$Result = $host.ui.PromptForChoice($Title, $Message, $Options, 0)
if ($Result -eq 0) {
  $BinDir = "$RiadHome\bin"
  Start-Process -NoNewWindow -FilePath "$BinDir\Riad.exe" -ArgumentList "deps", "sync", "--dev-deps", "--no-logo" -Wait 
}

# Update PATH
$User = [EnvironmentVariableTarget]::User
$Path = [Environment]::GetEnvironmentVariable('Path', $User)
if (!(";$Path;".ToLower() -like "*;$BinDir;*".ToLower())) {
  [Environment]::SetEnvironmentVariable('Path', "$Path;$BinDir", $User)
  $Env:Path += ";$BinDir"
}

if ($Result -eq 0) {
  Write-Output "`nSuccess! Installed Riad at $BinDir\Riad.exe!"
  Write-Output "Run ``Riad --help`` to get started."
}
else {
  Write-Output "`nRiad has been partially installed at $BinDir\Riad.exe!"
  Write-Output "Please run ``Riad deps sync --dev-deps`` to download necessary Java libraries."
}
