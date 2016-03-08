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
And `0600` permissions:
```
chmod 0600 .pgpass
```

Create a file called `config.ini` with:
```
PSQL_PROJECTION= [map projection in database]
OUTPUT_PROJECTION= [desired projection of output]

BBOX = minlat minlong maxlat maxlong

POLYGONS= [list of polygon features]

POINTS= [list of point features]
```

[More info](http://www.postgresql.org/docs/current/static/libpq-pgpass.html).
