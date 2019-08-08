#!/bin/bash -e
#Version: 0.5.1
#For use on clean Ubuntu 18 only!!!
#Cited, Inc. Wilmington, Delaware
#Usage: ./opentileserver.sh [web|ssl] [bright|carto] [pbf_url]"
#Example for Delaware
# ./opentileserver.sh web carto http://download.geofabrik.de/north-america/us/delaware-latest.osm.pbf

WEB_MODE="${1}"   #web,ssl
OSM_STYLE="${2}"	#bright, carto
PBF_URL="${3}";		#pbf URL
OSM_STYLE_XML=''

#User for DB and rednerd
OSM_USER='tile';			#system user for renderd and db
OSM_USER_PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
OSM_PG_PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32);
OSM_DB='gis';				#osm database name
VHOST=$(hostname -f)

NP=$(grep -c 'model name' /proc/cpuinfo)
osm2pgsql_OPTS="--slim -d ${OSM_DB} --number-processes ${NP} --hstore"

#Check input parameters
if [ -z "${PBF_URL}" -o \
	 $(echo "${OSM_STYLE}" | grep -c '[briht|carto]') -eq 0 -o \
	 $(echo "${WEB_MODE}"  | grep -c '[web|ssl]')	  -eq 0 ]; then
	echo "Usage: $0 [web|ssl] [bright|carto] pbf_url"; exit 1;
fi

touch /root/auth.txt

function style_osm_bright(){
	cd /usr/local/share/maps/style
	if [ ! -d 'osm-bright-master' ]; then
		wget --no-check-certificate https://github.com/mapbox/osm-bright/archive/master.zip
		unzip master.zip;
		mkdir -p osm-bright-master/shp
		rm master.zip
	fi

	for shp in 'land-polygons-split-3857' 'simplified-land-polygons-complete-3857'; do
		if [ ! -d "osm-bright-master/shp/${shp}" ]; then
			wget https://osmdata.openstreetmap.de/download/${shp}.zip
			unzip ${shp}.zip;
			mv ${shp}/ osm-bright-master/shp/
			rm ${shp}.zip
			pushd osm-bright-master/shp/${shp}/
				shapeindex *.shp
			popd
		fi
	done

	if [ ! -d 'osm-bright-master/shp/ne_10m_populated_places' ]; then
		wget http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip
		unzip ne_10m_populated_places.zip
		mkdir -p osm-bright-master/shp/ne_10m_populated_places
		rm ne_10m_populated_places.zip
		mv ne_10m_populated_places.* osm-bright-master/shp/ne_10m_populated_places/
	fi


	#9 Configuring OSM Bright
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

	#10 Compiling the stylesheet
	if [ ! -f /usr/local/share/maps/style/osm-bright-master/OSMBright/OSMBright.xml ]; then
		cd /usr/local/share/maps/style/osm-bright-master
		cp configure.py.sample configure.py
		sed -i.save 's|config\["path"\].*|config\["path"\] = path.expanduser("/usr/local/share/maps/style")|' configure.py
		sed -i.save "s|config\[\"postgis\"\]\[\"dbname\"\].*|config\[\"postgis\"\]\[\"dbname\"\]=\"${OSM_DB}\"|" configure.py
		./configure.py
		./make.py
		cd ../OSMBright/

		npm install -g carto@1.0.1
		carto project.mml > OSMBright.xml
	fi
	OSM_STYLE_XML='/usr/local/share/maps/style/OSMBright/OSMBright.xml'
}

function install_npm_carto(){
	apt-get -y install npm nodejs
	npm install -g carto@1.0.1
	ln -sf /usr/lib/nodejs/carto/bin/carto /usr/local/bin/carto
}

