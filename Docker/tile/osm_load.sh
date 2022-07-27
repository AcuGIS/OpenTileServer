#!/bin/bash -e
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGUSER=${POSTGRES_USER}
 
PBF_URL="${1}"
 
NP=$(grep -c 'model name' /proc/cpuinfo)
let C_MEM=$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f7 -d' ')-200
 
wget --no-check-certificate "${PBF_URL}"
PBF_FILE="${PBF_URL##*/}"
osm2pgsql --slim -H pg -d ${POSTGRES_DB} --number-processes ${NP} --hstore -C ${C_MEM} "${PBF_FILE}"
rm -rf "${PBF_FILE}"
 
# update osmosis URL
UPDATE_URL="$(echo ${PBF_URL} | sed 's/latest.osm.pbf/updates/')"
sed -i.save "s|#\?baseUrl=.*|baseUrl=${UPDATE_URL}|" ${WORKDIR_OSM}/configuration.txt
