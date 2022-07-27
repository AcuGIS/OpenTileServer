#!/bin/bash -e
 
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGUSER=${POSTGRES_USER}
 
# wait for PG to become ready
while [ $(pg_isready -h pg -d ${POSTGRES_DB} -U ${POSTGRES_USER} | grep -c 'accepting') -eq 0 ]; do
  sleep 1;
done
 
/etc/init.d/apache2 start
 
# run apache on foreground
/usr/local/bin/renderd -f -c /usr/local/etc/renderd.conf
