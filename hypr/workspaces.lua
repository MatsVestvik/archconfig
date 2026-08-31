-- Workspaces configuration for Hyprland (Lua format)

-- Primary Monitor (Laptop - eDP-1)
hl.workspace_rule({
    workspace = "1",
    monitor = "eDP-1",
    default = true,
})
hl.workspace_rule({
    workspace = "2",
    monitor = "eDP-1",
})
hl.workspace_rule({
    workspace = "3",
    monitor = "eDP-1",
})
hl.workspace_rule({
    workspace = "4",
    monitor = "eDP-1",
})

-- Secondary Monitor (External - DP-1)
hl.workspace_rule({
    workspace = "5",
    monitor = "DP-1",
    default = true,
})
