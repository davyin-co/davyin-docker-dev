---
name: davyin-docker-dev
description: >
  操作管理戴文（Davyin）统一 Docker 开发环境（davyin-docker-dev）。
  当用户需要初始化/启动/停止 Docker 开发环境、新建项目、管理 nginx-proxy 反向代理、
  操作 mariadb/mysql8/redis/elasticsearch/pma/db-backup/varnish 等中间件、
  配置 HTTPS 证书、添加本地 DNS，或排查环境问题时，使用本 skill。
  话题涉及「docker 开发环境」「nginx-proxy」「新建 drupal 项目」「VIRTUAL_HOST」
  「本地数据库」「pma / phpmyadmin」时也优先引导使用本 skill。
---

# 戴文 Docker 开发环境运维 Skill

## 什么时候使用

本 skill 覆盖对 `davyin-docker-dev` 统一 Docker 开发环境的一切运维操作：

- 初始化环境（创建网络、启动基础设施）
- 启动/停止/查看单个中间件服务
- 新建 Web/Drupal 项目（基于 demo-app 模板）
- 配置 nginx-proxy 反向代理（VIRTUAL_HOST）与 HTTPS 证书
- 排查容器、域名、数据库连接问题

如果用户只是问 Docker 通用知识，不涉及本环境，则走常规 Docker 操作，不必用本 skill。

## 仓库与前置条件

- 仓库地址：`https://github.com/davyin-co/davyin-docker-dev`
- 本地工作副本：以用户实际克隆路径为准（找不到时先 `git clone` 到合适位置）。
- 前置依赖：Docker 已安装、`docker compose`（v2）可用。本 skill 统一用 `docker compose`，若环境只有 v1 则回退 `docker-compose`。

## 架构概览

```
nginx-proxy (proxy / proxy-https)   ← 唯一对外入口，监听 80/443
   │  挂载 /var/run/docker.sock，自动发现 VIRTUAL_HOST 并反代
   └── external 网络 proxy (10.10.255.0/24)
        ├── mariadb (11.4)  mysql8 (8.4)   ← 数据库
        ├── redis (8.2)     elasticsearch (7.16.2 + IK)
        ├── pma (phpMyAdmin)                ← 数据库管理 UI
        ├── db-backup (mysql-backup-rotate) ← 每日自动备份
        ├── varnish (Drupal 缓存)
        └── demo-app / 各项目容器 (nginx-php:8.3-alpine)
```

核心规则：**任何 Web 容器只要带 `VIRTUAL_HOST=<name>.docker.localhost` 环境变量，并加入 `proxy` 网络，nginx-proxy 就会自动生成 server block 并反代**，无需改 nginx 配置。

## 初始化环境（一次性）

```bash
# 在仓库根目录执行

# 1. 创建外部网络（幂等，重复执行会报已存在，可忽略）
sh network.sh
# 等价：docker network create --driver=bridge \
#   --subnet=10.10.255.0/24 --ip-range=10.10.255.0/24 --gateway=10.10.255.254 proxy

# 2. 启动基础设施：proxy + mariadb + db-backup + pma
sh proxy.sh
```

> ⚠️ 网关不一致：`network.sh` 用 `.254`，而 `network/docker-compose.yml` 写的是 `10.10.255.255`（/24 的广播地址，疑似笔误）。**优先用 `network.sh` 建网**；若发现网络网关异常，用 `docker network inspect proxy` 核对，必要时删掉重建。

## 服务管理

所有服务都在各自目录下用 `docker-compose.yml` 定义，统一加入外部网络 `proxy`：

```bash
# 启动单个服务（在仓库根目录）
docker compose -f <service>/docker-compose.yml up -d

# 查看日志
docker compose -f <service>/docker-compose.yml logs -f

# 停止（不删数据卷）
docker compose -f <service>/docker-compose.yml down
```

### 组件清单与关键参数

| 目录 | 容器名 | 用途 / 关键点 |
|------|--------|---------------|
| `proxy/` | `proxy` | 纯 HTTP 反代（仅 80），`HTTPS_METHOD=nohttps` |
| `proxy-https/` | `proxy` | HTTPS 反代（80+443），挂载 `./certs` |
| `mariadb/` | `mariadb` | MariaDB 11.4，root 密码 `password`，`MYSQL_ROOT_HOST=%` |
| `mysql8/` | `mysql8` | MySQL 8.4，root 密码 `password`，默认 native_password 认证 |
| `redis/` | `redis` | Redis 8.2，maxmemory 8GB / allkeys-lru，禁用 FLUSH* |
| `elasticsearch/` | `es01` | ES 7.16.2 + IK 分词，单节点，`ELASTIC_PASSWORD=password` |
| `pma/` | `pma` | phpMyAdmin，`VIRTUAL_HOST=pma.docker.localhost` |
| `db-backup/` | `db-backup` | 每日 01:40 备份到 `./backup/`，连 `mariadb` |
| `varnish/` | `varnish` | Drupal 缓存预设，后端 `dsf:80` |
| `redirect-to-www/` | `redirect-to-www` | 示例：域名跳转到 www |
| `autoheal/` | `autoheal` | 自动重启不健康容器 |
| `demo-app/` | — | 项目模板（`project_name` 为占位符） |

