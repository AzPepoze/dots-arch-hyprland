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

## 🙏 Acknowledgements

The foundation of this setup, especially the Hyprland configuration and overall structure, is heavily inspired by and built upon the excellent work from [end-4's dotfiles](https://github.com/end-4/dots-hyprland).
