# Desktops Hardware Configuration

I have below two desktops: one Thinkpad (main) and another Dell (backup). I want to practice setting up desktop configuration on dell.

# Desktops

| Hostname  | IP Address     | CPU (Cores) | RAM | Model                 | GPU Capability                                               | OS                  | Status    | Role                          |
| --------- | -------------- | ----------- | --- | --------------------- | ------------------------------------------------------------ | ------------------- | --------- | ----------------------------- |
| dt-dev-01 | 192.168.10.189 | 16 Ryzen7   | 96G | -                     | ThinkPad P14s Gen 5 AMD + ThinkPad Universal USB Type-C Dock | Ununtu Server 24.04 | Available | Ansible Control Node          |
| dt-dev-02 | 192.168.10.135 | 8 Indel     | 32G | NVIDIA GTX 1050Ti 4GB | Dell XPS 15 (9570) + Dell Thunderbolt Dock WD19TBS           | Ununtu Server 24.04 | Available | Ansible Control Node (backup) |

I am worried, that there are hardware specific configurations that I did to my Ubuntu Server 24.04 (minimized) with Sway installation.

From what I remember:

- Netplan configuration have different ethernet and wifi interfaces names, also both have the wifi passwords, which should be probably handled in 1password through the Ansible templates using variables with correct interface names, and wifi passwords retrieved from 1password integration.
- Dell has touch screen, which I configured and it works, I do not remember where are these settings and how I did it.
- Dell has different fingerprint scanner model and it is not configured.
- Dell has different speakers probably.
- Will the same Sony Headsets connected to Dell be displayed and named differently on a sway status bar?
- The sound configuration sink names, are they different. It might be dt-dev-02 (dell) audio configuration needs to be cleaned, to make it similar to dt-dev-01 (thinkpad). Dell might have duplicated unnecesarry audio packages, that are cleaned on thinkpad. I want to make dell as clean as thinkpad.
- Notebook keyboard special keys, like dimming/brigtenin screen, volume up/down buttons are probably configured in sway configuration (/home/fastctl/fun/homelab/chezmoi/dot_config/sway/config.tmpl). Like are below the same for Dell and Thinkpad?
-

```
# fix notebook hardware buttons
bindsym XF86MonBrightnessUp exec brightnessctl set +10%
bindsym XF86MonBrightnessDown exec brightnessctl set 10%-

# Audio controls (speakers/headphones)
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioMicMute exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
# Additional microphone controls
bindsym $mod+m exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous
```

How difficult is to fix this? If it is possible to fix and automate. I would wipe out `dt-dev-02` into clean Ubuntu Server 24.04 (minimized) installation, and would try to install it with the ansible scriopts.
