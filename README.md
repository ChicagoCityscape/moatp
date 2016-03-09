moatp
-----

MOATP is a workflow for creating many svg maps that combine PostGreSQL and OSM geodata.

Requirements
------------

* GDAL installed with Postgresql support
* ImageMagick
* SVGIS

Optional (these improve performance):
* GEOS
* Numpy

Installation tasks are included for OS X and Ubuntu Linux:

```
make install-osx
sudo make install-ubuntu
```

The OS X installer assumes [`homebrew`](http://brew.sh). Both installers assume [`pip`](https://pip.pypa.io/en/stable/). If you don't have these available, install them first.

Setup
-----

Add a file called `.pgpass` in this directory. It should have the format:
````
hostname:port:database:username:password
````
and have `0600` permissions:
```
chmod 0600 .pgpass
```

[More info](http://www.postgresql.org/docs/current/static/libpq-pgpass.html).

Create a file called `config.ini` with the following information:
```
PSQL_PROJECTION= [map projection in database]
OUTPUT_PROJECTION= [desired projection of output]

# tables with POLYGON/MULTIPOLYGON geometry
POLYGONS= [space-separated of tables]

# tables with POINT/MULTIPOINT geometry
POINTS= [space-separated of tables]

# Bounding box for OSM data (long/lat format):
BBOX = minlat minlong maxlat maxlong

# template files that contain a {{bbox}} place holder
QUERIES= [space-separated of files]
```

See [`config_example.ini`](config_example.ini) for more options.

Getting a BBOX
--------------

If you need help figuring out what bbox you want, there's a helper Makefile called `bbox.mk`.

Run this after creating `.pgpass` and setting `PSQL_PROJECTION`, POLYGONS` and `POINTS`:
````
make -f bbox.mk
````

Targets
-------

To create all the `png` or `svg` files, run:
````
make pngs
make svgs
````

If your tables are named `boroughs` and `neighborhoods`, create pngs for one table like:
````
make boroughs
````

License
-------

Copyright 2016, Neil Freeman. Licensed under the GPL. See LICENSE for more.
