# Map of all the Places (MOATP)

MOATP would be a script that creates a map for each and every one of the 2,100+ "Places" (boundaries) that Chicago Cityscape uses to slice and dice development data (building permits, building violations, business licenses, and property taxes). 

## Uses
The maps would be used across the site, and in transactional emails, in these ways:

- Referenced in the page as part of the OpenGraph so that Twitter, Buffer, Pinterest, and Facebook embed them within social media posts. 
- Embedded in Place-based transactional emails that Chicago Cityscape users subscribe to

## How to make the images
1. Use `svgis` to generate a GeoJSON for each Place (boundary). 
2. Use `osm-tiny-maps` to download Chicago streets, parks, and buildings from OpenStreetMap
3. Combine the GeoJSON for each place from `svgis` and overlay the Place boundary on the OSM data. The Place boundary would be conspicuous; the OSM data wouldn't be clipped to the boundary. The OSM data would extend past the image dimensions. 
