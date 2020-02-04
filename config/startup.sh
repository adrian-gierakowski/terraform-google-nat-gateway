#!/bin/bash -xe

# Enable ip forwarding and nat
sysctl -w net.ipv4.ip_forward=1

# Make forwarding persistent.
sed -i= 's/^[# ]*net.ipv4.ip_forward=[[:digit:]]/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

apt-get update

# Install nginx for instance http health check
apt-get install -y nginx

ENABLE_SQUID="${squid_enabled}"

if [[ "$$ENABLE_SQUID" == "true" ]]; then
  apt-get install -y squid3

  cat - > /etc/squid/squid.conf <<'EOM'
${file("${squid_config == "" ? "${format("%s/config/squid.conf", module_path)}" : squid_config}")}
EOM

  systemctl reload squid
fi

# Install debug utils
ENABLE_DEBUG_UTILS="${debug_utils_enabled}"

if [[ "$$ENABLE_DEBUG_UTILS" == "true" ]]; then
  apt-get install -y dnsutils traceroute
fi