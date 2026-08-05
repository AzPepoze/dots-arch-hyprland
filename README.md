# dots-arch-hyprland Dotfiles

This repository contains my personal dotfiles for Arch Linux, heavily based on [end-4's dotfiles](https://github.com/end-4/dots-hyprland), and configured for a personalized development and desktop experience with the Hyprland window manager (for me specifically).

The setup is designed to be automated, allowing for a quick and easy installation of a complete environment and program on a new system.

## ✨ Features

-    **Automated Setup:** Scripts to install [end-4's dotfiles](https://github.com/end-4/dots-hyprland), essential applications, command-line tools, and system services.
-    **Additional Utility Scripts:** A collection of helper scripts for managing the system, handling keybinds, and syncing files.
-    **Cursor** Custom cursor.

## 🚀 Installation

First, clone the repository to your home directory:

```bash
cd ~
git clone https://github.com/AzPepoze/dots-arch-hyprland.git
```

## 🛠️ Usage

This repository uses a menu-driven management script as the main entry point.

To start, run:

```bash
cd ~/dots-arch-hyprland
bash main.sh
```

This will present you with a menu of options:

-    **1) Run Installer:** For first-time setup. This will install all the necessary packages, dotfiles, and configurations.
-    **2) Open Configuration Editor:** Launches a graphical editor to easily change settings like the device model (PC/Laptop) and other preferences stored in `config.json`.
-    **3) Load Dotfile Configurations:** Manually applies the dotfile configurations to your system.
-    **4) Update:** Runs the standard update process, which includes pulling the latest changes from this repository, updating system packages, and running the unstable `dots-hyprland` update.
-    **5) Update (Full):** Runs the full update process, which does everything the standard update does, but performs a full (clean) install of `dots-hyprland`.

## 🔄 Update

To update your system and configurations, run the main script and choose an update option from the menu:

```bash
cd ~/dots-arch-hyprland
bash main.sh
```

Then select either **Update** or **Update (Full)**.

## 🎨 Customization

To override default configurations, create a `dots-custom` directory. Files inside `dots-custom` will overwrite the corresponding files in the `dots` directory if they have the same path.

This lets you keep your personal tweaks separate from the main configuration, making updates easier.

**Example:** To use a custom Kitty config:

1. Create your custom config file at `dots-custom/config/kitty/kitty.conf`.
     - You can copy the original from `dots/config/kitty/kitty.conf` as a starting point.
2. Edit your new file.

To apply your changes, run the main script and select **Load Dotfile Configurations**:

```bash
bash main.sh
```

## 🌙 Suspend, Resume, and Laptop Lids

This overlay uses the end-4 configuration's single `hypridle` owner (started by
Hyprland once per session). It does not add a second `hypridle`, Quickshell,
Waybar, AGS, portal, or wallpaper user service. The selected login session is
`hyprland-uwsm.desktop`, so UWSM remains responsible for session lifecycle.

Before suspend, `hypridle` asks logind to lock the session. After resume it
runs `~/.config/hypr/scripts/resume.sh`, which waits for Hyprland IPC for at
most two seconds, re-enables DPMS for every active output, and then requests a
best-effort renderer reload. It detects the active instance through `hyprctl`;
it does not disable a monitor and does not hardcode `eDP-1` or `eDP-2`.

There are no lid-switch bindings in this repository. Logind handles lid close
and Hyprland's normal monitor detection handles lid open. Keep panel setup in
`~/.config/hypr/monitors.conf` (or `monitors.lua`), and identify a laptop panel
with:

```bash
hyprctl monitors all
```

Look for an output name beginning with `eDP`; use that detected name only when
you deliberately create a monitor profile. Do not use `monitor ...,disable`
for lid handling: DPMS keeps the panel's mode, scale, position, and workspace
assignment intact.

If the display is black after resume, switch to another TTY and run this as the
logged-in desktop user (replace `0` with the instance shown by `hyprctl
instances` when needed):

```bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
hyprctl instances
hyprctl -i 0 dispatch 'hl.dsp.dpms({ action = "enable" })' || hyprctl -i 0 dispatch dpms on
hyprctl -i 0 dispatch 'hl.dsp.force_renderer_reload()'
```

For the legacy dispatcher fallback, use `hyprctl -i 0 dispatch dpms on`. Do not
kill Hyprland to recover: that leaves session-owned components alive. To exit
cleanly, use the QuickShell session menu or run `uwsm stop` from a terminal in
the session. UWSM will stop the compositor and its session-owned user units.

Collect a focused diagnostic report with:

```bash
~/.config/hypr/scripts/debug-resume.sh
```

It reports Hyprland state, failed user units, and only relevant kernel/user
journal lines (DRM/GPU, suspend/resume, Hyprland, lock/idle, and portals). No
environment variables are printed. Renderer recovery can still vary with GPU
drivers and firmware; this repository does not add NVIDIA options or kernel
parameters. Test both the internal panel alone and any external-monitor layout
you use.

### Package and power profiles

The installer keeps package ownership in small manifests under [`packages/`](packages/README.md):
common session/power packages, PC and laptop additions, optional diagnostics,
GPU userspace stacks, and conflicting packages to remove are maintained
separately.

Both PC and laptop profiles use `power-profiles-daemon`; do not run TLP,
auto-cpufreq, tuned, system76-power, or laptop-mode-tools beside it. The
installer detects installed conflicts, shows their exact names, and asks before
removing them. Laptop mode adds `brightnessctl`; `powertop` is optional and is
never enabled with blanket auto-tuning. GPU packages are detected by PCI vendor,
and NVIDIA kernel drivers remain a separate explicit choice because they must
match the GPU generation and kernel.

## 🙏 Acknowledgements

The foundation of this setup, especially the Hyprland configuration and overall structure, is heavily inspired by and built upon the excellent work from [end-4's dotfiles](https://github.com/end-4/dots-hyprland).
