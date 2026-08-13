# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal Arch Linux dotfiles/provisioning repo (Cinnamon/GNOME desktop, Nord theme). `setup.sh` provisions a fresh machine (packages, symlinks, theme, systemd rules); `reset.sh` is its mirror-image undo. Everything else is either a file that gets symlinked/copied into place, or a standalone CLI tool installed to `/usr/local/bin`.

## Layout

```
setup.sh / reset.sh   entry points, mirror each other section-by-section
helpers/              flat — every shared helper AND every per-tool helper, side by side, no subfolders
tools/                flat — every entry-point script, no subfolders
home/                 mirrors $HOME exactly; every file here gets symlinked to the matching path under ~
etc/                  mirrors /etc exactly; every file here gets copied (not symlinked) to the matching /etc path
data/                 static data files consumed by .bashrc functions (e.g. Firefox user.js overrides)
```

There is no per-tool subfolder convention (that was tried and abandoned) — `helpers/` and `tools/` are both intentionally flat, matching the sibling `termux-config` repo's layout.

## Commands

There is no build step, package.json, or test suite. Verification is:

- **Syntax check after any edit**: `bash -n <file>` on every script touched.
- **Isolated reproduction**: for behavior that's hard to verify live (sudo paths, systemd units, fzf pickers), source the relevant helper in a throwaway `bash -c '...'` snippet and assert on output rather than trusting the read.
- **Live dry run** where safe: `bash setup.sh` / `bash reset.sh` actually mutate the system (packages, `/etc`, systemd, sudoers) — don't run them speculatively; reason from the mirrored logic in `link-helpers.sh` instead.
- To pick up `.bashrc` changes in the current shell: `source ~/.bashrc` (aliased to `reload`).

## Architecture

**`ARCH_CONFIG_PATH`** is the backbone. `setup.sh` writes it to `/etc/profile.d/arch-config.sh` pointing at the checkout dir; `.bashrc` and every `tools/*.sh` script source helpers relative to it (`$ARCH_CONFIG_PATH/helpers/...`). Never hardcode the repo path in a tool — always go through this variable.

**`helpers/link-helpers.sh`** is the generic tree-walker both `setup.sh` and `reset.sh` are built on:
- `_each_home_file` walks `home/` and calls a caller-defined `_home_file_action(src, target)` — setup symlinks, reset removes-and-restores-backup.
- `_each_etc_file` walks `etc/` and calls `_etc_file_action(src, dest)` — setup copies+chowns root, reset deletes.
- `_each_tool_file` walks `tools/*.sh` and calls `_tool_file_action(name, src)` — setup symlinks into `/usr/local/bin/<name>` (name = filename minus `.sh`), reset unlinks.

Each script (`setup.sh`/`reset.sh`) defines its own version of these three callback functions right before invoking the walker — read both definitions together when changing install/uninstall behavior, since they're expected to mirror each other exactly (see "reset counterparts" convention below).

**Printing.** One primitive, `printfc "$COLOR" "fmt" [args]` (or `printfc -n ...` for no trailing newline), defined in `helpers/printer.sh`. No `info`/`ok`/`err` wrapper functions — callers pass the color directly. Two separate color files, picked by lifecycle stage:
- `helpers/colors-standard.sh` (plain ANSI) — used only by `setup.sh`/`reset.sh`, which run *before* the Nord theme exists.
- `helpers/colors-nord.sh` (Nord truecolor) — used by everything else (`tools/*.sh`, `home/.bashrc`).

Semantic mapping (don't invent a new category, e.g. a separate "info" color — yellow already covers info/in-progress):
- Blue → section headers only. Green → success/completed-action detail. Yellow → warnings, cancellations, empty-but-normal state, in-progress/about-to-happen announcements. Red → errors/failures only. `NORD_SNOW_1` → neutral fact/detail lines, table headers, list bodies. `NORD_POLAR_4` → separators, de-emphasized labels. Plain `CYAN` is reserved solely for the `setup.sh`/`reset.sh` banner box.

**Tool scripts (`tools/*.sh`)** are self-contained CLIs, each following the same shape: source colors/printer/dep-checker (+ its own `*-helper.sh` if one exists), `_test_dependencies` guard at the top, self-elevate via `exec sudo -E bash "$(realpath "$0")" "$@"` if root is needed (see `wgm.sh`/`wpm.sh`), then a `case "$1" in ...)` router at the bottom with a fallback usage block. New tools should follow this same source-guard-router shape.

**Shared state lives under `~/.config/arch-config-files/<tool>/`**, with backups under `~/Documents/<tool>-backup/`. Path construction for each tool is centralized in its `helpers/<tool>-helper.sh` `_​<tool>_set_paths()` function (e.g. `_wgm_set_paths`, `_wpm_set_paths`) — both the live tool and `reset.sh` source this same function rather than each hardcoding paths.

**`home/.bashrc`** is itself one of the mirrored `home/` files (not a special case) — it sources `colors-nord.sh`/`printer.sh`/`dep-checker.sh` via `$ARCH_CONFIG_PATH` and gates most of its functionality behind a `_test_dependencies` check, falling back to a bare `PS1` if required tools are missing.

## Conventions to hold new/edited code to

- **Reset counterparts must actually mirror setup.** Any setup step that installs/creates something needs a matching reset step undoing exactly that, referencing the same shared path/list variables (`helpers/pkg-list.sh`, `helpers/theme-settings.sh`, `helpers/repo-list.sh`) — never a re-typed literal. `reset.sh`'s package-removal step is intentionally informational (prints a manual-removal list), not automatic — don't make it silently `pacman -R` things.
- **Executable bits are committed.** `tools/*.sh` must be `100755` in git, not just locally `chmod +x`'d — otherwise a fresh clone breaks the `/usr/local/bin` symlinks.
- **sudo failure must not fall through.** Any function that shells out to `sudo` and has logic after the failure branch needs an explicit `return 1` on failure — otherwise stale/partial state below can print a contradicting success message (this has been a recurring real bug in `.bashrc` functions like `cup`/`upp`). Prefer `if cmd; then ... else ...; fi` over checking `$?` afterward.
- **Color legibility**: use the normal-intensity 8-color ANSI codes or Nord truecolor as already defined, not bright-ANSI variants (`\e[90m`-`\e[97m`) or ad hoc truecolor — this repo's Nord palette is a deliberate exception already accounted for in `colors-nord.sh`, don't add more one-off hex escapes beside it.
- **Single source of truth**: a value needed by both a setup path and its reset counterpart (package lists, gsettings schema/key pairs, tool paths) lives once in a shared helper file both read, never duplicated.
