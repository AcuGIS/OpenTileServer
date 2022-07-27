FROM ubuntu:20.04
LABEL maintainer="AcuGIS <hello@citedcorp.com>"
SHELL ["/bin/bash", "-c"]

ENV WORKDIR_OSM=/var/tmp/.osmosis
ENV OSM_STYLE_XML='/usr/local/share/maps/style/OSMBright/OSMBright.xml'

ARG DEBIAN_FRONTEND=noninteractive
ARG POSTGRES_DB
ARG POSTGRES_USER
ARG POSTGRES_PASSWORD
ARG PBF_URL

# Install packages needed for building
# install modtile/renderd
ADD https://github.com/openstreetmap/mod_tile/archive/refs/tags/0.6.1.zip /tmp/mod_tile-0.6.1.zip
COPY build_modtile.sh /tmp/build_modtile.sh
RUN bash /tmp/build_modtile.sh ${OSM_STYLE_XML} && rm /tmp/build_modtile.sh

# install carto
RUN apt-get -y install npm nodejs && \
	npm install -g carto

# install Bright stylesheet
ADD https://github.com/mapbox/osm-bright/archive/master.zip /tmp/master.zip
RUN mkdir -p /usr/local/share/maps/style
WORKDIR /usr/local/share/maps/style
RUN	unzip /tmp/master.zip && rm -f /tmp/master.zip && \
	mkdir -p osm-bright-master/shp

# TODO: do we need the .shp files (1.2GB), after indexing ?
COPY index_polygons.sh /tmp/index_polygons.sh
RUN	bash /tmp/index_polygons.sh && rm -f /tmp/index_polygons.sh

# Configuring OSM Bright
COPY fix_mml.sh /tmp/fix_mml.sh
ADD http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip /tmp/ne_10m_populated_places.zip
RUN unzip /tmp/ne_10m_populated_places.zip && rm -f /tmp/ne_10m_populated_places.zip && \
	mkdir -p osm-bright-master/shp/ne_10m_populated_places && \
	mv ne_10m_populated_places.* osm-bright-master/shp/ne_10m_populated_places/ && \
	bash /tmp/fix_mml.sh && rm -f /tmp/fix_mml.sh

# Compiling the stylesheet
WORKDIR /usr/local/share/maps/style/osm-bright-master
RUN apt-get -y install python2 && \
	ln -s /usr/bin/python2 /usr/bin/python && \
	mv configure.py.sample configure.py && \
	sed -i.save 's|config\["path"\].*|config\["path"\] = path.expanduser("/usr/local/share/maps/style")|' configure.py && \
	sed -i.save "s|config\[\"postgis\"\]\[\"host\"\].*|config\[\"postgis\"\]\[\"host\"\]=\"pg\"|" configure.py && \
	sed -i.save "s|config\[\"postgis\"\]\[\"dbname\"\].*|config\[\"postgis\"\]\[\"dbname\"\]=\"${POSTGRES_DB}\"|" configure.py && \
	sed -i.save "s|config\[\"postgis\"\]\[\"user\"\].*|config\[\"postgis\"\]\[\"user\"\]=\"${POSTGRES_USER}\"|" configure.py && \
	sed -i.save "s|config\[\"postgis\"\]\[\"password\"\].*|config\[\"postgis\"\]\[\"password\"\]=\"${POSTGRES_PASSWORD}\"|" configure.py && \
	./configure.py && \
	./make.py && \
	cd ../OSMBright/ && \
	carto project.mml > OSMBright.xml

# Configure webserver
COPY mod_tile.load  	/etc/apache2/mods-enabled/mod_tile.load
COPY renderd.conf     /etc/apache2/conf-available/renderd.conf
COPY 000-default.conf /etc/apache2/sites-available/000-default.conf
RUN a2enconf renderd && a2ensite 000-default

# Configure webpages
ADD https://cdn.acugis.com/osm-assets/htmls/openlayers-example.html /var/www/html/openlayers-example.html
ADD https://cdn.acugis.com/osm-assets/htmls/leaflet-example.html 		/var/www/html/leaflet-example.html
ADD https://cdn.acugis.com/osm-assets/htmls/index.html 							/var/www/html/index.html
COPY latlong.py /tmp/latlong.py
RUN LOC_NAME=$(echo ${##*/} | sed 's/\(.*\)-latest.*/\1/') \
	&& sed -i.save "s|localhost|$(hostname -I | tr -d ' ')|" /var/www/html/leaflet-example.html \
	&& apt-get -y install python3-requests \
	&& LOC_LATLONG=$(python3 /tmp/latlong.py "${LOC_NAME}") \
	&& sed -i.save "s/\.setView(\[[0-9]\+\.[0-9]\+,[ \t]*-\?[0-9]\+\.[0-9]\+/.setView([${LOC_LATLONG}/" /var/www/html/leaflet-example.html \
	&& sed -i.save "s/L\.marker(\[[0-9]\+\.[0-9]\+,[ \t]*-\?[0-9]\+\.[0-9]\+/L.marker([${LOC_LATLONG}/" /var/www/html/leaflet-example.html \
	&& rm -f /tmp/latlong.py \
	&& chown -R www-data:www-data /var/www/

# install osmosis
COPY osm_update.sh /etc/cron.daily/osm_update
RUN apt-get -y install osmosis && \
	echo 'WORKDIR_OSM=/var/tmp/.osmosis' >> /etc/environment && \
	mkdir -p "${WORKDIR_OSM}" && \
	osmosis --read-replication-interval-init workingDirectory=${WORKDIR_OSM} && \
	STATE_URL="https://replicate-sequences.osm.mazdermind.de/?$(date -u +"%Y-%m-%dT%TZ")&stream=day" && \
	wget --no-check-certificate -O${WORKDIR_OSM}/state.txt ${STATE_URL} && \
	UPDATE_URL="$(echo ${PBF_URL} | sed 's/latest.osm.pbf/updates/')" && \
	sed -i.save "s|#\?baseUrl=.*|baseUrl=${UPDATE_URL}|" ${WORKDIR_OSM}/configuration.txt && \
	chmod +x /etc/cron.daily/osm_update

# install osm2pgsql
RUN apt-get -y --no-install-recommends install osm2pgsql

# Cleanup
RUN    apt-get clean \
    && apt-get -y autoclean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/doc/*

RUN useradd -m ${POSTGRES_USER} \
	&& echo ${POSTGRES_USER}:${POSTGRES_PASSWORD} | chpasswd \
	&& echo "pg:5432:${POSTGRES_DB}:${POSTGRES_USER}:${POSTGRES_PASSWORD}" > /home/${POSTGRES_USER}/.pgpass \
	&& chown ${POSTGRES_USER}:${POSTGRES_USER} /home/${POSTGRES_USER}/.pgpass

COPY entrypoint.sh /entrypoint.sh
COPY osm_load.sh /home/${POSTGRES_USER}/osm_load.sh
RUN chmod +x /entrypoint.sh /home/${POSTGRES_USER}/osm_load.sh

WORKDIR /home/${POSTGRES_USER}
#USER ${POSTGRES_USER}
EXPOSE 80/tcp
#EXPOSE 443/tcp

CMD ["/entrypoint.sh"]
