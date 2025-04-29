#!/usr/bin/env bash

set -e

DB="/etc/sing-box/protocols.db"
CERT_DIR="/etc/sing-box/cert"
CONFIG="/etc/sing-box/config.json"
DOMAIN_FILE="/etc/sing-box/domain.txt"

mkdir -p /etc/sing-box

# Helper: Generate UUID
gen_uuid() { cat /proc/sys/kernel/random/uuid; }

# Helper: Prompt with default
prompt() {
  local msg="$1"
  local def="$2"
  read -p "$msg [$def]: " val
  echo "${val:-$def}"
}

# Helper: Green title
green_title() {
  echo -e "\033[32m\033[01m$1\033[0m"
}

# Automatic: System-wide disable IPv6
disable_ipv6() {
  echo "Disabling IPv6 system-wide for maximum privacy..."
  grep -q disable_ipv6 /etc/sysctl.conf || cat >> /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
  sysctl -p
  echo "IPv6 disabled. (Reboot may be required for full effect.)"
}

disable_ipv6

# Prevent duplicate protocol/port entries
protocol_exists() {
  local proto="$1"
  local port="$2"
  grep -q "^$proto|$port" "$DB" 2>/dev/null
}

# Add protocol to database
add_protocol() {
  echo "Select protocol to add:"
  echo "1. SOCKS5"
  echo "2. Shadowsocks"
  echo "3. Vmess"
  echo "4. VLESS"
  echo "5. Trojan"
  echo "6. Hysteria2"
  read -p "> " idx

  # Flag to track if a new protocol was added
  local protocol_added=false

  case $idx in
    1)
      port=$(prompt "SOCKS5 port" "1080")
      if protocol_exists "SOCKS5" "$port"; then
        echo "SOCKS5 on port $port already exists."
      else
        echo "SOCKS5|$port" >> $DB
        echo "Added SOCKS5 on port $port."
        protocol_added=true
      fi
      ;;
    2)
      port=$(prompt "Shadowsocks port" "8388")
      if protocol_exists "SS" "$port"; then
        echo "Shadowsocks on port $port already exists."
      else
        pass=$(prompt "Shadowsocks password" "sspass$(date +%s)")
        echo "SS|$port|$pass" >> $DB
        echo "Added Shadowsocks on port $port."
        protocol_added=true
      fi
      ;;
    3)
      port=$(prompt "Vmess port" "10086")
      if protocol_exists "VMESS" "$port"; then
        echo "Vmess on port $port already exists."
      else
        uuid=$(prompt "Vmess UUID" "$(gen_uuid)")
        ws=$(prompt "Vmess use WebSocket? (y/n)" "n")
        if [[ "$ws" =~ ^[Yy]$ ]]; then
          ws_path=$(prompt "Vmess WebSocket path" "/vmessws")
          tls=$(prompt "Vmess use TLS? (y/n)" "n")
          echo "VMESS|$port|$uuid|$ws|$ws_path|$tls" >> $DB
        else
          echo "VMESS|$port|$uuid|n" >> $DB
        fi
        echo "Added Vmess on port $port."
        protocol_added=true
      fi
      ;;
    4)
      port=$(prompt "VLESS port" "10010")
      if protocol_exists "VLESS" "$port"; then
        echo "VLESS on port $port already exists."
      else
        uuid=$(prompt "VLESS UUID" "$(gen_uuid)")
        ws=$(prompt "VLESS use WebSocket? (y/n)" "y")
        ws_path=$(prompt "VLESS WebSocket path" "/vlessws")
        tls=$(prompt "VLESS use TLS? (y/n)" "y")
        echo "VLESS|$port|$uuid|$ws|$ws_path|$tls" >> $DB
        echo "Added VLESS on port $port (WebSocket+TLS)."
        protocol_added=true
      fi
      ;;
    5)
      port=$(prompt "Trojan port" "4443")
      if protocol_exists "TROJAN" "$port"; then
        echo "Trojan on port $port already exists."
      else
        pass=$(prompt "Trojan password" "trojanpass$(date +%s)")
        echo "TROJAN|$port|$pass|y" >> $DB
        echo "Added Trojan on port $port (TLS always enabled)."
        protocol_added=true
      fi
      ;;
    6)
      port=$(prompt "Hysteria2 port" "5678")
      if protocol_exists "HYSTERIA2" "$port"; then
        echo "Hysteria2 on port $port already exists."
      else
        pass=$(prompt "Hysteria2 password" "hypass$(date +%s)")
        tls=$(prompt "Hysteria2 use TLS? (y/n)" "y")
        echo "HYSTERIA2|$port|$pass|$tls" >> $DB
        echo "Added Hysteria2 on port $port."
        protocol_added=true
      fi
      ;;
  esac

  # If a new protocol was added, automatically generate config
  if [ "$protocol_added" = true ]; then
    echo "New protocol added. Generating configuration..."
    generate_config
  fi
}

