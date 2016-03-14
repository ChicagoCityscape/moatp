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

base = $(notdir $(basename $1))

# ogr2ogr flags and settings
PGPASSFILE ?= $(abspath .pgpass)
export PGPASSFILE

OSM_CONFIG_FILE ?= osm.ini
OSM_USE_CUSTOM_INDEXING = NO
export OSM_CONFIG_FILE OSM_USE_CUSTOM_INDEXING

HOST = $(shell cut -d : -f 1 $(PGPASSFILE))
DATABASE = $(shell cut -d : -f 3 $(PGPASSFILE))
USER = $(shell cut -d : -f 4 $(PGPASSFILE))
CONNECTION ?= dbname=$(DATABASE) host=$(HOST) user=$(USER)
OGRFLAGS = -f 'ESRI Shapefile' -lco ENCODING=UTF-8 -overwrite -skipfailures
BUFFER ?= 2640
SLUG ?= slug
GEOM ?= geom

# SVGIS flags and settings
PADDING ?= 1200
SCALE ?= 10
CSS ?= style.css
CLASSFIELDS = highway,railway
DRAWFLAGS = --style $(CSS) \
	--no-viewbox \
	--inline \
	--clip \
	--crs file \
	--scale $(SCALE) \
	--padding $(PADDING) \
	--precision 0 \
	--simplify 90 \
	$(CLASSFIELDSFLAG)

ifdef CLASSFIELDS
	CLASSFIELDSFLAG = --class-fields $(CLASSFIELDS)
endif

# curl flags and settings
API ?= http://overpass-api.de/api/interpreter

OSMS = $(foreach x,$(call base,$(POINT_QUERIES) $(LINE_QUERIES) $(AREA_QUERIES)),osm/$x.osm)

# Query files, by geometry
BGS = $(foreach x,\
	$(addprefix multipolygons/,$(call base,$(AREA_QUERIES)))\
	$(addprefix lines/,$(call base,$(LINE_QUERIES)))\
	$(addprefix points/,$(call base,$(POINT_QUERIES))),\
bg/$x.shp)

# Targets:

.PHONY: info bgs pngs shps rawshp svgs $(POLYGONS) $(POINTS)

svgs pngs shps: $(foreach x,$(POLYGONS) $(POINTS),slug/$x.csv)
	cat $^ | \
	sed 's,^,$(@:s=)/,;s,$$,.$(@:s=),g'| \
	xargs $(MAKE)

info:
	@echo CONNECTION= $(CONNECTION)
	@echo PSQL_PROJECTION= $(PSQL_PROJECTION)
	@echo OUTPUT_PROJECTION= $(OUTPUT_PROJECTION)
	@echo BBOX= $(BBOX)
	@echo POLYGONS= $(POLYGONS)
	@echo POINTS= $(POINTS)
	@echo QUERIES= $(call base,$(POINT_QUERIES) $(LINE_QUERIES) $(AREA_QUERIES))

rawshps: $(foreach x,$(POINTS) $(POLYGONS),shp/$x.shp)
bgs: $(BGS)
osms: $(OSMS)

# General rule for each table
$(POLYGONS) $(POINTS): %: slug/%.csv
	sed 's,^,png/,;s,$$,.png,' $< | xargs $(MAKE)

.SECONDEXPANSION:

png/%.png: svg/%.svg | $$(@D)
	convert -density 150 $< $(CONVERTFLAGS) $@

svg/%.svg: $(CSS) $(BGS) $(MORE_GEODATA) shp/%.shp | $$(@D)
	svgis draw -o $@ $(filter-out %.css,$^) $(DRAWFLAGS) --bounds $$(svgis bounds $(lastword $^))

slug/%.csv: shp/%.shp | slug
	ogr2ogr /dev/stdout $< -f CSV -select $(SLUG) | \
	tail +2 | sed -E 's,^,$*/,' > $@

shp/%.shp: $$(@D).shp | $$(@D)
	ogr2ogr $@ $< $(OGRFLAGS) -t_srs $(OUTPUT_PROJECTION) \
	-where "$(SLUG)='$(basename $(@F))'"

### Download PostGreSQL data
# POINTS and POLYGONS separately

$(foreach x,$(POINTS),shp/$x.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(OGRFLAGS) -a_srs $(PSQL_PROJECTION) \
	-sql "SELECT ST_Buffer($(GEOM), $(BUFFER), 120) $(GEOM), $(SLUG) FROM $(basename $(@F))"

$(foreach x,$(POLYGONS),shp/$x.shp): | $$(@D)
	ogr2ogr $@ PG:"$(CONNECTION)" $(basename $(@F)) \
	$(OGRFLAGS) -a_srs $(PSQL_PROJECTION) -select $(SLUG)

### Download OSM data

$(BGS): bg/%.shp: osm/$$(*F).osm | $$(@D)
	ogr2ogr $@ $^ $(*D) $(OGRFLAGS) -t_srs $(OUTPUT_PROJECTION)

.PRECIOUS .INTERMEDIATE: $(OSMS)

$(OSMS): osm/%.osm: osm/%.ql | osm
	curl $(API) $(CURLFLAGS) -o $@ --data @$<

osm/%.ql: queries/%.txt | osm
	sed -E "s/{{([bB][bB][oO][xX])}}/$(BBOX)/g;s,//.*$$,,;s/ *//" $< | \
	tr -d '\n' | \
	sed -e 's,/\*.*\*/,,g' > $@

bg/lines bg/points bg/multipolygons osm slug \
$(foreach x,png shp svg,$x $(addprefix $x/,$(POLYGONS) $(POINTS))):
	mkdir -p $@

### install

PIP = $(shell which pip)
PIPINSTALL = $(PIP) install --upgrade 'svgis[clip,simplify]>=0.4.0'

ifneq "$(notdir $(PIP))" "pip"
$(info pip not installed. Visit https://pip.pypa.io/en/stable/installing/)
endif

install-osx:
	- brew install gdal --with-postgres
	- brew install imagemagick
	- brew install geos
	sudo $(PIPINSTALL)

install-ubuntu:
	apt-get -q update
	apt-get -q install -y g++ libgdal1-dev gdal-bin libgeos-dev imagemagick python-dev
	$(PIPINSTALL)

# If this fails, try running this first
# yum update
# sudo yum install -y epel-release
# sudo yum-config-manager --enable epel/x86_64
install-centos: ImageMagick.tar.gz
	yum update
	yum install -y epel-release
	yum install -y gcc-c++ gdal gdal-devel geos \
		python27-cairosvg freetype-devel libjpeg-devel libpng-devel \
		libtiff-devel giflib-devel ghostscript-devel
	tar xzf $|
	cd ImageMagick* && ./configure && $(MAKE) && $(MAKE) install
	$(PIPINSTALL)

ImageMagick.tar.gz:
	curl -O http://www.imagemagick.org/download/ImageMagick.tar.gz
