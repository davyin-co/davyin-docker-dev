# run proxy
cd proxy
docker-compose up -d

# run db-backup
if [ ! "$(docker ps -q -f name=mariadb)" ]; then
  cd ../db-backup
  docker-compose up -d
  else
  echo 'container \033[31mmariadb\033[0m already exists!'
fi

# run pma
if [ ! "$(docker ps -q -f name=mariadb)" ]; then
  cd ../pma
  docker-compose up -d
  else
  echo 'container \033[31mpma\033[0m already exists!'
fi