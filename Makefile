# moatp: workflow for creating many maps combining PostGreSQL and OSM geodata
# Copyright (C) 2016 Neil Freeman

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

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

SLUG = slug
GEOM = geom

CONNECTION = dbname=$(DATABASE) host=$(HOST)
BUFFER ?= 2640

OGRFLAGS = -f 'ESRI Shapefile' -lco ENCODING=UTF-8 -overwrite

PADDING ?= 1200
CSS ?= style.css
OUTPUT_PROJECTION ?= local
DRAWFLAGS = -c $(CSS) \
	-xl \
	-j $(OUTPUT_PROJECTION) \
	-f 20 \
	--padding $(PADDING) \
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
	-where "$(SLUG)='$(basename $(@F))'"

# Download the POINTS and POLYGONS sep'tly
$(foreach x,$(POINTS),shp/$x.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(OGRFLAGS) -a_srs $(PSQL_PROJECTION) \
	-sql "SELECT ST_Buffer($(GEOM), $(BUFFER)) $(GEOM), $(SLUG) FROM $(basename $(@F))"

$(foreach x,$(POLYGONS),shp/$x.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(basename $(@F)) \
	$(OGRFLAGS) -a_srs $(PSQL_PROJECTION) -select $(SLUG)

slug/slug.csv: $(foreach x,$(POLYGONS) $(POINTS),slug/$x.csv)
	cat $^ > $@

slug/%.csv: | slug
	ogr2ogr /dev/stdout PG:"$(CONNECTION)" $* -f CSV -select $(SLUG) | \
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

bg osm slug $(foreach x,png shp svg,$x $(addprefix $x/,$(POLYGONS) $(POINTS))):
	mkdir -p $@
