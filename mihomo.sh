cat << 'EOF' > /usr/local/bin/mm
#!/bin/sh

# =====================================================================
#  Mihomo (Clash Meta) Alpine Linux & LXC 生产级全自动部署与管理系统
#  版本: v1.6.3 (原生gzip防损坏校验 / 300秒防超时 / 首次开箱自部署)
# =====================================================================

SCRIPT_VERSION="1.6.3"

# 终端色彩
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 系统路径定义
CONFIG_DIR="/etc/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
MIXIN_FILE="${CONFIG_DIR}/mixin.yaml"
SUB_URL_FILE="${CONFIG_DIR}/sub_url.txt"
UI_DIR="${CONFIG_DIR}/ui"
BINARY_PATH="/usr/local/bin/mihomo"
SERVICE_PATH="/etc/init.d/mihomo"
SHORTCUT_PATH="/usr/local/bin/mm"
LOG_FILE="/var/log/mihomo.log"
CRON_FILE="/etc/crontabs/root"

# 高可用 GitHub 代理池
GH_PROXIES="https://ghfast.top/ https://github.moeyy.xyz/ https://gh-proxy.com/ https://mirror.ghproxy.com/ "

# =====================================================================
#  1. 基础环境与工具函数
# =====================================================================

print_info() { printf "${GREEN}[信息] %s${NC}\n" "$*"; }
print_warn() { printf "${YELLOW}[警告] %s${NC}\n" "$*"; }
print_err()  { printf "${RED}[错误] %s${NC}\n" "$*"; }

check_env() {
    if [ "$(id -u)" -ne 0 ]; then
        print_err "请以 root 用户身份运行此脚本。"
        exit 1
    fi
    if [ ! -f /etc/alpine-release ]; then
        print_err "此脚本专为 Alpine Linux 环境打造。"
        exit 1
    fi
}

get_gh_proxy() {
    for proxy in $GH_PROXIES; do
        if curl -sSL --connect-timeout 2 -m 3 "${proxy}https://raw.githubusercontent.com" >/dev/null 2>&1; then
            echo "$proxy"
            return
        fi
    done
    echo ""
}

detect_arch() {
    local machine
    machine=$(uname -m)
    case "$machine" in
        x86_64)
            if grep -q "avx" /proc/cpuinfo 2>/dev/null; then
                echo "linux-amd64"
            else
                echo "linux-amd64-compatible"
            fi
            ;;
        aarch64|arm64)
            echo "linux-arm64"
            ;;
        armv7l|armhf)
            echo "linux-armv7"
            ;;
        *)
            print_err "不支持的架构: ${machine}"
            exit 1
            ;;
    esac
}

get_local_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -n 1)
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "$ip"
}

ensure_dns_fallback() {
    if ! grep -qE "nameserver[[:space:]]+(223\.5\.5\.5|1\.1\.1\.1|8\.8\.8\.8)" /etc/resolv.conf 2>/dev/null; then
        echo "nameserver 223.5.5.5" >> /etc/resolv.conf
        print_info "已在 /etc/resolv.conf 追加保底公共 DNS (223.5.5.5)。"
    fi
}

install_dependencies() {
    print_info "正在检查并安装系统运行依赖..."
    apk update >/dev/null 2>&1
    apk add --no-cache curl wget tar gzip ca-certificates tzdata iptables ip6tables logrotate >/dev/null 2>&1
    print_info "✔ 基础依赖安装完成。"
}

# =====================================================================
#  2. Mixin 补丁与配置管理
# =====================================================================

init_mixin_file() {
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$MIXIN_FILE" ]; then
        cat << 'EOF_MIXIN' > "$MIXIN_FILE"
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
ipv6: false
external-controller: 0.0.0.0:9090
external-ui: ui
secret: ""

tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-redirect: true
  auto-detect-interface: true
  dns-hijack:
    - "any:53"
    - "tcp://any:53"

dns:
  enable: true
  listen: 0.0.0.0:1053
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
EOF_MIXIN
        print_info "已初始化网关专用 Mixin 补丁模板: ${MIXIN_FILE}"
    fi
}

