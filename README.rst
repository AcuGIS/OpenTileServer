OpenTileServer
===========================

This script is for building a basic tile server with OpenStreetMap data.

Only for use on a clean Ubuntu 14, Ubuntu 16, or Ubuntu 18 install!!


Features
--------

- Load OSM Data
- Load OSM data (city, country, continent or planet).
- Postgres, PostGIS, and osm2pgsql
- Installs Postgres, PostGIS, and osm2pgsql.
- Installs and configures Apache for http or https
- Mapnik, mod_tile, and renderd
- OSM-carto or OSM-bright
- OpenLayer and Leaflet example page.

Installation
------------

Step 1: Get opentileserver.sh script from GitHub

Step 2: Make it executable::

    $ chmod 755 opentileserver-ubuntu-xx.sh

Step 3 (for non-Latin alphabet)

If using a non-Latin alphabet, ucomment line 24 below if needed::

    $ export LC_ALL=C

See https://github.com/AcuGIS/opentileserver/issues/4

Step 4: Run the script::

$ ./opentileserver-ubuntu-xx.sh  [web|ssl] [bright|carto] pbf_url

Options
-------   
    
::

    [web|ssl]: 'web' for http and 'ssl' for https
    [bright|carto]: 'carto' for openstreetmap-carto or 'bright' for openstreetmap-bright
    pbf_url: Complete PBF url from GeoFabrik (or other source)

Examples
-----------

Load Delaware data with openstreetmap-carto style and no SSL::

    $ ./opentileserver.sh web carto http://download.geofabrik.de/north-america/us/delaware-latest.osm.pbf 

Load Bulgaria data with openstreetmap-bright style and SSL::
    
    $ ./opentileserver-ubuntu-xx.sh http://download.geofabrik.de/europe/bulgaria-latest.osm.pbf bright

Load South America data with openstreetmap-carto style and SSL::

    $ ./opentileserver-ubuntu-xx.sh ssl carto http://download.geofabrik.de/south-america-latest.osm.pbf

Welcome Page
------------

Once installation completes, navigate to the IP or hostname of your server.

You should see a page as below:

.. image:: https://opentileserver.org/assets/img/welcome.jpg


Click on both the OpenLayer and Leaflet Examples and check your installation is rendering

[Produced by AcuGIS. We Make GIS Simple](https://www.acugis.com) 

[Cited, Inc. Wilmington, Delaware](https://citedcorp.com)



Contribute
----------

- Issue Tracker: github.com/AcuGIS/OpenTileServer/issues
- Source Code: github.com/AcuGIS/OpenTileServer

Support
-------

If you are having issues, please let us know.
We have a mailing list located at: project@google-groups.com

License
-------

The project is licensed under the BSD license.
