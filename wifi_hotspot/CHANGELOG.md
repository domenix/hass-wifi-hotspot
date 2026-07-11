# Changelog

## 1.0.0

Initial release.

- Wi-Fi clients join your LAN directly: DHCP from your router, same subnet,
  mDNS/casting work
- Kernel bridge carries the host's IP and MAC — nothing persistent is
  modified, a reboot always restores the plain wired configuration
- Automatic verification and rollback if the bridge doesn't come up
- Supervisor updates keep working while the hotspot runs
- 2.4 GHz and non-DFS 5 GHz channels, regulatory country code support
- Full configuration validation with actionable log messages, AppArmor
  profile