function style_osm_carto(){
	CARTO_VER='4.13.0'
	apt-get -y install ttf-dejavu fonts-droid-fallback ttf-unifont fonts-sipa-arundina fonts-sil-padauk fonts-khmeros fonts-indic fonts-taml-tscu fonts-lohit-knda fonts-knda

	cd /usr/local/share/maps/style
	if [ ! -d openstreetmap-carto-${CARTO_VER} ]; then
		wget --no-check-certificate https://github.com/gravitystorm/openstreetmap-carto/archive/v${CARTO_VER}.zip
		unzip v${CARTO_VER}.zip
		rm v${CARTO_VER}.zip
	fi
	cd openstreetmap-carto-${CARTO_VER}/

  sed -i.save 's|http://data\.openstreetmapdata\.com|https://osmdata\.openstreetmap\.de/download|' scripts/get-shapefiles.py

	if [ $(find data/ -type f -name "*.shp" 2>/dev/null | wc -l) -ne 6 ]; then
		./scripts/get-shapefiles.py
		rm data/*.zip data/world_boundaries-spherical.tgz
	fi

	npm install -g carto@1.0.1
	carto project.mml >osm-carto.xml

	osm2pgsql_OPTS+=" --style /usr/local/share/maps/style/openstreetmap-carto-${CARTO_VER}/openstreetmap-carto.style"
	osm2pgsql_OPTS+=" --tag-transform-script /usr/local/share/maps/style/openstreetmap-carto-${CARTO_VER}/openstreetmap-carto.lua"
	OSM_STYLE_XML="/usr/local/share/maps/style/openstreetmap-carto-${CARTO_VER}/osm-carto.xml"
}

function enable_osm_updates(){
	apt-get -y install osmosis

	export WORKDIR_OSM=/home/${OSM_USER}/.osmosis

	if [ $(grep -c 'WORKDIR_OSM' /etc/environment) -eq 0 ]; then
		echo 'export WORKDIR_OSM=/home/tile/.osmosis' >> /etc/environment
		mkdir -p $WORKDIR_OSM
		osmosis --read-replication-interval-init workingDirectory=${WORKDIR_OSM}
	fi

	#2. Generating state.txt
	if [ ! -f ${WORKDIR_OSM}/state.txt ]; then
		#NOTE: If you want hourly updates set stream=hourly
    STATE_URL="https://replicate-sequences.osm.mazdermind.de/?$(date -u +"%Y-%m-%dT%TZ")&stream=day"
		wget --no-check-certificate -O${WORKDIR_OSM}/state.txt ${STATE_URL}
	fi

	#3. Fix configuration.txt
	#Get the URL from http://download.geofabrik.de/europe/germany.html
	#example PBF_URL='http://download.geofabrik.de/europe/germany-latest.osm.pbf'
	UPDATE_URL="$(echo ${PBF_URL} | sed 's/latest.osm.pbf/updates/')"
	sed -i.save "s|#\?baseUrl=.*|baseUrl=${UPDATE_URL}|" ${WORKDIR_OSM}/configuration.txt

	#4. Add step 4 to cron, to make it run every day
	if [ ! -f /etc/cron.daily/osm_update ]; then
		cat >/etc/cron.daily/osm_update <<CMD_EOF
#!/bin/bash
export WORKDIR_OSM=/home/${OSM_USER}/.osmosis
export PGPASSWORD="${OSM_PG_PASS}"
osmosis --read-replication-interval workingDirectory=${WORKDIR_OSM} --simplify-change --write-xml-change /tmp/changes.osc.gz
sudo -u postgres osm2pgsql --append ${osm2pgsql_OPTS} /tmp/changes.osc.gz
CMD_EOF
		chmod +x /etc/cron.daily/osm_update
	fi
}

function create_system_user(){
	#3 Create system user
	if [ $(grep -wc ${OSM_USER} /etc/passwd) -eq 0 ]; then	#if we don't have the OSM user
		useradd -m ${OSM_USER}
		echo ${OSM_USER}:${OSM_USER_PASS} | chpasswd
		echo "${OSM_USER} pass: ${OSM_USER_PASS}" >> /root/auth.txt
	fi

	cat >/etc/postgresql/${PG_VER%.*}/main/pg_hba.conf <<CMD_EOF
local all all trust
host all all 127.0.0.1 255.255.255.255 md5
host all all 0.0.0.0/0 md5
host all all ::1/128 md5
CMD_EOF
	systemctl restart postgresql

	if [ $(psql -Upostgres -c "select usename from pg_user" | grep -m 1 -c ${OSM_USER}) -eq 0 ]; then
		psql -Upostgres -c "create user ${OSM_USER} with password '${OSM_PG_PASS}';"
	else
		psql -Upostgres -c "alter user ${OSM_USER} with password '${OSM_PG_PASS}';"
	fi

	if [ $(psql -Upostgres -c "select datname from pg_database" | grep -m 1 -c ${OSM_DB}) -eq 0 ]; then
		psql -Upostgres -c "create database ${OSM_DB} owner=${OSM_USER};"
	fi

	psql -Upostgres ${OSM_DB} <<EOF_CMD
\c ${OSM_DB}
CREATE EXTENSION hstore;
CREATE EXTENSION postgis;
ALTER TABLE geometry_columns OWNER TO ${OSM_USER};
ALTER TABLE spatial_ref_sys OWNER TO ${OSM_USER};
EOF_CMD
}

function install_mapnik(){
	#5 Installing osm2pgsql and mapnik
	#osm2pgsql has pg-9.3 dependency
	apt-get install -y osm2pgsql python-mapnik libmapnik3.0 mapnik-utils libmapnik-dev
}

function install_modtile(){
	#7 Install modtile and renderd
	if [ "$(which renderd)" ]; then	#if mapnik is installed
		return 0;
	fi

	mkdir -p ~/src
	cd ~/src
	git clone https://github.com/openstreetmap/mod_tile.git
	if [ ! -d mod_tile ]; then "Error: Failed to download mod_tile"; exit 1; fi

	cd mod_tile
	./autogen.sh
	./configure

	#install breaks if dir exists
	if [ -d /var/lib/mod_tile ]; then rm -r /var/lib/mod_tile; fi

	make
	make install
	make install-mod_tile

	ldconfig
	cp  debian/renderd.init /etc/init.d/renderd
	#Update daemon config
	sed -i.save 's|^DAEMON=.*|DAEMON=/usr/local/bin/$NAME|' /etc/init.d/renderd
	sed -i.save 's|^DAEMON_ARGS=.*|DAEMON_ARGS="-c /usr/local/etc/renderd.conf"|' /etc/init.d/renderd
	sed -i.save "s|^RUNASUSER=.*|RUNASUSER=${OSM_USER}|" /etc/init.d/renderd

	chmod u+x /etc/init.d/renderd
	ln -sf /etc/init.d/renderd /etc/rc2.d/S20renderd
	mkdir -p /var/run/renderd
	chown ${OSM_USER}:${OSM_USER} /var/run/renderd

	cd ../
	rm -rf mod_tile
}

function configure_stylesheet(){
	install_npm_carto;
	mkdir -p /usr/local/share/maps/style
	case $OSM_STYLE in
		bright)
			style_osm_bright
			;;
		carto)
			style_osm_carto
			;;
		*)
			echo "Error: Unknown style"; exit 1;
			;;
	esac
}

function configure_webserver(){

	MAPNIK_PLUG=$(mapnik-config --input-plugins)
	#remove commented lines, because daemon produces warning!
	sed -i.save '/^;/d' /usr/local/etc/renderd.conf
	sed -i.save 's/;socketname/socketname/' /usr/local/etc/renderd.conf
	sed -i.save "s|^plugins_dir=.*|plugins_dir=${MAPNIK_PLUG}|" /usr/local/etc/renderd.conf
	sed -i.save 's|^font_dir=.*|font_dir=/usr/share/fonts/truetype/|' /usr/local/etc/renderd.conf
	sed -i.save "s|^XML=.*|XML=${OSM_STYLE_XML}|" /usr/local/etc/renderd.conf
	sed -i.save 's|^HOST=.*|HOST=localhost|' /usr/local/etc/renderd.conf

	mkdir -p /var/run/renderd
	chown ${OSM_USER}:${OSM_USER} /var/run/renderd
	mkdir -p /var/lib/mod_tile
	chown ${OSM_USER}:${OSM_USER} /var/lib/mod_tile

	#12 Configure mod_tile
	if [ ! -f /etc/apache2/conf-available/mod_tile.conf ]; then
		echo 'LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so' > /etc/apache2/conf-available/mod_tile.conf

		echo 'LoadTileConfigFile /usr/local/etc/renderd.conf
	ModTileRenderdSocketName /var/run/renderd/renderd.sock
	# Timeout before giving up for a tile to be rendered
	ModTileRequestTimeout 0
	# Timeout before giving up for a tile to be rendered that is otherwise missing
	ModTileMissingRequestTimeout 30' > /etc/apache2/sites-available/tile.conf

		sed -i.save "/ServerAdmin/aInclude /etc/apache2/sites-available/tile.conf" /etc/apache2/sites-available/000-default.conf

		a2enconf mod_tile
		systemctl reload apache2
	fi
}

function configure_webpages(){
	#Download html pages
	rm -f /var/www/html/index.html
	for p in openlayers-example leaflet-example index; do
		wget --no-check-certificate -P/var/www/html/ https://cdn.acugis.com/osm-assets/htmls/${p}.html
	done

	sed -i.save "s|localhost|$(hostname -I | tr -d ' ')|" /var/www/html/leaflet-example.html


	#Set Leaflet point of view
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

	if [ "${WEB_MODE}" == 'ssl' ]; then
		mkdir -p /etc/apache2/ssl/
		#create SSL certificates
		if [ ! -f /etc/apache2/ssl/server.key -o ! -f /etc/apache2/ssl/server.crt ]; then
			SSL_PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32);
			if [ $(grep -m 1 -c 'ssl pass' /root/auth.txt) -eq 0 ]; then
				echo "ssl pass: ${SSL_PASS}" >> /root/auth.txt
			fi
			cd /etc/apache2/ssl/
			openssl genrsa -des3 -passout pass:${SSL_PASS} -out server.key 1024
			openssl rsa -in server.key -passin pass:${SSL_PASS} -out server.key

			chmod 400 server.key

			openssl req -new -key server.key -days 3650 -out server.crt -passin pass:${SSL_PASS} -x509 -subj '/C=CA/ST=Frankfurt/L=Frankfurt/O=acugis.com/CN=acugis.com/emailAddress=info@acugis.com'
			chown www-data:www-data server.key server.crt
		fi

		cat >/etc/apache2/sites-available/000-default-ssl.conf <<CMD_EOF
<IfModule mod_ssl.c>
	<VirtualHost _default_:443>
		ServerAdmin webmaster@localhost
        Include /etc/apache2/sites-available/tile.conf
        DocumentRoot /var/www/html

		#LogLevel info ssl:warn

		ErrorLog \${APACHE_LOG_DIR}/error.log
		CustomLog \${APACHE_LOG_DIR}/access.log combined

		SSLEngine on
		SSLCertificateFile	/etc/apache2/ssl/server.crt
		SSLCertificateKeyFile /etc/apache2/ssl/server.key
		#SSLCertificateChainFile /etc/apache2/ssl/DigiCertCA.crt

		<FilesMatch "\.(cgi|shtml|phtml|php)$">
				SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
			SSLOptions +StdEnvVars
		</Directory>

		BrowserMatch "MSIE [2-6]" \
				nokeepalive ssl-unclean-shutdown \
				downgrade-1.0 force-response-1.0
		# MSIE 7 and newer should be able to use keepalive
		BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

	</VirtualHost>
</IfModule>
CMD_EOF
		ln -sf /etc/apache2/sites-available/000-default-ssl.conf /etc/apache2/sites-enabled/
		a2enmod ssl

	else
		cat >/etc/apache2/sites-available/000-default.conf <<CMD_EOF
<VirtualHost _default_:80>
	ServerAdmin webmaster@localhost
	Include /etc/apache2/sites-available/tile.conf
	DocumentRoot /var/www/html
	ServerName ${VHOST}

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
CMD_EOF
		ln -sf /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/
	fi
}

function tune_system(){

	sed -i 's/#\?shared_buffers.*/shared_buffers = 128MB/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf
	sed -i 's/#\?checkpoint_segments.*/checkpoint_segments = 20/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf
	sed -i 's/#\?maintenance_work_mem.*/maintenance_work_mem = 256MB/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf

	if [ $(grep -c 'kernel.shmmax=268435456' /etc/sysctl.conf) -eq 0 ]; then
		echo '# Increase kernel shared memory segments - needed for large databases
	kernel.shmmax=268435456' >> /etc/sysctl.conf
		sysctl -w kernel.shmmax=268435456
	fi
}