generate_default_config() {
    init_mixin_file
    if [ ! -f "$CONFIG_FILE" ]; then
        cp -f "$MIXIN_FILE" "$CONFIG_FILE"
        cat << 'EOF_DEF' >> "$CONFIG_FILE"

# 默认占位节点配置（请在面板中导入正式订阅）
proxies:
  - name: "DIRECT"
    type: direct
    udp: true

proxy-groups:
  - name: "GLOBAL"
    type: select
    proxies:
      - "DIRECT"

rules:
  - MATCH,GLOBAL
EOF_DEF
        print_info "已生成默认初始化占位配置: ${CONFIG_FILE}"
    fi
}

merge_mixin_config() {
    local raw_sub="$1"
    local output_target="$2"

    init_mixin_file
    local stripped_sub="/tmp/sub_stripped.yaml"
    
    awk '
    BEGIN { skip = 0 }
    /^[[:space:]]*$/ { if (!skip) print; next }
    /^[a-zA-Z0-9_-]+:/ {
        if ($0 ~ /^(allow-lan|bind-address|mode|log-level|external-controller|external-ui|secret|tun|dns):/) {
            skip = 1
        } else {
            skip = 0
        }
    }
    !skip { print }
    ' "$raw_sub" > "$stripped_sub"

    cat "$MIXIN_FILE" > "$output_target"
    printf "\n# === 机场节点与分流规则 ===\n" >> "$output_target"
    cat "$stripped_sub" >> "$output_target"
    rm -f "$stripped_sub"
}

update_subscription() {
    ensure_dns_fallback
    local url="$1"
    mkdir -p "$CONFIG_DIR"

    if [ -z "$url" ]; then
        if [ -f "$SUB_URL_FILE" ]; then
            url=$(cat "$SUB_URL_FILE")
            printf "检测到历史订阅: %s\n" "$url"
            printf "直接回车沿用，或输入新订阅覆盖: "
            read -r input_url
            [ -n "$input_url" ] && url="$input_url"
        else
            printf "请输入订阅 URL: "
            read -r url
        fi
    fi

    if [ -z "$url" ]; then
        print_err "订阅链接为空！"
        return 1
    fi

    print_info "正在下载订阅并应用 Mixin 补丁注入..."
    local temp_raw="/tmp/sub_raw.yaml"
    local temp_merged="/tmp/sub_merged.yaml"

    if curl -fL --connect-timeout 15 -m 120 --retry 2 -A "clash.meta; mihomo" -o "$temp_raw" "$url"; then
        local fsize
        fsize=$(wc -c < "$temp_raw" 2>/dev/null || echo 0)
        if [ "$fsize" -lt 200 ]; then
            print_err "订阅内容过小，可能是无效链接！"
            rm -f "$temp_raw"
            return 1
        fi

        merge_mixin_config "$temp_raw" "$temp_merged"
        rm -f "$temp_raw"

        if [ -f "$BINARY_PATH" ]; then
            print_info "正在校验合并后配置语法..."
            if ! "$BINARY_PATH" -t -d "$CONFIG_DIR" -f "$temp_merged"; then
                print_err "校验失败，已丢弃，原有配置不受影响！"
                rm -f "$temp_merged"
                return 1
            fi
        fi

        [ -f "$CONFIG_FILE" ] && cp -f "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        mv -f "$temp_merged" "$CONFIG_FILE"
        echo "$url" > "$SUB_URL_FILE"
        print_info "✔ 订阅同步成功，已自动注入 TUN 与网关配置！"

        if rc-service mihomo status >/dev/null 2>&1; then
            service_control reload
        fi
    else
        print_err "订阅下载失败，请检查网络！"
        rm -f "$temp_raw" "$temp_merged"
        return 1
    fi
}

# =====================================================================
#  3. 核心与资源下载 (去除SHA256误报，引入gzip数据完整性校验)
# =====================================================================

