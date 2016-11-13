# Star Schema Benchmark Tool for Apache Kylin

The benchmark tool is built on the original SSB-DBGen(https://github.com/electrum/ssb-dbgen). We extend the tools to support column cardinality configuration. 

Read more about Star Schema Benchmark: [PDF Download](http://www.cs.umb.edu/~poneil/StarSchemaB.pdf)

## Generate Data

1. Compile SSB-Benchmark

   ```shell
   cd ssb-benchmark
   make clean
   make
   ```

2. Define the environment variable *HADOOP_STREAMING_JAR*

   ```shell
   export HADOOP_STREAMING_JAR=/usr/hdp/<version>/hadoop-mapreduce/hadoop-streaming.jar
   ```

3. Generate Data and Import into Hive

   ```shell
   cd ..
   bin/run.sh
   ```



## How to Config

**SCALE** is the key scale factor, defined in *bin/dbgen.sh*. Valid range from 0.01 to 100+. Default value is 0.01.

Other properties are defined in *bin/ssb.conf*.

**customer_base**, **part_base**, **supply_base**, **date_base** and **lineorder_base** are used to set the *base row number* for each table(*customer*, *part*, *supply*, *date*, *lineorder*). The total row number = *base row number* * *scale factor*.

**maux_max**, **cat_max**, **brand_max** are used to define the hierarchy  scale.  For example, **maux_max**=10, **cat_max=10**, **brand_max=10** means total 10 manufactures, and each manufacture has most 10 category parts, and each category has most 10 brands. So the cardinality for the *manufacture* is 10, for *category* is 100, for *brand* is 1000.

**cust_city_max** and **supp_city_max** are used to define the number of city for each country in *customer* and *supplier* tables. If the total country is 30, and **cust_city_max=100**, **supp_city_max=10**, the *customer* table will have 3000 different cities, the *supplier* table will have 300 different cities.

If the build job is killed by YARN, please increase YARN container memory settings.

## Load & Build Cube

The Kylin project, model and cube has been designed in advance, you could import it into Kylin directly. The *Cube Metadata* locates under cubemeta directory.

Run the following commands to import the cubemeta definition:

```shell
cd $KYLIN_HOME
bin/metastore.sh restore <path to cubemeta dir>
```

Restart Kylin or click ``Reload Metadata``. 

You could find new project *ssb*. Select the *ssb*, click *Disable* and *Purge* on the *ssb* cube at *Model* Tab to remove all old tempory files. And click *Build* next. The cube build will be finished in a few minutes.

## Query

Six Hive external tables are created: *customer*, *dates*, *part*, *supplier* and *lineorder*. The sixth table is *p_lineorder* which is the partitioned table for *lineorder*. 

Here is a list sample queries, the query parameter may be different between different *scale factor*. The sample data is generated randomly. 

##### Q1.1

```sql
SELECT SUM(v_revenue) AS revenue
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey
WHERE d_year = 1993
```

##### Q1.2

```sql
SELECT SUM(v_revenue) AS revenue
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey
WHERE d_yearmonthnum = 199401
```
##### Q1.3

```sql
SELECT SUM(v_revenue) AS revenue
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey
WHERE d_weeknuminyear = 6
	AND d_year = 1994
```
##### Q2.1

```sql
SELECT SUM(lo_revenue) AS lo_revenue, d_year, p_brand
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN part ON lo_partkey = p_partkey LEFT JOIN supplier ON lo_suppkey = s_suppkey
WHERE p_category = 'MFGR#02'
	AND s_region = 'AMERICA'
GROUP BY d_year, p_brand
ORDER BY d_year, p_brand
```
##### Q2.2

```sql
SELECT SUM(lo_revenue) AS lo_revenue, d_year, p_brand
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN part ON lo_partkey = p_partkey LEFT JOIN supplier ON lo_suppkey = s_suppkey
WHERE p_brand BETWEEN 'MFGR#0201' AND 'MFGR#0208'
	AND s_region = 'ASIA'
GROUP BY d_year, p_brand
ORDER BY d_year, p_brand
```
##### Q2.3

```sql
SELECT SUM(lo_revenue) AS lo_revenue, d_year, p_brand
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN part ON lo_partkey = p_partkey LEFT JOIN supplier ON lo_suppkey = s_suppkey
WHERE p_brand = 'MFGR#0209'
	AND s_region = 'EUROPE'
GROUP BY d_year, p_brand
ORDER BY d_year, p_brand
```
##### Q3.1

```sql
SELECT c_nation, s_nation, d_year, SUM(lo_revenue) AS lo_revenue
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN customer ON lo_custkey = c_custkey LEFT JOIN supplier ON lo_suppkey = s_suppkey
WHERE c_region = 'ASIA'
	AND s_region = 'ASIA'
	AND d_year >= 1992
	AND d_year <= 1997
GROUP BY c_nation, s_nation, d_year
ORDER BY d_year ASC, lo_revenue DESC
```
##### Q3.2

```sql
SELECT c_city, s_city, d_year, SUM(lo_revenue) AS lo_revenue
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN customer ON lo_custkey = c_custkey LEFT JOIN supplier ON lo_suppkey = s_suppkey
WHERE c_nation = 'UNITED STATES'
	AND s_nation = 'UNITED STATES'
	AND d_year >= 1992
	AND d_year <= 1997
GROUP BY c_city, s_city, d_year
ORDER BY d_year ASC, lo_revenue DESC
```
##### Q3.3

```sql
SELECT c_city, s_city, d_year, SUM(lo_revenue) AS lo_revenue
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN customer ON lo_custkey = c_custkey LEFT JOIN supplier ON lo_suppkey = s_suppkey
WHERE (c_city = 'UNITED KI1'
		OR c_city = 'UNITED KI5')
	AND (s_city = 'UNITED KI1'
		OR s_city = 'UNITED KI5')
	AND d_year >= 1992
	AND d_year <= 1997
GROUP BY c_city, s_city, d_year
ORDER BY d_year ASC, lo_revenue DESC
```
##### Q3.4

```sql
SELECT c_city, s_city, d_year, SUM(lo_revenue) AS lo_revenue
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN customer ON lo_custkey = c_custkey LEFT JOIN supplier ON lo_suppkey = s_suppkey
WHERE (c_city = 'UNITED KI1'
		OR c_city = 'UNITED KI5')
	AND (s_city = 'UNITED KI1'
		OR s_city = 'UNITED KI5')
	AND d_yearmonth LIKE '%1997'
GROUP BY c_city, s_city, d_year
ORDER BY d_year ASC, lo_revenue DESC
```
##### Q4.1

```sql
SELECT d_year, c_nation, SUM(lo_revenue) - SUM(lo_supplycost) AS profit
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN customer ON lo_custkey = c_custkey LEFT JOIN supplier ON lo_suppkey = s_suppkey LEFT JOIN part ON lo_partkey = p_partkey
WHERE c_region = 'AMERICA'
	AND s_region = 'AMERICA'
	AND (p_mfgr = 'MFGR#1'
		OR p_mfgr = 'MFGR#2')
GROUP BY d_year, c_nation
ORDER BY d_year, c_nation
```
##### Q4.2

```sql
SELECT d_year, s_nation, p_category, SUM(lo_revenue) - SUM(lo_supplycost) AS profit
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN customer ON lo_custkey = c_custkey LEFT JOIN supplier ON lo_suppkey = s_suppkey LEFT JOIN part ON lo_partkey = p_partkey
WHERE c_region = 'AMERICA'
	AND s_region = 'AMERICA'
	AND (d_year = 1997
		OR d_year = 1998)
	AND (p_mfgr = 'MFGR#1'
		OR p_mfgr = 'MFGR#2')
GROUP BY d_year, s_nation, p_category
ORDER BY d_year, s_nation, p_category
```
##### Q4.3

```sql
SELECT d_year, s_city, p_brand, SUM(lo_revenue) - SUM(lo_supplycost) AS profit
FROM p_lineorder LEFT JOIN dates ON lo_orderdate = d_datekey LEFT JOIN customer ON lo_custkey = c_custkey LEFT JOIN supplier ON lo_suppkey = s_suppkey LEFT JOIN part ON lo_partkey = p_partkey
WHERE c_region = 'AMERICA'
	AND s_nation = 'UNITED STATES'
	AND (d_year = 1997
		OR d_year = 1998)
	AND p_category = 'MFGR#04'
GROUP BY d_year, s_city, p_brand
ORDER BY d_year, s_city, p_brand
```
