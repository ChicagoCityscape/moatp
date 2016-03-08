moatp
-----

MOATP is a workflow for creating many svg maps that combine PostGreSQL and OSM geodata.

Requirements
------------

* GDAL installed with Postgresql support
* ImageMagick
* SVGIS

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

BBOX = minlat minlong maxlat maxlong

POLYGONS= [list of polygon features]

POINTS= [list of point features]
```

See [`config_example.ini`](config_example.ini) for more options.

Getting a BBOX
--------------

If you need help figuring out what bbox you want, there's a helper Makefile called `bbox.mk`.

Run this after creating `.pgpass` and setting `PSQL_PROJECTION`, POLYGONS` and `POINTS`:
````
make -f bbox.mk
````

License
-------

Copyright 2016, Neil Freeman. Licensed under the GPL. See LICENSE for more.
