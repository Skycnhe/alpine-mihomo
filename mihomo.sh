#!/bin/sh

# =====================================================================
#  Mihomo (Clash Meta) Alpine Linux & LXC 整合管理脚本 (多面板选择版)
# =====================================================================

# 脚本版本号定义
SCRIPT_VERSION="1.1.0"

# 字体颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误：请以 root 用户运行此脚本。${NC}"
    exit 1
fi

# 检查是否为 Alpine 系统
if [ ! -f /etc/alpine-release ]; then
    echo -e "${RED}错误：此脚本仅支持 Alpine Linux。${NC}"
    exit 1
fi

# 全局变量定义
CONFIG_DIR="/etc/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
BINARY_PATH="/usr/local/bin/mihomo"
SERVICE_PATH="/etc/init.d/mihomo"
SHORTCUT_PATH="/usr/local/bin/mm"
GH_PROXY=""

# =====================================================================
#  自动检测并清理旧脚本 / 智能版本比对升级 mm
# =====================================================================
cleanup_and_update_old_scripts() {
    # 1. 自动清理当前目录下因多次重复下载而残留的 mihomo.sh.1, mihomo.sh.2 等冗余文件
    local current_dir="./"
    for duplicate_file in ${current_dir}mihomo.sh.[0-9]*; do
        if [ -f "$duplicate_file" ]; then
            echo -e "${YELLOW}发现历史冗余下载脚本，正在自动清理: ${duplicate_file}${NC}"
            rm -f "$duplicate_file"
        fi
    done

    # 2. 检测并比对已注册快捷命令 mm 的版本号
    if [ -f "${SHORTCUT_PATH}" ]; then
        # 读取已安装快捷方式的版本号
        local installed_version
        installed_version=$(grep -oE '^SCRIPT_VERSION="[0-9.]+"' "${SHORTCUT_PATH}" | cut -d'"' -f2)
        [ -z "$installed_version" ] && installed_version="未知"

        # 如果当前脚本是通过本地文件运行的
        if [ -f "$0" ] && { [ "$(basename "$0")" = "mihomo.sh" ] || [ "$(basename "$0")" = "mm" ]; }; then
            # 比较版本号或文件内容，不一致则自动覆盖
            if [ "${SCRIPT_VERSION}" != "${installed_version}" ] || ! cmp -s "$0" "${SHORTCUT_PATH}"; then
                echo -e "${YELLOW}检测到本地脚本 (v${SCRIPT_VERSION}) 与系统的快捷命令 (v${installed_version}) 版本不一致。${NC}"
                echo -e "${BLUE}正在自动将快捷命令 'mm' 升级至 v${SCRIPT_VERSION}...${NC}"
                cp -f "$0" "${SHORTCUT_PATH}"
                chmod +x "${SHORTCUT_PATH}"
                echo -e "${GREEN}✔ 快捷命令 'mm' 已成功升级至 v${SCRIPT_VERSION}！${NC}"
            fi
        else
            # 如果是通过管道在线运行，主动抓取远端 GitHub 上的版本号进行比对
            local remote_script="https://raw.githubusercontent.com/Skycnhe/alpine-mihomo/refs/heads/Hk001/mihomo.sh"
            echo -e "${BLUE}正在检测管理脚本远端版本...${NC}"
            
            local remote_version
            remote_version=$(curl -sSL --connect-timeout 5 "${remote_script}" | grep -oE '^SCRIPT_VERSION="[0-9.]+"' | cut -d'"' -f2)
            
            if [ -n "$remote_version" ] && [ "${remote_version}" != "${installed_version}" ]; then
                echo -e "${YELLOW}检测到远端存在更新的管理脚本 (v${remote_version})，当前本地版本 (v${installed_version})。${NC}"
                echo -e "${BLUE}正在从远端同步最新版管理脚本...${NC}"
                if curl -sSL --connect-timeout 8 -o "${SHORTCUT_PATH}.tmp" "${remote_script}"; then
                    mv -f "${SHORTCUT_PATH}.tmp" "${SHORTCUT_PATH}"
                    chmod +x "${SHORTCUT_PATH}"
                    echo -e "${GREEN}✔ 快捷命令 'mm' 已成功从远端升级至 v${remote_version}！${NC}"
                else
                    rm -f "${SHORTCUT_PATH}.tmp"
                    echo -e "${RED}❌ 远端同步失败，已保留当前本地快捷命令。${NC}"
                fi
            fi
        fi
    fi
}

