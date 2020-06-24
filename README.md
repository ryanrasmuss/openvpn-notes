# OpenVPN Setup on AWS


### Dependencies

Deploy any debian based images on AWS. Ubuntu is 18.04 LTS is a good choice and will be used in this guide.

```
sudo apt update -y
sudo apt upgrade -y
apt install openvpn easy-rsa -y
make-cadir ca
cd ca/
```

### Build the CA

Edit ``/home/ubuntu/ca/vars`` to your liking (see below):

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

Now link the openssl config

``ln -s openssl-1.0.0.cnf openssl.cnf``

Source the vars file: ``source vars``

Clean the environment: ``./clean-all``

Generate the certificate authority: ``./build-ca``

### Generate Server and Client Certificate and Keys

Build server keys: ``./build-key-server server``

Generate Diffie-Hellman parameters: ``./build-dh``

**Two ways to generate client certificates**

1. No password: ./build-key client1

2. Password: ./build-key-pass client1

**Copy our keys and certs to the appropriate directory**

```
cp keys/server.crt /etc/openvpn/
cp keys/server.key /etc/openvpn/
cp keys/ca.crt /etc/openvpn/
cp keys/dh2048.pem /etc/openvpn/
```

### OpenVPN Server Configurations

Copy the pre-built config file from OpenVPN: ``zcat /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > /etc/openvpn/server.conf``


Edit the ``/etc/openvpn/server.conf`` with the following

Mostly the edits should be uncommenting, adding IP to local, and adding HMAC.

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

Start the OpenVPN service (may need to reboot before getting this to work)

```
systemctl start openvpn@server
systemctl status openvpn@server
```

If there is a problem with starting the service, check the logs are ``/var/log/openvpn/openvpn.log``


### Setting up routing


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


### Generate Client Profiles (.ovpn Files)

```
mkdir ca/clientprofiles && cd ca/
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf clientprofiles/client1.ovpn
```

### Configure Client Profiles

Edit the config with your server IP as following:

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

### What needs to be saved for automation

```
/etc/openvpn/server.conf
/etc/openvpn/ca.crt
/etc/openvpn/dh2048.pem
/etc/openvpn/server.crt
/etc/openvpn/server.key
/etc/openvpn/ta.key

client1.ovpn
ta.key

script to do...

ip forwarding
iptables
systemctl openvpn@server
```

Will need to edit openserver's configuration file to local [new ip] and the client file as well.

### Logs

``/var/log/openvpn/openvpn-status.log`` list connected users with: name,ip,bytes,recv,sent,connected-since

``/var/log/openvpn/openvpn.log`` contains system logs from openvpn server

``/var/log/openvpn/ipp.txt`` lists addresses assigned to vpn users (office mode essentially)