function load_data(){
	#Turn off autovacuum and fsync during load of PBF
	sed -i 's/#\?fsync.*/fsync = off/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf
	sed -i 's/#\?autovacuum.*/autovacuum = off/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf

	systemctl restart postgresql

	PBF_FILE="/home/${OSM_USER}/${PBF_URL##*/}"
	cd /home/${OSM_USER}
	if [ ! -f ${PBF_FILE} ]; then
		wget ${PBF_URL}
		chown ${OSM_USER}:${OSM_USER} ${PBF_FILE}
	fi

	#get available memory just before we call osm2pgsql!
	let C_MEM=$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f7 -d' ')-200
	sudo -u ${OSM_USER} osm2pgsql ${osm2pgsql_OPTS} -C ${C_MEM} ${PBF_FILE}

	if [ $? -eq 0 ]; then	#If import went good
		rm -rf ${PBF_FILE}
	fi

	#Turn on autovacuum and fsync after load of PBF
	sed -i.save 's/#\?fsync.*/fsync = on/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf
	sed -i.save 's/#\?autovacuum.*/autovacuum = on/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf
}

#Steps
#1 Update ATP and install needed packages
export DEBIAN_FRONTEND=noninteractive
apt-get clean

#needed for a lot of packages!
add-apt-repository universe

