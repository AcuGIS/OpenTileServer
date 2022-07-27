import sys
import requests
import re
 
place = sys.argv[1]
url = 'https://www.mapdevelopers.com/geocode_tool.php?address=' + place
response = requests.get(url)
if response.status_code == 200:
	res = re.findall(r"geocode_tool\.php\?lat=([0-9\-\.]+)&lng=([0-9\-\.]+)", str(response.content));
	print(res[0][0] + "," + res[0][1])
