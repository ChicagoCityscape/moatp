include config.ini
PGPASSFILE = $(abspath .pgpass)
export PGPASSFILE

OSM_CONFIG_FILE ?= osm.ini
OSM_USE_CUSTOM_INDEXING = NO
export OSM_CONFIG_FILE OSM_USE_CUSTOM_INDEXING

no =
space = $(no) $(no)
comma = ,

HOST = $(shell cut -d : -f 1 $(PGPASSFILE))
DATABASE = $(shell cut -d : -f 3 $(PGPASSFILE))

CONNECTION = dbname=$(DATABASE) host=$(HOST)
BUFFER ?= 2640

OGRFLAGS = -f 'ESRI Shapefile' -a_srs $(PROJECTION) -lco ENCODING=UTF-8 -overwrite

CSS = style.css
PROJECTION ?= local
DRAWFLAGS = -c $(CSS) \
	-xl \
	-j $(PROJECTION)

API ?= http://overpass-api.de/api/interpreter

.PHONY: pngs shps slugs svgs
info:
	@echo $(host)
	@echo $(database)
	@echo POLYGONS: $(POLYGONS)
	@echo POINTS: $(POINTS)

slugs: $(foreach x,$(POLYGONS) $(POINTS),slug/$x.csv)

.SECONDEXPANSION:

png/%.png: svg/%.svg | $$(@D)
	convert $< $@

svg/%.svg: shp/%.shp bg/bg-lines.shp bg/bg-area.shp | $$(@D)
	svgis draw -o $@ $^ $(DRAWFLAGS)

$(foreach x,$(POINTS),shp/$x/%.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(OGRFLAGS) \
	-sql "SELECT ST_Buffer(geom, $(BUFFER)) geom, slug \
		FROM $(notdir $(@D)) WHERE slug='$(*F)' AND GeometryType(geom)='POINT'"

$(foreach x,$(POLYGONS),shp/$x/%.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(*D) $(OGRFLAGS) \
	-select slug -where "slug='$(*F)' AND GeometryType(geom)='MULTIPOLYGON'"

slug/%.csv: | slug
	ogr2ogr /dev/stdout PG:"$(CONNECTION)" $* -f CSV -select slug | \
	tail +2 | \
	sed 's,",,g;' > $@

bg/bg-lines.shp: bg/bg.osm
	ogr2ogr $@ $^ lines $(OGRFLAGS)

bg/bg-area.shp: bg/bg.osm
	ogr2ogr $@ $^ multipolygons $(OGRFLAGS)

bg/bg.osm: bg/query.ql
	curl $(API) $(CURLFLAGS) -o $@ --data @$<

bg/query.ql: $(QUERYFILE) | bg
	sed -e "s/{{bbox}}/$(subst $(space),$(comma),$(BBOX))/g;s,//.*,,;s/ *//" $(QUERYFILE) | \
	tr -d '\n' | \
	sed -e 's,/\*.*\*/,,g' > $@

# Create the bbox once to find the bounds using "svgis bounds bbox/bbox.shp"

bbox/bbox.shp: $(foreach x,$(POLYGONS) $(POINTS),bbox/$x.shp)
	@rm $@
	for file in $^; do ogr2ogr $@ $$file -f 'ESRI Shapefile' -a_srs $(PROJECTION) -update -append;\
	done;

bbox/%.shp: | bbox
	ogr2ogr $@ PG:"$(CONNECTION)" $(OGRFLAGS) \
	-sql "SELECT ST_Envelope(ST_Collect(geom)) geom, '$*' slug FROM $*"

bbox bg $(foreach x,png slug shp svg,$(addprefix $x/,$(POLYGONS) $(POINTS))):
	mkdir -p $@
