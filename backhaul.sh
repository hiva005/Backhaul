#!/bin/bash

set -e

BACKHAUL_VERSION="v0.6.5"
INSTALL_DIR="/root/backhaul"
CONFIG_FILE="$INSTALL_DIR/config.toml"
SERVICE_FILE="/etc/systemd/system/backhaul.service"
EXECUTABLE="$INSTALL_DIR/backhaul"

# ÑäåÇ
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[1;30m'
NC='\033[0m'

while true; do
    clear

    SERVER_IP=$(curl -s https://api.ipify.org)  # ÝÞØ IPv4
    ISP=$(curl -s https://ipapi.co/org 2>/dev/null || echo "Unavailable")
    LOCATION=$(curl -s https://ipapi.co/country_name 2>/dev/null || echo "Unavailable")

    echo -e "${BLUE}------------------------------${NC}"
    echo -e "${BLUE}Server IP   : $SERVER_IP${NC}"
    echo -e "${BLUE}Location    : $LOCATION${NC}"
    echo -e "${BLUE}ISP         : $ISP${NC}"
    if [ -f "$EXECUTABLE" ]; then
        echo -e "${GREEN}Backhaul Core : Installed${NC}"
    else
        echo -e "${RED}Backhaul Core : Not Installed${NC}"
    fi
    echo -e "${BLUE}------------------------------${NC}"

    echo ""
    echo -e "${YELLOW}==============================${NC}"
    echo -e "${YELLOW}|    Backhaul Management     |${NC}"
    echo -e "${YELLOW}==============================${NC}"
    echo -e "${GREEN}1) Install / Reinstall Backhaul${NC}"
    echo -e "${BLUE}2) Uninstall Backhaul${NC}"
    echo -e "${YELLOW}3) Backhaul Service Status${NC}"
    echo -e "${RED}4) Restart Backhaul Service${NC}"
    echo -e "${MAGENTA}5) View Backhaul Logs (live)${NC}"
    echo -e "${CYAN}6) Edit Backhaul Config File${NC}"
    echo -e "${MAGENTA}7) Multi-Tunnel Setup${NC}"
    echo -e "${GRAY}0) Exit${NC}"
    echo -e "${YELLOW}------------------------------${NC}"
    read -p "Select an option [0-7]: " option

    case $option in
        1)
            if [ -f "$EXECUTABLE" ]; then
                echo -e "${YELLOW}\nBackhaul is already installed. Skipping reinstallation.${NC}"
            else
                apt update -y > /dev/null 2>&1
                apt install -y wget tar curl > /dev/null 2>&1

                mkdir -p "$INSTALL_DIR"
                cd "$INSTALL_DIR"
                rm -f backhaul*

                wget -q "https://github.com/Musixal/Backhaul/releases/download/$BACKHAUL_VERSION/backhaul_linux_amd64.tar.gz"
                tar -xzf backhaul_linux_amd64.tar.gz
                rm -f backhaul_linux_amd64.tar.gz README.md LICENSE
                chmod +x backhaul
            fi

            echo ""
            echo -e "${YELLOW}Select Mode:${NC}"
            echo -e "${GREEN}1) Iran${NC}"
            echo -e "${RED}2) Kharej${NC}"
            read -p "Enter your choice [1-2]: " MODE_CHOICE

            TRANSPORT="tcp"

            if [[ "$MODE_CHOICE" == "1" ]]; then
                read -p "Enter bind port (e.g., 8000): " PORT
                read -p "Enter shared token: " TOKEN
                read -p "Enable sniffer? (true/false): " SNIPPER
                SNIPPER=${SNIPPER:-false}
                read -p "Enter web dashboard port: " WEB_PORT
                WEB_PORT=${WEB_PORT:-2068}
                read -p "Enter allowed ports (comma-separated, e.g. 443,8080,8880): " PORTS

                BIND_ADDR="0.0.0.0:$PORT"

                IFS=',' read -ra PORTS_ARRAY <<< "$PORTS"
                PORTS_BLOCK="ports = ["
                for PORT_ITEM in "${PORTS_ARRAY[@]}"; do
                    PORTS_BLOCK="$PORTS_BLOCK
    \"${PORT_ITEM// /}\","
                done
                PORTS_BLOCK="$PORTS_BLOCK
]"

                cat > "$CONFIG_FILE" <<EOF
[server]
bind_addr = "$BIND_ADDR"
transport = "$TRANSPORT"
token = "$TOKEN"
keepalive_period = 75
nodelay = true
heartbeat = 40
channel_size = 2048
sniffer = $SNIPPER
web_port = $WEB_PORT
sniffer_log = "$INSTALL_DIR/sniffer.json"
log_level = "info"
$PORTS_BLOCK
EOF

            else
                read -p "Enter server IP or domain: " SERVER_IP
                read -p "Enter server port: " PORT
                read -p "Enter shared token: " TOKEN
                read -p "Enable sniffer? (true/false): " SNIPPER
                SNIPPER=${SNIPPER:-false}
                read -p "Enter web dashboard port: " WEB_PORT
                WEB_PORT=${WEB_PORT:-2068}

                cat > "$CONFIG_FILE" <<EOF
[client]
remote_addr = "$SERVER_IP:$PORT"
transport = "$TRANSPORT"
token = "$TOKEN"
connection_pool = 8
aggressive_pool = true
keepalive_period = 75
dial_timeout = 10
nodelay = true
retry_interval = 3
sniffer = $SNIPPER
web_port = $WEB_PORT
sniffer_log = "$INSTALL_DIR/sniffer.json"
log_level = "info"
EOF
            fi

            cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Backhaul Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=$EXECUTABLE -c $CONFIG_FILE
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reexec > /dev/null 2>&1
            systemctl enable backhaul > /dev/null 2>&1
            systemctl restart backhaul > /dev/null 2>&1

            echo -e "${GREEN}\nBackhaul configuration applied and service started.${NC}"
            read -p "Press Enter to return to menu..." dummy
            ;;

        2)
            echo -e "${YELLOW}Uninstalling all Backhaul-related files and services...${NC}"

            # Stop and disable main service
            systemctl stop backhaul 2>/dev/null || true
            systemctl disable backhaul 2>/dev/null || true
            rm -f "$SERVICE_FILE"

            # Stop, disable and remove all multi-location services
            for svc in /etc/systemd/system/backhaul-*.service; do
                [ -e "$svc" ] || continue
                svc_name=$(basename "$svc")
                systemctl stop "$svc_name" 2>/dev/null || true
                systemctl disable "$svc_name" 2>/dev/null || true
                rm -f "$svc"
            done

            # Remove all related config and log files
            rm -rf "$INSTALL_DIR"

            # Reload systemd
            systemctl daemon-reexec
            systemctl daemon-reload
            systemctl reset-failed

            echo -e "${RED}\nAll Backhaul services and files have been removed.${NC}"
            read -p "Press Enter to return to menu..." dummy
            ;;

        3)
            systemctl status backhaul.service
            read -p "Press Enter to return to menu..." dummy
            ;;

        4)
            systemctl restart backhaul.service
            echo -e "${GREEN}\nBackhaul service restarted.${NC}"
            read -p "Press Enter to return to menu..." dummy
            ;;

        5)
            journalctl -u backhaul.service -f
            ;;

        6)
                        while true; do
                echo -e "${CYAN}\nAvailable configuration files:${NC}"
                CONFIG_PATHS=("$INSTALL_DIR"/*.toml)

                CONFIG_NAMES=()
                for path in "${CONFIG_PATHS[@]}"; do
                    CONFIG_NAMES+=("$(basename "$path")")
                done

                if [ ${#CONFIG_NAMES[@]} -eq 0 ]; then
                    echo -e "${RED}No configuration files found in $INSTALL_DIR.${NC}"
                    read -p "Press Enter to return to menu..." dummy
                    break
                else
                    select CONFIG_NAME in "${CONFIG_NAMES[@]}" "Exit"; do
                        if [[ "$CONFIG_NAME" == "Exit" ]]; then
                            break 2
                        elif [ -n "$CONFIG_NAME" ]; then
                            while true; do
                                echo -e "\nSelected: ${GREEN}$CONFIG_NAME${NC}"
                                echo -e "${YELLOW}Select an action:${NC}"
                                echo -e "${GREEN}1) Edit${NC}"
                                echo -e "${RED}2) Delete${NC}"
                                echo -e "${CYAN}3) Copy${NC}"
                                echo -e "${GRAY}4) Back${NC}"
                                read -p "Select: " ACTION

                                case $ACTION in
                                    1)
                                        nano "$INSTALL_DIR/$CONFIG_NAME"
                                        ;;
                                    2)
                                        read -p "Are you sure you want to delete '$CONFIG_NAME'? [y/N]: " CONFIRM
                                        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                                            rm -f "$INSTALL_DIR/$CONFIG_NAME"
                                            echo -e "${RED}Deleted.${NC}"
                                            break
                                        fi
                                        ;;
                                    3)
                                        read -p "Enter name for the new copy (e.g., config-copy.toml): " NEW_NAME
                                        if [ -n "$NEW_NAME" ]; then
                                            cp "$INSTALL_DIR/$CONFIG_NAME" "$INSTALL_DIR/$NEW_NAME"
                                            echo -e "${GREEN}Copied to '$NEW_NAME'.${NC}"
                                        fi
                                        ;;
                                    4)
                                        break
                                        ;;
                                    *)
                                        echo -e "${RED}Invalid selection.${NC}"
                                        ;;
                                esac
                            done
                        else
                            echo -e "${RED}Invalid selection.${NC}"
                        fi
                    done
                fi
            done
            ;;
        7)
            echo -e "${MAGENTA}\n[Multi-Tunnel Setup]${NC}"
            read -p "Enter a name for this tunnel (e.g. ir, uk, us): " NAME
            read -p "Is this client or server mode? (c/s): " TYPE
            read -p "Enter Port (or remote port): " PORT
            read -p "Enter IP/Domain (if client, else leave blank): " IP
            read -p "Enter Shared Token: " TOKEN
            read -p "Enable sniffer? (true/false) [default: false]: " SNIPPER
            SNIPPER=${SNIPPER:-false}
            read -p "Enter web dashboard port [default: 2068]: " WEB_PORT
            WEB_PORT=${WEB_PORT:-2068}

            CONFIG_PATH="$INSTALL_DIR/config-$NAME.toml"
            SERVICE_NAME="backhaul-$NAME.service"
            SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

            if [[ "$TYPE" == "s" ]]; then
                read -p "Enter allowed ports (comma-separated): " PORTS
                IFS=',' read -ra PORTS_ARRAY <<< "$PORTS"
                PORTS_BLOCK="ports = ["
                for PORT_ITEM in "${PORTS_ARRAY[@]}"; do
                    PORTS_BLOCK="$PORTS_BLOCK
    \"${PORT_ITEM// /}\","
                done
                PORTS_BLOCK="$PORTS_BLOCK
]"

                cat > "$CONFIG_PATH" <<EOF
[server]
bind_addr = "0.0.0.0:$PORT"
transport = "tcp"
token = "$TOKEN"
keepalive_period = 75
nodelay = true
heartbeat = 40
channel_size = 2048
sniffer = $SNIPPER
web_port = $WEB_PORT
sniffer_log = "$INSTALL_DIR/sniffer-$NAME.json"
log_level = "info"
$PORTS_BLOCK
EOF
            else
                cat > "$CONFIG_PATH" <<EOF
[client]
remote_addr = "$IP:$PORT"
transport = "tcp"
token = "$TOKEN"
connection_pool = 8
aggressive_pool = true
keepalive_period = 75
dial_timeout = 10
nodelay = true
retry_interval = 3
sniffer = $SNIPPER
web_port = $WEB_PORT
sniffer_log = "$INSTALL_DIR/sniffer-$NAME.json"
log_level = "info"
EOF
            fi

            cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Backhaul Tunnel - $NAME
After=network.target

[Service]
Type=simple
ExecStart=$EXECUTABLE -c $CONFIG_PATH
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reexec
            systemctl enable "$SERVICE_NAME"
            systemctl restart "$SERVICE_NAME"
            echo -e "${GREEN}Multi-tunnel '$NAME' added and started!${NC}"
            read -p "Press Enter to return to menu..." dummy
            ;;

        0)
            echo "Exiting..."
            exit 0
            ;;

        *)
            echo -e "${RED}\nInvalid option. Try again.${NC}"
            sleep 1
            ;;
    esac
done
