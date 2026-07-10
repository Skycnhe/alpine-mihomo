# Alpine Linux & LXC Mihomo 一键管理脚本

这是一个专为 **Alpine Linux**（支持物理机、虚拟机、搭载 ARMv8/AArch64 的单板电脑）以及 **Proxmox VE (PVE) LXC 容器**环境深度定制的 Mihomo（原 Clash.Meta）一键安装与维护脚本。

由于 Alpine 默认采用极简的 OpenRC 初始化系统，且环境极度精简，本脚本通过纯正的 POSIX Shell 编写，并针对虚拟化容器隔离环境进行了多项兼容性优化与排坑适配。

---

## 🌟 核心特性

- **架构自动适配**：自动识别并下载对应架构内核。在 x86_64 环境下默认拉取 `amd64-compatible`（兼容版）内核，避开 GOAMD64 v3 指令集限制，防止在 LXC 虚拟化 CPU 下发生 `Illegal instruction`（非法指令）闪退 [1]。
- **原生 OpenRC 服务集成**：无缝对接 Alpine 原生 OpenRC 系统服务（`/etc/init.d/mihomo`），支持开机自启、优雅启停、日志重定向，无需安装任何 Systemd 兼容层。
- **一键 TUN 网关模式**：自动处理 `tun` 内核模块加载、永久开启 IPv4/IPv6 内核转发，并自动向配置文件中安全追加高性能 TUN 配置及 DNS 劫持规则。
- **LXC 容器特殊优化**：在 TUN 部署阶段，脚本能自动检测 LXC 的网卡设备隔离情况。若检测到权限缺失，会精准给出 PVE 宿主机的配置修改提示。
- **图形化 Web 面板**：一键拉取并部署 MetaCubeXD 面板静态资源（放置于 `/etc/mihomo/ui`），无需运行多余的服务进程 [1.1.3]。
- **Geodata 规则同步**：集成最新版 GeoIP / GeoSite / Country.mmdb 路由规则数据库的一键同步与更新。

---

## 🚀 快速开始

在 Alpine Linux 终端中运行以下命令即可：

```bash
# 1. 如果是极简 Alpine 模板，建议先确保安装了下载工具 curl
apk add --no-cache curl

# 2. 下载并启动一键管理脚本
curl -sSL -o mihomo.sh https://raw.githubusercontent.com/Skycnhe/alpine-mihomo/main/mihomo.sh && chmod +x mihomo.sh && ./mihomo.sh

📁 文件结构与默认路径
内核程序路径：/usr/local/bin/mihomo
配置与数据目录：/etc/mihomo
主配置文件：/etc/mihomo/config.yaml
静态规则数据库：/etc/mihomo/Country.mmdb（及 geoip.dat/geosite.dat）
Web 仪表盘目录：/etc/mihomo/ui
系统服务脚本：/etc/init.d/mihomo
运行日志文件：/var/log/mihomo.log
