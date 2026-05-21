#!/usr/bin/bash
# Wait for tun0 address to become available and bind microsocks egress to it.
while true; do
	IP=$(ip -4 -o addr show dev tun0 2>/dev/null | awk '{print $4}' | sed "s|/.*||" | head -n1)
	if [ "x$IP" != "x" ]; then
		echo "Starting SOCKS5 proxy on 0.0.0.0:1080 with VPN egress $IP"
		exec /usr/bin/microsocks -i 0.0.0.0 -p 1080 -b "$IP"
	fi
	echo "Waiting for VPN to become ready"
	sleep 1
done
