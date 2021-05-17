# 介绍
戴文公司开发环境

# 组件功能及介绍
|组件|文件|说明|
|---|---|---|
|proxy|proxy/docker-compose.yml|基于nginx-proxy/nginx-proxy的镜像，可以自动基于容器的环境变量生成配置|
|mariadb|mariadb/docker-compose.yml|基于mariadb:10.5镜像的数据库|
|pma|pma/docker-compose.yml|运行phpmyadmin镜像，方便数据库管理。连接数据库的主机名为mariadb|
|db-backup|db-backup/docker-compose.yml|基于tiredofit/mariadb-backup镜像的自动化数据库备份

# 常用命令
```
docker-compose -f proxy/docker-compose.yml -f mariadb/docker-compose.yml -f pma/docker-compose.yml up -d
```

# 第一次运行代理
```sh
sh proxy.sh
```

# 创建新项目
```sh
sh quick-start.sh
```