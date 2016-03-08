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

OGRFLAGS = -f 'ESRI Shapefile' -lco ENCODING=UTF-8 -overwrite

CSS = style.css
OUTPUT_PROJECTION ?= local
DRAWFLAGS = -c $(CSS) \
	-xl \
	-j $(OUTPUT_PROJECTION) \
	-f 20 \
	--padding 1200 \
	-P0 \
	--clip

API ?= http://overpass-api.de/api/interpreter

QUERIES = $(basename $(shell ls queries))

BGS = $(foreach x,$(QUERIES),bg/$x-lines.shp bg/$x-area.shp)

SLUGS = $(sort $(shell cat slug/slug.csv))

.PHONY: info bgs pngs shps raw slugs svgs

svgs: $(foreach x,$(SLUGS),svg/$x.svg)

info:
	@echo CONNECTION: $(CONNECTION)
	@echo POLYGONS: $(POLYGONS)
	@echo POINTS: $(POINTS)
	@echo QUERIES: $(QUERIES)

slugs: slug/slug.csv

shps: $(foreach x,$(SLUGS),shp/$x.shp)

raw: $(foreach x,$(POINTS),shp/$x.shp) $(foreach x,$(POLYGONS),shp/$x.shp)

bgs: $(BGS)

.SECONDEXPANSION:

png/%.png: svg/%.svg | $$(@D)
	convert $< $@

svg/%.svg: shp/%.shp $(BGS) | $$(@D)
	svgis draw -o $@ $^ $(DRAWFLAGS) --bounds $$(svgis bounds $<)

$(foreach x,$(SLUGS),shp/$x.shp): $$(@D).shp | $$(@D)
	ogr2ogr $@ $< $(OGRFLAGS) -t_srs EPSG:4326 \
	-where "slug='$(basename $(@F))'"

# Download the POINTS and POLYGONS sep'tly
$(foreach x,$(POINTS),shp/$x.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(OGRFLAGS) -a_srs $(PSQL_PROJECTION) \
	-sql "SELECT ST_Buffer(geom, $(BUFFER)) geom, slug FROM $(basename $(@F))"

$(foreach x,$(POLYGONS),shp/$x.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(basename $(@F)) \
	$(OGRFLAGS) -a_srs $(PSQL_PROJECTION) -select slug

slug/slug.csv: $(foreach x,$(POLYGONS) $(POINTS),slug/$x.csv)
	cat $^ > $@

slug/%.csv: | slug
	ogr2ogr /dev/stdout PG:"$(CONNECTION)" $* -f CSV -select slug | \
	tail +2 | \
	sed -E 's,^,$*/,' > $@

bg/%-lines.shp: osm/%.osm | bg
	ogr2ogr $@ $^ lines $(OGRFLAGS) -t_srs EPSG:4326

bg/%-area.shp: osm/%.osm | bg
	ogr2ogr $@ $^ multipolygons $(OGRFLAGS) -t_srs EPSG:4326

.PRECIOUS: osm/%.osm

osms: $(foreach x,$(QUERIES),osm/$x.osm)

osm/%.osm: osm/%.ql | osm
	curl $(API) $(CURLFLAGS) -o $@ --data @$<

osm/%.ql: queries/%.txt | osm
	sed -E "s/{{(bbox|BBOX)}}/$(subst $(space),$(comma),$(BBOX))/g;s,//.*,,;s/ *//" $< | \
	tr -d '\n' | \
	sed -e 's,/\*.*\*/,,g' > $@

bbox/bbox.shp: $(foreach x,$(POLYGONS) $(POINTS),bbox/$x.shp)
	@rm $@
	for file in $^; do ogr2ogr $@ $$file -f 'ESRI Shapefile' -a_srs $(PROJECTION) -update -append;\
	done;

bbox/%.shp: | bbox
	ogr2ogr $@ PG:"$(CONNECTION)" $(OGRFLAGS) \
	-sql "SELECT ST_Envelope(ST_Collect(geom)) geom FROM $*"

bbox bg osm slug $(foreach x,png shp svg,$x $(addprefix $x/,$(POLYGONS) $(POINTS))):
	mkdir -p $@
