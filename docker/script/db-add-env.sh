#/bin/sh
echo "Getting the environment vars and populating $DATABASE_YML"
sed s/\"postgres\"/\"$DB_USER\"/g $DATABASE_YML -i
echo "Database User adjusted"
sed s/\"localhost\"/\"$DB_HOST\"/g $DATABASE_YML -i
echo "Database Host adjusted"
sed s/\"\"/\"$DB_PASSWORD\"/g $DATABASE_YML -i
echo "Database Password adjusted"
sed s/5432/$DB_PORT/g $DATABASE_YML -i
echo "Database Port adjusted"