# Remove protocol from database
remove_protocol() {
  show_protocols
  read -p "Enter the protocol line number to remove: " lineno
  if [[ "$lineno" =~ ^[0-9]+$ ]]; then
    sed -i "${lineno}d" $DB
    echo "Protocol removed."
    echo "Regenerating configuration..."
    generate_config
  else
    echo "Invalid input."
  fi
}

# Show all enabled protocols
show_protocols() {
  green_title "Enabled protocols:"
  if [[ ! -s $DB ]]; then
    echo "No protocols enabled."
  else
    nl -w2 -s'. ' $DB
  fi
}

# Remove config.json and disable sing-box
remove_config() {
  echo "Removing $CONFIG and disabling sing-box..."
  rm -f $CONFIG
  systemctl stop sing-box 2>/dev/null || true
  systemctl disable sing-box 2>/dev/null || true
  echo "Config removed and sing-box disabled."
}

# Generate config from database
generate_config() {
  if [[ ! -s $DB ]]; then
    echo "No protocols enabled. Please add at least one protocol first."
    return
  fi

  # Check if any protocol needs TLS
  NEED_TLS=false
  while IFS="|" read -r proto port arg1 arg2 arg3 arg4; do
    case $proto in
      VMESS|VLESS|TROJAN|HYSTERIA2)
        if [[ "$arg4" =~ ^[Yy]$ ]] || [[ "$arg3" =~ ^[Yy]$ ]]; then
          NEED_TLS=true
        fi
        ;;
    esac
  done < $DB

  if $NEED_TLS; then
    DOMAIN=$(prompt "Enter your domain (must point to this VPS for TLS)" "your.domain.com")
    echo "$DOMAIN" > $DOMAIN_FILE
    echo "Obtaining free TLS certificate for $DOMAIN using Let's Encrypt ..."
    apt update && apt install -y socat curl
    mkdir -p $CERT_DIR
    if ! command -v acme.sh &>/dev/null; then
      curl https://get.acme.sh | sh
      export PATH="$HOME/.acme.sh":$PATH
    fi
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if ! ~/.acme.sh/acme.sh --issue --standalone -d $DOMAIN --force; then
      echo "Let's Encrypt failed or rate-limited. Generating a self-signed certificate for testing..."
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout $CERT_DIR/private.key \
        -out $CERT_DIR/cert.pem \
        -subj "/CN=$DOMAIN"
      echo "Self-signed certificate generated at $CERT_DIR/"
    else
      ~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
        --key-file $CERT_DIR/private.key \
        --fullchain-file $CERT_DIR/cert.pem
      echo "TLS certificate installed at $CERT_DIR/"
    fi
  fi

  # Open firewall ports
  echo "Opening firewall ports..."
  apt install -y ufw
  while IFS="|" read -r proto port _; do
    ufw allow "$port"
  done < $DB
  ufw allow 80
  ufw allow 443
  ufw reload

  # Generate config (listen only on IPv4)
  echo "Generating $CONFIG ..."
  cat > $CONFIG <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
EOF
  FIRST=true
  while IFS="|" read -r proto port arg1 arg2 arg3 arg4; do
    [[ "$FIRST" == "true" ]] && FIRST=false || echo "," >> $CONFIG
    case $proto in
      SOCKS5)
        echo "    { \"type\": \"socks\", \"listen\": \"0.0.0.0\", \"listen_port\": $port }" >> $CONFIG
        ;;
      SS)
        echo "    { \"type\": \"shadowsocks\", \"listen\": \"0.0.0.0\", \"listen_port\": $port, \"method\": \"aes-128-gcm\", \"password\": \"$arg1\" }" >> $CONFIG
        ;;
      VMESS)
        if [[ "$arg2" =~ ^[Yy]$ ]]; then
          if [[ "$arg4" =~ ^[Yy]$ ]]; then
            echo "    { \"type\": \"vmess\", \"listen\": \"0.0.0.0\", \"listen_port\": $port, \"users\": [{ \"uuid\": \"$arg1\" }], \"transport\": { \"type\": \"ws\", \"path\": \"$arg3\" }, \"tls\": { \"enabled\": true, \"certificate_path\": \"$CERT_DIR/cert.pem\", \"key_path\": \"$CERT_DIR/private.key\" } }" >> $CONFIG
          else
            echo "    { \"type\": \"vmess\", \"listen\": \"0.0.0.0\", \"listen_port\": $port, \"users\": [{ \"uuid\": \"$arg1\" }], \"transport\": { \"type\": \"ws\", \"path\": \"$arg3\" } }" >> $CONFIG
          fi
        else
          echo "    { \"type\": \"vmess\", \"listen\": \"0.0.0.0\", \"listen_port\": $port, \"users\": [{ \"uuid\": \"$arg1\" }] }" >> $CONFIG
        fi
        ;;
      VLESS)
        # Always use ws+tls for VLESS in export and config
        echo "    { \"type\": \"vless\", \"listen\": \"0.0.0.0\", \"listen_port\": $port, \"users\": [{ \"uuid\": \"$arg1\" }], \"transport\": { \"type\": \"ws\", \"path\": \"$arg3\" }, \"tls\": { \"enabled\": true, \"certificate_path\": \"$CERT_DIR/cert.pem\", \"key_path\": \"$CERT_DIR/private.key\" } }" >> $CONFIG
        ;;
      TROJAN)
        # Always require TLS for Trojan
        echo "    { \"type\": \"trojan\", \"listen\": \"0.0.0.0\", \"listen_port\": $port, \"users\": [{ \"password\": \"$arg1\" }], \"tls\": { \"enabled\": true, \"certificate_path\": \"$CERT_DIR/cert.pem\", \"key_path\": \"$CERT_DIR/private.key\" } }" >> $CONFIG
        ;;
      HYSTERIA2)
        echo "    { \"type\": \"hysteria2\", \"listen\": \"0.0.0.0\", \"listen_port\": $port, \"users\": [{ \"password\": \"$arg1\" }], \"tls\": { \"enabled\": true, \"certificate_path\": \"$CERT_DIR/cert.pem\", \"key_path\": \"$CERT_DIR/private.key\" } }" >> $CONFIG
        ;;
    esac
  done < $DB
  cat >> $CONFIG <<EOF
  ],
  "outbounds": [
    { "type": "direct" }
  ]
}
EOF
  # Create systemd service if it doesn't exist
  if [ ! -f "/etc/systemd/system/sing-box.service" ]; then
    cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable sing-box
  fi

  systemctl restart sing-box
  echo "Config generated and sing-box restarted."
  export_links
}