# 设置/清除 GitHub 代理 (已指定为 https://gh-proxy.com/)
set_proxy() {
    echo -e "${YELLOW}选择下载源加速（主要针对国内环境）：${NC}"
    echo "1. 使用 https://gh-proxy.com/ 代理 (推荐)"
    echo "2. 直接从 GitHub 官方下载"
    echo -n "请选择 [1-2]: "
    read -r PROXY_OPT
    if [ "$PROXY_OPT" = "1" ]; then
        GH_PROXY="https://gh-proxy.com/"
        echo -e "${GREEN}✔ 已启用 https://gh-proxy.com/ 加速下载。${NC}"
    else
        GH_PROXY=""
        echo -e "${BLUE}已选择直接从 GitHub 官方拉取。${NC}"
    fi
}

# 自动更换 Alpine 软件源 (APK 源)
change_alpine_mirror() {
    echo -e "${YELLOW}检测到您正在准备安装依赖，是否需要将 Alpine APK 软件源替换为国内加速镜像源？${NC}"
    echo "1. 替换为 清华大学 (Tsinghua) 镜像源 [推荐]"
    echo "2. 替换为 阿里云 (Aliyun) 镜像源"
    echo "3. 替换为 腾讯云 (Tencent) 镜像源"
    echo "4. 保持系统当前默认源 (不修改)"
    echo -n "请选择 [1-4]: "
    read -r MIRROR_OPT
    case "$MIRROR_OPT" in
        1)
            sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
            echo -e "${GREEN}✔ 已成功将系统 APK 源替换为【清华大学】镜像源。${NC}"
            ;;
        2)
            sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
            echo -e "${GREEN}✔ 已成功将系统 APK 源替换为【阿里云】镜像源。${NC}"
            ;;
        3)
            sed -i 's/dl-cdn.alpinelinux.org/mirrors.cloud.tencent.com/g' /etc/apk/repositories
            echo -e "${GREEN}✔ 已成功将系统 APK 源替换为【腾讯云】镜像源。${NC}"
            ;;
        *)
            echo -e "${BLUE}保持系统默认源不变。${NC}"
            ;;
    esac
}

# 自动下载缺少的系统软件与依赖 (已添加 gcompat 和 iproute2 提升运行兼容性)
install_dependencies() {
    echo -e "${BLUE}正在同步 APK 软件包并安装依赖 (curl, gzip, unzip, ca-certificates, gcompat, iproute2)...${NC}"
    apk update >/dev/null 2>&1
    apk add --no-cache curl gzip unzip ca-certificates tzdata gcompat iproute2 >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}依赖安装失败，请检查您的网络连接或尝试在菜单中先执行换源操作。${NC}"
        exit 1
    fi
    echo -e "${GREEN}依赖组件准备完毕。${NC}"
}

# 自动检测 CPU 架构并适配 LXC
detect_arch() {
    ARCH_RAW=$(uname -m)
    case "${ARCH_RAW}" in
        x86_64) 
            ARCH="amd64-compatible" 
            ;; 
        aarch64|arm64) 
            ARCH="arm64" 
            ;;
        armv7l|armv7) 
            ARCH="armv7" 
            ;;
        i386|i686) 
            ARCH="386" 
            ;;
        *)
            echo -e "${RED}不支持的 CPU 架构: ${ARCH_RAW}${NC}"
            exit 1
            ;;
    esac
    echo -e "${GREEN}检测到系统架构: ${ARCH_RAW} -> 适配内核: ${ARCH}${NC}"
}

