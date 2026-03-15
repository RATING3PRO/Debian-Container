# Debian Container with SSH

基于 Debian slim 镜像，默认启动 SSH 服务，支持通过环境变量初始化账号、密码和时区，适合在容器环境中快速部署可远程连接的 Debian 运行环境。

## 功能特性

- 默认启动 `sshd`，容器前台进程即 SSH 服务
- 支持 `SSH_USER`、`SSH_PASSWORD`、`TZ` 等环境变量初始化
- 内置 Docker 卷声明，支持 SSH 密钥和家目录持久化
- 支持切换 Debian 版本构建
- 支持通过 GitHub Actions 构建多版本、多架构并推送到 GHCR

## 环境变量

| 变量名 | 默认值 | 说明 |
| --- | --- | --- |
| `SSH_USER` | `debian` | 创建或复用的 SSH 登录用户 |
| `SSH_PASSWORD` | `debian` | SSH 用户密码 |
| `TZ` | `Etc/UTC` | 容器时区 |
| `SSH_PORT` | `22` | SSH 监听端口 |
| `SSH_ALLOW_PASSWORD_AUTH` | `true` | 是否启用密码认证，`false` 时关闭 |
| `SSH_ALLOW_ROOT_LOGIN` | `false` | 是否允许 root 登录，`true` 时开启 |
| `ROOT_PASSWORD` | 空 | 可选，设置 root 密码 |

## 本地构建

```bash
docker build -t debian-ssh:bookworm --build-arg DEBIAN_VERSION=bookworm .
```

## 本地运行

```bash
docker run -d \
  --name debian-ssh \
  -p 2222:22 \
  -e SSH_USER=admin \
  -e SSH_PASSWORD=StrongPassw0rd \
  -e TZ=Asia/Shanghai \
  debian-ssh:bookworm
```

## 持久化存储

镜像默认声明以下持久化路径：

- `/etc/ssh`：SSH 主机密钥与 SSH 配置
- `/home`：普通用户家目录数据
- `/root`：root 用户家目录数据
- `/var/log`：系统与服务运行日志
- `/usr/local`：自编译或手动安装的全局软件
- `/opt`：第三方独立安装的软件包
- `/var/cache/apt/archives`：APT 软件包下载缓存，加速容器重建后的重装过程

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
  debian-ssh:bookworm
```

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
  debian-ssh:bookworm
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
