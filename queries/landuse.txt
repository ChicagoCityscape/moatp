[out:xml][timeout:600][bbox:{{bbox}}];
(
    way["landuse"="retail"]({{bbox}});
	relation["landuse"="retail"]({{bbox}});
);
(
    ._;
    >;
);
out body qt;