# 获取最新 Mihomo Version
get_latest_version() {
    echo -e "${BLUE}正在从 GitHub 获取最新内核版本...${NC}"
    LATEST_TAG=$(curl -s --connect-timeout 5 https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep -oE '"tag_name": "[^"]+"' | head -n1 | cut -d'"' -f4)
    if [ -z "$LATEST_TAG" ]; then
        LATEST_TAG="v1.19.28" # 默认 fallback 稳定版
        echo -e "${YELLOW}动态获取失败，将使用内置兜底版本: ${LATEST_TAG}${NC}"
    else
        echo -e "${GREEN}获取到最新版本: ${LATEST_TAG}${NC}"
    fi
}

# 下载并替换内核二进制
download_binary() {
    echo -e "${BLUE}正在下载运行文件 (${ARCH})...${NC}"
    DOWNLOAD_URL="${GH_PROXY}https://github.com/MetaCubeX/mihomo/releases/download/${LATEST_TAG}/mihomo-linux-${ARCH}-${LATEST_TAG}.gz"
    
    curl -L -o /tmp/mihomo.gz "${DOWNLOAD_URL}"
    if [ ! -f /tmp/mihomo.gz ] || [ $(wc -c < /tmp/mihomo.gz) -lt 5000 ]; then
        echo -e "${RED}内核下载损坏或超时，请检查您的网络连接或尝试开启镜像代理。${NC}"
        rm -f /tmp/mihomo.gz
        exit 1
    fi

    gzip -d -f /tmp/mihomo.gz
    mv /tmp/mihomo "${BINARY_PATH}"
    chmod +x "${BINARY_PATH}"
    
    if [ ! -x "${BINARY_PATH}" ]; then
        echo -e "${RED}二进制文件校验失败。${NC}"
        exit 1
    fi
    echo -e "${GREEN}Mihomo 主程序下载并部署成功。${NC}"
}

# 创建 OpenRC 服务
create_service() {
    echo -e "${BLUE}正在构建 OpenRC 服务控制流...${NC}"
    
    cat << 'EOF' > "${SERVICE_PATH}"
#!/sbin/openrc-run

name="mihomo"
description="Mihomo (formerly Clash Meta) Service"

command="/usr/local/bin/mihomo"
command_args="-d /etc/mihomo"
command_background="yes"
pidfile="/run/mihomo.pid"
output_log="/var/log/mihomo.log"
error_log="/var/log/mihomo.log"

depend() {
    need net
    after firewall
}

start_pre() {
    if [ ! -d "/etc/mihomo" ]; then
        mkdir -p /etc/mihomo
    fi
    touch /var/log/mihomo.log
}
EOF

    chmod +x "${SERVICE_PATH}"
    rc-update add mihomo default >/dev/null 2>&1
    echo -e "${GREEN}已将 Mihomo 注册至系统自启动级别 (default)。${NC}"
}

# 从指定的 GitHub URL 拉取配置模板
setup_config() {
    mkdir -p "${CONFIG_DIR}"
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "${BLUE}正在拉取指定的配置模板...${NC}"
        TEMPLATE_URL="${GH_PROXY}https://raw.githubusercontent.com/Skycnhe/alpine-mihomo/refs/heads/Hk001/Configuration%20profile/config.yaml"
        
        curl -L -s --connect-timeout 10 -o "${CONFIG_FILE}" "${TEMPLATE_URL}"
        
        if [ ! -f "${CONFIG_FILE}" ] || [ $(wc -c < "${CONFIG_FILE}") -lt 200 ]; then
            echo -e "${RED}❌ 在线模板拉取失败或模板不合规，正在创建极简备用配置兜底...${NC}"
            cat << 'EOF' > "${CONFIG_FILE}"
# 备用本地配置模版
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
external-controller: '0.0.0.0:9090'
secret: '123456'

proxies:
  - name: "Direct_Sample"
    type: direct

proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - Direct_Sample

rules:
  - MATCH,Proxy
EOF
            echo -e "${YELLOW}✔ 已写入备用配置。您稍后可以尝试手动更新配置文件。${NC}"
        else
            echo -e "${GREEN}✔ 已成功下载并应用您指定的在线配置模板！${NC}"
        fi
    else
        echo -e "${BLUE}配置文件 ${CONFIG_FILE} 已存在，跳过覆盖。${NC}"
    fi
}

