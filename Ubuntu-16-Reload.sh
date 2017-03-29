#!/bin/bash -e
#Version: 0.1
#Description: Reload OSM data
#Note: This script assumes all external commands
#	(pg_config, osm2pgsl, ...) are installed.
 
PBF_ADD='no'
if [ "${1}" == '-add' ]; then
	PBF_ADD='yes'
	shift 1;
fi
 
PBF_URL="${1}";	#http://download.geofabrik.de/europe/andorra-latest.osm.pbf
OSM_USER='tile'
OSM_DB='gis'
 
#Check input parameters
if [ -z "${PBF_URL}" ]; then
	echo "Usage: $0 [-add] pbf_url"; exit 1;
fi
 
NP=$(grep -c 'model name' /proc/cpuinfo)
osm2pgsql_OPTS="--slim -d ${OSM_DB} --number-processes ${NP}"
PG_VER=$(pg_config | grep '^VERSION' | cut -f4 -d' ' | cut -f1,2 -d.)
 
#Clear renderd cache
systemctl stop renderd
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
 
systemctl restart postgresql
 
 
if [ "${PBF_ADD}" == 'no' ]; then
	#Remove old osm db and user
	sudo -u postgres dropdb --if-exists ${OSM_DB}
	sudo -u postgres dropuser --if-exists ${OSM_USER}
 
	#create user,db and extensions
	psql -Upostgres <<EOF_CMD
create user ${OSM_USER} with password '${OSM_PG_PASS}';
create database ${OSM_DB} owner=${OSM_USER};
\c ${OSM_DB}
CREATE EXTENSION postgis;
ALTER TABLE geometry_columns OWNER TO ${OSM_USER};
ALTER TABLE spatial_ref_sys OWNER TO ${OSM_USER};
EOF_CMD
fi
 
let C_MEM=$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f7 -d' ')-200
sudo -u ${OSM_USER} osm2pgsql ${osm2pgsql_OPTS} -C ${C_MEM} ${PBF_FILE}
if [ $? -eq 0 ]; then	#If import went good
	rm -rf ${PBF_FILE}
fi
 
#restore password for pg
#Turn on autovacuum and fsync during load of PBF
sed -i.save 's/#\?fsync.*/fsync = on/' 				/etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i.save 's/#\?autovacuum.*/autovacuum = on/'	/etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i.save 's/local all all.*/local all all trust/'	/etc/postgresql/${PG_VER}/main/pg_hba.conf
 
#Restart services
systemctl restart postgresql apache2 renderd
 
#update osmosis baseURL in configuration file
WORKDIR_OSM=/home/${OSM_USER}/.osmosis
if [ -f ${WORKDIR_OSM}/configuration.txt ]; then
	#Get the URL from http://download.geofabrik.de/europe/germany.html
	#example PBF_URL='http://download.geofabrik.de/europe/germany-latest.osm.pbf'
	UPDATE_URL="$(echo ${PBF_URL} | sed 's/latest.osm.pbf/updates/')"
	sed -i.save "s|#\?baseUrl=.*|baseUrl=${UPDATE_URL}|" ${WORKDIR_OSM}/configuration.txt
fi
 
#Update leaflet
LOC_NAME=$(echo ${PBF_URL##*/} | sed 's/\(.*\)-latest.*/\1/')
cat >/tmp/latlong.php <<EOF
<?php
  \$Address = urlencode(\$argv[1]);
  \$request_url = "http://maps.googleapis.com/maps/api/geocode/xml?address=".\$Address."&sensor=true";
  \$xml = simplexml_load_file(\$request_url) or die("url not loading");
  \$status = \$xml->status;
  if (\$status=="OK") {
      \$Lat = \$xml->result->geometry->location->lat;
      \$Lon = \$xml->result->geometry->location->lng;
      \$LatLng = "\$Lat,\$Lon";
	echo "\$LatLng";
  }
?>
EOF
echo "Updating lat,long for ${LOC_NAME} in Leaflet..."
LOC_LATLONG=$(php /tmp/latlong.php "${LOC_NAME}")
if [ -z "${LOC_LATLONG}" ]; then
	echo "Error: Lat/Long for ${LOC_NAME} not found";
	echo "Update manually in /var/www/html/leaflet-example.html"
else
	echo "Lat/Long for ${LOC_NAME} set to ${LOC_LATLONG}"
	sed -i.save "s/\.setView(\[[0-9]\+\.[0-9]\+,[ \t]*-\?[0-9]\+\.[0-9]\+/.setView([${LOC_LATLONG}/" /var/www/html/leaflet-example.html
	sed -i.save "s/L\.marker(\[[0-9]\+\.[0-9]\+,[ \t]*-\?[0-9]\+\.[0-9]\+/L.marker([${LOC_LATLONG}/" /var/www/html/leaflet-example.html
fi
