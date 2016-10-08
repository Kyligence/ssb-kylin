# Star Schema Benchmark Tool for Apache Kylin

The benchmark tool is built on the original SSB-DBGen(https://github.com/electrum/ssb-dbgen). We extend the tools to support column cardinality configuration. 



## Generate Data

1. Compile SSB-Benchmark

   ```shell
   cd ssb-benchmark
   make clean
   make
   ```

2. Generate Data and Import into Hive

   ```shell
   cd ..
   EXPORT HADOOP_STREAMING_JAR=/usr/hdp/<version>/hadoop-mapreduce/hadoop-streaming.jar
   bin/run.sh
   ```



## How to Config

The configuration file locates at *bin/example.conf*

**customer_base**, **part_base**, **supply_base**, **date_base** and **lineorder_base** are used to set the *base row number* for each table. The final total row number will be *base row number* times *scale factor*.

**maux_max**, **cat_max**, **brand_max** are used to define the hierarchy  scale. **maux_max**=10, **cat_max=10**, **brand_max** means total 10 manufactures, and each manufacture has max 10 category parts, and each category has max 10 brands. So the cardinality for the manufacture is 10, for category is 100, for brand is 1000.

**cust_city_max** and **supp_city_max** are used to define the city numbers for each country in *customer* and *supplier* tables. If the total country is 30, and **cust_city_max=100**, **supp_city_max=10**, the customer table will have 3000 different cities, the supplier table will have 300 different cities.



## Load Cube

The *Cube Metadata* locates under cubemeta directory.

Run the following commands to load cube

```shell
cd $KYLIN_HOME
bin/metastore.sh restore <path to cubemeta dir>
```

Restart Kylin or click *Reload Metadata* 