# 创建快捷命令 mm
add_shortcut() {
    if [ -f "$0" ] && [ "$(basename "$0")" = "mihomo.sh" ]; then
        cp "$0" "${SHORTCUT_PATH}"
        chmod +x "${SHORTCUT_PATH}"
        echo -e "${GREEN}✔ 快捷命令创建成功：可通过在终端输入 'mm' 快速启动此管理面板。${NC}"
    else
        # 兼容直接在线管道运行的情况，从 GitHub 抓取最新版本并写入快捷命令
        echo -e "${BLUE}由于您当前是在线直接运行，正在自动部署最新版管理程序至本地快捷命令...${NC}"
        local remote_script="https://raw.githubusercontent.com/Skycnhe/alpine-mihomo/refs/heads/Hk001/mihomo.sh"
        curl -sSL -o "${SHORTCUT_PATH}" "${remote_script}"
        if [ -f "${SHORTCUT_PATH}" ]; then
            chmod +x "${SHORTCUT_PATH}"
            echo -e "${GREEN}✔ 快捷命令部署成功！您可以在终端随时输入 'mm' 调出管理面板。${NC}"
        fi
    fi
}

# 1. 主安装流程
install_mihomo() {
    change_alpine_mirror  
    set_proxy
    install_dependencies  
    detect_arch
    get_latest_version
    download_binary
    create_service
    setup_config
    add_shortcut
    echo -e "\n${GREEN}===============================================${NC}"
    echo -e "${GREEN}            Mihomo 一键部署安装完成！           ${NC}"
    echo -e "${GREEN}===============================================${NC}"
}

# 2. 内核升级
update_mihomo() {
    if [ ! -f "${BINARY_PATH}" ]; then
        echo -e "${RED}检测到您未安装 Mihomo，请先执行“1”进行安装。${NC}"
        return
    fi
    set_proxy
    detect_arch
    get_latest_version
    
    CURRENT_VER=$("${BINARY_PATH}" -v | head -n1 | awk '{print $3}')
    echo -e "当前已安装版本: ${CURRENT_VER}"
    echo -e "官方最新发布版: ${LATEST_TAG}"
    
    if [ "$CURRENT_VER" = "$LATEST_TAG" ]; then
        echo -e "${GREEN}您当前的程序已是最新版本，无需额外升级。${NC}"
        return
    fi
    
    echo -e "${YELLOW}开始拉取升级...${NC}"
    rc-service mihomo stop >/dev/null 2>&1
    download_binary
    rc-service mihomo start >/dev/null 2>&1
    echo -e "${GREEN}内核平滑升级并重新拉起服务成功！${NC}"
}

# 3. 导入在线配置 / 订阅
import_config() {
    echo -e "${YELLOW}请输入要导入的配置文件 / 订阅直链 URL：${NC}"
    read -r SUB_URL
    if [ -z "$SUB_URL" ]; then
         echo -e "${RED}输入为空，取消操作。${NC}"
         return
    fi
    
    echo -e "${YELLOW}这会覆盖当前存在的 ${CONFIG_FILE}，确认覆盖吗？[y/N]: ${NC}"
    read -r CONFIRM
    case "$CONFIRM" in
        [yY]|[yY][eE][sS])
            echo -e "${BLUE}正在建立连接并下载新配置文件...${NC}"
            curl -L -s --connect-timeout 10 -o /tmp/mihomo_temp.yaml "${SUB_URL}"
            if [ ! -f /tmp/mihomo_temp.yaml ] || [ $(wc -c < /tmp/mihomo_temp.yaml) -lt 50 ]; then
                echo -e "${RED}下载失败或配置文件内容不合规（太小），未对原配置进行任何变动。${NC}"
                rm -f /tmp/mihomo_temp.yaml
                return
            fi
            
            mv -f /tmp/mihomo_temp.yaml "${CONFIG_FILE}"
            echo -e "${GREEN}配置文件成功导入并替换！${NC}"
            check_config_syntax
            ;;
        *)
            echo -e "${YELLOW}已取消导入。${NC}"
            ;;
    esac
}

