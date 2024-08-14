#!/bin/bash

# Шаг 1 — Обновляем ОС нашего сервера
sudo apt update && sudo apt upgrade -y

# Шаг 2 — Установка StrongSwan
sudo apt-get install -y strongswan

# Шаг 3 — Установка xl2tpd
sudo apt-get install -y xl2tpd

# Шаг 4 — Настройка StrongSwan (IPsec)
sudo bash -c 'cat > /etc/ipsec.conf <<EOF
config setup 
 nat_traversal=yes 
 virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12 
 oe=off 
 protostack=netkey 

conn L2TP-PSK-NAT 
 rightsubnet=vhost:%priv 
 also=L2TP-PSK-noNAT 

conn L2TP-PSK-noNAT 
 authby=secret 
 pfs=no 
 auto=add 
 keyingtries=3 
 rekey=no 
 ikelifetime=8h 
 keylife=1h 
 type=transport 
 left=195.133.39.85 
 leftprotoport=17/1701 
 right=%any 
 rightprotoport=17/%any
EOF'

# Напоминание: Не забудьте сменить 'VASH_IP_SERVERA' на реальный IP вашего сервера.

# Шаг 5 — Генерируем надежный общий ключ
PSK=$(openssl rand -base64 30)
echo "Сгенерированный общий ключ: $PSK"

# Шаг 6 — Используем сгенерированный общий ключ для IPsec PSK
sudo bash -c "echo '195.133.39.85 %any : PSK \"$PSK\"' > /etc/ipsec.secrets"

# Напоминание: Не забудьте сменить 'VASH_IP_SERVERA' на реальный IP вашего сервера.

# Шаг 7 — Настраиваем фаервол сервера на передачу IP-пакетов
sudo bash -c 'cat > /usr/local/bin/ipsec <<EOF
#!/bin/bash
iptables --table nat --append POSTROUTING --jump MASQUERADE 
echo 1 > /proc/sys/net/ipv4/ip_forward 
for each in /proc/sys/net/ipv4/conf/* 
do 
  echo 0 > \$each/accept_redirects 
  echo 0 > \$each/send_redirects 
done 
/etc/init.d/ipsec restart
EOF'

# Делаем файл исполняемым
sudo chmod +x /usr/local/bin/ipsec

# Шаг 8 — Включаем rc.local для исполнения скриптов
sudo bash -c 'cat > /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF'

sudo bash -c 'cat > /etc/rc.local <<EOF
#!/bin/sh -ee
/usr/local/bin/ipsec 
exit 0
EOF'

# Делаем файл исполняемым
sudo chmod +x /etc/rc.local

# Шаг 9 — Включаем rc.local для исполнения скриптов
sudo systemctl enable rc-local

# Шаг 10 — Настраиваем L2TP
sudo bash -c 'cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
ipsec saref = yes

[lns default]
ip range = 10.1.2.2-10.1.2.255
local ip = 10.1.2.1 
refuse chap = yes 
refuse pap = yes 
require authentication = yes 
ppp debug = yes 
pppoptfile = /etc/ppp/options.xl2tpd 
length bit = yes
EOF'

# Шаг 11 — Настраиваем службу авторизации PPP
sudo bash -c 'cat > /etc/ppp/options.xl2tpd <<EOF
require-mschap-v2 
ms-dns 8.8.8.8 
ms-dns 8.8.4.4 
asyncmap 0 
auth 
crtscts 
lock 
hide-password 
modem 
debug 
name AVIRVPN 
proxyarp 
lcp-echo-interval 30 
lcp-echo-failure 4
EOF'

# Шаг 12 — Создаем пароли и логины для пользователей VPN
sudo bash -c 'cat >> /etc/ppp/chap-secrets <<EOF
Avirlusik AVIRVPN Avirlusik37300593000 *
EOF'

# Шаг 13 — Производим рестарт всех настроенных сервисов и служб
sudo systemctl enable ipsec
sudo systemctl restart ipsec

sudo systemctl enable xl2tpd
sudo systemctl restart xl2tpd

sudo systemctl enable strongswan-starter
sudo systemctl restart strongswan-starter

echo "Скрипт завершён. Убедитесь, что вы заменили все необходимые параметры на реальные значения."
