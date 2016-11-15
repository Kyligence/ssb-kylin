#!/bin/bash
dir=$(dirname ${0})
ssb_home=$dir/../ssb-benchmark

# configurations
LOCAL_TMP_DIR=/tmp
HDFS_BASE_DIR=/user/root/ssb/
PARALLEL_TASKS=10

# check for existence of hadoop streaming
if [ -n "$HADOOP_HOME" ]; then
    # for hadoop 1.0.x
    if [ -z "$HADOOP_STREAMING_JAR" ] && [ -e $HADOOP_HOME/contrib/streaming/hadoop-streaming-*.jar ]; then
        HADOOP_STREAMING_JAR=$HADOOP_HOME/contrib/streaming/hadoop-streaming-*.jar
    fi
    # for hadoop 2.0.x
    if [ -z "$HADOOP_STREAMING_JAR" ] && [ -e $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar ]; then
        HADOOP_STREAMING_JAR=$HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar
    fi
    # for other hadoop version
    if [ -z "$HADOOP_STREAMING_JAR" ]; then
        HADOOP_STREAMING_JAR=`find $HADOOP_HOME -name hadoop-stream*.jar -type f`
    fi
else
    # for hadoop 1.0.x
    if [ -z "$HADOOP_STREAMING_JAR" ] && [ -e `dirname ${HADOOP_EXAMPLES_JAR}`/contrib/streaming/hadoop-streaming-*.jar ]; then
        HADOOP_STREAMING_JAR=`dirname ${HADOOP_EXAMPLES_JAR}`/contrib/streaming/hadoop-streaming-*.jar
    fi
    # for hadoop 2.0.x
    if [ -z "$HADOOP_STREAMING_JAR" ] && [ -e `dirname ${HADOOP_EXAMPLES_JAR}`/../tools/lib/hadoop-streaming-*.jar ]; then
        HADOOP_STREAMING_JAR=`dirname ${HADOOP_EXAMPLES_JAR}`/../tools/lib/hadoop-streaming-*.jar
    fi
fi

if [ -z "$HADOOP_STREAMING_JAR" ]; then
    echo 'Can not find hadoop-streaming jar file, please set HADOOP_STREAMING_JAR path.'
    exit
fi

# clean up temp files
rm -f $LOCAL_TMP_DIR/ssb/input/*
mkdir -p $LOCAL_TMP_DIR/ssb/input
for c in $(seq $PARALLEL_TASKS);do
    echo "${c}" > $LOCAL_TMP_DIR/ssb/input/$c.txt
done

# clean up hive metadata
hive -e 'DROP DATABASE IF EXISTS SSB CASCADE;'

# clean up previous data if available
hadoop fs -rm -r $HDFS_BASE_DIR
hadoop fs -mkdir -p $HDFS_BASE_DIR
hadoop fs -mkdir -p $HDFS_BASE_DIR/tmp
hadoop fs -moveFromLocal $LOCAL_TMP_DIR/ssb/input $HDFS_BASE_DIR/tmp
hadoop fs -mkdir -p $HDFS_BASE_DIR/data
for tbl in customer part supplier date lineorder
do
    hadoop fs -mkdir -p $HDFS_BASE_DIR/data/$tbl
    hadoop fs -chmod 777 $HDFS_BASE_DIR/data/$tbl
done

# run hadoop streaming job
OPTION="-D mapred.reduce.tasks=0 \
-D mapred.job.name=generate_ssb_date \
-D mapred.task.timeout=0 \
-input ${HDFS_BASE_DIR}/tmp/input \
-output ${HDFS_BASE_DIR}/data/output \
-mapper ${dir}/dbgen.sh \
-file ${dir}/dbgen.sh -file ${dir}/ssb.conf -file ${ssb_home}/dbgen -file ${ssb_home}/dists.dss"

echo hadoop jar ${HADOOP_STREAMING_JAR} ${OPTION}

hadoop jar ${HADOOP_STREAMING_JAR} ${OPTION}

echo "Creating Hive External Tables"
hive -f $dir/../hive/1_create_basic.sql
if [ "$1" == "partition" ]
then
    echo "Creating Hive Partitioned Table, may cost some time..."
    hive -f $dir/../hive/2_create_partitions.sql
else
    echo "Creating Hive View"
    hive -f $dir/../hive/2_create_views.sql
fi