# 4. 配置语法校验
check_config_syntax() {
    if [ ! -f "${BINARY_PATH}" ]; then
        echo -e "${RED}未检测到安装的内核程序。${NC}"
        return
    fi
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo -e "${RED}配置文件 ${CONFIG_FILE} 不存在。${NC}"
        return
    fi
    echo -e "${BLUE}正在校验 ${CONFIG_FILE} 文件语法合法性...${NC}"
    "${BINARY_PATH}" -t -d "${CONFIG_DIR}"
    if [ $? -eq 0 ]; then
         echo -e "${GREEN}✔ [Success] 配置文件语法校验通过，无任何语法错误！${NC}"
    else
         echo -e "${RED}✘ [Error] 配置文件校验未通过，请按上面输出的提示进行修正。${NC}"
    fi
}

# 5. 安装/更新 Web 仪表盘 (多面板选择支持)
install_dashboard() {
    echo -e "${YELLOW}选择要安装的 Web 仪表盘面板：${NC}"
    echo "1. MetaCubeXD 面板 (Mihomo 推荐，功能极其丰富)"
    echo "2. Yacd-meta 面板 (经典 Yacd 修改版，适配 Clash Meta/Mihomo 规则)"
    echo "3. Clash-dashboard 面板 (传统经典面板，极简轻量)"
    echo "4. Zashboard 面板 (现代化、响应式，体验出色的新生代多后端面板)"
    echo "5. 返回主菜单"
    echo -n "请选择 [1-5]: "
    read -r DB_OPT

    case "$DB_OPT" in
        1)
            DB_NAME="MetaCubeXD"
            REPO_URL="https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
            DIR_NAME="metacubexd-gh-pages"
            ;;
        2)
            DB_NAME="Yacd-meta"
            REPO_URL="https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"
            DIR_NAME="Yacd-meta-gh-pages"
            ;;
        3)
            DB_NAME="Clash-dashboard"
            REPO_URL="https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip"
            DIR_NAME="clash-dashboard-gh-pages"
            ;;
        4)
            DB_NAME="Zashboard"
            REPO_URL="https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
            DIR_NAME="zashboard-gh-pages"
            ;;
        *)
            echo -e "${BLUE}已取消面板安装。${NC}"
            return
            ;;
    esac

    echo -e "${BLUE}正在处理 Web UI 仪表盘依赖...${NC}"
    apk add --no-cache unzip >/dev/null 2>&1
    set_proxy
    
    UI_DIR="${CONFIG_DIR}/ui"
    ZIP_URL="${GH_PROXY}${REPO_URL}"
    
    echo -e "${BLUE}正在下载 ${DB_NAME} 面板静态包...${NC}"
    curl -L -o /tmp/dashboard_temp.zip "${ZIP_URL}"
    
    if [ ! -f /tmp/dashboard_temp.zip ] || [ $(wc -c < /tmp/dashboard_temp.zip) -lt 5000 ]; then
         echo -e "${RED}下载仪表盘资源包失败，请检查网络或更换加速代理重试。${NC}"
         rm -f /tmp/dashboard_temp.zip
         return
    fi
    
    echo -e "${BLUE}正在进行解压和部署...${NC}"
    # 安全起见，解压前彻底清理旧的临时解压目录，防止路径合并错误
    rm -rf "/tmp/${DIR_NAME}"
    unzip -q -o /tmp/dashboard_temp.zip -d /tmp
    
    if [ -d "/tmp/${DIR_NAME}" ]; then
         rm -rf "${UI_DIR}"
         mv "/tmp/${DIR_NAME}" "${UI_DIR}"
         echo -e "${GREEN}Web 仪表盘 (${DB_NAME}) 已成功部署于：${UI_DIR}${NC}"
    else
         echo -e "${RED}面板提取资源失败，包结构可能不合规。${NC}"
         rm -rf "/tmp/${DIR_NAME}" /tmp/dashboard_temp.zip
         return
    fi
    rm -f /tmp/dashboard_temp.zip
    
    if [ -f "${CONFIG_FILE}" ]; then
         if grep -q "external-ui:" "${CONFIG_FILE}"; then
              echo -e "${YELLOW}检测到配置文件中已存在 external-ui 条目，请确保其路径被定义为 'ui'。${NC}"
         else
              echo "" >> "${CONFIG_FILE}"
              echo "external-controller: '0.0.0.0:9090'" >> "${CONFIG_FILE}"
              echo "external-ui: 'ui'" >> "${CONFIG_FILE}"
              echo -e "${GREEN}已成功为您追加外部控制器及面板启用项配置。${NC}"
         fi
    fi
}

