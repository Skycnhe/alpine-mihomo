# Mihomo Alpine Linux & LXC 一键管理脚本

本脚本专为 Alpine Linux 环境（包括 Proxmox VE 下的 LXC 容器）设计，提供了一套轻量级的 Mihomo（原 Clash Meta）一键部署、运行与维护方案。脚本基于 OpenRC 初始化系统注册服务，并支持自定义 GitHub 模板拉取及系统级 TUN 模式的自动化适配。

## 核心功能

- **自动换源与依赖处理**：支持将 Alpine APK 软件源一键切换为国内镜像源（清华/阿里/腾讯），并自动补充 `curl`、`gzip`、`unzip`、`ca-certificates` 等必要依赖。
- **自定义配置模板**：支持在脚本中预设您自定义的 GitHub Raw 配置直链。部署时将优先拉取该配置，拉取失败时自动降级使用脚本内置的本地基础模板。
- **网络加速可选**：集成了 `gh-proxy.com` 下载代理，有效解决国内环境下 GitHub 核心文件或资源包下载超时的问题。
- **系统级 TUN 模式支持**：自动加载 tun 内核模块并设置开机自启，永久开启系统内核 IP 转发（修改 `sysctl.conf`），并向配置文件自动追加高性能内置 DNS 与流量劫持规则。
- **Web UI 面板集成**：支持一键下载、部署及升级 MetaCubeXD 仪表盘。
- **完整的服务控制**：
  - OpenRC 系统服务注册与开机自启配置。
  - 服务的启动、停止、重启与状态实时监控。
  - 规则数据包（GeoIP / GeoSite / Country.mmdb）在线同步。
  - 实时日志流追踪（Live Log）与日志清空。
  - 在线订阅链接导入与配置文件语法合法性校验。

## 目录结构

部署成功后，系统文件布局如下：

| 文件/目录路径 | 说明 |
| :--- | :--- |
| `/usr/local/bin/mihomo` | Mihomo 核心二进制程序 |
| `/etc/mihomo` | 配置文件及相关资源目录 |
| `/etc/mihomo/config.yaml` | 主配置文件 |
| `/etc/mihomo/ui` | Web 仪表盘静态资源目录 |
| `/etc/init.d/mihomo` | OpenRC 服务控制脚本 |
| `/var/log/mihomo.log` | 运行日志文件 |

## 快速开始

### 国外环境
```bash
curl -sSL -o mihomo.sh https://raw.githubusercontent.com/Skycnhe/alpine-mihomo/refs/heads/Hk001/mihomo.sh && chmod +x mihomo.sh && ./mihomo.sh