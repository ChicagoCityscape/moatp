.SECONDEXPANSION:

.PHONY: all

all: bbox/bbox.shp
	svgis bounds --latlon $<

include Makefile

bbox/bbox.shp: $(foreach x,$(POLYGONS) $(POINTS),bbox/$x.shp)
	@rm -f $@
	for file in $^; \
	do ogr2ogr $@ $$file -f 'ESRI Shapefile' -update -append -t_srs EPSG:4326; \
	done;

bbox/%.shp: shp/%.shp | $$(@D)
	ogr2ogr $@ $< $(OGRFLAGS) -dialect sqlite \
	-sql 'SELECT ST_Envelope(ST_Collect(Geometry)) Geometry FROM "$(*F)"'

$(foreach x,bbox,$x $(addprefix $x/,$(POLYGONS) $(POINTS))):
	mkdir -p $@
