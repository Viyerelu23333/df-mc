-- using default substitutions

create view orders_per_cust0 (custkey, ordercount) as
	select
		c_custkey,
		count(o_orderkey)
	from
		customer left outer join orders on
			c_custkey = o_custkey
			and o_comment not like '%special%requests%'
	group by
		c_custkey;


select
	ordercount,
	count(*) as custdist
from
	orders_per_cust0
group by
	ordercount
order by
	custdist desc,
	ordercount desc;

drop view orders_per_cust0;
