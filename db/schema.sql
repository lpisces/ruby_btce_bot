create table ltc_usd_ticks(
id int(11) not null auto_increment,
last decimal(12,6) not null,
buy decimal(12,6) not null,
sell decimal(12,6) not null,
updated int(11) not null,
primary key(id)
)default charset utf8;

create table ltc_usd_minute(
id int(11) not null auto_increment,
`open` decimal(12,6) not null,
`close` decimal(12,6) not null,
`high` decimal(12,6) not null,
`low` decimal(12,6) not null,
updated int(11) not null,
primary key(id)
)default charset utf8;
