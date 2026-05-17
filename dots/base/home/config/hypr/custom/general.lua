hl.config({
    input = {
        kb_layout = "us,th",
        sensitivity = 0.1,
        numlock_by_default = true,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 0.2
        }
    },
    decoration = {
        inactive_opacity = 1.0,
        active_opacity = 1.0,
        dim_special = 0.2,
        blur = {
            enabled = true,
            special = true,
            xray = false,
            size = 10,
            passes = 3,
            ignore_opacity = true,
            new_optimizations = true,
            brightness = 1.0,
            noise = 0.0,
            contrast = 1.0,
            vibrancy = 0.5,
            vibrancy_darkness = 0.0
        }
    },
    general = {
        border_size = 1,
        resize_on_border = true,
        allow_tearing = false
    }
})