# 6. 下载/更新规则数据包 Geodata
download_geodata() {
    mkdir -p "${CONFIG_DIR}"
    set_proxy
    echo -e "${BLUE}准备从 MetaCubeX 数据库同步 Geodata 规则库...${NC}"
    
    GEOIP_URL="${GH_PROXY}https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat"
    GEOSITE_URL="${GH_PROXY}https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"
    MMDB_URL="${GH_PROXY}https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country-lite.mmdb"
    
    echo -e "${BLUE}1. 下载 Country.mmdb...${NC}"
    curl -L -o "${CONFIG_DIR}/Country.mmdb" "${MMDB_URL}"
    echo -e "${BLUE}2. 下载 geoip.dat...${NC}"
    curl -L -o "${CONFIG_DIR}/geoip.dat" "${GEOIP_URL}"
    echo -e "${BLUE}3. 下载 geosite.dat...${NC}"
    curl -L -o "${CONFIG_DIR}/geosite.dat" "${GEOSITE_URL}"
    
    echo -e "${GREEN}规则数据库下载更新完毕。${NC}"
}

# 7. 一键配置并开启系统级 TUN 模式支持
enable_tun_mode() {
    echo -e "${BLUE}开始配置系统级 TUN 模式支持...${NC}"
    
    if [ ! -c /dev/net/tun ]; then
        echo -e "${BLUE}正在尝试手动加载 tun 内核模块...${NC}"
        modprobe tun >/dev/null 2>&1
    fi
    
    if [ ! -c /dev/net/tun ]; then
        echo -e "${RED}❌ 警告：未检测到系统的 /dev/net/tun 设备！${NC}"
        echo -e "${YELLOW}如果您是在 Proxmox VE (PVE) 等虚拟化 LXC 容器内运行 Alpine，${NC}"
        echo -e "${YELLOW}非特权 LXC 默认无权加载该虚拟网卡，请务必在【PVE 宿主机】修改本容器的配置：${NC}"
        echo -e "${BLUE}  在宿主机的 /etc/pve/lxc/<容器ID>.conf 中，加入以下内容以放行 TUN 设备挂载：${NC}"
        echo -e "  --------------------------------------------------"
        echo -e "  lxc.cgroup2.devices.allow: c 10:200 rwm"
        echo -e "  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"
        echo -e "  --------------------------------------------------"
        echo -e "按 [回车键] 强制继续系统配置（建议稍后按上面步骤配置宿主机）...${NC}"
        read -r
    else
        echo -e "${GREEN}✔ 已确认系统存在 /dev/net/tun 设备。${NC}"
    fi
    
    if [ -f /etc/modules ]; then
        if ! grep -q "^tun" /etc/modules; then
            echo "tun" >> /etc/modules
            echo -e "${GREEN}✔ 已将 'tun' 写入 /etc/modules，实现开机自动加载。${NC}"
        fi
    fi
    
    echo -e "${BLUE}正在开启系统内核转发 (IP Forwarding)...${NC}"
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1
    for key in "net.ipv4.ip_forward" "net.ipv6.conf.all.forwarding"; do
        if grep -q "^${key}" /etc/sysctl.conf; then
            sed -i "s/^${key}.*/${key} = 1/" /etc/sysctl.conf
        else
            echo "${key} = 1" >> /etc/sysctl.conf
        fi
    done
    echo -e "${GREEN}✔ 系统内核 IP 转发已永久开启（修改 sysctl.conf 完成）。${NC}"
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        setup_config
    fi
    
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak"
    echo -e "${YELLOW}已为您备份当前配置文件至 ${CONFIG_FILE}.bak${NC}"
    
    if grep -q "^tun:" "${CONFIG_FILE}"; then
        echo -e "${YELLOW}检测到您当前的 config.yaml 中已经包含 'tun:' 标记，脚本已跳过自动追加。${NC}"
        echo -e "${YELLOW}请手动确认其中的配置已经含有: enable: true 且 auto-route: true。${NC}"
    else
        cat << 'EOF' >> "${CONFIG_FILE}"

# === 以下由一键脚本自动追加的 TUN 模式及 DNS 劫持配置 ===
tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-redirect: true
  auto-detect-interface: true
  dns-hijack:
    - "any:53"

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
# === TUN 配置结束 ===
EOF
        echo -e "${GREEN}✔ 成功将 TUN 模式与高性能内置 DNS 规则追加到：${CONFIG_FILE}${NC}"
    fi
    
    check_config_syntax
    
    echo -e "\n${GREEN}TUN 模式一键开启与适配成功！${NC}"
    echo -e "请注意：如果您系统已经运行了其他占用 53 端口的服务（如 dnsmasq），可能会产生冲突导致启动失败。"
    echo -e "提示：您需要【重启服务】才能令 TUN 模式生效：${YELLOW}rc-service mihomo restart${NC}"
}

