#!/bin/sh

if [ ! -f /etc/ocserv/data/server-key.pem ] || [ ! -f /etc/ocserv/data/server-cert.pem ]; then
	echo "Generating self signed server certificate"

	OCSERV_CA_CN=${OCSERV_CA_CN:-Root CA}
	OCSERV_CA_ORG=${OCSERV_CA_ORG:-CA Company}
	OCSERV_CA_DAYS=${OCSERV_CA_DAYS:-9999}
	OCSERV_HOST_CN=${OCSERV_HOST_CN:-www.example.com}
	OCSERV_HOST_ORG=${OCSERV_HOST_ORG:-My Company}
	OCSERV_HOST_DAYS=${OCSERV_HOST_DAYS:-9999}

	# No certification found, generate one
	cd /etc/ocserv/data
	certtool --generate-privkey --outfile ca-key.pem
	cat > /tmp/ca.tmpl <<-EOCA
	cn = "${OCSERV_CA_CN}"
	organization = "${OCSERV_CA_ORG}"
	serial = 1
	expiration_days = ${OCSERV_CA_DAYS}
	ca
	signing_key
	cert_signing_key
	crl_signing_key
	EOCA
	certtool --generate-self-signed --load-privkey ca-key.pem --template /tmp/ca.tmpl --outfile ca.pem
	certtool --generate-privkey --outfile server-key.pem
	cat > /tmp/server.tmpl <<-EOSRV
	cn = "${OCSERV_HOST_CN}"
	organization = "${OCSERV_HOST_ORG}"
	expiration_days = ${OCSERV_HOST_DAYS}
	signing_key
	encryption_key
	tls_www_server
	EOSRV
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem --template /tmp/server.tmpl --outfile server-cert.pem
fi

echo "Configuring ocserv"

OCSERV_TCP_PORT=${OCSERV_TCP_PORT:-443}
OCSERV_UDP_PORT=${OCSERV_UDP_PORT:-443}
OCSERV_MAX_CLIENTS=${OCSERV_MAX_CLIENTS:-10}
OCSERV_MAX_SAME_CLIENTS=${OCSERV_MAX_SAME_CLIENTS:-2}
OCSERV_DEFAULT_DOMAIN=${OCSERV_DEFAULT_DOMAIN:-example.com}
OCSERV_IPV4_NETWORK=${OCSERV_IPV4_NETWORK:-192.168.99.0/24}
OCSERV_DNS=${OCSERV_DNS:-}
OCSERV_ROUTES=${OCSERV_ROUTES:-}
OCSERV_NO_ROUTES=${OCSERV_NO_ROUTES:-}

if [[ -n "${OCSERV_DNS}" ]]; then
	OCSERV_DNS="dns = ${OCSERV_DNS}"
fi

cd /etc/ocserv
cp ocserv.conf.template ocserv.conf
sed -i "s|{{OCSERV_TCP_PORT}}|${OCSERV_TCP_PORT}|g" ocserv.conf
sed -i "s|{{OCSERV_UDP_PORT}}|${OCSERV_UDP_PORT}|g" ocserv.conf
sed -i "s|{{OCSERV_MAX_CLIENTS}}|${OCSERV_MAX_CLIENTS}|g" ocserv.conf
sed -i "s|{{OCSERV_MAX_SAME_CLIENTS}}|${OCSERV_MAX_SAME_CLIENTS}|g" ocserv.conf
sed -i "s|{{OCSERV_DEFAULT_DOMAIN}}|${OCSERV_DEFAULT_DOMAIN}|g" ocserv.conf
sed -i "s|{{OCSERV_IPV4_NETWORK}}|${OCSERV_IPV4_NETWORK}|g" ocserv.conf
sed -i "s|{{OCSERV_DNS}}|${OCSERV_DNS}|g" ocserv.conf

for ROUTE in $(echo ${OCSERV_ROUTES} | tr "," "\n"); do
	echo "route = ${ROUTE}" >> ocserv.conf
done

for NO_ROUTE in $(echo ${OCSERV_NO_ROUTES} | tr "," "\n"); do
	echo "no-route = ${NO_ROUTE}" >> ocserv.conf
done

echo "Configuring network"

# Open ipv4 ip forward
sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpennConnect Server
exec "$@"