# Export links for all protocols (IPv4/domain only)
export_links() {
  if [[ ! -s $DB ]]; then
    echo "No protocols enabled."
    return
  fi
  if [[ -f $DOMAIN_FILE ]]; then
    host=$(cat $DOMAIN_FILE)
  else
    host=$(curl -4 -s ifconfig.me)
  fi
  green_title "Export links:"
  n=1
  while IFS="|" read -r proto port arg1 arg2 arg3 arg4; do
    case $proto in
      SOCKS5)
        echo "$n. SOCKS5: socks5://$host:$port"
        ;;
      SS)
        echo "$n. Shadowsocks: ss://$(echo -n "aes-128-gcm:$arg1@$host:$port" | base64 | tr -d '\n')"
        ;;
      VMESS)
        echo "$n. Vmess: vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"singbox\",\"add\":\"$host\",\"port\":\"$port\",\"id\":\"$arg1\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"tls\":\"\"}" | base64 | tr -d '\n')"
        ;;
      VLESS)
        # Always export ws+tls link for VLESS
        echo "$n. VLESS: vless://$arg1@$host:$port?type=ws&security=tls&host=$host&path=%2Fvlessws"
        ;;
      TROJAN)
        echo "$n. Trojan: trojan://$arg1@$host:$port"
        ;;
      HYSTERIA2)
        echo "$n. Hysteria2: hysteria2://$arg1@$host:$port?insecure=1"
        ;;
    esac
    n=$((n+1))
  done < $DB
}

# Install/Uninstall/Update/Status functions
install_singbox() {
  echo "Installing sing-box..."
  apt update && apt install -y wget tar
  SINGBOX_VERSION="1.8.7"
  ARCH="amd64"
  wget -O /tmp/sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz
  tar -xzf /tmp/sing-box.tar.gz -C /tmp
  cp /tmp/sing-box-${SINGBOX_VERSION}-linux-${ARCH}/sing-box /usr/local/bin/
  chmod +x /usr/local/bin/sing-box
  mkdir -p /etc/sing-box

  # Create systemd service
  cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable sing-box
  echo "sing-box installed."
}

uninstall_singbox() {
  echo "Uninstalling sing-box..."
  systemctl stop sing-box 2>/dev/null || true
  systemctl disable sing-box 2>/dev/null || true
  rm -f /usr/local/bin/sing-box
  rm -rf /etc/sing-box
  rm -f /etc/systemd/system/sing-box.service
  systemctl daemon-reload
  echo "sing-box uninstalled."
}

update_singbox() {
  echo "Updating sing-box..."
  uninstall_singbox
  install_singbox
}

show_status() {
  systemctl status sing-box --no-pager || echo "sing-box is not installed or not running."
}

# Main menu
menu() {
  while true; do
    green_title "=============================="
    green_title " sing-box 管理菜单 / Menu"
    green_title "=============================="
    echo "1. Add protocol"
    echo "2. Remove protocol"
    echo "3. Show enabled protocols"
    echo "4. Generate config (all protocols stay online)"
    echo "5. Export links"
    echo "6. Install sing-box"
    echo "7. Uninstall sing-box"
    echo "8. Update sing-box"
    echo "9. Show status"
    echo "10. Remove config and disable sing-box"
    echo "11. Exit"
    read -p "Choose: " CHOICE
    case $CHOICE in
      1) add_protocol ;;
      2) remove_protocol ;;
      3) show_protocols ;;
      4) generate_config ;;
      5) export_links ;;
      6) install_singbox ;;
      7) uninstall_singbox ;;
      8) update_singbox ;;
      9) show_status ;;
      10) remove_config ;;
      11) echo "Bye!"; exit 0 ;;
      *) echo "Invalid choice, try again." ;;
    esac
    echo
  done
}

menu
