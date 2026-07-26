# arch-config

Personal Arch Linux system configuration: a single `setup.sh` that takes a
fresh install to a fully configured desktop (theme, packages, dotfiles,
browser/editor policies) and a matching `reset.sh` that undoes it.

Built for Cinnamon on Arch (or an Arch-based distro with a compatible
package manager and AUR access). Some steps (`gsettings` schemas, the theme
package list) are Cinnamon-specific — skip or adapt those sections if you're
on a different desktop.

## Quick start

```bash
git clone https://github.com/jehan593/arch-config ~/arch-config
bash ~/arch-config/setup.sh
```

`setup.sh` must be run as a regular user (it escalates with `sudo` itself)
from inside the checkout. To undo everything it did:

```bash
bash ~/arch-config/reset.sh
```

## What `setup.sh` does

1. Sets `ARCH_CONFIG_PATH` system-wide (`/etc/profile.d/arch-config.sh`).
2. Symlinks everything under `home/` into `$HOME`, backing up any existing
   file it would overwrite (`<file>.bak.<timestamp>`).
3. Symlinks everything under `tools/` into `/usr/local/bin`.
4. Copies everything under `etc/` into `/etc`, mirroring the same path
   (e.g. `etc/brave/policies/managed/arch-config.json` →
   `/etc/brave/policies/managed/arch-config.json`).
5. Installs `yay` and enables the Chaotic-AUR repo if not already present.
6. Installs the package list in `helpers/pkg-list.sh` plus theme packages.
7. Adds a passwordless-sudo rule scoped to `updatedb` only.
8. Enables `Color`/`ILoveCandy` in `pacman.conf`.
9. Clones a [wallpapers repo](https://github.com/jehan593/my-wallpapers)
   into `~/Pictures/config-wallpapers`.
10. Installs the Nord GTK/icon/cursor theme and applies it via `gsettings`.

`reset.sh` reverses each of these in turn (with confirmation prompts before
anything destructive) and leaves the repository checkout itself untouched.

## Layout

```
etc/          Files copied verbatim to /etc (browser & editor policies)
data/         Data consumed by shell functions (e.g. Firefox pref overrides)
helpers/      Shared shell libraries sourced by setup.sh/reset.sh/tools
home/         Dotfiles, symlinked into $HOME
tools/        Standalone CLI tools, symlinked into /usr/local/bin
setup.sh      Installer
reset.sh      Uninstaller
```

## Tools (`tools/`)

| Command | Purpose |
|---|---|
| `wgm {on,off,add,rm,status}` | WireGuard profile manager (including a built-in Cloudflare WARP profile via `wgcf`) |
| `wpm {add,ls,rm,start,stop,restart}` | Manage `wireproxy` SOCKS5 tunnels as systemd services |
| `timer <duration>` | Fullscreen countdown timer (e.g. `timer 25m`, `timer 1h30m`) |

## Shell environment (`home/.bashrc`)

Requires `fzf`, `yay`, `git`, `curl`, `xclip`, `checkupdates`, `paccache`,
`reflector`, and `xdg-open` — falls back to a minimal prompt if any are
missing.

| Command | Purpose |
|---|---|
| `sys` | Uptime, kernel, package count, memory, OS age, battery |
| `cup` | List available pacman/AUR updates, grouped by repo |
| `upp [-all]` | Upgrade packages (fzf-select a repo, or `-all` for everything) |
| `upc` | Pull the latest arch-config from git |
| `upf` | Refresh Firefox prefs from Betterfox + local overrides |
| `upwp` | Pull the latest wallpapers |
| `upall` | Runs `upp -all`, `upf`, `upwp`, `upc` together |
| `inst` / `inst -refresh` | fzf package installer (Pacman + AUR) |
| `uinst` | fzf package remover, flags explicitly-installed packages |
| `cleanup` | Clears pacman/AUR caches, trash, and stale history files |
| `cons-mode {on,off}` | Toggle ThinkPad/IdeaPad battery conservation mode |
| `sys-res {on,off}` | Toggle a blank `systemd-resolved.conf` (back up/restore) |
| `trash <path>...` | Freedesktop-Trash-compatible delete |
| `ff [dir]` | fzf file finder, copies the picked path to the clipboard |
| `sz [path]` | Disk usage of a file/directory |
| `open [path]` | Wraps `xdg-open` |
| `conf` | Opens the repo in Zed, if installed |
| `\C-h` | Deduplicated fzf history search bound to Ctrl+H |

## Configuration included

- **Shell**: `.bashrc`, Starship prompt (`starship.toml`), Nord truecolor
  palette
- **Editor**: Neovim (`init.lua`)
- **Media**: mpv (`mpv.conf`, `input.conf`)
- **Maintenance**: Topgrade (`topgrade.toml`)
- **Browser policy**: Brave, Firefox (telemetry/tracking disabled, uBlock
  Origin pinned), VS Code — installed system-wide via `etc/`
- **Firefox prefs**: [Betterfox](https://github.com/yokoffing/Betterfox)
  baseline, pruned/extended by `data/firefox/` and applied by `upf`
