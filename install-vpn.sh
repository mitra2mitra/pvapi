#!/bin/bash

# تنظیمات اولیه
WG_PORT=49321
WG_INTERFACE="wg0"
WG_SERVER_IP="10.66.66.1/24"
DOMAIN_NAME="finapi.amirnick.at"

# نصب پیش‌نیازها
apt update && apt install -y wireguard qrencode curl

# تولید کلیدهای سرور
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIVATE=$(cat server_private.key)
SERVER_PUBLIC=$(cat server_public.key)

# تعریف کلاینت‌ها: نام:آدرس_IP
CLIENTS=(
  "Bijanguard:10.66.66.2/32"
  "Mohsenguard:10.66.66.3/32"
)

# پیکربندی سرور WireGuard
cat > /etc/wireguard/${WG_INTERFACE}.conf <<EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE}
Address = ${WG_SERVER_IP}
ListenPort = ${WG_PORT}
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

# ایجاد و افزودن کلاینت‌ها
for entry in "${CLIENTS[@]}"; do
  NAME=${entry%%:*}
  IP=${entry##*:}
  wg genkey | tee ${NAME}_private.key | wg pubkey > ${NAME}_public.key
  PRIV_KEY=$(cat ${NAME}_private.key)
  PUB_KEY=$(cat ${NAME}_public.key)

  # افزودن Peer به سرور
  cat >> /etc/wireguard/${WG_INTERFACE}.conf <<EOF

[Peer]
PublicKey = ${PUB_KEY}
AllowedIPs = ${IP}
EOF

  # ساخت کانفیگ کلاینت
  cat > /root/${NAME}.conf <<EOF
[Interface]
PrivateKey = ${PRIV_KEY}
Address = ${IP}
DNS = ${WG_SERVER_IP%/*}

[Peer]
PublicKey = ${SERVER_PUBLIC}
Endpoint = ${DOMAIN_NAME}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

done

# فعال‌سازی IP Forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# فعال و راه‌اندازی WireGuard
systemctl enable wg-quick@${WG_INTERFACE}
systemctl start wg-quick@${WG_INTERFACE}

# نصب AdGuard Home
cd /opt
curl -sL https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz | tar xz
cd AdGuardHome
./AdGuardHome -s install

# راه‌اندازی مجدد AdGuard Home
systemctl restart AdGuardHome

echo "[✓] نصب کامل شد. فایل‌های کانفیگ کلاینت در /root قرار دارند."
