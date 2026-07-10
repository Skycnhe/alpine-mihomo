以下为您提供纯文本格式的 `README.md` 内容，去除了嵌套的代码格式限制，您可以直接复制使用：

# Mihomo Alpine Linux & LXC 一键管理脚本

本脚本专为 Alpine Linux 环境（包括 Proxmox VE 下的 LXC 容器）设计，提供了一套轻量级的 Mihomo（原 Clash Meta）一键部署、运行与维护方案。脚本基于 OpenRC 初始化系统注册服务，并支持自定义 GitHub 模板拉取及系统级 TUN 模式的自动化适配。

---

## 核心功能

* **自动换源与依赖处理**：支持将 Alpine APK 软件源一键切换为国内镜像源（清华/阿里/腾讯），并自动补充 curl、gzip、unzip、ca-certificates 等必要依赖。
* **自定义配置模板**：支持在脚本中预设您自定义的 GitHub Raw 配置直链。部署时将优先拉取该配置，拉取失败时自动降级使用脚本内置的本地基础模板。
* **网络加速可选**：集成了 gh-proxy.com 下载代理，有效解决国内环境下 GitHub 核心文件或资源包下载超时的问题。
* **系统级 TUN 模式支持**：自动加载 tun 内核模块并设置开机自启，永久开启系统内核 IP 转发（修改 sysctl.conf），并向配置文件自动追加高性能内置 DNS 与流量劫持规则。
* **Web UI 面板集成**：支持一键下载、部署及升级 MetaCubeXD 仪表盘。
* **完整的服务控制**：
  * OpenRC 系统服务注册与开机自启配置。
  * 服务的启动、停止、重启与状态实时监控。
  * 规则数据包（GeoIP / GeoSite / Country.mmdb）在线同步。
  * 实时日志流追踪（Live Log）与日志清空。
  * 在线订阅链接导入与配置文件语法合法性校验。

---

## 目录结构

部署成功后，系统文件布局如下：

| 文件/目录路径 | 说明 |
| :--- | :--- |
| /usr/local/bin/mihomo | Mihomo 核心二进制程序 |
| /etc/mihomo | 配置文件及相关资源目录 |
| /etc/mihomo/config.yaml | 主配置文件 |
| /etc/mihomo/ui | Web 仪表盘静态资源目录 |
| /etc/init.d/mihomo | OpenRC 服务控制脚本 |
| /var/log/mihomo.log | 运行日志文件 |

---

## 快速开始

### 1. 使用前置配置（可选）

如果您希望在安装时直接部署您存放在 GitHub 上的个性化配置文件，请在运行脚本前用编辑器打开本脚本，修改 第 26 行 附近的 CUSTOM_TEMPLATE_URL 变量：

```sh
# 将其修改为您的自定义 GitHub Raw 链接
CUSTOM_TEMPLATE_URL="https://raw.githubusercontent.com/您的用户名/您的仓库名/分支名/您的配置文件.yaml"
```
> 注：请确保该文件在 GitHub 上为公开（Public）状态。若是默认占位符或留空，脚本将自动采用本地基础模板。

### 2. 运行脚本

在 Alpine Linux 终端中运行以下命令：

```sh
# 赋予执行权限
chmod +x mihomo_manager.sh

# 启动管理菜单
./mihomo_manager.sh
```

---

## PVE LXC 容器环境准备（非常重要）

如果您在 Proxmox VE (PVE) 的非特权 LXC 容器 中运行 Alpine Linux，并希望使用 TUN 模式 作为旁路网关，容器默认无法直接加载虚拟网卡设备，请按照以下步骤处理：

1. 登录 PVE 宿主机 终端。
2. 编辑该 Alpine 容器的配置文件（假设容器 ID 为 100）：
   ```bash
   nano /etc/pve/lxc/100.conf
   ```
3. 在文件末尾添加以下两行内容，以授权容器挂载并读写 /dev/net/tun：
   ```text
   lxc.cgroup2.devices.allow: c 10:200 rwm
   lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
   ```
4. 保存修改并重启容器。
5. 重启后，可在容器内通过以下命令确认设备是否就绪：
   ```bash
   ls -la /dev/net/tun
   ```
   若输出中包含 c 10, 200 等字样，即可在脚本菜单中选择 选项 7 开启 TUN 模式支持。

---

## 常见问题与日常维护

* **如何查看运行日志？**
  您可以在脚本菜单中选择 12，或者在 Alpine 终端直接执行 `tail -f /var/log/mihomo.log`。
* **为什么服务无法启动？**
  如果修改配置后服务无法拉起，请在脚本中执行 4. 一键校验当前配置文件语法，查看是否有语法错误或端口冲突（如 53 端口、7890 端口被其他服务占用）。
* **如何卸载？**
  运行脚本并选择 14. 一键完全卸载程序，即可安全移除核心、系统服务及配置文件。

---

## 免责声明

* 本脚本仅作为系统运维管理辅助工具，请在合规及合法的网络环境下使用。
