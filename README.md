# OpenVPN Setup on AWS


### Dependencies

Deploy any debian based images on AWS. Ubuntu is 18.04 LTS is a good choice.

```
sudo apt update -y
sudo apt upgrade -y
apt install openvpn easy-rsa -y
make-cadir ca
cd ca/
```

### Build the CA

need to copy custom vars to /home/ubuntu/ca/vars

vars file:

```
# These are the default values for fields
# which will be placed in the certificate.
# Don't leave any of these fields blank.
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="Fort-Funston"
export KEY_EMAIL="me@myhost.mydomain"
export KEY_OU="MyOrganizationalUnit"
```

Edit above to your need

``ln -s openssl-1.0.0.cnf openssl.cnf``

(not as root below)

```
source ./vars

./clean-all

./build-key-server server

./build-dh

./build-key client1 (no password) or ./build-key-pass client1 (with password)
```


Move required keys to openvpn config via...

```
cp keys/server.crt /etc/openvpn/
cp keys/server.key /etc/openvpn/
cp keys/ca.crt /etc/openvpn/
cp keys/dh2048.pem /etc/openvpn/
```

### OpenVPN Server Configurations

Edit the server.conf with the following

```
local [ip or hostname.com] <-- in aws, its the LOCAL PUBLIC IP

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 208.67.222.222"
push "dhcp-option DNS 208.67.220.220"

user nobody
group nogroup

log-append /var/log/openvpn/openvpn.log

#Enable HMAC
auth SHA256
```

Generate TLS key via...

```openvpn --genkey --secret /etc/openvpn/ta.key```


(may need to reboot before getting this to work)

```
systemctl start openvpn@server
systemctl status openvpn@server
```

If there is a problem with starting the service, check the logs are ``/var/log/openvpn/openvpn.log``

Allow ip forwarding via...

```
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/local.conf
sysctl --system
```

(check with ``ip route``)

Make iptables changes

```
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -i tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.0/24 -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -j REJECT
```

Make them persist

``apt install iptables-persistent``


Generate Client Profiles (.ovpn Files)

```
mkdir ca/clientprofiles && cd ca/
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf clientprofiles/client1.ovpn
```

### Build Client Profiles

Edit the config as following:

```
remote my-server-1 1194 with ...
remote 203.0.113.2 1194
```

Find the following

```
ca ca.crt
cert client.crt
key client.key
```

and comment them out to

```
;ca ca.crt
;cert client.crt
;key client.key
```

Add HMAC to client profile

```
#Enable HMAC
auth SHA256
```

Copy the correct client keys, certificates, and CA certificate to the profile

```
echo "<key>
`cat keys/client1.key`
</key>" >> clientprofiles/client1.ovpn

echo "<cert>
`cat keys/client1.crt`
</cert>"  >> clientprofiles/client1.ovpn

echo "<ca>
`cat keys/ca.crt`
</ca>" >> clientprofiles/client1.ovpn

echo "<tls-auth>
`cat /etc/openvpn/ta.key`
</tls-auth>" >> clientprofiles/client1.ovpn
```

Download the client ovpn profile to your machine.

You may need to copy the ta.key to the local client.


