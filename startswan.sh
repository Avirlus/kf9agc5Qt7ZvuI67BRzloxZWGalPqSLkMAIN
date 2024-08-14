#!/bin/bash

# Обновление списка пакетов и установка strongSwan
sudo apt update
sudo apt install -y strongswan

# Включение пересылки пакетов в ядре[^1^][1]
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
sudo sysctl -p

# Настройка конфигурации ipsec.conf
sudo cp /etc/ipsec.conf /etc/ipsec.conf.orig
sudo bash -c 'cat > /etc/ipsec.conf <<EOF
config setup
    charondebug="all"
    uniqueids=yes

conn myvpn
    type=tunnel
    auto=start
    keyexchange=ikev2
    authby=secret
    left=%defaultroute
    leftsubnet=0.0.0.0/0
    right=%any
    rightsubnet=0.0.0.0/0
    ike=aes256-sha1-modp1024!
    esp=aes256-sha1!
    dpddelay=30s
    dpdtimeout=120s
    dpdaction=restart
EOF'

# Настройка PSK
sudo bash -c 'cat > /etc/ipsec.secrets <<EOF
: PSK "vpn"
EOF'

# Перезапуск службы strongSwan
sudo systemctl restart strongswan

echo "VPN настроен и готов к использованию."
