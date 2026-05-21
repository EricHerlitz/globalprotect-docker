#!/usr/bin/bash
set -u

# Keep replies for Docker-published inbound services on the Docker interface.
#
# openconnect may replace the container default route with the VPN tunnel. When
# clients connect to the host's eth0 address and Docker DNATs that traffic into
# the container, replies from the container's Docker-facing address must still
# leave through eth0. Otherwise the replies can be routed into tun0 and the
# client connection times out.

IFACE="${DOCKER_EGRESS_IFACE:-eth0}"
TABLE="${DOCKER_EGRESS_TABLE:-100}"
PRIORITY="${DOCKER_EGRESS_PRIORITY:-100}"

log() {
	echo "docker-egress-route: $*"
}

get_iface_ip() {
	ip -4 -o addr show dev "$IFACE" scope global 2>/dev/null | awk '{print $4}' | sed 's|/.*||' | head -n1
}

get_iface_cidr() {
	ip -4 -o addr show dev "$IFACE" scope global 2>/dev/null | awk '{print $4}' | head -n1
}

get_default_gateway() {
	ip -4 route show default dev "$IFACE" 2>/dev/null | awk '/default/ {print $3; exit}'
}

derive_docker_gateway() {
	# Docker bridge networks normally use the first address in the subnet as the
	# gateway. This fallback keeps the script useful even if openconnect has
	# already removed the original eth0 default route before this script starts.
	local ip_addr="$1"
	awk -F. '{print $1"."$2"."$3".1"}' <<< "$ip_addr"
}

wait_for_eth0() {
	local ip_addr=""
	while [ -z "$ip_addr" ]; do
		ip_addr="$(get_iface_ip)"
		if [ -z "$ip_addr" ]; then
			log "waiting for $IFACE IPv4 address"
			sleep 1
		fi
	done
}

ensure_policy_route() {
	local ip_addr cidr gateway network

	ip_addr="$(get_iface_ip)"
	cidr="$(get_iface_cidr)"
	gateway="$(get_default_gateway)"
	if [ -z "$gateway" ]; then
		gateway="$(derive_docker_gateway "$ip_addr")"
	fi

	if [ -z "$ip_addr" ] || [ -z "$cidr" ] || [ -z "$gateway" ]; then
		log "cannot configure policy route yet: ip='$ip_addr' cidr='$cidr' gateway='$gateway'"
		return 1
	fi

	network="$(ip -4 route show dev "$IFACE" scope link 2>/dev/null | awk 'NR == 1 {print $1}')"
	if [ -n "$network" ]; then
		ip route replace table "$TABLE" "$network" dev "$IFACE" src "$ip_addr" 2>/dev/null || true
	fi
	ip route replace table "$TABLE" default via "$gateway" dev "$IFACE" src "$ip_addr"

	if ! ip rule show | grep -q "from $ip_addr lookup $TABLE"; then
		ip rule add priority "$PRIORITY" from "$ip_addr/32" table "$TABLE"
	fi

	ip route flush cache 2>/dev/null || true
	log "ensured replies from $ip_addr use $IFACE via $gateway in table $TABLE"
}

wait_for_eth0

while true; do
	ensure_policy_route || true
	sleep 10
done
