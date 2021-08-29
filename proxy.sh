# run proxy
docker-compose -f network/docker-compose.yml up -d
docker-compose -f proxy/docker-compose.yml up -d

# run mariadb
if [ ! "$(docker ps -q -f name=mariadb)" ]; then
  docker-compose -f mariadb/docker-compose.yml up -d
else
  docker start mariadb
  echo 'container \033[31mmariadb\033[0m already exists!'
fi

# run db-backup
if [ ! "$(docker ps -q -f name=db-backup)" ]; then
  docker-compose -f db-backup/docker-compose.yml up -d
else
  docker start db-backup
  echo 'container \033[31mdb-backup\033[0m already exists!'
fi

# run pma
if [ ! "$(docker ps -q -f name=pma)" ]; then
  docker-compose -f pma/docker-compose.yml up -d
else
  docker start pma
  echo 'container \033[31mpma\033[0m already exists!'
fi