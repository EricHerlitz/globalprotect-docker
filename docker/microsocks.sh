#!/usr/bin/bash
# Wait for tun0 address to become available and bind microsocks egress to it.

STATIC_ROUTES="${DOCKER_STATIC_ROUTES:-}"
SOCKS_PORT="${MICROSOCKS_PORT:-1080}"

log() {
	echo "microsocks: $*"
}

ensure_static_routes() {
	local route

	if [ -z "$STATIC_ROUTES" ]; then
		return 0
	fi

	# Configure one or more plain ip-route fragments separated by semicolons.
	# Example:
	#   DOCKER_STATIC_ROUTES="10.11.0.0/16 via 172.19.0.1 dev eth0;192.168.1.0/24 via 172.19.0.1 dev eth0"
	IFS=';' read -ra routes <<< "$STATIC_ROUTES"
	for route in "${routes[@]}"; do
		# Trim leading/trailing whitespace.
		route="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$route")"
		if [ -z "$route" ]; then
			continue
		fi

		# Intentionally allow word splitting here because the value is an ip route
		# argument fragment, not a single shell word.
		# shellcheck disable=SC2086
		if ip route replace $route; then
			log "ensured static route after SOCKS startup: $route"
		else
			log "failed to configure static route after SOCKS startup: $route"
		fi
	done
}

wait_for_microsocks() {
	local microsocks_pid="$1"

	while kill -0 "$microsocks_pid" 2>/dev/null; do
		if ss -ltn "sport = :$SOCKS_PORT" | grep -q ":$SOCKS_PORT"; then
			return 0
		fi
		log "waiting for SOCKS listener on 0.0.0.0:$SOCKS_PORT"
		sleep 1
	done

	return 1
}

while true; do
	IP=$(ip -4 -o addr show dev tun0 2>/dev/null | awk '{print $4}' | sed "s|/.*||" | head -n1)
	if [ "x$IP" != "x" ]; then
		log "starting SOCKS5 proxy on 0.0.0.0:$SOCKS_PORT with VPN egress $IP"
		/usr/bin/microsocks -i 0.0.0.0 -p "$SOCKS_PORT" -b "$IP" &
		MICROSOCKS_PID="$!"

		if wait_for_microsocks "$MICROSOCKS_PID"; then
			ensure_static_routes
		fi

		wait "$MICROSOCKS_PID"
		exit "$?"
	fi
	log "waiting for VPN to become ready"
	sleep 1
done
