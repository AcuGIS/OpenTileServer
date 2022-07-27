# OpenTileServer Docker

# Info
Dockerized OpenTileServer

First build the containers, then start PostgreSQL, renderd, and Apache. 

# Install
Clone OpenTileServer-Docker and copy docker-compose and api-gateway configuration template:

    git clone https://github.com/AcuGIS/OpenTileServer.git
    cd OpenTileServer/Docker
    docker-compose build
    docker-compose up -d
    
# Add PBF File

    $ docker images (to get container id)
    $ docker exec -it ${CONTAINER_ID} bash
    $ root@${CONTAINER_ID}:/home/tile# ./osm_load.sh 'https://download.geofabrik.de/europe/andorra-latest.osm.pbf'
    $ docker-compose restart tile
    
You can access PostgreSQL on localhost:5432 and Apache on localhost:8080



