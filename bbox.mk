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
.SECONDEXPANSION:

.PHONY: all

all: bbox/bbox.shp
	svgis bounds --latlon $< | sed 's/ /,/g'

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
