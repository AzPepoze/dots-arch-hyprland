package installer

import (
	"tui/internal/repo"
)

type InstallItem struct {
	Type        string
	Text        string
	Func        string
	Description string
	IsSelected  bool
	IsHeader    bool
}

func getInstallItems(repoDir string) []InstallItem {
	return []InstallItem{
		{IsHeader: true, Text: "--- Core & Package Management ---"},
		{
			Type:        "essential",
			Text:        "Install paru (AUR Helper)",
			Func:        "install_paru",
			Description: "Installs paru, an AUR helper that simplifies installing and managing packages from the Arch User Repository.",
		},
		{
			Type:        "essential",
			Text:        "Install Flatpak",
			Func:        "install_flatpak",
			Description: "Installs Flatpak, a universal packaging system for Linux applications, providing sandboxed environments.",
		},
		{
			Type:        "essential",
			Text:        "Install downgrade utility",
			Func:        "install_downgrade",
			Description: "Installs downgrade, a utility to downgrade one or more packages to a version in your cache or from the Arch Linux Archive.",
		},
		{
			Type:        "essential",
			Text:        "Adjust GRUB menu resolution",
			Func:        "adjust_grub_menu",
			Description: "Adjusts the resolution of the GRUB boot menu for better display compatibility.",
		},
		{
			Type:        "essential",
			Text:        "Enable os-prober for GRUB",
			Func:        "enable_os_prober",
			Description: "Enables os-prober in GRUB to detect and list other operating systems installed on the machine.",
		},
		{
			Type:        "essential",
			Text:        "Install Catppuccin Theme for GRUB",
			Func:        "select_and_install_catppuccin_grub_theme",
			Description: "Installs the Catppuccin theme for GRUB, enhancing the bootloader's appearance.",
		},
		{
			Type:        "essential",
			Text:        "Install rate-mirrors and Rank Mirrors",
			Func:        "install_rate_mirrors_and_rank",
			Description: "Installs rate-mirrors and then runs the script to rank Arch Linux mirrors for optimal performance.",
		},
		{
			Type:        "essential",
			Text:        "Install ananicy-cpp",
			Func:        "install_ananicy_cpp",
			Description: "Installs ananicy-cpp, a C++ port of ananicy, which automatically adjusts process nice values and I/O priorities for better system responsiveness.",
		},

		{IsHeader: true, Text: "--- Drivers & Hardware ---"},
		{
			Type:        "essential",
			Text:        "Install Linux Headers",
			Func:        "install_linux_headers",
			Description: "Installs essential Linux kernel headers for building modules and other system components.",
		},
		{
			Type:        "optional",
			Text:        "Install v4l2loopback (for Droidcam/OBS)",
			Func:        "install_v4l2loopback",
			Description: "Installs v4l2loopback, a kernel module that creates virtual video devices, useful for Droidcam or OBS.",
		},
		{
			Type:        "optional",
			Text:        "Install MX002 Tablet Driver",
			Func:        "install_mx002_driver",
			Description: "Installs the necessary drivers for MX002 series drawing tablets.",
		},
		{
			Type:        "optional",
			Text:        "Install Virtualization (libvirt, virt-manager, QEMU)",
			Func:        "install_virt_packages",
			Description: "Installs essential virtualization tools including libvirt, virt-manager, QEMU, dnsmasq, and dmidecode, and enables the libvirtd service.",
		},
		{
			Type:        "optional",
			Text:        "Install Droidcam",
			Func:        "install_droidcam",
			Description: "Installs Droidcam, allowing you to use your Android phone as a webcam.",
		},

		{IsHeader: true, Text: "--- System Services & Libraries ---"},
		{
			Type:        "essential",
			Text:        "Install Session & Power Profile",
			Func:        "install_power_session_stack",
			Description: "Installs the maintained Hyprland/UWSM/portal stack and one power manager (PPD), with PC/laptop-specific packages and conflict cleanup.",
		},
		{
			Type:        "optional",
			Text:        "Install Detected GPU Userspace Stack",
			Func:        "install_detected_graphics_stack",
			Description: "Detects AMD, Intel, and NVIDIA GPUs and installs only their maintained userspace packages; NVIDIA kernel drivers remain an explicit hardware choice.",
		},
		{
			Type:        "essential_laptop",
			Text:        "Install Laptop Power Diagnostics",
			Func:        "install_laptop_power_diagnostics",
			Description: "Installs powertop for measurement only; no automatic tuning service is enabled.",
		},

		{
			Type:        "essential",
			Text:        "Install FUSE",
			Func:        "install_fuse",
			Description: "Installs FUSE (Filesystem in Userspace), allowing non-privileged users to create their own file systems.",
		},
		{
			Type:        "essential",
			Text:        "Install NTFS Support (fast ntfs3 & utilities)",
			Func:        "install_ntfs_3g",
			Description: "Provides support for NTFS partitions using the fast kernel-level 'ntfs3' driver, and installs 'ntfs-3g' for essential maintenance utilities (like ntfsfix).",
		},
		{
			Type:        "essential",
			Text:        "Install systemd-oomd.service",
			Func:        "install_systemd_oomd",
			Description: "Installs and enables systemd-oomd, a userspace OOM killer that can prevent system freezes under heavy memory pressure.",
		},
		{
			Type:        "essential",
			Text:        "Install inotify-tools",
			Func:        "install_inotify_tools",
			Description: "Installs inotify-tools, a set of command-line programs for monitoring filesystem events.",
		},
		{
			Type:        "essential",
			Text:        "Install Mission Center",
			Func:        "install_mission_center",
			Description: "Installs Mission Center (AUR version), a modern and fast system monitor for Linux.",
		},

		{IsHeader: true, Text: "--- Desktop & Theming ---"},
		{
			Type:        "essential",
			Text:        "Install end-4's Hyprland Dots",
			Func:        "install_end4_hyprland_dots",
			Description: "Installs the core Hyprland configuration files and dependencies from end-4.",
		},
		{
			Type:        "essential",
			Text:        "Install and Run nwg-displays",
			Func:        "install_nwg_displays",
			Description: "Installs and runs nwg-displays, a small utility for managing displays in Wayland compositors like Hyprland.",
		},
		{
			Type:        "essential",
			Text:        "Install nwg-look",
			Func:        "install_nwg_look",
			Description: "Installs nwg-look, a GTK settings editor for Wayland.",
		},
		{
			Type:        "essential",
			Text:        "Install qt5ct",
			Func:        "install_qt5ct",
			Description: "Installs qt5ct, a tool to configure Qt5 application appearance.",
		},
		{
			Type:        "essential",
			Text:        "Install qt6ct",
			Func:        "install_qt6ct",
			Description: "Installs qt6ct, a tool to configure Qt6 application appearance.",
		},
		{
			Type:        "essential",
			Text:        "Install SDDM Astronaut Theme",
			Func:        "install_sddm_theme",
			Description: "Installs the Astronaut theme for SDDM, the Simple Desktop Desktop Manager.",
		},
		{
			Type:        "essential",
			Text:        "Install Cursor Theme",
			Func:        "install_cursors",
			Description: "Installs one of the cursor themes bundled with this repository and applies it to GTK and Flatpak applications.",
		},
		{
			Type:        "essential",
			Text:        "Install Fish Shell",
			Func:        "install_fish",
			Description: "Installs the Fish shell, a smart and user-friendly command line shell.",
		},
		{
			Type:        "essential",
			Text:        "Load all configurations (GPU, cursor, etc)",
			Func:        "bash " + repo.LoadConfigsScript(repoDir),
			Description: "Loads and applies various system configurations, including GPU settings, cursor themes, and other dotfiles.",
		},

		{IsHeader: true, Text: "--- Applications ---"},
		{
			Type:        "essential",
			Text:        "Install Rofi",
			Func:        "install_rofi",
			Description: "Installs Rofi, a window switcher, application launcher, and dmenu replacement.",
		},
		{
			Type:        "optional",
			Text:        "Install Zen Browser",
			Func:        "install_zen_browser",
			Description: "Installs Zen Browser, a privacy-focused web browser.",
		},
		{
			Type:        "optional",
			Text:        "Install Microsoft Edge (Stable)",
			Func:        "install_ms_edge_stable",
			Description: "Installs the Microsoft Edge (Stable) browser.",
		},
		{
			Type:        "optional",
			Text:        "Install VS Code",
			Func:        "install_vscode",
			Description: "Installs the stable Visual Studio Code package.",
		},
		{
			Type:        "optional",
			Text:        "Install Tabby",
			Func:        "install_tabby",
			Description: "Installs Tabby, a configurable terminal, SSH, and serial client from the AUR binary package.",
		},
		{
			Type:        "optional",
			Text:        "Install npm",
			Func:        "install_npm",
			Description: "Installs npm (Node Package Manager), a package manager for JavaScript.",
		},
		{
			Type:        "optional",
			Text:        "Install pnpm",
			Func:        "install_pnpm",
			Description: "Installs pnpm, a fast, disk-space efficient package manager for Node.js.",
		},
		{
			Type:        "optional",
			Text:        "Install bun",
			Func:        "install_bun",
			Description: "Installs Bun, a fast all-in-one JavaScript runtime, packager, transpiler, and runner.",
		},
		{
			Type:        "optional",
			Text:        "Install Discord",
			Func:        "install_discord",
			Description: "Installs the official Discord client.",
		},
		{
			Type:        "optional",
			Text:        "Install Vencord (Discord Mod)",
			Func:        "install_vencord",
			Description: "Installs the Vencord mod for Discord.",
		},
		{
			Type:        "optional",
			Text:        "Install Steam",
			Func:        "install_steam",
			Description: "Installs Steam, the popular digital distribution platform for video games.",
		},
		{
			Type:        "essential",
			Text:        "Install Pinta",
			Func:        "install_pinta",
			Description: "Installs Pinta, a free, open-source drawing/editing program.",
		},
		{
			Type:        "essential",
			Text:        "Install Nomacs",
			Func:        "install_nomacs",
			Description: "Installs Nomacs, a fast and easy-to-use image viewer.",
		},
		{
			Type:        "optional",
			Text:        "Install YouTube Music (Pear)",
			Func:        "install_youtube_music_pear",
			Description: "Installs YouTube Music (Pear Desktop).",
		},
		{
			Type:        "optional",
			Text:        "Install HandBrake",
			Func:        "install_handbrake",
			Description: "Installs HandBrake, a free and open-source video transcoder.",
		},
		{
			Type:        "optional",
			Text:        "Install Linux Wallpaper Engine",
			Func:        "install_wallpaper_engine",
			Description: "Installs Linux Wallpaper Engine, a port of the popular Wallpaper Engine for Linux.",
		},
		{
			Type:        "optional",
			Text:        "Install Linux Wallpaper Engine GUI",
			Func:        "install_wallpaper_engine_gui",
			Description: "Installs the GUI for Linux Wallpaper Engine using paru.",
		},
		{
			Type:        "optional",
			Text:        "Install EasyEffects",
			Func:        "install_easyeffects",
			Description: "Installs EasyEffects, a PulseAudio/PipeWire application for applying audio effects.",
		},
		{
			Type:        "essential",
			Text:        "Install Pavucontrol-Qt",
			Func:        "install_pavucontrol",
			Description: "Installs Pavucontrol, a simple GTK based volume control tool for PulseAudio.",
		},
		{
			Type:        "essential",
			Text:        "Install Set up Git Credential Management",
			Func:        "setup_git_credential_management",
			Description: "Sets up Git Credential Manager to securely store and manage Git credentials.",
		},
		{
			Type:        "essential",
			Text:        "Install Switcheroo",
			Func:        "install_switcheroo",
			Description: "Installs Switcheroo, a simple application switcher for Wayland.",
		},
		{
			Type:        "essential",
			Text:        "Install BleachBit",
			Func:        "install_bleachbit",
			Description: "Installs BleachBit, a system cleaner to free up disk space and maintain privacy.",
		},
		{
			Type:        "essential",
			Text:        "Install QDirStat",
			Func:        "install_qdirstat",
			Description: "Installs QDirStat, a graphical disk usage display.",
		},
		{
			Type:        "essential",
			Text:        "Install GParted (Partition Editor)",
			Func:        "install_gparted",
			Description: "Installs GParted, a graphical partition editor for creating, reorganizing, and deleting disk partitions.",
		},
		{
			Type:        "essential",
			Text:        "Install Flatseal",
			Func:        "install_flatseal",
			Description: "Installs Flatseal, a graphical utility to review and modify permissions for your Flatpak applications.",
		},
		{
			Type:        "optional",
			Text:        "Install gdrive-bisync (Google Drive)",
			Func:        "install_gdrive_bisync",
			Description: "Installs gdrive-bisync, a Google Drive client for Linux.",
		},
		{
			Type:        "optional",
			Text:        "Install Waydroid",
			Func:        "install_waydroid",
			Description: "Installs Waydroid, a container-based approach to boot a full Android system on a Linux device.",
		},
		{
			Type:        "optional",
			Text:        "Install Waydroid Helper",
			Func:        "install_waydroid_helper",
			Description: "Installs Waydroid Helper, a utility to simplify Waydroid management.",
		},
		{
			Type:        "optional",
			Text:        "Install Waydroid Extra Script",
			Func:        "install_waydroid_extra_script",
			Description: "Installs the Waydroid Extra Script for enhanced Waydroid management.",
		},
	}
}
