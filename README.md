# Alpine Linux & LXC Mihomo 一键管理脚本

这是一个专为 **Alpine Linux**（包含物理机、虚拟机、搭载 ARMv8/AArch64 的单板电脑）以及 **Proxmox VE (PVE) LXC 容器** 环境深度定制的 Mihomo（原 Clash.Meta）一键安装与管理脚本。

由于 Alpine 默认采用极简的 OpenRC 初始化系统且环境非常精简，常规的 systemd 一键脚本无法在此类系统运行。本脚本通过纯正的 POSIX Shell 编写，并针对虚拟化容器隔离环境进行了多项兼容性优化。

---

## 🌟 核心特性

- **架构自动适配**：自动识别并下载对应架构内核。在 x86_64 环境下默认拉取 `amd64-compatible`（兼容版）内核，避开 GOAMD64 v3 指令集限制，防止在 LXC 虚拟化 CPU 下发生 `Illegal instruction`（非法指令）闪退 [1]。
- **原生 OpenRC 服务集成**：无缝对接 Alpine 原生 OpenRC 系统服务（`/etc/init.d/mihomo`），支持开机自启、优雅启停、日志重定向，无需安装任何 Systemd 兼容层。
- **一键 TUN 模式支持**：自动处理 `tun` 内核模块的加载、永久开启 IPv4/IPv6 内核转发，并可自动向配置文件中安全追加 TUN 配置及 DNS 劫持规则。
- **LXC 容器特殊优化**：在 TUN 部署阶段，脚本能自动检测 LXC 的网卡设备隔离情况。若检测到权限缺失，会精准给出 PVE 宿主机的配置修改提示。
- **图形化 Web 面板**：一键拉取并部署 MetaCubeXD 面板静态资源（放置于 `/etc/mihomo/ui`），无需运行多余的服务进程 [1.1.3]。
- **Geodata 规则同步**：集成最新版 GeoIP / GeoSite / Country.mmdb 路由规则数据库的一键同步与更新。
- **实用维护功能**：支持在线导入订阅/自定义配置、语法校验、实时追踪运行日志（tail -f）等。

---

## 🚀 快速开始

在 Alpine Linux 终端中运行以下命令即可：

```bash
# 1. 如果是极简 Alpine 模板，建议先确保安装了下载工具 curl
apk add --no-cache curl

# 2. 下载并启动一键管理脚本
curl -sSL -o mihomo.sh https://raw.githubusercontent.com/<你的用户名>/<你的仓库名>/main/mihomo.sh && chmod +x mihomo.sh && ./mihomo.sh
🛠 PVE LXC 容器环境部署 TUN 模式特殊说明
在非特权的 LXC 容器内，Mihomo 默认无权创建 TUN 虚拟网卡设备 /dev/net/tun。如果您需要开启 TUN 模式（即作透明网关、旁路由使用），请严格按照以下步骤操作：
1. 修改 PVE 宿主机中的容器配置文件
登录您的 PVE 宿主机终端（而不是 Alpine 容器内部），编辑该容器对应的配置文件：
code
Bash
nano /etc/pve/lxc/<您的容器ID>.conf
在文件末尾追加以下两行，用于将宿主机的 TUN 设备挂载共享进容器，并赋予读写控制权限：
code
Ini
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
2. 重启容器并配置
保存配置文件并重启该 LXC 容器。随后进入 Alpine 容器内，运行本脚本并选择 7（一键配置并开启系统级 TUN 模式支持），然后选择重启服务即可。
💡 作为局域网旁路由 / 网关的使用方法
当您成功开启 TUN 模式并将服务运行起来后，您可以将该 Alpine 设备作为局域网内的“旁路由”：
设置客户端网关：将手机、电脑或主路由的 Gateway（网关/路由器） 改为该 Alpine 的 IP 地址。
设置客户端 DNS：将客户端的 DNS 服务器 地址同样指向该 Alpine 的 IP 地址（Mihomo 会自动劫持 53 端口处理 DNS 请求）。
⚠️ 注意：如果 Alpine 系统上已经安装并启用了 dnsmasq、unbound 或 bind 等占用 53 端口的服务，请先将其停止，否则 Mihomo 的内置 DNS 服务将无法顺利绑定。
📁 文件结构与路径
程序路径：/usr/local/bin/mihomo
配置目录：/etc/mihomo
配置文件：/etc/mihomo/config.yaml
面板目录：/etc/mihomo/ui
系统服务：/etc/init.d/mihomo
运行日志：/var/log/mihomo.log
⚖ 免责声明与致谢
本脚本仅作为系统部署与运维辅助工具，不提供任何网络节点。
感谢 MetaCubeX/mihomo 提供的优秀开源内核。
