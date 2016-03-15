moatp
-----

MOATP is a workflow for combining GIS data in PostgreSQL and [OpenStreetMap](http://openstreetmap.org) geodata into beautiful and highly customizable SVG and PNG maps.

If you have a bunch of data in a PostgreSQL/PostGIS database and want to combine it with OpenStreetMap to create a whole bunch of maps, try it out.

Requirements
------------

* [GDAL](http://www.gdal.org) with PostgreSQL support
* [ImageMagick](http://www.imagemagick.org/script/binary-releases.php)
* [svgis](https://github.com/fitnr/svgis)

Recommended (these improve performance):
* [GEOS](https://trac.osgeo.org/geos/)
* [Numpy](http://www.numpy.org)

Installation tasks are included for OS X and two flavors of Linux:
```
make install-osx
sudo make install-ubuntu
sudo make install-centos
```

The OS X installer assumes [homebrew](http://brew.sh) (`brew`).

Both installers assume [`pip`](https://pip.pypa.io/en/stable/). If you don't have these available, install them first.

You can check if your machine is ready with this command:
```
which make && which pip && which brew
```
On OS X you should see three paths. On Linux, only two since brew isn't needed.

To test if the required commands are available, use the command `make check`. It should spit out the versions of `ogr2ogr`, `svgis` and `convert`.

Setup
-----

Add a file called `.pgpass` in this directory. It should have the format:
````
hostname:port:database:username:password
````
and `0600` permissions:
```
chmod 0600 .pgpass
```

[More info about .pgpass files](http://www.postgresql.org/docs/current/static/libpq-pgpass.html).

Create a file called `config.ini` with the following information:
```
PSQL_PROJECTION= [map projection in database]
OUTPUT_PROJECTION= [desired projection of output]

# tables with POLYGON/MULTIPOLYGON geometry
POLYGONS= [space-separated of tables]

# tables with POINT/MULTIPOINT geometry
POINTS= [space-separated of tables]

# Bounding box for OSM data (lng/lat format, comma-separated) (this one's for Chicagoland):
#BBOX = minlat,minlng,maxlat,maxlng
BBOX = 41.36,-88.62,42.59,-87.03

# template files that contain a {{bbox}} place holder
QUERIES= [space-separated of files]

# options for ImageMagick (these can be overridden in the command line)
CONVERTFLAGS = -resize 1200x\> -depth 5
```

See [`config_example.ini`](config_example.ini) for more options.

## BBOX

Run this after creating `.pgpass` and setting the tables in `POLYGONS` and `POINTS`:
````
make -f bbox.mk
````

It will spit the bounding box for all the data in your tables.

Queries
-------

To extract the OpenStreetMap data necessary to combine with your GIS, MOATP uses the Overpass API. Overpass queries use a unique and fairly complicated syntax. See the wizard at [Overpass Turbo](http://overpass-turbo.eu) and the documentation for [Overpass API language guide](https://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide) for help in writing a query.

MOATP expects queries to return only one type of geometry. See the [`queries`](queries) directory for examples that return point, line and polygon data.

Styles
------

See [`style.css`](style.css) for an example stylesheet, which is customized to Chicago Cityscape. It shows only certain classes of roads, parks and park-like spaces, water features, buildings, parking lots, train stations, and transit routes. 

Targets
-------

For a review of settings, run `make info`.

To create all the `svg` or `png` files, run:
````
make svgs
make pngs
````

If your tables are named `boroughs` and `neighborhoods`, create pngs for one table like:
````
make boroughs neighborhoods
````

License
-------

MOATP was developed by [Neil Freeman](http://fakeisthenewreal.org) for [Chicago Cityscape](http://chicagocityscape.com).

Copyright 2016, Neil Freeman. Licensed under the GPL. See LICENSE for more.
