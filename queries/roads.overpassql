[out:xml][timeout:600][bbox:{{bbox}}];
(
    way[highway=primary];
    relation[highway=primary];
    way[highway=motorway];
    relation[highway=motorway];
    way[highway=secondary];
    relation[highway=secondary];
    way[highway=tertiary];
    relation[highway=tertiary];
    way[highway=trunk];
    relation[highway=trunk];
    way[highway=residential];
    relation[highway=residential];
    
    way[highway=path];
	way[highway=footway];
	way[highway=cycleway];
);
(
    ._;
    >;
);
out body qt;
