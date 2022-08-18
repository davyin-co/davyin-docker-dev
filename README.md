# 介绍
戴文公司开发环境

# 设计原则
1. 可扩展
    可支持扩展为任意的web类应用容器部署。

2. 统一入口
    基于nginx-proxy/nginx-proxy的镜像，自动生成配置。也可替换为trafik。
    使用nginx-proxy的好处是，nginx广泛流行，配置成熟，方便扩展。trafik配置需要学习一套新的规则。

3. 可复用
    该方案即可做为本地开发环境，也可以作为线上部署使用。

4. 安全性
    选用的容器镜像经过响应的安全改进。

# 组件功能及介绍
|组件|文件|说明|FQDN|
|---|---|---|--|
|proxy|proxy/docker-compose.yml|基于[nginx-proxy](https://hub.docker.com/r/jwilder/nginx-proxy)的镜像，可以自动基于容器的环境变量生成配置|proxy|
|proxy-https|proxy-https/docker-compose.yml|基于[nginx-proxy](https://hub.docker.com/r/jwilder/nginx-proxy)的镜像，可以自动基于容器的环境变量生成配置，支持ssl证书|proxy|
|mariadb|mariadb/docker-compose.yml|基于[mariadb:10.5](https://hub.docker.com/r/wodby/mariadb)镜像的数据库|mariadb|
|redis|redis/docker-compose.yml|基于[bitnam/redis:6.2](https://hub.docker.com/r/wodby/redis)镜像的redis>数据库|redis|
|elasticsearch|elasticsearch/docker-compose.yml|基于[davyinsa/elasticsearch](https://hub.docker.com/r/davyinsa/elasticsearch-ik)镜像的数据库,含有IK分词插件|es01|
|pma|pma/docker-compose.yml|运行[phpmyadmin/phpmyadmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin)镜像，方便数据库管理。连接数据库的主机名为mariadb|N/A|
|db-backup|db-backup/docker-compose.yml|基于[tiredofit/mariadb-backup](https://hub.docker.com/r/tiredofit/db-backup)镜像的自动化数据库备份。|N/A|
|demo-app|demo-app/docker-compose.yml|用作实例，作为drupal部署。可以使用其他的web类镜像。|demo-app.docker|

# 整体架构（docker)
![](https://github.com/davyin-co/davyin-docker-dev/raw/master/nginx-proxy.jpg)
# 步骤
1. 创建docker网络
``` shell
## 执行脚本
sh network.sh

## 也可以手动执行相关的命令
docker network create --driver=bridge --subnet=10.10.255.0/24 --ip-range=10.10.255.0/24 --gateway=10.10.255.254 proxy
```

2. 启动容器公用容器（docker启动时候自动启动）
```shell
## 执行脚本
sh proxy.sh

## 也可以手动执行相关的命令
docker-compose -f proxy/docker-compose.yml -f mariadb/docker-compose.yml -f pma/docker-compose.yml up -d
```

3. 项目配置（drupal)
```shell
## 执行shell脚本
sh quick-start.sh

## 也可以手动copy，然后修改相关配置
cp -r demo-app/docker-compose.yml demo-project/
cd demo-project

## 编辑配置，主要VIRTUAL_HOST环境变量，用来设置访问的域名
```

4. （可选）
如果本地配置自动的DNS解析，可以忽略。
如果没有配置，修改本机的hosts，将VIRTUAL_HOST中的域名指向本地IP（一般为127.0.0.1)

5. 浏览器访问
```shell
## 一般是如下格式的IP
xx.docker.localhost   
## e.g.  dyniva.docker.localhost
```

## proxy容器的HTTPS支持
进入proxy-https/certs目录下，将SSL证书放到这里，ssl证书必须以.key和.crt结尾。
例如域名是example.com,则证书名如下：
```
example.com.key
example.com.crt
```
注意，这里支持泛域名证书，例如域名是test.example.com，可以使用example.com的泛域名证书；泛域名证书的文件名不带"\*."。例如*.example.com的泛域名证书文件名为：

```
example.com.key
example.com.crt
```
设置之后，所有的子域名（例如a.example.com,b.example.com,www.example.com）等会自动使用该泛域名证书。

## proxy容器自定义nginx配置
nginx-proxy的镜像会自动生成基本的配置；在一些项目中会有一些特殊的需求，这样可以通过自定义配置实现，参考官方文档：
[per-VIRTUAL_HOST](https://github.com/nginx-proxy/nginx-proxy#per-virtual_host)

## 备注

### 为什么mysql8使用 --authentication-policy=mysql_native_password？
[Authentication Plugin - SHA-256](https://mariadb.com/kb/en/authentication-plugin-sha-256/)
> mysql8.0.4开始，默认的密码验证插件为caching_sha2_password，而这种验证方式mariadb是不支持的。
> 一些基于alpine的镜像，默认安装的mysql-client是mariadb提供的；以及站群镜像中为了规避一些潜在问题，也是使用mariadb提供的client。
> mariadb client和mysql client都支持mysql_native_password
> 基于以上的理由，mysql8使用的默认密码插件为mysql_native_password
