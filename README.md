# opentileserver

This script is for building a basic tile server with OpenStreetMap data.

Only for use on a clean Ubuntu 14 install!!

Before proceeding, see <a href="opentileserver.org" target="blank"> opentileserver.org </a> for limitations, etc..

Step 1: Get opentileserver.sh script from GitHub

Step 2: Make it executable:

<code>chmod 755 opentileserver.sh</code>

Step 3:

vi and change the password on line 19 to something difficult

<code>
OSM_USER_PASS='osm2015SgsjcK';	#CHANGE ME
</code>

Step 4: Run the script

## Script usage:

<code>./opentileserver.sh  [web|ssl] [bright|carto] pbf_url</code>

[web|ssl]: 'web' for http and 'ssl' for https.

[bright|carto]: 'carto' for openstreetmap-carto or 'bright' for openstreetmap-bright

pbf_url: Complete PBF url from GeoFarbrik (or other source)


## Examples:

Load Delware data with openstreetmap-carto style and no SSL:

<code>./opentileserver.sh web carto http://download.geofabrik.de/north-america/us/delaware-latest.osm.pbf </code>

Load Bulgaria data with openstreetmap-bright style and SSL:

<code>./opentileserver.sh http://download.geofabrik.de/europe/bulgaria-latest.osm.pbf bright</code>

Load South America data with openstreetmap-carto style and SSL:

<code>./opentileserver.sh ssl carto http://download.geofabrik.de/south-america-latest.osm.pbf </code>


## Welcome Page

Once installation completes, navigate to the IP or hostname of your server.

You should see a page as below:

![installation complete](http://opentileserver.org/assets/img/welcome.jpg)


Click on both the OpenLayer and Leaflet Examples and check your installation is rendering

