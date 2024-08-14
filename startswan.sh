#!/bin/bash

# Обновляем список пакетов и устанавливаем необходимые зависимости
apt-get update
apt-get install -y strongswan strongswan-pki libcharon-extra-plugins

# Создаём конфигурационный файл для strongSwan
cat > /etc/ipsec.conf <<EOF
config setup
    charondebug="ike 2, knl 2, cfg 2"

conn %default
    keyexchange=ikev1
    authby=secret
    left=%any
    leftid=195.133.39.85
    leftsubnet=0.0.0.0/0
    right=%any
    rightsourceip=10.10.10.0/24

conn IPSec-IKEv1
    keyexchange=ikev1
    ike=aes256-sha1-modp1024!
    esp=aes256-sha1!
    ikelifetime=24h
    lifetime=24h
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%defaultroute
    leftfirewall=yes
    right=%any
    rightsubnet=0.0.0.0/0
    rightsourceip=10.10.10.0/24
    auto=add
EOF

# Создаём файл с общим ключом
cat > /etc/ipsec.secrets <<EOF
: PSK "vpn373"
EOF

# Включаем переадресацию IPv4
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Настраиваем правила фаервола для NAT
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o aes192 -j MASQUERADE
iptables-save > /etc/iptables.rules

# Устанавливаем сохранение правил при перезагрузке
cat > /etc/network/if-pre-up.d/iptables <<EOF
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF

chmod +x /etc/network/if-pre-up.d/iptables

# Перезапускаем strongSwan для применения конфигураций
systemctl restart strongswan

echo "Настройка завершена. VPN сервер готов к использованию."
