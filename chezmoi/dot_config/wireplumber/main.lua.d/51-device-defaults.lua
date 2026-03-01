-- WirePlumber default device configuration
-- Auto-switch to newly connected devices

-- Default node rules
default_nodes_rules = {
    -- When a new Bluetooth device connects, make it the default
    {
        matches = {
            {
                { "node.name", "matches", "bluez_output.*" },
            },
        },
        apply_properties = {
            ["priority.driver"] = 2000,
            ["priority.session"] = 2000,
        },
    },
}

-- Automatically switch to newly connected devices
alsa_monitor.rules = {
    {
        matches = {
            {
                { "node.name", "matches", "alsa_output.*" },
            },
        },
        apply_properties = {
            ["session.suspend-timeout-seconds"] = 5,
        },
    },
}
