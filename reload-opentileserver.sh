#!/bin/bash -e
#Version: 0.2
#Description: Reload OSM data to server built with opentileserver.sh
#Note: This script assumes all external commands
#	(pg_config, osm2pgsl, ...) are installed.
#Usage: reload-opentileserver.sh [-add] [pbf_url]
# To run in non-Latin language uncomment below
#export LC_ALL=C
PBF_ADD='no'
if [ "${1}" == '-add' ]; then
	PBF_ADD='yes'
	shift 1;
fi

PBF_URL="${1}";	#http://download.geofabrik.de/europe/germany-latest.osm.pbf
OSM_USER='tile'
OSM_DB='gis'

#Check input parameters
if [ -z "${PBF_URL}" ]; then
	echo "Usage: $0 [-add] pbf_url"; exit 1;
fi

#C_MEM is the sum of free memory and cached memory
C_MEM=$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f4,7 -d' ' | tr ' ' '+' | bc)
NP=$(grep -c 'model name' /proc/cpuinfo)
osm2pgsql_OPTS="--slim -d ${OSM_DB} -C ${C_MEM} --number-processes ${NP}"
PG_VER=$(pg_config | grep '^VERSION' | cut -f4 -d' ' | cut -f1,2 -d.)

#Clear renderd cache
service renderd stop
rm -rf /var/lib/mod_tile/default/*

PBF_FILE="/home/${OSM_USER}/${PBF_URL##*/}"
if [ ! -f ${PBF_FILE} ]; then
	wget -P/home/${OSM_USER} ${PBF_URL}
	chown ${OSM_USER}:${OSM_USER} ${PBF_FILE}
fi

cat >/etc/postgresql/${PG_VER}/main/pg_hba.conf <<CMD_EOF
local all all trust
host all all 127.0.0.1 255.255.255.255 md5
host all all 0.0.0.0/0 md5
host all all ::1/128 md5
CMD_EOF

#Turn off autovacuum and fsync during load of PBF
sed -i 's/#\?fsync.*/fsync = off/' /etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i 's/#\?autovacuum.*/autovacuum = off/' /etc/postgresql/${PG_VER}/main/postgresql.conf

service postgresql restart


if [ "${PBF_ADD}" == 'no' ]; then
	#Remove old osm db and user
	sudo -u postgres dropdb --if-exists ${OSM_DB}
	sudo -u postgres dropuser --if-exists ${OSM_USER}

	#create user,db and extensions
	psql -Upostgres ${OSM_DB} <<EOF_CMD
create user ${OSM_USER} with password '${OSM_PG_PASS}';
create database ${OSM_DB} owner=${OSM_USER};
\c ${OSM_DB}
CREATE EXTENSION postgis;
ALTER TABLE geometry_columns OWNER TO ${OSM_USER};
ALTER TABLE spatial_ref_sys OWNER TO ${OSM_USER};
EOF_CMD
	if [ $? -ne 0 ]; then	echo "Error: Failed to setup osm user, db or extensions";	exit 1; fi
fi

sudo -u ${OSM_USER} osm2pgsql ${osm2pgsql_OPTS} ${PBF_FILE}
if [ $? -eq 0 ]; then	#If import went good
	rm -rf ${PBF_FILE}
fi

#restore password for pg
#Turn on autovacuum and fsync during load of PBF
sed -i.save 's/#\?fsync.*/fsync = on/' 				/etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i.save 's/#\?autovacuum.*/autovacuum = on/'	/etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i.save 's/local all all.*/local all all md5/'	/etc/postgresql/${PG_VER}/main/pg_hba.conf

#Restart services
service postgresql restart
service apache2 reload
service renderd start

