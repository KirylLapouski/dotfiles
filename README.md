# .dotfiles

Portable Git config for a new Windows machine. No username or absolute paths in the tracked files.

## New machine

Java 8+ is required for Excel diffs (`winget install Microsoft.OpenJDK.21` if needed).

```powershell
git clone https://github.com/KirylLapouski/.dotfiles.git
cd .dotfiles
powershell -ExecutionPolicy Bypass -File install.ps1
```

Open a new terminal, then `git diff` on an `.xlsx` file uses ExcelCompare.

Chocolatey and packages need an **elevated** PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -InstallChocolatey
powershell -ExecutionPolicy Bypass -File install.ps1 -InstallPackages
```

`-InstallPackages` installs Chocolatey first if it is missing, then `chocolatey/packages.config`. `-InstallChocolatey` only bootstraps Chocolatey (official [install.ps1](https://community.chocolatey.org/install.ps1)).

## What gets installed

| Tracked file | Destination |
|---|---|
| `git/gitconfig` | `~/.gitconfig` |
| `git/attributes` | `~/.config/git/attributes` |
| `git/ignore` | `~/.config/git/ignore` |
| `git/exceldiff.cmd` | `%LOCALAPPDATA%\ExcelCompare\ExcelCompare-0.7.0\` (on `PATH`) |
| `chocolatey/packages.config` | `choco install chocolatey\packages.config --yes` |

`install.ps1` also downloads ExcelCompare 0.7.0 if it is missing. Existing Git files are copied to `*.bak` before overwrite.

Do not copy `%ChocolateyInstall%\config\chocolatey.config` into git. That file is machine-local (proxy passwords, cache paths). Package lists belong in `packages.config`; sources/features can be set with `choco source` / `choco feature` if you ever change them from defaults.

Machine-only overrides can go in `~/.gitconfig.local` (not tracked). Add this to your local config if you need them:

```ini
[include]
	path = ~/.gitconfig.local
```
