#!/bin/bash

# Definition de colores
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT_RED='\033[1;31m'
export LIGHT_GREEN='\033[1;32m'
export WHITE='\033[1;37m'
export BG_RED='\033[41;37m'
export NC='\033[0m'

# Obtención de Datos del Sistema
domain=$(cat /etc/data/domain 2>/dev/null || echo "sin-dominio.com")
ip_publica=$(curl -s --max-time 2 ifconfig.me || echo "127.0.0.1")
so_info=$(lsb_release -ds 2>/dev/null || cat /etc/issue | head -n1 | awk '{print $1,$2}')
uptime_info=$(uptime -p | sed 's/up //')

# Uso de Disco
disco_total=$(df -h / | awk 'NR==2 {print $2}')
disco_uso=$(df -h / | awk 'NR==2 {print $3}')
disco_libre=$(df -h / | awk 'NR==2 {print $4}')

# Uso de CPU
cpu_cores=$(nproc)
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
cpu_usage_int=$(printf "%.0f" "$cpu_usage" 2>/dev/null || echo 0)

# Uso de Memoria RAM
ram_total=$(free -m | awk 'NR==2 {print $2}')
ram_used=$(free -m | awk 'NR==2 {print $3}')
ram_free=$(free -m | awk 'NR==2 {print $4}')
ram_usage_pct=$(( ram_used * 100 / ram_total ))

# Función para generar barra de progreso visual [||||||||||]
draw_bar() {
    local percentage=$1
    local total_bars=20
    local filled=$(( percentage * total_bars / 100 ))
    local empty=$(( total_bars - filled ))
    local bar=""
    
    for ((i=0; i<filled; i++)); do bar="${bar}|"; done
    for ((i=0; i<empty; i++)); do bar="${bar} "; done
    echo "$bar"
}

cpu_bar=$(draw_bar $cpu_usage_int)
ram_bar=$(draw_bar $ram_usage_pct)

# Ping a Cloudflare
url="1.1.1.1"
ping_val=$(ping -c 1 $url 2>/dev/null | grep -oP 'time=\K\d+\.\d+' || echo "0")
if (( $(echo "$ping_val < 100" | bc -l 2>/dev/null || echo 0) )); then
    ping_color="${GREEN}${ping_val} ms${NC}"
elif (( $(echo "$ping_val < 200" | bc -l 2>/dev/null || echo 0) )); then
    ping_color="${YELLOW}${ping_val} ms${NC}"
else
    ping_color="${RED}${ping_val} ms${NC}"
fi

# Cálculo del ancho de vnstat (Uso de Ancho de Banda)
read_vnstat_usage() {
  local interface=$1
  local today=$(vnstat -i "$interface" 2>/dev/null | grep "today" | awk '{print $8" "$9}')
  local yesterday=$(vnstat -i "$interface" 2>/dev/null | grep "yesterday" | awk '{print $8" "$9}')
  local this_month=$(vnstat -i "$interface" -m 2>/dev/null | grep "$(date +"%b '%y")" | awk '{print $9" "$10}')
  echo "$today;$yesterday;$this_month"
}

convert_to_mb() {
  local value=$1
  local unit=$2
  case $unit in
    B) echo "scale=6; $value / 1048576" | bc ;;
    KiB) echo "scale=6; $value / 1024" | bc ;;
    MiB) echo "$value" ;;
    GiB) echo "scale=6; $value * 1024" | bc ;;
    TiB) echo "scale=6; $value * 1048576" | bc ;;
    *) echo "0" ;;
  esac
}

all_interfaces=$(vnstat --iflist 2>/dev/null | sed 's/Available interfaces: //')
total_today=0
total_yesterday=0
total_month=0

if [ -n "$all_interfaces" ]; then
    for iface in $all_interfaces; do
      result=$(read_vnstat_usage "$iface")
      today=$(echo "$result" | awk -F';' '{print $1}')
      yesterday=$(echo "$result" | awk -F';' '{print $2}')
      month=$(echo "$result" | awk -F';' '{print $3}')
      
      today_val=$(echo "$today" | awk '{print $1}')
      today_unit=$(echo "$today" | awk '{print $2}')
      yesterday_val=$(echo "$yesterday" | awk '{print $1}')
      yesterday_unit=$(echo "$yesterday" | awk '{print $2}')
      month_val=$(echo "$month" | awk '{print $1}')
      month_unit=$(echo "$month" | awk '{print $2}')
      
      total_today=$(echo "$total_today + $(convert_to_mb $today_val $today_unit)" | bc 2>/dev/null || echo 0)
      total_yesterday=$(echo "$total_yesterday + $(convert_to_mb $yesterday_val $yesterday_unit)" | bc 2>/dev/null || echo 0)
      total_month=$(echo "$total_month + $(convert_to_mb $month_val $month_unit)" | bc 2>/dev/null || echo 0)
    done
