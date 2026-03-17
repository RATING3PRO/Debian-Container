# Debian Container with SSH

基于 Debian slim 镜像，默认启动 SSH 服务，支持通过环境变量初始化账号、密码和时区，适合在容器环境中快速部署可远程连接的 Debian 运行环境。

## 功能特性

- 默认启动 `sshd`，容器前台进程即 SSH 服务
- 支持 `SSH_USER`、`SSH_PASSWORD`、`TZ` 等环境变量初始化
- 内置 Docker 卷声明，支持 SSH 密钥和家目录持久化
- 支持切换 Debian 版本构建
- 支持通过 GitHub Actions 构建多版本、多架构并推送到 GHCR

## 环境变量

| 变量名                           | 默认值       | 说明                            |
| ----------------------------- | --------- | ----------------------------- |
| `SSH_USER`                    | `debian`  | 创建或复用的 SSH 登录用户               |
| `SSH_PASSWORD`                | `debian`  | SSH 用户密码                      |
| `TZ`                          | `Etc/UTC` | 容器时区                          |
| `SSH_PORT`                    | `22`      | SSH 监听端口                      |
| `SSH_ALLOW_PASSWORD_AUTH`     | `true`    | 是否启用密码认证，`false` 时关闭          |
| `SSH_ALLOW_ROOT_LOGIN`        | `false`   | 是否允许 root 登录，`true` 时开启       |
| `ROOT_PASSWORD`               | 空         | 可选，设置 root 密码                 |
| `KOMARI_SERVER`               | 空         | Komari Server 地址，设置后开启 Agent  |
| `KOMARI_TOKEN`                | 空         | Komari Server 通讯 Token        |
| `KOMARI_DISABLE_WEB_SSH`      | `false`   | 设置为 `true` 禁用 Web SSH         |
| `KOMARI_DISABLE_AUTO_UPDATE`  | `false`   | 设置为 `true` 禁用自动更新             |
| `KOMARI_IGNORE_UNSAFE_CERT`   | `false`   | 设置为 `true` 忽略不安全的 SSL 证书      |
| `KOMARI_MEMORY_INCLUDE_CACHE` | `false`   | 设置为 `true` 将缓存/Buffer 计入内存使用量 |

## 运行

```bash
docker run -d \
  --name debian-ssh \
  -p 2222:22 \
  -e SSH_USER=admin \
  -e SSH_PASSWORD=StrongPassw0rd \
  -e TZ=Asia/Shanghai \
  ghcr.io/rating3pro/debian-container:trixie
```

## 持久化存储

镜像默认声明以下持久化路径，建议根据实际使用场景规划存储容量：

| 路径               | 建议大小      | 说明          | 增长特性                         |
| ---------------- | --------- | ----------- | ---------------------------- |
| `/etc/ssh`       | < 10MB    | SSH 主机密钥与配置 | 几乎不增长，仅保存文本配置                |
| `/home`          | 10GB+     | 普通用户数据      | 取决于用户存放的代码、数据量               |
| `/root`          | 1GB+      | root 用户数据   | 通常用于存放管理脚本或临时配置              |
| `/var/log`       | 1GB - 5GB | 系统与服务日志     | 持续增长，建议定期清理或配置 logrotate     |
| `/usr/local`     | 5GB+      | 自编译软件       | 取决于手动编译安装的软件数量与体积            |
| `/opt`           | 10GB+     | 第三方独立软件     | 取决于部署的大型软件（如数据库、中间件）         |
| `/var/cache/apt` | 2GB - 5GB | APT 软件包缓存   | 随安装软件数量增长，可随时 `apt clean` 清理 |

推荐使用命名卷运行：

```bash
docker run -d \
  --name debian-ssh \
  -p 2222:22 \
  -e SSH_USER=admin \
  -e SSH_PASSWORD=StrongPassw0rd \
  -e TZ=Asia/Shanghai \
  -v debian_ssh_etc:/etc/ssh \
  -v debian_ssh_home:/home \
  -v debian_ssh_root:/root \
  -v debian_ssh_log:/var/log \
  -v debian_ssh_usr_local:/usr/local \
  -v debian_ssh_opt:/opt \
  -v debian_ssh_apt_cache:/var/cache/apt/archives \
  ghcr.io/rating3pro/debian-container:trixie
```

**注意：**

- 由于 `/usr/local` 被声明为持久化卷，容器启动脚本已移至 `/usr/bin/entrypoint.sh`，避免被空卷覆盖。
- 如需覆盖启动行为，请使用 `--entrypoint` 参数或在 `docker run` 命令后指定。

如需绑定宿主机目录：

```bash
docker run -d \
  --name debian-ssh \
  -p 2222:22 \
  -e SSH_USER=admin \
  -e SSH_PASSWORD=StrongPassw0rd \
  -v /opt/debian-ssh/etc-ssh:/etc/ssh \
  -v /opt/debian-ssh/home:/home \
  -v /opt/debian-ssh/root:/root \
  -v /opt/debian-ssh/log:/var/log \
  -v /opt/debian-ssh/usr-local:/usr/local \
  -v /opt/debian-ssh/opt:/opt \
  -v /opt/debian-ssh/apt-cache:/var/cache/apt/archives \
  ghcr.io/rating3pro/debian-container:trixie
```

## GitHub Actions 推送 GHCR

工作流文件位于 `.github/workflows/build-and-push.yml`，触发后将构建以下版本：

- `bullseye`
- `bookworm`
- `trixie`

每个版本构建平台：

- `linux/amd64`
- `linux/arm64`

推送地址格式：

`ghcr.io/<github_owner>/debian-container`

建议在仓库设置中确认：

- `Actions` 具备 `Read and write permissions`
- 使用默认 `GITHUB_TOKEN` 可写入 `packages`