download_core() {
    ensure_dns_fallback
    local channel="${1:-stable}"
    local proxy
    proxy=$(get_gh_proxy)
    local arch
    arch=$(detect_arch)
    mkdir -p /tmp/mihomo_bin "$CONFIG_DIR"

    print_info "检索核心版本 [渠道: ${channel}]..."
    local download_url=""
    local tag="latest"

    if [ "$channel" = "alpha" ]; then
        download_url="${proxy}https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-${arch}-alpha-latest.gz"
    else
        local latest_tag
        latest_tag=$(curl -sSL --connect-timeout 5 -m 10 "${proxy}https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | grep '"tag_name":' | head -n 1 | cut -d'"' -f4)
        [ -z "$latest_tag" ] && latest_tag="v1.19.2"
        tag="$latest_tag"
        download_url="${proxy}https://github.com/MetaCubeX/mihomo/releases/download/${tag}/mihomo-${arch}-${tag}.gz"
    fi

    print_info "正在下载核心 (限时5分钟，带进度显示): ${download_url}"
    if curl -fL --connect-timeout 15 -m 300 --retry 3 --progress-bar -o /tmp/mihomo_bin/mihomo.gz "$download_url"; then
        
        # 使用 gzip -t 对压缩包进行原生的数据完整性校验，彻底杜绝 404 误报与下载截断
        if ! gzip -t /tmp/mihomo_bin/mihomo.gz 2>/dev/null; then
            print_err "压缩包完整性校验失败，可能网络传输中断或文件损坏！"
            rm -rf /tmp/mihomo_bin
            return 1
        fi
        print_info "✔ 文件完整性校验通过 (gzip CRC 验证成功)。"

        [ -f "$BINARY_PATH" ] && cp -f "$BINARY_PATH" "${BINARY_PATH}.bak"
        gzip -d -f /tmp/mihomo_bin/mihomo.gz
        mv -f /tmp/mihomo_bin/mihomo "$BINARY_PATH"
        chmod +x "$BINARY_PATH"
        rm -rf /tmp/mihomo_bin
        print_info "✔ 核心安装/更新成功！当前版本: $("$BINARY_PATH" -v 2>/dev/null | head -n 1)"
    else
        print_err "核心下载超时或失败！"
        [ -f "${BINARY_PATH}.bak" ] && mv -f "${BINARY_PATH}.bak" "$BINARY_PATH"
        rm -rf /tmp/mihomo_bin
        return 1
    fi
}

download_geodata() {
    ensure_dns_fallback
    local proxy
    proxy=$(get_gh_proxy)
    mkdir -p "$CONFIG_DIR"
    print_info "正在同步 GeoIP / GeoSite 规则库 (限时5分钟)..."
    local base_url="${proxy}https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest"

    printf "下载 geoip.dat: \n"
    curl -fL --connect-timeout 15 -m 300 --retry 3 --progress-bar -o "${CONFIG_DIR}/geoip.dat" "${base_url}/geoip.dat"
    printf "下载 geosite.dat (~17MB): \n"
    curl -fL --connect-timeout 15 -m 300 --retry 3 --progress-bar -o "${CONFIG_DIR}/geosite.dat" "${base_url}/geosite.dat"
    printf "下载 country.mmdb: \n"
    curl -fL --connect-timeout 15 -m 300 --retry 3 --progress-bar -o "${CONFIG_DIR}/country.mmdb" "${base_url}/country.mmdb"

    print_info "✔ 规则库更新完成！"
}

download_webui() {
    ensure_dns_fallback
    local proxy
    proxy=$(get_gh_proxy)
    print_info "正在部署 Metacubexd Web 控制台..."
    mkdir -p "$UI_DIR"
    if curl -fL --connect-timeout 15 -m 180 --retry 3 --progress-bar -o /tmp/ui.tar.gz "${proxy}https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.tar.gz"; then
        tar -xzf /tmp/ui.tar.gz -C "$UI_DIR" --strip-components=1
        rm -f /tmp/ui.tar.gz
        print_info "✔ Web 面板部署成功: ${UI_DIR}"
    fi
}

# =====================================================================
#  4. 网络与日志防护
# =====================================================================

setup_lxc_network() {
    print_info "正在配置系统内核转发与 TUN..."
    ensure_dns_fallback
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1

    mkdir -p /etc/sysctl.d
    cat << 'EOF_SYS' > /etc/sysctl.d/99-mihomo.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF_SYS

    if [ ! -c /dev/net/tun ]; then
        print_warn "未检测到 /dev/net/tun！若为 PVE LXC，请在宿主机容器配置中追加 TUN 映射并重启容器。"
    else
        print_info "TUN 设备正常就绪。"
    fi
}

setup_nat_masquerade() {
    print_info "配置旁路由出站 NAT 伪装 (MASQUERADE)..."
    local default_iface
    default_iface=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n 1)
    [ -z "$default_iface" ] && default_iface="eth0"

    iptables -t nat -C POSTROUTING -o "$default_iface" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o "$default_iface" -j MASQUERADE

    mkdir -p /etc/local.d
    cat << EOF_NAT > /etc/local.d/mihomo-nat.start
#!/bin/sh
iptables -t nat -C POSTROUTING -o ${default_iface} -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o ${default_iface} -j MASQUERADE
EOF_NAT
    chmod +x /etc/local.d/mihomo-nat.start
    rc-update add local default >/dev/null 2>&1
    print_info "✔ NAT 规则已固化自启。"
}

