[out:xml][timeout:600][bbox:{{bbox}}];
(
    way["name"]["building"]({{bbox}});
	relation["name"]["building"]({{bbox}});
	
	way["building"="school"]({{bbox}});
	relation["building"="school"]({{bbox}});
	
	way["amenity"="school"]({{bbox}});
	relation["amenity"="school"]({{bbox}});
	
	way["public_transport"="station"]({{bbox}});
);
(
    ._;
    >;
);
out body qt;
