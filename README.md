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
|组件|文件|说明|
|---|---|---|
|proxy|proxy/docker-compose.yml|基于nginx-proxy/nginx-proxy的镜像，可以自动基于容器的环境变量生成配置|
|mariadb|mariadb/docker-compose.yml|基于mariadb:10.5镜像的数据库|
|redis|redis/docker-compose.yml|基于bitname/redis:6.2镜像的redis数据库|
|elasticsearch|elasticsearch/docker-compose.yml|基于davyinsa/elasticsearch:7.12.1镜像的数据库,含有IK分词插件|
|pma|pma/docker-compose.yml|运行phpmyadmin/phpmyadmin镜像，方便数据库管理。连接数据库的主机名为mariadb|
|db-backup|db-backup/docker-compose.yml|基于tiredofit/mariadb-backup镜像的自动化数据库备份。|
|demo-app|demo-app/docker-compose.yml|用作实例，作为drupal部署。可以使用其他的web类镜像。|

# 整体架构（docker)
![](https://github.com/davyin-co/davyin-docker-dev/raw/master/nginx-proxy.jpg)
# 步骤
1. 创建docker网络
```
docker network create \
                --driver=bridge \
                --subnet=10.10.255.0/24 \
                --ip-range=10.10.255.0/24 \
                --gateway=10.10.255.254 \
                proxy

```

2. 启动容器公用容器（docker启动时候自动启动）
```
docker-compose -f proxy/docker-compose.yml -f mariadb/docker-compose.yml -f pma/docker-compose.yml up -d
```

3. 项目配置（drupal)
```
cp -r demo-app demo-project
cd demo-project
## 编辑配置，主要VIRTUAL_HOST环境变量，用来设置访问的域名
```

4. （可选）
如果本地配置自动的DNS解析，可以忽略。
如果没有配置，修改本机的hosts，将VIRTUAL_HOST中的域名指向本地IP（一般为127.0.0.1)

5. 浏览器访问
