#!/bin/bash
# ───────────────────────────────────────────────
# 🐉 DRAGON VPS MANAGER (Full Version)
# Dropbear + BadVPN (systemd)
# Compatible with Ubuntu 20 → 25
# ───────────────────────────────────────────────

# --- Root Check ---
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m You must run this script as root!"
    exit 1
fi

clear

# --- Progress Bar Function ---
fun_bar() {
    comando="$1"
    (
        $comando > /dev/null 2>&1
        touch /tmp/fim
    ) &
    echo -ne "  \033[1;33m◇ PLEASE WAIT...\033[1;37m ["
    while true; do
        for((i=0; i<20; i++)); do
            echo -ne "\033[1;31m#"
            sleep 0.1
        done
        [[ -e /tmp/fim ]] && rm /tmp/fim && break
        echo -e "\033[1;33m]"
        tput cuu1
        tput dl1
        echo -ne "  \033[1;33m◇ PLEASE WAIT...\033[1;37m ["
    done
    echo -e "\033[1;33m]\033[1;32m ◇ DONE!\033[0m"
}

# --- System Update ---
fun_bar "apt-get update -y && apt-get upgrade -y"

# --- Install Essential Packages ---
install_packages() {
    apt-get install -y bc apache2 cron screen nano unzip lsof \
    net-tools dos2unix nload jq curl figlet python3 python3-pip dropbear cmake build-essential git
    python3 -m pip install --upgrade pip
    python3 -m pip install speedtest-cli
}
fun_bar install_packages

# --- Restart SSH ---
if command -v systemctl > /dev/null; then
    systemctl restart ssh
else
    service ssh restart
fi

# --- Alias for Menu ---
if ! grep -q "dragon_menu" ~/.bashrc; then
    echo "alias menu='$HOME/dragon.sh'" >> ~/.bashrc
    source ~/.bashrc
fi

# --- Banner ---
tput setaf 7 ; tput setab 4 ; tput bold
printf '%40s%s%-12s\n' "◇─────────🐉 DRAGON VPS MANAGER 🐉─────────◇"
tput sgr0
echo -e "\033[1;33m◇ Full VPS Management Script (Dropbear + BadVPN)\033[0m"
echo ""

# --- User Management ---
user_management() {
    while true; do
        echo -e "\033[1;36m[1]\033[0m Add User"
        echo -e "\033[1;36m[2]\033[0m Delete User"
        echo -e "\033[1;36m[3]\033[0m List Users"
        echo -e "\033[1;36m[4]\033[0m Back to Main Menu"
        read -p "Option: " um
        case $um in
            1)
                read -p "Username: " uadd
                read -s -p "Password: " upass
                echo
                useradd -m $uadd
                echo "$uadd:$upass" | chpasswd
                echo "User $uadd added!"
                ;;
            2)
                read -p "Username to delete: " udel
                deluser --remove-home $udel
                echo "User $udel removed!"
                ;;
            3)
                awk -F: '$3 >= 500 {print $1}' /etc/passwd
                ;;
            4) break ;;
            *) echo "Invalid option!" ;;
        esac
        echo ""
    done
}

# --- Dropbear + BadVPN Management ---
vpn_management() {
    while true; do
        echo -e "\033[1;36m[1]\033[0m Install/Start Dropbear"
        echo -e "\033[1;36m[2]\033[0m Add Dropbear User"
        echo -e "\033[1;36m[3]\033[0m Delete Dropbear User"
        echo -e "\033[1;36m[4]\033[0m List Dropbear Users"
        echo -e "\033[1;36m[5]\033[0m Install/Start BadVPN (systemd)"
        echo -e "\033[1;36m[6]\033[0m Stop BadVPN Service"
        echo -e "\033[1;36m[7]\033[0m Back to Main Menu"
        read -p "Option: " vpn

        case $vpn in
            1)
                echo "Installing Dropbear..."
                apt-get install -y dropbear
                systemctl enable dropbear
                systemctl restart dropbear
                echo "Dropbear started!"
                ;;
            2)
                read -p "New username: " uadd
                read -s -p "Password: " upass
                echo
                useradd -m $uadd
                echo "$uadd:$upass" | chpasswd
                echo "User $uadd added for Dropbear!"
                ;;
            3)
                read -p "Username to delete: " udel
                deluser --remove-home $udel
                echo "User $udel removed!"
                ;;
            4)
                echo "Dropbear Users:"
                awk -F: '$3 >= 500 {print $1}' /etc/passwd
                ;;
            5)
                echo "Installing BadVPN..."
                git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn
                mkdir -p /tmp/badvpn/build && cd /tmp/badvpn/build
                cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
                make install

                # Create systemd service
                cat >/etc/systemd/system/badvpn.service <<EOL
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

                systemctl daemon-reload
                systemctl enable badvpn
                systemctl start badvpn
                echo "BadVPN service started on 127.0.0.1:7300 and enabled at boot!"
                ;;
            6)
                echo "Stopping BadVPN service..."
                systemctl stop badvpn
                echo "BadVPN service stopped!"
                ;;
            7) break ;;
            *) echo "Invalid option!" ;;
        esac
        echo ""
    done
}

# --- System / Network Info ---
system_info() {
    echo -e "\033[1;32m◇ System Info ◇\033[0m"
    uname -a
    echo ""
    echo -e "\033[1;32m◇ Network Interfaces ◇\033[0m"
    ip addr show
    echo ""
    echo -e "\033[1;32m◇ Disk Usage ◇\033[0m"
    df -h
    echo ""
    read -p "Press Enter to continue..."
}

# --- Speedtest ---
run_speedtest() {
    echo "Running Speedtest..."
    speedtest-cli
    read -p "Press Enter to continue..."
}

# --- Main Menu ---
while true; do
    echo -e "\033[1;36m[1]\033[0m User Management"
    echo -e "\033[1;36m[2]\033[0m VPN/Proxy Management (Dropbear + BadVPN)"
    echo -e "\033[1;36m[3]\033[0m System/Network Info"
    echo -e "\033[1;36m[4]\033[0m Speedtest"
    echo -e "\033[1;36m[5]\033[0m Exit"
    read -p "Select an option: " main_opt
    case $main_opt in
        1) user_management ;;
        2) vpn_management ;;
        3) system_info ;;
        4) run_speedtest ;;
        5) echo "Bye 🐉"; exit 0 ;;
        *) echo "Invalid option!" ;;
    esac
    echo ""
done
Add Dragon VPS Manager script
