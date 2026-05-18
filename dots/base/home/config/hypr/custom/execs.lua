hl.on("hyprland.start", function ()
    hl.exec_cmd("bash ~/dots-arch-hyprland/scripts/startup.sh")
    hl.exec_cmd("vicinae server")
end)