fi

format_usage() {
  local value=$1
  if (( $(echo "$value >= 1024" | bc -l 2>/dev/null || echo 0) )); then
    echo "$(printf "%.2f" $(echo "$value / 1024" | bc 2>/dev/null || echo 0)) GB"
  else
    echo "$(printf "%.2f" $value 2>/dev/null || echo 0) MB"
  fi
}

ttoday=$(format_usage "$total_today")
tyest=$(format_usage "$total_yesterday")
tmon=$(format_usage "$total_month")

# ESTADÍSTICAS VISUALES (INTERFAZ)
clear
echo -e "${LIGHT_RED}╔═════════════════════════════════════════════════════════════╗${NC}"
echo -e "${LIGHT_RED}║${NC}   ${CYAN}🛸  PANEL DE CONTROL GOLBERT MULTIPORT X SSH  🛸${NC}      ${LIGHT_RED}║${NC}"
echo -e "${LIGHT_RED}╚═════════════════════════════════════════════════════════════╝${NC}"
echo -e "${BLUE}OS       :${NC} ${WHITE}$so_info${NC}"
echo -e "${BLUE}UPTIME   :${NC} ${WHITE}$uptime_info${NC}"
echo -e "${BLUE}IP/DOM   :${NC} ${WHITE}$ip_publica${NC} / ${CYAN}$domain${NC}"
echo -e "${BLUE}DISCO    :${NC} Total ${WHITE}$disco_total${NC}   Uso ${WHITE}$disco_uso${NC}   Libre ${WHITE}$disco_libre${NC}"
echo -e "${BLUE}CPU      :${NC} [${GREEN}$cpu_bar${NC}] ${WHITE}${cpu_usage_int}%${NC} Cores: ${WHITE}$cpu_cores${NC}"
echo -e "${BLUE}RAM      :${NC} [${GREEN}$ram_bar${NC}] ${WHITE}${ram_used}M/${ram_total}M${NC} Libre: ${WHITE}${ram_free}M${NC}"
echo -e "${LIGHT_RED}───────────────────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}CONSUMO :${NC} Hoy: ${LIGHT_GREEN}$ttoday${NC}  Ayer: ${LIGHT_GREEN}$tyest${NC}  Mes: ${LIGHT_GREEN}$tmon${NC}"
echo -e " ${BLUE}LATENCIA:${NC} $ping_color [ Cloudflare ]"
echo -e "${LIGHT_RED}───────────────────────────────────────────────────────────────${NC}"
echo -e " ${LIGHT_GREEN}[01]${NC} MENU SSH                   ${LIGHT_GREEN}[06]${NC} SETUP BOT MARZBAN"
echo -e " ${LIGHT_GREEN}[02]${NC} MENU MARZBAN               ${LIGHT_GREEN}[07]${NC} WARP MENU"
echo -e " ${LIGHT_GREEN}[03]${NC} CAMBIAR DOMINIO            ${LIGHT_GREEN}[08]${NC} MENU SERVICE MANAGER"
echo -e " ${LIGHT_GREEN}[04]${NC} MENU BACKUP                ${LIGHT_GREEN}[09]${NC} RENEW CERTIFICATE"
echo -e " ${LIGHT_GREEN}[05]${NC} CEK SERVICE                ${LIGHT_GREEN}[00]${NC} SALIR"
echo -e "${LIGHT_RED}───────────────────────────────────────────────────────────────${NC}"
echo -e "           ${BG_RED} AUTOSCRIPT MARZBAN X GOLBERT-VPS ${NC}"
echo -e "${LIGHT_RED}───────────────────────────────────────────────────────────────${NC}"
echo -ne " ${WHITE}Seleccione una opción :${NC} "
read opt

case $opt in
1|01) menu-ssh ;;
2|02) marzban ;;
3|03) change-domain ;;
4|04) bmenu ;;
5|05) cekservice ;;
6|06) menu-bot ;;
7|07) warp ;;
8|08) fn-sc1 ;;
9|09) crt ;;
0|00) exit ;;
*) menu ;;
esac
