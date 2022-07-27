for shp in 'land-polygons-split-3857' 'simplified-land-polygons-complete-3857'; do
	wget -nv --no-check-certificate https://osmdata.openstreetmap.de/download/${shp}.zip
	unzip ${shp}.zip
	rm -f ${shp}.zip
	mv ${shp}/ osm-bright-master/shp/
	pushd osm-bright-master/shp/${shp}/
		shapeindex *.shp
	popd
done