# 实时日志追踪
view_live_logs() {
    if [ ! -f /var/log/mihomo.log ]; then
         echo -e "${RED}当前系统未产生任何日志。${NC}"
         return
    fi
    echo -e "${YELLOW}正在查看日志流，按键盘 [Ctrl + C] 可退出追踪日志...${NC}"
    tail -f /var/log/mihomo.log
}

# 清理日志文件
truncate_logs() {
    if [ -f /var/log/mihomo.log ]; then
         echo -n "" > /var/log/mihomo.log
         echo -e "${GREEN}日志文件已清空重置。${NC}"
    else
         echo -e "${YELLOW}未发现待清理的日志文件。${NC}"
    fi
}

# 卸载服务
uninstall_mihomo() {
    echo -e "${RED}警告：确认完全移除所有 Mihomo 主程序和运行状态吗？ [y/N]: ${NC}"
    read -r CONFIRM
    case "$CONFIRM" in
        [yY]|[yY][eE][sS])
            rc-service mihomo stop >/dev/null 2>&1
            rc-update del mihomo default >/dev/null 2>&1
            rm -f "${BINARY_PATH}"
            rm -f "${SERVICE_PATH}"
            rm -f "${SHORTCUT_PATH}"
            rm -f /var/log/mihomo.log
            
            echo -e "${RED}是否同时删除本地配置文件和面板目录 (${CONFIG_DIR})？ [y/N]: ${NC}"
            read -r CONFIRM_DIR
            if [ "$CONFIRM_DIR" = "y" ] || [ "$CONFIRM_DIR" = "Y" ]; then
                 rm -rf "${CONFIG_DIR}"
                 echo -e "${GREEN}配置目录已一并清理。${NC}"
            fi
            echo -e "${GREEN}已成功卸载并清除服务。${NC}"
            ;;
        *)
            echo -e "${YELLOW}已取消。${NC}"
            ;;
    esac
}

