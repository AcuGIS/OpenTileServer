#!/bin/bash -e
 
OSM_STYLE_XML="${1}"
 
sed -i 's/^#\s*\(deb.*universe\)$/\1/g' /etc/apt/sources.list
apt-get -y update
apt-get -y install apt-utils
 
apt-get -y install tar unzip wget bzip2 \
		python3-mapnik libmapnik3.0 mapnik-utils \
		ttf-unifont fonts-arphic-ukai fonts-arphic-uming fonts-thai-tlwg \
		apache2 postgresql-client lua-rrd libgeotiff5 build-essential autoconf \
  apache2-dev libcairo2-dev libcurl4-gnutls-dev libglib2.0-dev \
  libiniparser-dev libmapnik-dev libmemcached-dev librados-dev
 
unzip /tmp/mod_tile-0.6.1.zip && rm -f /tmp/mod_tile-0.6.1.zip
pushd mod_tile-0.6.1
./autogen.sh && ./configure
make && make install && make install-mod_tile
popd
 
rm -rf mod_tile-0.6.1
#apt-get -y remove build-essential autoconf \
#	apache2-dev libcairo2-dev libcurl4-gnutls-dev libglib2.0-dev \
#	libiniparser-dev libmapnik-dev libmemcached-dev librados-dev
 
ldconfig
 
mkdir -p /var/run/renderd /var/cache/renderd/tiles
chown www-data:www-data /var/run/renderd /var/cache/renderd/tiles
 
MAPNIK_PLUG=$(mapnik-config --input-plugins)
 
sed -i.save "s|^plugins_dir=.*|plugins_dir=${MAPNIK_PLUG}|" /usr/local/etc/renderd.conf
 
cat >> /usr/local/etc/renderd.conf << CAT_EOF
[default]
URI=/osm_tiles
XML=${OSM_STYLE_XML}
HOST=localhost
TILESIZE=256
CAT_EOF
