#!/bin/bash
apt update
myip=$(hostname -I | awk '{print $1}')
apt install strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins -y

# Создаем резервную копию файла настроек
mv /etc/ipsec.conf{,.original}

# Настраиваем конфигурацию IPsec для использования PSK
cat << EOF > /etc/ipsec.conf
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    authby=secret
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
    ike=chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024,aes256-sha256-modp2048!
    esp=chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1!
EOF

# Настраиваем PSK в файле /etc/ipsec.secrets
cat << EOF > /etc/ipsec.secrets
# Формат: leftid : PSK "shared_secret"
$myip : PSK "vpn37300593000"
EOF

ufw allow OpenSSH
ufw enable
ufw allow 500/udp
ufw allow 4500/udp

# Замените ens192 на ваш сетевой интерфейс
interface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
cat << EOF > /etc/ufw/before.rules
*nat
-A POSTROUTING -s 10.10.10.0/24 -o $interface -m policy --pol ipsec --dir out -j ACCEPT
-A POSTROUTING -s 10.10.10.0/24 -o $interface -j MASQUERADE                             
COMMIT

*mangle
-A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o $interface -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
COMMIT

*filter
-A ufw-before-forward --match policy --pol ipsec --dir in --proto esp -s 10.10.10.0/24 -j ACCEPT
-A ufw-before-forward --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT
COMMIT
EOF

cat << EOF >> /etc/ufw/sysctl.conf
net/ipv4/ip_forward=1
net/ipv4/conf/all/accept_redirects=0
net/ipv4/conf/all/send_redirects=0
net/ipv4/ip_no_pmtu_disc=1
EOF

ufw disable
ufw enable