setup_logrotate() {
    print_info "配置日志防爆盘机制..."
    cat << 'EOF_LOG' > /etc/logrotate.d/mihomo
/var/log/mihomo.log {
    size 10M
    rotate 3
    missingok
    compress
    copytruncate
    notifempty
}
EOF_LOG
    rc-service crond status >/dev/null 2>&1 || { rc-service crond start; rc-update add crond default; }
    print_info "✔ 日志防爆盘就绪。"
}

# =====================================================================
#  5. 服务与体检
# =====================================================================

install_openrc_service() {
    print_info "注册 OpenRC 服务 (/etc/init.d/mihomo)..."
    cat << EOF_SVC > "$SERVICE_PATH"
#!/sbin/openrc-run
name="mihomo"
description="Mihomo Proxy Daemon"
command="${BINARY_PATH}"
command_args="-d ${CONFIG_DIR} -f ${CONFIG_FILE}"
supervisor="supervise-daemon"
supervise_daemon_args="--respawn-delay 3 --respawn-max 5"
output_log="${LOG_FILE}"
error_log="${LOG_FILE}"

depend() {
    need net
    after firewall
}

extra_started_commands="reload check"

check() {
    ebegin "Checking Mihomo config"
    ${BINARY_PATH} -t -d ${CONFIG_DIR} -f ${CONFIG_FILE}
    eend \$?
}

reload() {
    ebegin "Reloading Mihomo config safely"
    ${BINARY_PATH} -t -d ${CONFIG_DIR} -f ${CONFIG_FILE} >/dev/null 2>&1
    if [ \$? -ne 0 ]; then
        eerror "语法验证失败，取消重载！"
        return 1
    fi
    killall -HUP mihomo
    eend \$?
}
EOF_SVC
    chmod +x "$SERVICE_PATH"
    rc-update add mihomo default >/dev/null 2>&1
}

test_config() {
    [ ! -f "$BINARY_PATH" ] && { print_err "核心文件不存在"; return 1; }
    [ ! -f "$CONFIG_FILE" ] && { print_err "未找到主配置文件: ${CONFIG_FILE}"; return 1; }
    print_info "正在检验配置文件语法..."
    if "$BINARY_PATH" -t -d "$CONFIG_DIR" -f "$CONFIG_FILE"; then
        print_info "✔ 配置文件语法合法！"
        return 0
    else
        print_err "✘ 配置文件存在错误！"
        return 1
    fi
}

service_control() {
    case "$1" in
        start)   test_config && rc-service mihomo start ;;
        stop)    rc-service mihomo stop ;;
        restart) test_config && rc-service mihomo restart ;;
        reload)  rc-service mihomo reload ;;
        status)  rc-service mihomo status ;;
    esac
}

