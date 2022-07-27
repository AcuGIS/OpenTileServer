#!/bin/bash
#export WORKDIR_OSM=/home/${OSM_USER}/.osmosis
export PGPASSWORD="${POSTGRES_PASSWORD}"
NP=$(grep -c 'model name' /proc/cpuinfo)
osm2pgsql_OPTS="--slim -d ${POSTGRES_DB} --number-processes ${NP} --hstore"
 
osmosis --read-replication-interval workingDirectory=${WORKDIR_OSM} --simplify-change --write-xml-change /tmp/changes.osc.gz
sudo -u ${POSTGRES_USER} osm2pgsql --append ${osm2pgsql_OPTS} /tmp/changes.osc.gz
