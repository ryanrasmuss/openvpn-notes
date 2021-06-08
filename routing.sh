#!/bin/bash

if [ $(id -u) != 0 ]; then
  printf "\e[1;41mHi! Please run as root!\e[0m🇺🇦\n"
  exit 1
fi

# allow for ip forwarding on server
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/local.conf
sysctl --system

# set rules for vpn traffic
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -i tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.0/24 -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -j REJECT

# install iptables save tool
apt install iptables-persistent

# save our iptables config
/sbin/iptables-save > /etc/iptables/rules.v4

# check that it makes sense
cat /etc/iptables/rules.v4
