#!/bin/sh
# Bridge-transition test with a REAL NetworkManager, inside a privileged
# container. Reproduces the on-device NM behavior without touching a real
# box: a veth pair plays the wired LAN (veth1 = "the router", answering
# ping), a dummy device plays wlan0 (wireless check bypassed via
# HOTSPOT_TEST_SKIP_WIRELESS_CHECK).
#
# Expected end state: hotspot0 bridge active, holding the original static
# IP, gateway ping OK, hostapd.conf generated with bridge=hotspot0.
set -x

apk add --no-cache networkmanager networkmanager-cli dbus eudev >/dev/null 2>&1 || \
    apk add --no-cache networkmanager networkmanager-cli dbus eudev

mkdir -p /data /run/s6/container_environment /tmp/.bashio /run/dbus /etc/NetworkManager/conf.d

# NM only manages devices announced by udev; run eudev in the container
udevd --daemon
udevadm trigger --action=add
udevadm settle

cat > /etc/NetworkManager/NetworkManager.conf <<'EOF'
[main]
plugins=keyfile
auth-polkit=false
dhcp=internal
no-auto-default=*
[keyfile]
unmanaged-devices=none
[logging]
level=INFO
EOF

dbus-daemon --system
NetworkManager
sleep 3
nmcli general status || { echo "NM did not start"; exit 1; }

# fake LAN: veth0 = wired NIC, veth1 = rest of LAN / gateway
ip link add veth0 type veth peer name veth1
ip link set veth1 up
ip addr add 10.9.8.1/24 dev veth1

# fake AP device
ip link add wlan0 type dummy

udevadm trigger --action=add
udevadm settle
sleep 2
nmcli device set veth0 managed yes
nmcli device set wlan0 managed yes 2>/dev/null || true
nmcli device status

# original wired profile, like "Supervisor end0" (static variant)
nmcli connection add type ethernet ifname veth0 con-name "Supervisor veth0" \
    ipv4.method manual ipv4.addresses 10.9.8.7/24 ipv4.gateway 10.9.8.1 \
    ipv6.method disabled connection.autoconnect yes
nmcli connection up "Supervisor veth0"
nmcli -t -f NAME,DEVICE connection show --active

printf '%s' '{"ssid":"TestNet","wpa_passphrase":"longenough","channel":6,"interface":"wlan0","lan_interface":"veth0","country_code":"HU","log_level":"debug"}' \
    > /tmp/.bashio/addons.self.options.config.cache

export HOTSPOT_TEST_SKIP_WIRELESS_CHECK=1
printf '1' > /run/s6/container_environment/HOTSPOT_TEST_SKIP_WIRELESS_CHECK
if /etc/s6-overlay/scripts/hotspot-init; then
    echo ">>> INIT OK"
else
    echo "!!! INIT FAILED"
    nmcli connection show
    nmcli device status
    exit 1
fi

echo "----- bridge state:"
nmcli -t -f NAME,DEVICE,STATE connection show --active
echo "----- host IP must be on the bridge:"
ip -4 addr show dev hotspot0 | grep inet || { echo "!!! no IP on hotspot0"; exit 1; }
ip route show default
echo "----- gateway ping through bridge:"
ping -c 2 -W 3 10.9.8.1 || { echo "!!! gateway unreachable"; exit 1; }
echo "----- NM connectivity check must be disabled (runtime):"
ccheck=$(dbus-send --system --print-reply \
    --dest=org.freedesktop.NetworkManager /org/freedesktop/NetworkManager \
    org.freedesktop.DBus.Properties.Get \
    string:org.freedesktop.NetworkManager string:ConnectivityCheckEnabled \
    | grep -o "boolean [a-z]*")
echo "ConnectivityCheckEnabled: ${ccheck}"
[ "${ccheck}" = "boolean false" ] && echo ">>> connectivity check disabled" \
    || { echo "!!! connectivity check still enabled"; exit 1; }
echo "----- original NM profile untouched (autoconnect must stay yes):"
[ "$(nmcli -g connection.autoconnect connection show 'Supervisor veth0')" = "yes" ] \
    && echo ">>> original profile intact" || { echo "!!! original profile modified"; exit 1; }
echo "----- wired iface released at runtime only (unmanaged):"
nmcli -t -f DEVICE,STATE device status | grep "^veth0:"
echo "----- generated hostapd.conf:"
grep -E "^(interface|bridge|ssid|hw_mode|channel)=" /run/hotspot/hostapd.conf
echo "----- /data/bridge-state.json:"
cat /data/bridge-state.json

echo "----- re-run: must take the fast path (no transition):"
/etc/s6-overlay/scripts/hotspot-init 2>&1 | grep -q "no network transition needed" \
    && echo ">>> fast path OK" || { echo "!!! fast path missing"; exit 1; }

echo "ALL BRIDGE TESTS PASSED"
