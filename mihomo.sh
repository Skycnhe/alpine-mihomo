#!/bin/sh

# =====================================================================
#  Mihomo (Clash Meta) Alpine Linux & LXC 整合管理脚本 (无感自更新版)
# =====================================================================

# 脚本版本号定义
SCRIPT_VERSION="1.2.1"

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
#  非交互命令行参数支持（供自动定时任务等调用）
# =====================================================================
if [ -n "$1" ]; then
    case "$1" in
        "update-geodata")
            # 定时任务静默更新规则库，默认启用代理以防网络受限
            GH_PROXY="https://gh-proxy.com/"
            download_geodata
            exit 0
            ;;
        *)
            # 默认继续执行后面流程
            ;;
    esac
fi

# =====================================================================
#  自动拉取管理面板最新版本 / 自动覆盖旧面板并热重载
# =====================================================================
cleanup_and_update_old_scripts() {
    # 1. 自动清理当前目录下重复下载的冗余文件
    local current_dir="./"
    for duplicate_file in ${current_dir}mihomo.sh.[0-9]*; do
        if [ -f "$duplicate_file" ]; then
            echo -e "${YELLOW}发现历史冗余下载脚本，正在自动清理: ${duplicate_file}${NC}"
            rm -f "$duplicate_file"
        fi
    done

    # 2. 自动检索远端 GitHub 面板版本
    local remote_script="https://raw.githubusercontent.com/Skycnhe/alpine-mihomo/refs/heads/Hk001/mihomo.sh"
    
    # 默认尝试使用 gh-proxy 加速代理检测
    local check_url="https://gh-proxy.com/${remote_script}"
    
    echo -e "${BLUE}正在检查面板更新 (自动拉取最新版本)...${NC}"
    
    # 快速获取远端版本号 (限制 2 秒超时，防止无网卡顿)
    local remote_version
    remote_version=$(curl -sSL --connect-timeout 2 "${check_url}" | grep -oE '^SCRIPT_VERSION="[0-9.]+"' | cut -d'"' -f2)
    
    # 如果通过代理获取失败，尝试直连获取一次
    if [ -z "$remote_version" ]; then
        remote_version=$(curl -sSL --connect-timeout 2 "${remote_script}" | grep -oE '^SCRIPT_VERSION="[0-9.]+"' | cut -d'"' -f2)
        if [ -n "$remote_version" ]; then
            check_url="${remote_script}"
        fi
    fi

    # 比对版本，发现新版本则自动拉取覆盖旧面板并重启
    if [ -n "$remote_version" ] && [ "${remote_version}" != "${SCRIPT_VERSION}" ]; then
        echo -e "${YELLOW}检测到新版面板 (v${remote_version})，正在自动拉取并覆盖旧面板...${NC}"
        local temp_script="/tmp/mihomo_auto_update.sh"
        if curl -sSL --connect-timeout 5 -o "${temp_script}" "${check_url}"; then
            if grep -q '^SCRIPT_VERSION=' "${temp_script}"; then
                # 自动覆盖系统快捷命令 mm
                cp -f "${temp_script}" "${SHORTCUT_PATH}"
                chmod +x "${SHORTCUT_PATH}"
                
                # 自动覆盖当前运行的源脚本文件
                if [ -f "$0" ] && [ "$(basename "$0")" != "sh" ] && [ "$(basename "$0")" != "ash" ]; then
                    cp -f "${temp_script}" "$0"
                    chmod +x "$0"
                fi
                rm -f "${temp_script}"
                echo -e "${GREEN}✔ 面板已成功自动覆盖升级至 v${remote_version}！正在热重载...${NC}"
                sleep 1
                exec sh "$0" "$@" || exit 0
            fi
        fi
        rm