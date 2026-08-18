#Requires -Version 5.1
<#
.SYNOPSIS
  Install portable Git config and ExcelCompare onto this machine.

.DESCRIPTION
  Copies Git files to Git's default locations (no hardcoded user paths) and
  puts exceldiff.cmd on PATH. Java 8+ is required for Excel diffs.

    powershell -ExecutionPolicy Bypass -File install.ps1
    powershell -ExecutionPolicy Bypass -File install.ps1 -InstallChocolatey
    powershell -ExecutionPolicy Bypass -File install.ps1 -InstallPackages
#>
param(
    [switch]$InstallChocolatey,
    [switch]$InstallPackages
)

$ErrorActionPreference = "Stop"

$ExcelCompareVersion = "0.7.0"
$ExcelCompareUrl = "https://github.com/na-ka-na/ExcelCompare/releases/download/$ExcelCompareVersion/ExcelCompare-$ExcelCompareVersion.zip"
$ExcelCompareSha256 = "BF5709FC7C86A59F6F535685B0E08A7C8BCB73C48C4C03E4D54B1FD816C90825"

$RepoRoot = $PSScriptRoot
$GitDir = Join-Path $RepoRoot "git"
$HomeDir = $env:USERPROFILE
$ConfigGit = Join-Path $HomeDir ".config\git"
$ExcelCompareDir = Join-Path $env:LOCALAPPDATA "ExcelCompare\ExcelCompare-$ExcelCompareVersion"

function Copy-TrackedFile {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    $destDir = Split-Path $Destination -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    if ((Test-Path $Destination) -and -not (Test-Path "$Destination.bak")) {
        $existing = Get-FileHash $Destination -Algorithm SHA256
        $incoming = Get-FileHash $Source -Algorithm SHA256
        if ($existing.Hash -ne $incoming.Hash) {
            Copy-Item $Destination "$Destination.bak"
            Write-Host "Backed up $Destination -> $Destination.bak"
        }
    }
    Copy-Item $Source $Destination -Force
    Write-Host "Installed $Destination"
}

function Install-ExcelCompare {
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        throw "Java 8+ is required. Install a JDK (for example: winget install Microsoft.OpenJDK.21) and re-run."
    }

    $cmp = Join-Path $ExcelCompareDir "excel_cmp.bat"
    if (-not (Test-Path $cmp)) {
        Write-Host "Downloading ExcelCompare $ExcelCompareVersion..."
        $zip = Join-Path $env:TEMP "ExcelCompare-$ExcelCompareVersion.zip"
        Invoke-WebRequest -Uri $ExcelCompareUrl -OutFile $zip

        $actual = (Get-FileHash $zip -Algorithm SHA256).Hash
        if ($actual -ne $ExcelCompareSha256) {
            throw "Checksum mismatch for ExcelCompare zip. Expected $ExcelCompareSha256, got $actual"
        }

        $extract = Join-Path $env:TEMP "ExcelCompare-$ExcelCompareVersion-extract"
        if (Test-Path $extract) {
            Remove-Item -Recurse -Force $extract
        }
        Expand-Archive -Path $zip -DestinationPath $extract -Force

        $source = $extract
        $nested = Get-ChildItem $extract -Directory | Select-Object -First 1
        if ($nested -and (Test-Path (Join-Path $nested.FullName "excel_cmp.bat"))) {
            $source = $nested.FullName
        }

        if (Test-Path $ExcelCompareDir) {
            Remove-Item -Recurse -Force $ExcelCompareDir
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $ExcelCompareDir) | Out-Null
        Copy-Item -Recurse $source $ExcelCompareDir
        Write-Host "Installed ExcelCompare to $ExcelCompareDir"
    } else {
        Write-Host "ExcelCompare already present at $ExcelCompareDir"
    }

    Copy-Item (Join-Path $GitDir "exceldiff.cmd") (Join-Path $ExcelCompareDir "exceldiff.cmd") -Force
}

function Add-UserPathEntry {
    param([Parameter(Mandatory = $true)][string]$Directory)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($userPath) {
        $parts = $userPath -split ";" | Where-Object { $_ -ne "" }
    }
    $already = $parts | Where-Object { $_.TrimEnd("\") -ieq $Directory.TrimEnd("\") }
    if ($already) {
        Write-Host "PATH already contains $Directory"
        return
    }
    $newPath = if ($userPath) { "$userPath;$Directory" } else { $Directory }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    if ($env:Path -notlike "*$Directory*") {
        $env:Path += ";$Directory"
    }
    Write-Host "Added to User PATH: $Directory"
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Update-SessionPath {
    $env:Path = @(
        [Environment]::GetEnvironmentVariable("Path", "Machine")
        [Environment]::GetEnvironmentVariable("Path", "User")
    ) -join ";"
}

function Install-ChocolateyCli {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Chocolatey already installed: $(choco --version)"
        return
    }
    if (-not (Test-IsAdmin)) {
        throw "Installing Chocolatey requires an elevated PowerShell. Re-run as Administrator with -InstallChocolatey."
    }

    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1"))
    Update-SessionPath

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        throw "Chocolatey install finished but choco is not on PATH. Open a new elevated terminal and re-run."
    }
    Write-Host "Chocolatey installed: $(choco --version)"
}

function Install-ChocolateyPackages {
    Install-ChocolateyCli
    $packages = Join-Path $RepoRoot "chocolatey\packages.config"
    Write-Host "Installing packages from $packages (needs an elevated shell)..."
    & choco install $packages --yes
    if ($LASTEXITCODE -ne 0) {
        throw "choco install failed with exit code $LASTEXITCODE"
    }
}

Copy-TrackedFile -Source (Join-Path $GitDir "gitconfig") -Destination (Join-Path $HomeDir ".gitconfig")
Copy-TrackedFile -Source (Join-Path $GitDir "attributes") -Destination (Join-Path $ConfigGit "attributes")
Copy-TrackedFile -Source (Join-Path $GitDir "ignore") -Destination (Join-Path $ConfigGit "ignore")
Install-ExcelCompare
Add-UserPathEntry -Directory $ExcelCompareDir

if ($InstallPackages) {
    Install-ChocolateyPackages
} elseif ($InstallChocolatey) {
    Install-ChocolateyCli
}

Write-Host "Done. Open a new terminal, then run: git diff"