run_doctor() {
    clear
    printf "${CYAN}====================================================${NC}\n"
    printf "${CYAN}          Mihomo 系统健康体检报告                   ${NC}\n"
    printf "${CYAN}====================================================${NC}\n"

    if pidof mihomo >/dev/null 2>&1; then
        printf "[ ${GREEN}PASS${NC} ] Mihomo 核心存活 (PID: %s)\n" "$(pidof mihomo | tr '\n' ' ')"
    else
        printf "[ ${RED}FAIL${NC} ] Mihomo 未在运行！\n"
    fi

    if [ -f "$BINARY_PATH" ]; then
        printf "[ ${GREEN}PASS${NC} ] 核心二进制就绪 (%s)\n" "$("$BINARY_PATH" -v 2>/dev/null | head -n 1)"
    else
        printf "[ ${RED}FAIL${NC} ] 核心文件缺失！\n"
    fi

    if [ -c /dev/net/tun ]; then
        printf "[ ${GREEN}PASS${NC} ] TUN 虚拟网卡设备正常\n"
    else
        printf "[ ${RED}FAIL${NC} ] /dev/net/tun 缺失！\n"
    fi

    if [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" = "1" ]; then
        printf "[ ${GREEN}PASS${NC} ] 内核 IPv4 转发已开启\n"
    else
        printf "[ ${RED}FAIL${NC} ] 内核 IPv4 转发关闭！\n"
    fi

    printf "正在测试连通性...\n"
    local delay_cn delay_intl
    delay_cn=$(curl -s -w "%{time_total}\n" -o /dev/null -m 3 https://www.baidu.com 2>/dev/null)
    delay_intl=$(curl -s -w "%{time_total}\n" -o /dev/null -m 3 https://www.google.com 2>/dev/null)

    [ -n "$delay_cn" ] && printf "[ ${GREEN}PASS${NC} ] 国内连通性 (Baidu): %ss\n" "$delay_cn" || printf "[ ${RED}FAIL${NC} ] 无法访问国内网络\n"
    [ -n "$delay_intl" ] && printf "[ ${GREEN}PASS${NC} ] 海外连通性 (Google): %ss\n" "$delay_intl" || printf "[ ${YELLOW}WARN${NC} ] 无法访问 Google (请确认是否导入可用节点)\n"

    printf "${CYAN}====================================================${NC}\n"
    printf "按回车返回..."
    read -r _
}

# =====================================================================
#  6. 全自动流水线部署
# =====================================================================

run_auto_deploy() {
    clear
    printf "${CYAN}====================================================${NC}\n"
    printf "${CYAN}       🚀 开始执行 Mihomo 全自动一键初始化部署      ${NC}\n"
    printf "${CYAN}====================================================${NC}\n\n"

    install_dependencies
    setup_lxc_network
    setup_nat_masquerade
    setup_logrotate
    download_core stable
    download_geodata
    download_webui
    install_openrc_service

    printf "\n${YELLOW}---------------- 机场订阅配置 ----------------${NC}\n"
    printf "是否现在导入机场订阅链接？[Y/n] (若选 n 则生成基础占位配置): "
    read -r has_sub
    if [ "$has_sub" != "n" ] && [ "$has_sub" != "N" ]; then
        printf "请输入订阅链接 URL: "
        read -r sub_link
        update_subscription "$sub_link"
    else
        generate_default_config
    fi

    print_info "正在启动 Mihomo 核心服务..."
    service_control start

    local local_ip
    local_ip=$(get_local_ip)

    printf "\n${GREEN}====================================================${NC}\n"
    printf "${GREEN}  🎉 Mihomo 全自动初始化部署已全部完成！${NC}\n"
    printf "${GREEN}====================================================${NC}\n"
    printf "Web 控制台直达: ${BLUE}http://%s:9090/ui${NC}\n" "$local_ip"
    printf "快捷管理指令: 在终端任意位置输入 ${YELLOW}mm${NC} 即可调出菜单\n\n"
    printf "按回车键进入管理面板..."
    read -r _
}

check_first_run() {
    if [ ! -f "$BINARY_PATH" ] || [ ! -f "$CONFIG_FILE" ]; then
        clear
        printf "${CYAN}====================================================${NC}\n"
        printf "${YELLOW}检测到当前 Alpine 系统尚未部署 Mihomo！${NC}\n"
        printf "${CYAN}====================================================${NC}\n"
        printf "是否立即开始全自动一键流水线部署？[Y/n]: "
        read -r start_deploy
        if [ "$start_deploy" != "n" ] && [ "$start_deploy" != "N" ]; then
            run_auto_deploy
        fi
    fi
}

# =====================================================================
#  7. 菜单与入口
# =====================================================================

register_shortcut() {
    if [ ! -f "$SHORTCUT_PATH" ] || [ "$0" != "$SHORTCUT_PATH" ]; then
        cp -f "$0" "$SHORTCUT_PATH" 2>/dev/null
        chmod +x "$SHORTCUT_PATH" 2>/dev/null
    fi
}

show_menu() {
    clear
    local local_ip
    local_ip=$(get_local_ip)

    printf "${CYAN}====================================================${NC}\n"
    printf "${CYAN}    Mihomo 生产级全能控制台 (Alpine / LXC 网关)     ${NC}\n"
    printf "    版本: ${GREEN}v%s${NC} | 网关 IP: ${YELLOW}%s${NC}\n" "$SCRIPT_VERSION" "$local_ip"
    printf "${CYAN}====================================================${NC}\n"
    printf " 1. 启动 Mihomo 服务\n"
    printf " 2. 停止 Mihomo 服务\n"
    printf " 3. 重启 Mihomo 服务\n"
    printf " 4. ${GREEN}平滑重载配置 (热更新连接不断流)${NC}\n"
    printf " 5. 查看运行状态\n"
    printf " 6. 静态语法校验\n"
    printf " 7. 实时查看日志 (Ctrl+C 退出)\n"
    printf "------------------- 订阅与 Mixin -------------------\n"
    printf " 8. ${YELLOW}导入 / 更新订阅 (自动应用 Mixin 补丁)${NC}\n"
    printf " 9. 查看 / 编辑 Mixin 旁路由安全补丁\n"
    printf "10. 同步 GeoIP / GeoSite 规则库\n"
    printf "------------------- 系统与网络 ---------------------\n"
    printf "11. ${BLUE}全链路健康体检 (mm doctor)${NC}\n"
    printf "12. 检查修复 LXC 环境 (TUN / 内核转发)\n"
    printf "13. 旁路由 NAT 伪装配置\n"
    printf "14. 部署日志防爆盘机制 (Logrotate)\n"
    printf "------------------- 核心与部署 ---------------------\n"
    printf "15. ${CYAN}重新执行全自动流水线部署${NC}\n"
    printf "16. 更新/重装 Mihomo 核心\n"
    printf "17. 部署/更新 Metacubexd Web 控制台\n"
    printf " 0. 退出面板\n"
    printf "${CYAN}====================================================${NC}\n"
    printf "Web 控制台直达: ${BLUE}http://%s:9090/ui${NC}\n" "$local_ip"
    printf "${CYAN}====================================================${NC}\n"
    printf "请选择 [0-17]: "
    read -r choice

    case "$choice" in
        1) service_control start ;;
        2) service_control stop ;;
        3) service_control restart ;;
        4) service_control reload ;;
        5) service_control status ;;
        6) test_config ;;
        7) tail -n 50 -f "$LOG_FILE" ;;
        8) update_subscription ;;
        9) init_mixin_file; ${EDITOR:-vi} "$MIXIN_FILE" ;;
        10) download_geodata ;;
        11) run_doctor ;;
        12) setup_lxc_network ;;
        13) setup_nat_masquerade ;;
        14) setup_logrotate ;;
        15) run_auto_deploy ;;
        16) download_core stable && service_control restart ;;
        17) download_webui ;;
        0) exit 0 ;;
        *) print_err "无效输入！" ;;
    esac
}

# =====================================================================
#  入口执行调度
# =====================================================================

check_env
register_shortcut
init_mixin_file

if [ -n "$1" ]; then
    case "$1" in
        start|stop|restart|reload|status) service_control "$1" ;;
        test) test_config ;;
        log) tail -n 50 -f "$LOG_FILE" ;;
        doctor) run_doctor ;;
        install) run_auto_deploy ;;
        update-sub) update_subscription "$2" ;;
        update-geodata) download_geodata ;;
        update-core) download_core stable && service_control reload ;;
        *) printf "用法: %s {start|stop|restart|reload|status|test|log|doctor|install|update-sub|update-geodata|update-core}\n" "$0"; exit 1 ;;
    esac
    exit 0
fi

check_first_run
show_menu
EOF
chmod +x /usr/local/bin/mm