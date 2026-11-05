# 🏡 Feel like home on any machine

macOS · Linux Mint · Windows 11 — one repository, one command.

> [!IMPORTANT]
> The configurations and scripts in this repository are **HIGHLY PERSONALIZED** to my own preferences and workflows. If you decide to use them, please be aware that they will **MODIFY** your current system, potentially making some changes that are **IRREVERSIBLE** without a fresh installation of your operating system.

## One-click-setup

**macOS / Linux Mint**

```bash
curl -fsSL https://raw.githubusercontent.com/dikayx/.dotfiles/main/setup.sh | bash -s -- -hn "My-Host" -gn "John Doe" -ge "<your_mail>@example.com"
```

**Windows 11** (PowerShell, run as a normal user — the hostname step asks for admin rights by itself)

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/dikayx/.dotfiles/main/setup.ps1))) -Hostname "My-PC" -GitUsername "John Doe" -GitEmail "<your_mail>@example.com"
```

All arguments are optional.

<details>
<summary>Arguments</summary>

| Unix (`install.sh`)         | Windows (`install.ps1`)    | Meaning                                                        |
| --------------------------- | -------------------------- | -------------------------------------------------------------- |
| `-hn`, `--hostname <name>`  | `-Hostname <name>`         | Set the hostname (Windows: max. 15 chars, restart required)    |
| `-gn`, `--gitname <name>`   | `-GitUsername <name>`      | Git user name (stored in the untracked `~/.gitconfig.local`)   |
| `-ge`, `--gitemail <mail>`  | `-GitEmail <mail>`         | Git user email (same)                                          |
| `-h`, `--help`              | `Get-Help .\install.ps1`   | Help                                                           |
| –                           | `-NoTweaks`                | Windows only: skip dark mode / Explorer tweaks                 |
| –                           | `-NoClassicContextMenu`    | Windows only: keep the new Windows 11 context menu             |

</details>

---

<details>
<summary>How it is organized</summary>

```
setup.sh / setup.ps1        Bootstrap: install git, clone to ~/.dotfiles, hand over
install.sh / install.ps1    Entry points, run the same sequence of steps on every OS
lib/                        Shared helpers (common.sh, common.ps1)
configs/
  common/                   All OSes:        .gitconfig, .vimrc
  unix/                     macOS + Linux:   .zshrc, .tmux.conf
  macos/ linux/ windows/    One OS only:     .zprofile, .zshrc.os, .gitconfig.os, profile.ps1
platforms/
  macos/                    platform.sh, Brewfile, Predawn.terminal
  linux/                    platform.sh, packages.apt, flatpaks.txt, predawn.dconf
  windows/                  platform.ps1, packages.txt, predawn.scheme.json
scripts/                    cleanup / chkdsk (.sh for macOS + Linux, .ps1 for Windows), clipcopy
tools/                      gen-terminal-themes.py
```

**Steps** (`install.sh` / `install.ps1`): hostname → OS preparation → link configs → Git identity → packages → Vim plugins → terminal profile → (Windows: tweaks). The OS specific parts are the `platform_*` functions in `platforms/<os>/platform.sh` (and their PowerShell twins in `platform.ps1`).

**Config layering.** Every file from `configs/common`, `configs/unix` and `configs/<os>` is linked into `$HOME`. Shared files pull in their OS-specific part through a small include:

- `.gitconfig` → `~/.gitconfig.os` (credential helper) and `~/.gitconfig.local` (identity from the CLI arguments)
- `.zshrc` → `~/.zshrc.os` (`bubu`, `l`, `ll`)

Because identity lives in `~/.gitconfig.local`, the tracked `.gitconfig` is never modified. Use `git config --file ~/.gitconfig.local user.name "..."` instead of `--global` to change it later.

**Clipboard.** Vim and tmux copy through `scripts/clipcopy` (`pbcopy`, `wl-copy`, `xclip`, …) — on Windows Vim uses `clip`.

**Terminal theme.** `platforms/macos/Predawn.terminal` is the single source of truth. Run `python3 tools/gen-terminal-themes.py` to regenerate the gnome-terminal and Windows Terminal versions after changing it.

**Adding a package:** macOS → `Brewfile`, Linux Mint → `packages.apt` / `flatpaks.txt`, Windows → `packages.txt` (winget IDs).

</details>

<details>
<summary>Manual setup</summary>

> `setup.sh` / `setup.ps1` are meant to be used as shown above. To set things up by hand, clone the repo to `~/.dotfiles` (the path is expected by the aliases and the Vim/tmux clipboard setup).

**macOS / Linux Mint**

```bash
# macOS: xcode-select --install     Linux Mint: sudo apt install git
git clone https://github.com/dikayx/.dotfiles.git ~/.dotfiles && chmod +x ~/.dotfiles/*.sh ~/.dotfiles/scripts/*
~/.dotfiles/install.sh -hn "My-Host" -gn "John Doe" -ge "<your_mail>@example.com"
```

**Windows 11**

```powershell
winget install Git.Git   # then reopen the shell
git clone https://github.com/dikayx/.dotfiles.git $HOME\.dotfiles
powershell -ExecutionPolicy Bypass -File $HOME\.dotfiles\install.ps1 -Hostname "My-PC" -GitUsername "John Doe" -GitEmail "<your_mail>@example.com"
```

> **Windows symlinks:** enable *Developer Mode* (Settings → System → For developers) so configs can be symlinked. Without it the installer copies the files instead and you need to re-run it after updating the repo.

> **Note:** I recommend using your GitHub email address and name here.

</details>
