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