hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "x11")

-- Tablet configurations for osu!
hl.config({
    device = {
        {
            name = "virtual_tablet",
            active_area_size = "1000 1000",
            active_area_position = "0 1024"
        },
        {
            name = "virtual_tablet_1",
            active_area_size = "1000 1000",
            active_area_position = "0 1024"
        }
    }
})
