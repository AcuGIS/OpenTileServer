#!/bin/bash -e
#Version: 0.5.1
#Usage: ./opentileserver.sh [web|ssl] [bright|carto] [pbf_url]"
#Example for Delaware
# ./opentileserver.sh web carto http://download.geofabrik.de/north-america/us/delaware-latest.osm.pbf

DIST_YEAR=$(lsb_release -sr | cut -d '.' -f 1)


if [ "${0:17:6}" = "reload" ]; then
    SCRIPT_NAME="ubuntu-${DIST_YEAR}-reload.sh"
else
    SCRIPT_NAME="ubuntu-${DIST_YEAR}.sh"
fi    

chmod 755 $SCRIPT_NAME
./$SCRIPT_NAME  ${*}

