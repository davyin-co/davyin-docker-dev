# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

戴文公司 (davyin-sa) 统一 Docker 开发环境。基于 `nginx-proxy` 镜像自动发现容器环境变量来生成 nginx 配置，所有 web 类应用通过 `VIRTUAL_HOST` 环境变量接入。设计原则：可扩展、统一入口、可复用 (本地开发/线上部署)、安全性 (镜像经过筛选)。

## 架构

```
┌─────────────────────────────────────────────────────────┐
│  nginx-proxy (proxy / proxy-https)                      │
│  监听 80/443，根据 VIRTUAL_HOST 自动反代后端容器        │
└──────────┬──────────────────────────────────────────────┘
           │  外部网络 proxy (10.10.255.0/24)
           │
  ┌────────┴─────────┬──────────┬──────────┬──────────────┐
  ▼                  ▼          ▼          ▼              ▼
mariadb (10.5/11.4)  redis    pma      db-backup     demo-app (Drupal)
mysql8 (8.4)         ES (IK)  varnish  redirect-www  autoheal
```

所有服务都加入 `external` 网络 `proxy`。**新增 web 容器**只需：`container_name`、`hostname: <name>.docker.localhost`、`environment.VIRTUAL_HOST=<name>.docker.localhost`、挂载 `./<name>-data`（如需持久化）。

## 组件清单

| 目录 | 作用 | 关键镜像 |
|---|---|---|
| `network/` | 声明 `proxy` 网络 (10.10.255.0/24) | — |
| `proxy/` | 纯 HTTP 反代 (端口 80) | `davyin/nginx-proxy` |
| `proxy-https/` | HTTPS 反代 (80+443)，挂载 `./certs` | `davyin/nginx-proxy` |
| `mariadb/` | MariaDB 11.4 (主数据库) | `davyin/wodby-mariadb:11.4` |
| `mysql8/` | MySQL 8.4 备选 | `davyin/mysql:8.4` |
| `redis/` | Redis 8.2 (maxmemory 8G) | `davyin/bitnami-redis:8.2` |
| `elasticsearch/` | ES 7.16.2 + IK 分词 | `davyin/elasticsearch-ik:7.16.2` |
| `pma/` | phpMyAdmin，FQDN `pma.docker.localhost` | `phpmyadmin/phpmyadmin` |
| `db-backup/` | 自动备份到 `./backup/`，每日 1440 分钟 | `davyin/mysql-backup-rotate` |
| `varnish/` | Drupal 预设缓存 | `davyin/wodby-varnish:6` |
| `redirect-to-www/` | davyin.com → www.davyin.com 重定向 | `schmunk42/nginx-redirect` |
| `autoheal/` | 监控并重启不健康容器 | `davyin/autoheal` |
| `demo-app/` | 模板项目，**`project_name` 为占位符** | `davyin/nginx-php:8.3-alpine` |

所有镜像通过 `registry.cn-hangzhou.aliyuncs.com/davyin/*` 阿里云仓库分发（见 `.github/workflows/image-sync.yml` 用 `skopeo` 同步上游）。

## 常用命令

### 初始化环境
```bash
# 创建外部网络（一次性）
sh network.sh
# 等价：docker network create --driver=bridge --subnet=10.10.255.0/24 --ip-range=10.10.255.0/24 --gateway=10.10.255.254 proxy

# 启动基础设施：proxy + mariadb + db-backup + pma
sh proxy.sh
```

### 启动/停止单服务
```bash
# 启动
docker compose -f <service>/docker-compose.yml up -d
# 例：docker compose -f mariadb/docker-compose.yml up -d

# 查看日志
docker compose -f <service>/docker-compose.yml logs -f

# 停止
docker compose -f <service>/docker-compose.yml down
```

### 新建项目
```bash
sh quick-start.sh
# 按提示输入 PROJECT_NAME 和 PROJECT_PATH（不要用 ~）
# 脚本会从 demo-app/ 复制 docker-compose.yml，sed 替换 project_name 和 project_path
# 访问 http://<PROJECT_NAME>.docker.localhost
```

### 本地 DNS
未配置自动 DNS 时，需在 `/etc/hosts` 将 `VIRTUAL_HOST` 域名指向 `127.0.0.1`。

### HTTPS 证书
将证书放入 `proxy-https/certs/`，文件名必须以 `.key`/`.crt` 结尾。**通配符证书**的文件名不包含 `*.`，例如 `*.example.com` 的证书命名为 `example.com.key` / `example.com.crt`，可覆盖所有子域名。

## 注意事项

- **mysql8 默认 `--authentication-policy=mysql_native_password`**：caching_sha2_password 与 mariadb client 不兼容 (见 README 备注)。
- **pma 连接 mariadb 的主机名是 `mariadb`**，不是 `localhost`。
- **VIRTUAL_HOST 是必填**——nginx-proxy 据此生成 server block；不填则不可访问。
- **持久化目录**已被 `.gitignore` 忽略：`mariadb/mariadb-data`、`proxy/mariadb-data`、`db-backup/backup/`。
- **数据库 root 密码均为 `password`**（仅用于本地开发）。
- **语言要求**：用户全局要求所有回复使用简体中文（见 `~/.claude/CLAUDE.md`）。
- **不使用 mcp__claude-in-chrome***：网页浏览统一走 gstack 的 `/browse` skill。

## 架构图源文件
- `nginx-proxy.jpg` / `nginx-proxy.drawio` — 整体网络拓扑
