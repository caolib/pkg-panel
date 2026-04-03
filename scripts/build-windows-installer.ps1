[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$BuildName,
  [string]$BuildNumber,
  [switch]$NoPubGet,
  [switch]$RunAnalyze,
  [switch]$RunTest,
  [switch]$OpenOutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
  param([string]$Message)

  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-CommandPath {
  param([string]$CommandName)

  $command = Get-Command $CommandName -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $command) {
    return $null
  }

  return $command.Source
}

function Invoke-External {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$StepMessage
  )

  Write-Step $StepMessage
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed: $FilePath $($Arguments -join ' ')"
  }
}

function Get-PubspecVersionInfo {
  param([string]$PubspecPath)

  $versionLine = Get-Content -Path $PubspecPath |
    Where-Object { $_ -match '^\s*version\s*:\s*(.+?)\s*$' } |
    Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($versionLine)) {
    throw 'Could not find a version field in pubspec.yaml.'
  }

  $match = [regex]::Match($versionLine, '^\s*version\s*:\s*([^+\s]+)(?:\+([^\s]+))?\s*$')
  if (-not $match.Success) {
    throw "Failed to parse version from pubspec.yaml: $versionLine"
  }

  $resolvedBuildName = $match.Groups[1].Value.Trim()
  $resolvedBuildNumber = $match.Groups[2].Value.Trim()
  if ([string]::IsNullOrWhiteSpace($resolvedBuildNumber)) {
    $resolvedBuildNumber = '1'
  }

  return [PSCustomObject]@{
    BuildName = $resolvedBuildName
    BuildNumber = $resolvedBuildNumber
    InstallerVersion = "$resolvedBuildName+$resolvedBuildNumber"
  }
}

function Resolve-InnoSetupCompiler {
  $fromPath = Resolve-CommandPath -CommandName 'iscc.exe'
  if (-not [string]::IsNullOrWhiteSpace($fromPath)) {
    return $fromPath
  }

  $appPathKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\ISCC.exe',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\ISCC.exe'
  )
  foreach ($key in $appPathKeys) {
    if (-not (Test-Path -Path $key)) {
      continue
    }

    $item = Get-Item -Path $key
    $candidate = $item.GetValue('')
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -Path $candidate)) {
      return $candidate
    }
  }

  $uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1'
  )
  foreach ($key in $uninstallKeys) {
    $item = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
    if ($null -eq $item -or [string]::IsNullOrWhiteSpace($item.InstallLocation)) {
      continue
    }

    $candidate = Join-Path -Path $item.InstallLocation -ChildPath 'ISCC.exe'
    if (Test-Path -Path $candidate) {
      return $candidate
    }
  }

  $commonCandidates = @(
    (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Programs\Inno Setup 6\ISCC.exe'),
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Inno Setup 6\ISCC.exe'),
    (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Inno Setup 6\ISCC.exe')
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  foreach ($candidate in $commonCandidates) {
    if (Test-Path -Path $candidate) {
      return $candidate
    }
  }

  throw 'Unable to find Inno Setup compiler ISCC.exe. Install Inno Setup 6 first.'
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $scriptRoot = Split-Path -Parent $PSCommandPath
  $ProjectRoot = Split-Path -Parent $scriptRoot
}

$resolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$pubspecPath = Join-Path -Path $resolvedProjectRoot -ChildPath 'pubspec.yaml'
$installerScriptPath = Join-Path -Path $resolvedProjectRoot -ChildPath 'windows\installer.iss'
$releaseDir = Join-Path -Path $resolvedProjectRoot -ChildPath 'build\windows\x64\runner\Release'
$outputDir = Join-Path -Path $resolvedProjectRoot -ChildPath 'dist\windows-installer'

if (-not (Test-Path -Path $pubspecPath)) {
  throw "Missing file: $pubspecPath"
}
if (-not (Test-Path -Path $installerScriptPath)) {
  throw "Missing file: $installerScriptPath"
}

$flutter = Resolve-CommandPath -CommandName 'flutter'
if ([string]::IsNullOrWhiteSpace($flutter)) {
  throw 'Unable to find the flutter command. Make sure Flutter is on PATH.'
}

$versionInfo = Get-PubspecVersionInfo -PubspecPath $pubspecPath
if ([string]::IsNullOrWhiteSpace($BuildName)) {
  $BuildName = $versionInfo.BuildName
}
if ([string]::IsNullOrWhiteSpace($BuildNumber)) {
  $BuildNumber = $versionInfo.BuildNumber
}
$installerVersion = "$BuildName+$BuildNumber"

$iscc = Resolve-InnoSetupCompiler

Write-Host "Project root: $resolvedProjectRoot"
Write-Host "Flutter: $flutter"
Write-Host "ISCC: $iscc"
Write-Host "Version: $installerVersion"

Push-Location -Path $resolvedProjectRoot
try {
  if (-not $NoPubGet) {
    Invoke-External -FilePath $flutter -Arguments @('pub', 'get') -StepMessage 'Running flutter pub get'
  }

  if ($RunAnalyze) {
    Invoke-External -FilePath $flutter -Arguments @('analyze') -StepMessage 'Running flutter analyze'
  }

  if ($RunTest) {
    Invoke-External -FilePath $flutter -Arguments @('test') -StepMessage 'Running flutter test'
  }

  Invoke-External -FilePath $flutter -Arguments @(
    'build',
    'windows',
    '--release',
    "--build-name=$BuildName",
    "--build-number=$BuildNumber"
  ) -StepMessage 'Building Windows release'

  if (-not (Test-Path -Path $releaseDir)) {
    throw "Missing release output directory: $releaseDir"
  }

  if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
  }

  Invoke-External -FilePath $iscc -Arguments @(
    "/DMyAppVersion=$installerVersion",
    "/DMyAppSourceDir=$releaseDir",
    "/DMyAppOutputDir=$outputDir",
    $installerScriptPath
  ) -StepMessage 'Building Inno Setup installer'

  $installerPath = Join-Path -Path $outputDir -ChildPath "pkg_panel-setup-$installerVersion.exe"
  if (Test-Path -Path $installerPath) {
    Write-Host "Installer created: $installerPath" -ForegroundColor Green
  } else {
    Write-Host "Installer build finished. Output directory: $outputDir" -ForegroundColor Green
  }

  if ($OpenOutputDir) {
    Invoke-Item -Path $outputDir
  }
}
finally {
  Pop-Location
}
