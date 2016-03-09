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
no =
space = $(no) $(no)
comma = ,

include config.ini

# ogr2ogr flags and settings
PGPASSFILE ?= $(abspath .pgpass)
export PGPASSFILE

OSM_CONFIG_FILE ?= osm.ini
OSM_USE_CUSTOM_INDEXING = NO
export OSM_CONFIG_FILE OSM_USE_CUSTOM_INDEXING

HOST = $(shell cut -d : -f 1 $(PGPASSFILE))
DATABASE = $(shell cut -d : -f 3 $(PGPASSFILE))
CONNECTION = dbname=$(DATABASE) host=$(HOST)
OGRFLAGS = -f 'ESRI Shapefile' -lco ENCODING=UTF-8 -overwrite
BUFFER ?= 2640
SLUG ?= slug
GEOM ?= geom

# SVGIS flags and settings
PADDING ?= 1200
SCALE ?= 10
CSS ?= style.css
OUTPUT_PROJECTION ?= local
DRAWFLAGS = --style $(CSS) \
	--no-viewbox \
	--inline \
	--clip \
	--crs $(OUTPUT_PROJECTION) \
	--scale $(SCALE) \
	--padding $(PADDING) \
	--precision 0

# curl flags and settings
API ?= http://overpass-api.de/api/interpreter

# Query files, by geometry
POINT_BG = $(foreach x,$(notdir $(basename $(POINT_QUERIES))),bg/$x.shp)
LINE_BG = $(foreach x,$(notdir $(basename $(LINE_QUERIES))),bg/$x.shp)
AREA_BG = $(foreach x,$(notdir $(basename $(AREA_QUERIES))),bg/$x.shp)

# Targets:

.PHONY: info bgs pngs shps rawshp svgs $(POLYGONS) $(POINTS)

svgs pngs shps: slug/slug.csv
	sed -E 's,^,$(patsubst %s,%,$@)/,;s,$$,.$(patsubst %s,%,$@),g' $< | \
	xargs $(MAKE)	

$(POLYGONS) $(POINTS): slug/slug.csv
	grep ^$@ $< | \
	sed -E 's,^,png/,;s,$$,.png,g' | \
	xargs $(MAKE)

info:
	@echo CONNECTION: $(CONNECTION)
	@echo POLYGONS: $(POLYGONS)
	@echo POINTS: $(POINTS)
	@echo QUERIES: $(QUERIES)

rawshps: $(foreach x,$(POINTS) $(POLYGONS),shp/$x.shp)

BGS = $(AREA_BG) $(LINE_BG) $(POINT_BG)
bgs: $(BGS)

osms: $(foreach x,$(QUERIES),osm/$x.osm)

.SECONDEXPANSION:

png/%.png: svg/%.svg | $$(@D)
	convert $< $(CONVERTFLAGS) $@

svg/%.svg: $(CSS) $(BGS) shp/%.shp | $$(@D)
	svgis draw -o $@ $(filter-out $<,$^) $(DRAWFLAGS) --bounds $$(svgis bounds $(lastword $^))

shp/%.shp: $$(@D).shp | $$(@D)
	ogr2ogr $@ $< $(OGRFLAGS) -t_srs EPSG:4326 \
	-where "$(SLUG)='$(basename $(@F))'"

# Download the POINTS and POLYGONS sep'tly
$(foreach x,$(POINTS),shp/$x.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(OGRFLAGS) -a_srs $(PSQL_PROJECTION) \
	-sql "SELECT ST_Buffer($(GEOM), $(BUFFER)) $(GEOM), $(SLUG) FROM $(basename $(@F))"

$(foreach x,$(POLYGONS),shp/$x.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(basename $(@F)) \
	$(OGRFLAGS) -skipfailures -a_srs $(PSQL_PROJECTION) -select $(SLUG)

$(POINT_BG): bg/%.shp: osm/%.osm | bg
	ogr2ogr $@ $^ points $(OGRFLAGS) -t_srs EPSG:4326

$(LINE_BG): bg/%.shp: osm/%.osm | bg
	ogr2ogr $@ $^ lines $(OGRFLAGS) -t_srs EPSG:4326

$(AREA_BG): bg/%.shp: osm/%.osm | bg
	ogr2ogr $@ $^ multipolygons $(OGRFLAGS) -t_srs EPSG:4326

slug/slug.csv: $(foreach x,$(POLYGONS) $(POINTS),slug/$x.csv)
	cat $^ > $@

slug/%.csv: | slug
	ogr2ogr /dev/stdout PG:"$(CONNECTION)" $* -f CSV -select $(SLUG) | \
	tail +2 | \
	sed -E 's,^,$*/,' > $@

.PRECIOUS .INTERMEDIATE: $(foreach x,$(QUERIES),osm/$x.osm)

osm/%.osm: osm/%.ql | osm
	curl $(API) $(CURLFLAGS) -o $@ --data @$<

osm/%.ql: queries/%.txt | osm
	sed -E "s/{{(bbox|BBOX)}}/$(subst $(space),$(comma),$(BBOX))/g;s,//.*,,;s/ *//" $< | \
	tr -d '\n' | \
	sed -e 's,/\*.*\*/,,g' > $@

bg osm slug $(foreach x,png shp svg,$x $(addprefix $x/,$(POLYGONS) $(POINTS))):
	mkdir -p $@

PIPINSTALL = pip install 'svgis[clip,simplify]>=0.4.0'

install-osx:
	- brew install gdal --with-postgres
	- brew install imagemagick
	- brew install geos
	$(PIPINSTALL)

install-ubuntu:
	apt-get -q update
	apt-get -q install -y gdal-bin libgeos-dev imagemagick python-dev
	$(PIPINSTALL)
