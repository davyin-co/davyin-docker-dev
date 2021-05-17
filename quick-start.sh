# Script to quickly create sub-theme.

echo '
+------------------------------------------------------------------------+
| With this script you could quickly create dyniva_ui sub-theme           |
| In order to use this:                                                    |
| - dyniva_ui theme (this folder) should be in the custom folder          |
+------------------------------------------------------------------------+
'
echo 'Enter the \033[31mproject name\033[0m of your new project? [e.g. test]'
read PROJECT_NAME

echo 'Enter the \033[31mpath\033[0m of your new project? [e.g. /home/zlchen/workspace/test ] [promp: do not use ~]'
read PROJECT_PATH

# copy docker-compose.yml to new project
if [ ! -d $PROJECT_PATH ]; then
  mkdir -p $PROJECT_PATH
fi

cp -f demo-app/docker-compose.yml $PROJECT_PATH

# replace SUBTHEME to new theme string
sed -i "s/project_name/$PROJECT_NAME/g" $PROJECT_PATH/docker-compose.yml
sed -i "s#project_path#$PROJECT_PATH#g" $PROJECT_PATH/docker-compose.yml

# done
echo "\nNew project \033[31m${PROJECT_NAME}\033[0m docker config has been generated in \033[31m${PROJECT_PATH}\033[0m"
echo "Next \033[36mcd ${PROJECT_PATH}\033[0m"
echo "Then run \033[36mdocker-compose up -d\033[0m"
echo "Thanks for use!"
