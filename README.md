# .dotfiles

Cross-platform dotfiles for Windows and Ubuntu/Debian (native and WSL2), managed with
[chezmoi](https://chezmoi.io), [mise](https://mise.jdx.dev), and platform package
managers (Chocolatey on Windows, apt on Linux).

One source of truth and one package set for every machine. Machine-only tweaks go in
untracked local files (see below).

## New machine

Windows (elevated PowerShell — Chocolatey needs admin):

```powershell
winget install twpayne.chezmoi
chezmoi init --apply KirylLapouski/.dotfiles
```

Ubuntu/Debian, including WSL2 (the repo is private, so authenticate first):

```bash
sudo apt-get update && sudo apt-get install -y gh git curl
gh auth login            # GitHub.com -> HTTPS -> login with browser/device code
gh auth setup-git        # writes a credential helper into ~/.gitconfig

sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply KirylLapouski/.dotfiles
```

No Windows dependency: `gh auth setup-git` makes git use the token stored by `gh`,
so this works on native Linux and inside WSL. SSH alternative: add an SSH key to
GitHub and run
`chezmoi init --apply git@github.com:KirylLapouski/.dotfiles.git`.

Open a new shell afterwards so `PATH` picks up Chocolatey/mise shims. The first full
`chezmoi apply` installs apt packages and mise tools, so run `sudo -v` first or enter
your password when prompted.

## What gets managed

| Source | Target |
|---|---|
| `dot_gitconfig` | `~/.gitconfig` |
| `dot_config/git/ignore` | `~/.config/git/ignore` |
| `dot_config/opencode/*` | `~/.config/opencode/*` |
| `dot_config/mise/config.toml.tmpl` | `~/.config/mise/config.toml` |
| `dot_config/Code/User/*.json.tmpl` | `~/.config/Code/User/*.json` (Linux) |
| `dot_AppData/Roaming/Code/User/*.json.tmpl` | `%APPDATA%\Code\User\*.json` (Windows) |

The chezmoi source directory is `~/.local/share/chezmoi`.

## VS Code

Settings and keybindings are stored once in `.data/vscode/` and included from
per-OS target templates, so both platforms stay identical:

```
.data/vscode/settings.json                 # raw, shared content
.data/vscode/keybindings.json
dot_config/Code/User/settings.json.tmpl    # {{ include ".data/vscode/settings.json" }}
dot_AppData/Roaming/Code/User/settings.json.tmpl
```

`.chezmoiignore` deploys `AppData` only on Windows and `.config/Code` only on Linux.
Extensions are listed in `packages/vscode-extensions.txt` and installed by
`run_onchange_after_install-vscode-extensions.{ps1,sh}.tmpl` when the list changes.
If the `code` CLI is not on `PATH` (or the list is empty), the script skips itself.

To change VS Code config:

```sh
chezmoi cd
code .data/vscode/settings.json          # edit shared settings
code --list-extensions > packages/vscode-extensions.txt
chezmoi apply
```

Alternatively add a file straight from a machine: `chezmoi add ~/.config/Code/User/settings.json`.

In WSL, VS Code user settings come from the Windows client, so the Linux target only
matters for native Linux VS Code.

## Package layers

- **mise** (both OS): `node`, `python` 3.12 + 3.11, `java` temurin-21 + temurin-11,
  and the opencode `chrome-devtools-mcp` MCP server. On Linux only: `maven`, `rust`,
  `kubectl`, `helm`, `pandoc` (on Windows these stay in Chocolatey).
- **Chocolatey** (Windows): `packages/choco.config`. GUI/system apps only.
- **apt** (Linux): `packages/apt-packages.txt`; `packages/apt-gui-packages.txt` is
  skipped in WSL.

Run scripts only re-execute when their generated content changes, so adding a package
to a list and running `chezmoi apply` installs it.

### Changing package lists

1. Edit the list in the source: `packages/apt-packages.txt`, `packages/choco.config`,
   `packages/vscode-extensions.txt`, or `dot_config/mise/config.toml.tmpl`.
2. Run `chezmoi apply` — each install script embeds a SHA-256 of its list, so editing
   the list changes the script and it re-runs automatically.
3. Commit and push; other machines pick it up with `chezmoi update`.

Removing an entry does **not** uninstall it — the scripts only install. Uninstall
manually if needed: `sudo apt-get remove --autoremove <pkg>` or `choco uninstall <pkg>`.

## Machine-specific overrides

`~/.gitconfig.local` is included by the managed `.gitconfig` but never tracked. For
example, on a personal machine override the email with:

```sh
git config --file ~/.gitconfig.local user.email lapkovskyk@mail.ru
```

## Daily use

```sh
chezmoi update      # pull latest source and apply
chezmoi cd          # shell in the source dir
chezmoi edit FILE   # edit a managed file
chezmoi diff        # show pending changes
chezmoi apply       # apply changes
```

Useful: `chezmoi managed`, `chezmoi status`, `chezmoi data`.

## Secrets (copy manually to a new machine)

These are intentionally not tracked. Copy them over a secure channel:

- `~/.config/yandex-cloud/credentials/default`
- `~/.gitconfig.local` (machine-only git overrides, if any)
- `~/.git-credentials`
- `~/.ssh/`
- `~/.kube/config`
- `~/.docker/config.json`
- `~/.npmrc`
- `~/.local/share/opencode/auth.json` (opencode provider credentials)

## Notes

- `~/.config/git/ignore` still ignores Excel temp/lock files (`~$*.xlsx` and friends).
- `.data` and `packages` are source-side helpers; they are not deployed to `~`.
- Line endings: `.gitattributes` forces LF for scripts/templates and CRLF for
  PowerShell/cmd files.
- Repo default branch is `main`, active development happens on `master`.
