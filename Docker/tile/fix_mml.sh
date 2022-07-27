if [ $(grep -c '.zip' /usr/local/share/maps/style/osm-bright-master/osm-bright/osm-bright.osm2pgsql.mml) -ne 0 ]; then	#if we have zip in mml
	cd /usr/local/share/maps/style/osm-bright-master
	cp osm-bright/osm-bright.osm2pgsql.mml osm-bright/osm-bright.osm2pgsql.mml.orig
	sed -i.save 's|.*simplified-land-polygons-complete-3857.zip",|"file":"/usr/local/share/maps/style/osm-bright-master/shp/simplified-land-polygons-complete-3857/simplified_land_polygons.shp",\n"type": "shape",|' osm-bright/osm-bright.osm2pgsql.mml
	sed -i.save 's|.*land-polygons-split-3857.zip"|"file":"/usr/local/share/maps/style/osm-bright-master/shp/land-polygons-split-3857/land_polygons.shp",\n"type":"shape"|' osm-bright/osm-bright.osm2pgsql.mml
	sed -i.save 's|.*10m-populated-places-simple.zip"|"file":"/usr/local/share/maps/style/osm-bright-master/shp/ne_10m_populated_places/ne_10m_populated_places.shp",\n"type": "shape"|' osm-bright/osm-bright.osm2pgsql.mml
 
	sed -i.save '/name":[ \t]*"ne_places"/a"srs": "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"' osm-bright/osm-bright.osm2pgsql.mml
	#Delete
	#"srs": "",
	#      "srs_name": "",
	LINE_FROM=$(grep -n '"srs": "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"' osm-bright/osm-bright.osm2pgsql.mml | cut -f1 -d':')
	let LINE_FROM=LINE_FROM+1
	let LINE_TO=LINE_FROM+1
	sed -i.save "${LINE_FROM},${LINE_TO}d" osm-bright/osm-bright.osm2pgsql.mml
fi
