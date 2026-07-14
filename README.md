# Mihomo Alpine Linux & LXC 一键管理脚本

本脚本专为 Alpine Linux 环境（包括 Proxmox VE 下的 LXC 容器）设计，提供轻量级的 Mihomo（原 Clash Meta）一键部署、运行与维护方案。基于 OpenRC 初始化系统，支持自定义 GitHub 模板拉取及系统级 TUN 模式自动适配。

---

## 核心功能

* **自动换源与依赖处理**：支持将 Alpine APK 软件源一键切换为国内镜像源（清华/阿里/腾讯），并自动补充 `curl`、`gzip`、`unzip`、`ca-certificates` 等必要依赖。
* **自定义配置模板**：支持预设自定义的 GitHub Raw 配置直链。部署时优先拉取该配置，失败时自动降级使用内置的本地基础模板。
* **网络加速支持**：集成 `gh-proxy.com` 代理，解决国内环境下下载 GitHub 核心文件超时的问题。
* **系统级 TUN 模式**：自动加载 `tun` 内核模块并设置开机自启，开启系统内核 IP 转发（自动修改 `sysctl.conf`），并自动追加内置 DNS 与流量劫持规则。
* **Web UI 面板集成**：支持一键部署及升级 MetaCubeXD 仪表盘。
* **服务管理**：支持基于 OpenRC 的开机自启、启动、停止、重启、日志追踪、订阅更新及配置校验。

---

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

---

## 快速开始

请根据您的网络环境选择以下命令复制运行：

### 国外环境
```bash
curl -sSL -o mihomo.sh https://raw.githubusercontent.com/Skycnhe/alpine-mihomo/refs/heads/Hk001/mihomo.sh && chmod +x mihomo.sh && ./mihomo.sh
```

### 国内环境
```bash
curl -sSL -o mihomo.sh http://kr1-proxy.gitwarp.top:8081/https://raw.githubusercontent.com/Skycnhe/alpine-mihomo/refs/heads/Hk001/mihomo.sh && chmod +x mihomo.sh && ./mihomo.sh
```

---

## 命令行服务管理

部署完成后，您可以在 Alpine 终端直接运行系统内置的服务指令进行快捷控制。

### 方式一：使用系统服务命令（推荐）

* **启动服务**：
  ```bash
  rc-service mihomo start
  ```
* **停止服务**：
  ```bash
  rc-service mihomo stop
  ```
* **重启服务**：
  ```bash
  rc-service mihomo restart
  ```
* **查看状态**：
  ```bash
  rc-service mihomo status
  ```
* **启用开机自启**：
  ```bash
  rc-update add mihomo default
  ```
* **禁用开机自启**：
  ```bash
  rc-update del mihomo default
  ```

### 方式二：直接调用初始化脚本

```bash
/etc/init.d/mihomo start     # 启动
/etc/init.d/mihomo stop      # 停止
/etc/init.d/mihomo restart   # 重启
/etc/init.d/mihomo status    # 状态
```

---

## PVE LXC 容器环境准备（非特权容器使用 TUN 模式必看）

如果在 Proxmox VE (PVE) 的**非特权 LXC 容器**中运行 Alpine，并需要开启 **TUN 模式**，请按照以下步骤配置宿主机：

1. 登录 **PVE 宿主机** 终端。
2. 编辑对应的容器配置文件（以容器 ID `100` 为例）：
   ```bash
   nano /etc/pve/lxc/100.conf
   ```
3. 在文件末尾添加以下两行内容：
   ```ini
   lxc.cgroup2.devices.allow: c 10:200 rwm
   lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
   ```
4. 保存修改并重启该容器。
5. 在容器内运行以下命令确认设备是否就绪：
   ```bash
   ls -la /dev/net/tun
   ```
   *若输出中包含 `c 10, 200`，即可在脚本菜单中选择开启 TUN 模式支持。*

---

## 常见问题与维护

* **如何查看运行日志？**
  ```bash
  tail -f /var/log/mihomo.log
  ```
* **服务无法启动？**  
  请在脚本中执行 `4. 一键校验当前配置文件语法`，排查语法错误或端口（如 `53`、`7890`）冲突。
* **如何卸载？**  
  运行脚本并选择 `14. 一键完全卸载程序`，即可安全清除核心、服务及配置文件。

---

## 免责声明

* 本脚本仅作为系统运维管理辅助工具，请在合规及合法的网络环境下使用。
