sudo -i
cd /etc
mkdir spida
cd spida
wget https://raw.githubusercontent.com/spidasoftware/opentileserver/master/opentileserver.sh
chmod +x ./opentileserver.sh
vi opentileserver.sh
./opentileserver.sh ssl bright http://download.geofabrik.de/north-america/us/ohio-latest.osm.pbf 
