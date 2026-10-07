-- Custom Window Rules

-- Frosted settings window: opt out of the global no_blur default + lower
-- opacity so compositor blur shows through
hl.window_rule({ match = { title = "^(illogical-impulse Settings)$" }, no_blur = false })
hl.window_rule({ match = { title = "^(illogical-impulse Settings)$" }, opacity = "0.85 0.85 1.0" })

hl.window_rule({match = {class = "^(kitty)$"}, opacity = "0.80 0.80 1.0", no_blur = false})
hl.window_rule({match = {class = "(?i)^(tabby)$"}, no_blur = false})
hl.window_rule({match = {class = "^(org.kde.dolphin)$"}, opacity = "0.80 0.80 1.0", no_blur = false})

-- Float + pin pavucontrol-qt bottom-right (base only covers "pavucontrol" class)
hl.window_rule({match = {class = "^(pavucontrol-qt)$"}, float = true})
hl.window_rule({match = {class = "^(pavucontrol-qt)$"}, pin = true})
hl.window_rule({match = {class = "^(pavucontrol-qt)$"}, size = {"(monitor_w*0.36)", "(monitor_h*0.55)"}})
hl.window_rule({match = {class = "^(pavucontrol-qt)$"}, move = {"(monitor_w*0.63)", "(monitor_h*0.43)"}})

-- Float + center Mission Center
hl.window_rule({match = {class = "(?i).*missioncenter.*"}, float = true})
hl.window_rule({match = {class = "(?i).*missioncenter.*"}, size = {"(monitor_w*0.55)", "(monitor_h*0.60)"}})
hl.window_rule({match = {class = "(?i).*missioncenter.*"}, center = true})
