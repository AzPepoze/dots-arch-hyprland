# Keep reboot commands out of fish history so they never show up in
# autosuggestions. Installed from dots-arch-hyprland:
# dots/base/home/config/fish/conf.d/no_reboot_history.fish
function fish_should_add_to_history --description 'Keep reboot commands out of history'
    set -l cmd (string join ' ' -- $argv)

    # Preserve fish's default: commands starting with a space are not saved.
    string match -qr '^\s' -- $cmd; and return 1

    # Skip `reboot`, `sudo reboot`, and variants like `sudo reboot -f` or `reboot now`.
    string match -qr '^\s*(sudo\s+)?reboot(\s|$)' -- $cmd; and return 1

    return 0
end
