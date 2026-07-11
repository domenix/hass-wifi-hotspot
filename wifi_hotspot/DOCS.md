# Wi-Fi Hotspot

Turns the device running Home Assistant OS (e.g. a Raspberry Pi 4) into a
Wi-Fi access point **bridged into your LAN**. Clients get DHCP from your
router, keep your usual IP range, and device discovery (mDNS, casting)
works — exactly as if they had joined your main Wi-Fi.

```
phone/laptop ──Wi-Fi──> wlan0 ─┐
                               ├─ hotspot0 (carries the device's LAN IP)
your router <────── eth0 ──────┘
```

## Getting started

1. Set `ssid` and `wpa_passphrase` in the **Configuration** tab.
2. Start the add-on and watch the **Log** tab.

On start the add-on bridges the wired interface with the access point.
**The device's network blips for a moment**; the IP address and MAC stay
the same, so DHCP reservations keep working.

### Safety

- **Nothing persistent is modified.** A reboot always restores the plain
  wired configuration; the add-on simply re-bridges at startup.
- After the switch the gateway is verified by ping — on any failure the
  add-on rolls back to the wired configuration automatically.
- Stopping the add-on only stops the AP; the bridge stays until reboot, so
  a working network is never torn down.
- If the device ever becomes unreachable: power-cycle it.

While the hotspot runs, **Settings → System → Network** shows no active
interface and the host's connectivity status is unavailable. Both are
cosmetic and revert on reboot.

## Options

| Option | Default | Notes |
|---|---|---|
| `ssid` | — | Network name, 1–32 characters |
| `wpa_passphrase` | — | WPA2 passphrase, 8–63 characters |
| `channel` | `6` | `1`–`13` (2.4 GHz, better range) or `36/40/44/48/149/153/157/161/165` (5 GHz, faster). In most of the EU only 36–48 are allowed on 5 GHz. DFS channels are not supported. |
| `interface` | `wlan0` | Wireless interface to broadcast on |
| `lan_interface` | auto | Wired interface to bridge with; empty = the default-route interface. Wi-Fi repeater (AP + client on one radio) is not supported. |
| `country_code` | `HU` | Two-letter regulatory domain (e.g. `DE`, `US`) |
| `log_level` | `warning` | `debug` / `info` / `warning` / `error` |

## Reverting to plain wired networking

Turn off *Start on boot*, stop (or uninstall) the add-on, and reboot the
device.

## Limitations (onboard Raspberry Pi Wi-Fi)

- ~5 concurrent clients (firmware limit) — use a USB Wi-Fi adapter for more
- Modest throughput (single antenna); a metal case reduces range
- WPA2-PSK only (the onboard firmware's WPA3 AP support is unreliable)

## Troubleshooting

**Stops right after starting** — the Log tab names the exact option to fix.

**"Bridge verification failed / rolled back"** — the bridge came up but the
gateway didn't answer. Your network was restored automatically; check the
wired connection and try again.

**Interface busy / `Could not configure driver mode`** — remove any Wi-Fi
network configured in **Settings → System → Network** for the AP interface
and restart the add-on.

Don't reconfigure the wired interface in **Settings → System → Network**
while the hotspot runs — revert first.

## Support

https://github.com/domenix/hass-wifi-hotspot/issues
