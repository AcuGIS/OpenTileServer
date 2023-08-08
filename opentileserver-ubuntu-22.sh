#!/bin/bash -e

#For use on clean Ubuntu 22.04 only!!!
# TODO: disable bright, because of PROJ 8 ?
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
HNAME=$(hostname | sed -n 1p | cut -f1 -d' ' | tr -d '\n')

NP=$(grep -c 'model name' /proc/cpuinfo)
osm2pgsql_OPTS="--slim -d ${OSM_DB} --number-processes ${NP} --hstore"

function style_osm_bright(){
	cd /usr/local/share/maps/style
	if [ ! -d 'osm-bright-master' ]; then
		wget --no-check-certificate https://github.com/mapbox/osm-bright/archive/master.zip
		unzip master.zip
		mkdir -p osm-bright-master/shp
		rm -f master.zip
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
		wget https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip
		unzip ne_10m_populated_places.zip
		mkdir -p osm-bright-master/shp/ne_10m_populated_places
		rm ne_10m_populated_places.zip
		mv ne_10m_populated_places.* osm-bright-master/shp/ne_10m_populated_places/
	fi


	#9 Configuring OSM Bright
	if [ $(grep -c '.zip' /usr/local/share/maps/style/osm-bright-master/osm-bright/osm-bright.osm2pgsql.mml) -ne 0 ]; then	#if we have zip in mml
		cd /usr/local/share/maps/style/osm-bright-master
		
		sed -i.save '
s|.*simplified-land-polygons-complete-3857.zip",|"file":"/usr/local/share/maps/style/osm-bright-master/shp/simplified-land-polygons-complete-3857/simplified_land_polygons.shp",\n"type": "shape",|
s|.*land-polygons-split-3857.zip"|"file":"/usr/local/share/maps/style/osm-bright-master/shp/land-polygons-split-3857/land_polygons.shp",\n"type":"shape"|
s|.*10m-populated-places-simple.zip"|"file":"/usr/local/share/maps/style/osm-bright-master/shp/ne_10m_populated_places/ne_10m_populated_places.shp",\n"type": "shape"|' osm-bright/osm-bright.osm2pgsql.mml

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
	apt-get -y install python2.7-minimal
	
	if [ ! -f /usr/local/share/maps/style/osm-bright-master/OSMBright/OSMBright.xml ]; then
		cd /usr/local/share/maps/style/osm-bright-master
		cp configure.py.sample configure.py
		sed -i.save 's|config\["path"\].*|config\["path"\] = path.expanduser("/usr/local/share/maps/style")|' configure.py
		
		sed -i.save "
s|config\[\"postgis\"\]\[\"dbname\"\].*|config\[\"postgis\"\]\[\"dbname\"\]=\"${OSM_DB}\"|
s|config\[\"postgis\"\]\[\"user\"\].*|config\[\"postgis\"\]\[\"user\"\]=\"${OSM_USER}\"|
s|config\[\"postgis\"\]\[\"password\"\].*|config\[\"postgis\"\]\[\"password\"\]=\"${OSM_USER_PASS}\"|" configure.py
		
		python2.7 ./configure.py
		python2.7 ./make.py
		cd ../OSMBright/
	
		carto project.mml > OSMBright.xml
	fi
	OSM_STYLE_XML='/usr/local/share/maps/style/OSMBright/OSMBright.xml'
}

function install_npm_carto(){
	apt-get -y install npm nodejs
	npm install -g carto
}

function style_osm_carto(){
	CARTO_VER='5.7.0'
	apt-get -y install fonts-droid-fallback fonts-unifont fonts-sipa-arundina \
				fonts-sil-padauk fonts-khmeros fonts-indic fonts-taml-tscu fonts-lohit-knda fonts-knda \
				fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted fonts-hanazono \
				python3-psycopg2 gdal-bin


	cd /usr/local/share/maps/style
	if [ ! -d openstreetmap-carto-${CARTO_VER} ]; then
		wget --no-check-certificate https://github.com/gravitystorm/openstreetmap-carto/archive/v${CARTO_VER}.zip
		unzip v${CARTO_VER}.zip
		rm -f v${CARTO_VER}.zip
	fi
	cd openstreetmap-carto-${CARTO_VER}/

	./scripts/get-external-data.py -d ${OSM_DB} -U ${OSM_USER}
	#./scripts/get-fonts.sh

	sed -i.save '/dbname: "gis"/a\    user: "tile"' project.mml

	carto -a "3.0.22" project.mml >osm-carto.xml

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
	echo "${OSM_USER} PG pass: ${OSM_PG_PASS}" >> /root/auth.txt

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
	apt-get install -y osm2pgsql
	
	if [ ${OSM_STYLE} == 'carto' ]; then
		apt-get install -y osm2pgsql python3-mapnik libmapnik3.1 mapnik-utils libmapnik-dev
	else
		build_mapnik_src;
	fi
	#build_mapnik_pkg;
}

function build_mapnik_src(){
	apt-get -y install cmake make gcc g++ autoconf python3-pip \
		libharfbuzz-dev libfreetype-dev libcairo2-dev
	#pip3 install scons
	
	git clone https://github.com/mapnik/mapnik.git
	
	pushd mapnik
		# fix for build failure
		#sed -i.save 's/DEFAULT_CXX_STD.*/DEFAULT_CXX_STD = "17"' SConstruct
		
		git submodule update --init
		
		#export PYTHON=python3
		#python3 scons/scons.py configure INPUT_PLUGINS=all OPTIMIZATION=3 SYSTEM_FONTS=/usr/share/fonts/truetype/ DEMO=False
		
		mkdir build
		pushd build
			cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
						-DBUILD_TESTING=OFF -DBUILD_DEMO_VIEWER=OFF -DBUILD_DEMO_CPP=OFF \
						-DUSE_STATS=ON \
						../
			JOBS=${NP} make
			make install
		popd
		
		cp ../utils/mapnik-config/mapnik-config /usr/bin/mapnik-config
		
		ldconfig
	popd
	rm -rf mapnik
}

function build_mapnik_pkg(){
	apt-get -y install build-essential pbuilder
	
	sed -i.save 's/# deb\-src/deb-src/' /etc/apt/sources.list
	apt-get -y update
	
	apt-get -y build-dep python3-mapnik libmapnik3.1 mapnik-utils libmapnik-dev
	
	apt-get -y source mapnik
	
	# trick SCons builder, which uses old proj_api.h for PROJ detection
	ln -s /usr/include/proj.h /usr/include/proj_api.h
	#touch /usr/include/proj_api.h
	
	pushd mapnik-3.1.0+ds
		sed -i.save 's|SCONS_FLAGS += PROJ_INCLUDES.*|SCONS_FLAGS += PROJ_INCLUDES=/usr/include/ PROJ_LIBS=/usr/lib/x86_64-linux-gnu/|' debian/rules
		debuild
	popd
}

function install_modtile(){
	apt-get -y install renderd libapache2-mod-tile
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
	cat >> /etc/renderd.conf <<CAT_EOF
[default]
XML=${OSM_STYLE_XML}
HOST=${HNAME}
URI=/osm_tiles/
TILEDIR=/var/cache/renderd/tiles
CAT_EOF
	
	if [ "${OSM_STYLE}" == 'bright' ]; then
		sed -i.save 's|^plugins_dir=.*|plugins_dir=/usr/lib/x86_64-linux-gnu/mapnik/input|' /etc/renderd.conf
	fi
}

function configure_webpages(){

	rm -f /var/www/html/index.html
 	wget --quiet -P/tmp https://github.com/AcuGIS/OpenTileServer/archive/refs/heads/master.zip
	unzip /tmp/master.zip -d/tmp

	cp -r /tmp/OpenTileServer-master/app/* /var/www/html/
	rm -rf /tmp/master.zip
  
	sed -i.save "s/localhost/${HNAME}/" /var/www/html/leaflet-example.html
	
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
			openssl genrsa -des3 -passout pass:${SSL_PASS} -out server.key 2048
			openssl rsa -in server.key -passin pass:${SSL_PASS} -out server.key

			chmod 400 server.key

			openssl req -new -key server.key -days 3650 -out server.crt -passin pass:${SSL_PASS} -x509 -subj '/C=CA/ST=Frankfurt/L=Frankfurt/O=acugis.com/CN=acugis.com/emailAddress=info@acugis.com'
			chown www-data:www-data server.key server.crt
		fi

		cat >/etc/apache2/sites-available/000-default-ssl.conf <<CMD_EOF
<IfModule mod_ssl.c>
	<VirtualHost _default_:443>
		ServerAdmin webmaster@localhost
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

	#create the custom indexes
	if [ $OSM_STYLE -eq 'carto' ]; then
		sudo -u ${OSM_USER} psql -d gis -f /usr/local/share/maps/style/openstreetmap-carto-${CARTO_VER}/indexes.sql
	fi

	#Turn on autovacuum and fsync after load of PBF
	sed -i.save 's/#\?fsync.*/fsync = on/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf
	sed -i.save 's/#\?autovacuum.*/autovacuum = on/' /etc/postgresql/${PG_MAJOR}/main/postgresql.conf
}


#Check input parameters
if [ -z "${PBF_URL}" -o \
	 $(echo "${OSM_STYLE}" | grep -c '[briht|carto]') -eq 0 -o \
	 $(echo "${WEB_MODE}"  | grep -c '[web|ssl]')	  -eq 0 ]; then
	echo "Usage: $0 [web|ssl] [bright|carto] pbf_url"; exit 1;
fi

touch /root/auth.txt

export DEBIAN_FRONTEND=noninteractive
apt-get clean

#needed for a lot of packages!
add-apt-repository -y universe

apt-get -y install tar unzip wget bzip2 \
					apache2 fonts-arphic-ukai fonts-arphic-uming fonts-thai-tlwg \
					lua-rrd-dev lua-rrd libgeotiff5 \
					postgresql postgresql-contrib postgis postgresql-14-postgis-3 \
					php libapache2-mod-php php-xml


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
systemctl restart postgresql apache2 renderd

cat <<EOF
OSM server install done.
Your authentication data is in /root/auth.txt
If you have CA signed certificates, replace server.crt and server.key in /etc/apache2/ssl
EOF