# 手动执行换源服务入口
manual_change_mirror() {
    change_alpine_mirror
    echo -e "${BLUE}正在使用新源进行索引测试...${NC}"
    apk update
    echo -e "${GREEN}源配置更新完毕。${NC}"
}

# 获取实时进程状态
get_status() {
    if pgrep -x "mihomo" >/dev/null; then
         STATUS_TEXT="${GREEN}运行中 (RUNNING)${NC}"
    else
         STATUS_TEXT="${RED}已停止 (STOPPED)${NC}"
    fi
    
    if [ -f "${BINARY_PATH}" ]; then
         VERSION_TEXT=$("${BINARY_PATH}" -v | head -n1 | awk '{print $3}')
    else
         VERSION_TEXT="未安装"
    fi
}

# 渲染主面板
show_menu() {
    get_status
    clear
    echo -e "${GREEN}====================================================${NC}"
    echo -e "     Alpine Linux Mihomo 整合管理脚本 (v${SCRIPT_VERSION})      "
    echo -e "${GREEN}====================================================${NC}"
    echo -e "  服务状态: ${STATUS_TEXT}    |  已装版本: ${BLUE}${VERSION_TEXT}${NC}"
    echo -e "  主配置文件: ${CONFIG_FILE}"
    echo -e "${GREEN}====================================================${NC}"
    echo -e "  1.  安装部署 Mihomo (包含系统自动换源与缺失依赖下载)"
    echo -e "  2.  在线检测并升级内核"
    echo -e "  3.  导入在线配置文件 / 订阅链接"
    echo -e "  4.  一键校验当前配置文件语法"
    echo -e "  5.  安装/升级 Web 仪表盘 (支持多种面板选择)"
    echo -e "  6.  同步/更新 Geo 数据规则库 (GeoIP/GeoSite)"
    echo -e "  7.  一键配置并开启系统级 TUN 模式支持 (核心功能)"
    echo -e "  8.  手动更换/恢复 Alpine 系统 APK 软件源"
    echo -e "----------------- 状态管理服务 --------------------"
    echo -e "  9.  启动服务 (Start)"
    echo -e "  10. 停止服务 (Stop)"
    echo -e "  11. 重启服务 (Restart)"
    echo -e "  12. 查看实时追踪日志 (Live Log)"
    echo -e "  13. 清理重置本地日志"
    echo -e "  14. 一键完全卸载程序"
    echo -e "  15. 退出脚本"
    echo -e "${GREEN}====================================================${NC}"
    echo -n "请键入对应项 [1-15]: "
}

# =====================================================================
#  脚本启动入口
# =====================================================================

# 1. 自动执行旧脚本清理及快捷方式智能版本比对
cleanup_and_update_old_scripts

# 2. 进入菜单主循环
while true; do
    show_menu
    read -r OPTION
    case "$OPTION" in
        1) install_mihomo ;;
        2) update_mihomo ;;
        3) import_config ;;
        4) check_config_syntax ;;
        5) install_dashboard ;;
        6) download_geodata ;;
        7) enable_tun_mode ;;
        8) manual_change_mirror ;;
        9) rc-service mihomo start ;;
        10) rc-service mihomo stop ;;
        11) rc-service mihomo restart ;;
        12) view_live_logs ;;
        13) truncate_logs ;;
        14) uninstall_mihomo ;;
        15) echo -e "${GREEN}已安全退出。${NC}"; exit 0 ;;
        *) echo -e "${RED}输入无效，请输入 1 至 15 范围内的编号。${NC}" ;;
    esac
    echo -e "\n请按 [回车键] 再次返回主控面板..."
    read -r
done