apt-get -y install	libboost-dev subversion git tar unzip wget bzip2 \
					build-essential autoconf libtool libxml2-dev libgeos-dev \
					libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node \
					munin libprotobuf-c-dev protobuf-c-compiler libfreetype6-dev \
					libpng-dev libtiff5-dev libicu-dev libgdal-dev libcairo2-dev \
					libcairomm-1.0-dev apache2 apache2-dev libagg-dev \
					ttf-unifont fonts-arphic-ukai fonts-arphic-uming fonts-thai-tlwg \
					lua-rrd-dev lua-rrd libgeotiff2 node-carto \
					postgresql postgresql-contrib postgis postgresql-10-postgis-2.4 \
					php libapache2-mod-php php7.2-xml

PG_VER=$(pg_config | grep '^VERSION' | cut -f4 -d' ' | cut -f1,2 -d.)
PG_MAJOR=${PG_VER%.*}

create_system_user;
install_mapnik;
install_modtile;

configure_stylesheet;
configure_webserver;
configure_webpages;

tune_system;

load_data;

ldconfig
enable_osm_updates

#tiles need to have access without password
sed -i 's/local all all.*/local all all trust/'  /etc/postgresql/${PG_MAJOR}/main/pg_hba.conf

#Restart services
systemctl daemon-reload
systemctl restart postgresql apache2 renderd

cat <<EOF
OSM server install done.
Your authentication data is in /root/auth.txt
If you have CA signed certificates, replace server.crt and server.key in /etc/apache2/ssl
EOF
