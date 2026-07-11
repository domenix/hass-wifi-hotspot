#!/bin/sh
# Functional test of hotspot-init v2 (bridge mode) inside a privileged
# container. The bridge transition itself needs a live NetworkManager, so
# these tests cover the validation layer and the NM-availability guard:
# every misconfiguration must be rejected BEFORE any network mutation, and
# a valid config must stop at the "cannot talk to NetworkManager" guard
# (proving nothing network-mutating runs without NM present).

mkdir -p /data /run/s6/container_environment /tmp/.bashio

ip link add wlan0 type dummy
UPLINK_REAL=$(ip -4 route show default | awk '{ for (i=1; i<NF; i++) if ($i == "dev") { print $(i+1); exit } }')
echo "container uplink: ${UPLINK_REAL}"

mount -t tmpfs tmpfs /sys/class/net
mkdir -p /sys/class/net/wlan0/wireless "/sys/class/net/${UPLINK_REAL}"

seed() {
    printf '%s' "$1" > /tmp/.bashio/addons.self.options.config.cache
}

fail=0

expect_fail() {
    name="$1"; opts="$2"; want="$3"
    echo "=========== EXPECT-FAIL: ${name}"
    seed "${opts}"
    if /etc/s6-overlay/scripts/hotspot-init > /tmp/out.log 2>&1; then
        echo "!!! ${name} UNEXPECTEDLY PASSED"; fail=1
    elif ! grep -q "${want}" /tmp/out.log; then
        echo "!!! ${name} failed with the WRONG error:"; tail -3 /tmp/out.log; fail=1
    else
        grep -E "ERROR|FATAL" /tmp/out.log | tail -1
        echo ">>> failed as expected"
    fi
}

expect_fail short-pass \
    '{"ssid":"TestNet","wpa_passphrase":"short","channel":6,"interface":"wlan0","lan_interface":"","country_code":"HU","log_level":"info"}' \
    "wpa_passphrase"
expect_fail bad-channel \
    '{"ssid":"TestNet","wpa_passphrase":"longenough","channel":52,"interface":"wlan0","lan_interface":"","country_code":"HU","log_level":"info"}' \
    "channel"
expect_fail ssid-too-long \
    '{"ssid":"123456789012345678901234567890123","wpa_passphrase":"longenough","channel":6,"interface":"wlan0","lan_interface":"","country_code":"HU","log_level":"info"}' \
    "ssid"
expect_fail no-such-iface \
    '{"ssid":"TestNet","wpa_passphrase":"longenough","channel":6,"interface":"wlan9","lan_interface":"","country_code":"HU","log_level":"info"}' \
    "does not exist"
expect_fail lan-iface-missing \
    '{"ssid":"TestNet","wpa_passphrase":"longenough","channel":6,"interface":"wlan0","lan_interface":"nope0","country_code":"HU","log_level":"info"}' \
    "does not exist"
expect_fail lan-iface-wireless \
    '{"ssid":"TestNet","wpa_passphrase":"longenough","channel":6,"interface":"wlan0","lan_interface":"wlan0","country_code":"HU","log_level":"info"}' \
    "wireless"

# Valid config in a container without NetworkManager: must stop at the NM
# guard, BEFORE creating bridges or touching interfaces.
echo "=========== EXPECT-FAIL: valid config, no NetworkManager"
seed "{\"ssid\":\"TestNet\",\"wpa_passphrase\":\"longenough\",\"channel\":6,\"interface\":\"wlan0\",\"lan_interface\":\"${UPLINK_REAL}\",\"country_code\":\"HU\",\"log_level\":\"info\"}"
if /etc/s6-overlay/scripts/hotspot-init > /tmp/out.log 2>&1; then
    echo "!!! ran without NetworkManager"; fail=1
elif grep -q "NetworkManager" /tmp/out.log; then
    grep FATAL /tmp/out.log | tail -1
    if ip link show br0 > /dev/null 2>&1; then
        echo "!!! bridge was created despite NM guard"; fail=1
    else
        echo ">>> stopped at NM guard, no network mutation"
    fi
else
    echo "!!! wrong failure:"; tail -3 /tmp/out.log; fail=1
fi

# Teardown with no state file must be a no-op success.
echo "=========== EXPECT-OK: teardown without state"
if /etc/s6-overlay/scripts/hotspot-down; then echo ">>> down OK"; else echo "!!! down FAILED"; fail=1; fi

[ "$fail" -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $fail
