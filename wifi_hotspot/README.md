# Wi-Fi Hotspot

Broadcast a Wi-Fi access point straight from the device running Home
Assistant OS, **bridged into your LAN**: clients get DHCP from your router,
sit on your normal subnet, and device discovery (mDNS, casting) just works.
No extra hardware, no routing, no NAT.

- WPA2-protected SSID on the onboard wireless interface
- Clients are first-class LAN devices
- 2.4 GHz and 5 GHz (non-DFS) channels
- Safe by design: automatic rollback if the bridge fails, and a reboot
  always restores the original network configuration

See [DOCS.md](DOCS.md) for configuration and troubleshooting.