> 所有镜像均来自阿里云镜像仓库 `registry.cn-hangzhou.aliyuncs.com/davyin/*`，不要改成上游 Docker Hub 原镜像（可能拉取失败）。

## 新建 Web/Drupal 项目

```bash
# 方式一：交互式脚本（推荐）
sh quick-start.sh
# 输入 PROJECT_NAME（如 test）、PROJECT_PATH（绝对路径，不要用 ~）
# 脚本会复制 demo-app/docker-compose.yml 并替换占位符

# 方式二：手动
cp demo-app/docker-compose.yml <project_path>/
# 编辑该文件，替换 project_name、project_path
```

建好后：

```bash
cd <project_path>
docker compose up -d
# 访问 http://<PROJECT_NAME>.docker.localhost
```

### demo-app 模板关键配置（新建项目时注意）

- `image`: `davyin/nginx-php:8.3-alpine`
- `VIRTUAL_HOST=project_name.docker.localhost`（**必填**，nginx-proxy 据此反代）
- `hostname: project_name.docker.localhost`
- `DRUPAL_WEB_ROOT=docroot`（Drupal 代码在项目根的 `docroot/`，若在根目录则删掉此变量或设为空）
- 挂载：`./:/var/www/html`、`./logs:/www/logs`
- 内置 healthcheck：`curl -fs http://localhost/`

## 本地 DNS / hosts

若未配置自动 DNS（如 `*.docker.localhost` 通配解析），需把 `VIRTUAL_HOST` 域名指向本地 IP：

```bash
# /etc/hosts 增加一行
127.0.0.1  <name>.docker.localhost
```

## HTTPS 证书

1. 使用 `proxy-https/`（容器名也是 `proxy`，与 `proxy/` 互斥，二选一）。
2. 把证书放进 `proxy-https/certs/`，文件名以 `.key` / `.crt` 结尾。
3. 通配符证书**文件名不含 `*.`**：`*.example.com` → `example.com.key` + `example.com.crt`，自动覆盖所有子域名。

## 关键约定与坑（务必遵守）

1. **VIRTUAL_HOST 必填**：不填则 nginx-proxy 不生成 server block，容器无法通过域名访问。
2. **数据库 root 密码均为 `password`**（仅本地开发用，勿用于生产）。
3. **pma 连 mariadb 的主机名是 `mariadb`**，不是 `localhost`；pma 已设 `PMA_ARBITRARY=1`，可连接任意数据库。
4. **mysql8 用 `mysql_native_password`**：因为 mariadb client 不支持 caching_sha2_password。
5. **持久化目录已被 .gitignore 忽略**：`mariadb/mariadb-data`、`proxy/mariadb-data`、`db-backup/backup/`，不要提交。
6. **占位符需替换**：`redis` 的 `REDIS_PASSWORD` 是字面量 `******`；`varnish` 的 `VARNISH_BACKEND_HOST=dsf`、`redirect-to-www` 的 `VIRTUAL_HOST=example.com` 都是示例值，实际使用前必须改成真实值。
7. **proxy 与 proxy-https 互斥**：两者容器名都是 `proxy`，同时启动会冲突，按需二选一。
8. 单服务 `docker compose down` 默认不删数据卷（volume），数据不会丢；但 `demo-app` 用 bind mount，数据在宿主机目录。

## 常见排障

- **容器起来了但域名打不开**：检查该容器是否 (1) 加入了 `proxy` 网络、(2) 设置了 `VIRTUAL_HOST`、(3) hosts 已指向本地。
- **403 / 502**：看后端容器 healthcheck 是否通过、`docker compose logs` 后端；nginx-proxy 侧 `docker logs proxy`。
- **数据库连不上**：pma 里主机名用 `mariadb`（或 `mysql8`），不要用 `127.0.0.1`；确认两者在同一 `proxy` 网络。
- **端口占用**：`proxy` 占 80、`proxy-https` 占 80+443、`redis` 占 6379、`varnish` 占 8080，冲突时改端口映射。
- **网络已存在报错**：`network.sh` 重复执行会报 `network with name proxy already exists`，属正常。

## 危险 / 有副作用操作（执行前必须向用户确认）

- `docker compose ... down -v`（会删数据卷，导致数据库数据丢失）
- `docker network rm proxy`（会断掉所有服务的网络）
- 修改或重建 `mariadb` / `mysql8` / `redis` / `elasticsearch` 的数据目录
- `docker system prune -a` 等全局清理命令

## 镜像同步（一般运维不需要，仅维护镜像时用）

上游镜像 → 阿里云仓库的同步由 `.github/workflows/image-sync.yml` 完成，用 `skopeo copy`，每日 01:30（UTC）自动跑，也可手动触发。新增镜像同步时需在 workflow 里加一行 `skopeo copy docker://<上游> docker://registry.cn-hangzhou.aliyuncs.com/davyin/<目标>`，并确认阿里云凭证 secret 已配置。

## 扩展与限制

- 本 skill 只负责**运维本环境**，不负责改 `davyin-docker-dev` 仓库代码或镜像。
- 新增一个中间件 = 新建一个目录 + 一份 `docker-compose.yml`，加入 `proxy` 网络即可，无需改 proxy 配置。
- 若用户要求修改仓库或 CI，回到常规开发流程。
