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

[More info](http://www.postgresql.org/docs/current/static/libpq-pgpass.html).

