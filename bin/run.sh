#!/bin/bash
dir=$(dirname ${0})
ssb_home=$dir/../ssb-benchmark

# configurations
LOCAL_TMP_DIR=/tmp
HDFS_BASE_DIR=/user/root/ssb/
PARALLEL_TASKS=10

partition=false
database=SSB
scale=0.1

while [[ $# -ge 1 ]]
do
    key="$1"
    case $key in
        --partition)
            partition=true
            echo "enable hive partition"
            ;;
        --database)
            database="$2"
            echo "database changed to ${database}"
            shift
            ;;
        --hdfs-dir)
            HDFS_BASE_DIR="$2"
            echo "hdfs base dir changed to ${HDFS_BASE_DIR}"
            shift
            ;;
        --scale)
            scale="$2"
            echo "scale changed to ${scale}"
            shift
            ;;
        --parallel)
            PARALLEL_TASKS="$2"
            echo "parallel changed to ${PARALLEL_TASKS}"
            shift
            ;;
        *)
            ;;

    esac
    shift
done

scale2int=$scale
if ! [[ "$scale" =~ ^[0-9]+$ ]]; then
    scale2int=`echo $scale |awk '{ print int($0)+1}'`
fi

if [ ${scale2int} -gt 1000 ]; then
    echo 'Scale factor > 1000 since implementation is incomplete.'
    exit
fi

# clean up hive metadata
hive -e "DROP DATABASE IF EXISTS ${database} CASCADE;"

# clean up previous data if available
hadoop fs -rm -r $HDFS_BASE_DIR
hadoop fs -mkdir -p $HDFS_BASE_DIR
hadoop fs -mkdir -p $HDFS_BASE_DIR/data

for tbl in customer part supplier date lineorder
do
    hadoop fs -mkdir -p $HDFS_BASE_DIR/data/$tbl
    hadoop fs -chmod 777 $HDFS_BASE_DIR/data/$tbl
done

echo "Creating Hive External Tables"
ls $dir/../hive/* | xargs -I {} cp {} {}.tmp
sed -i -e "s/<DATABASE>/${database}/g" $dir/../hive/*.tmp
sed -i -e "s|<hdfs-dir>|${HDFS_BASE_DIR}|g" $dir/../hive/*.tmp
hive -f $dir/../hive/1_create_basic.sql.tmp
if [ "${partition}" == "true" ]
then
    echo "Creating Hive Partitioned Table, may cost some time..."
    hive -f $dir/../hive/2_create_partitions.sql.tmp
else
    echo "Creating Hive View"
    hive -f $dir/../hive/2_create_views.sql.tmp
fi
rm $dir/../hive/*.tmp


# run datagen locally
cp ${ssb_home}/dbgen ${dir}
if [[ "$?" -ne 0 ]]
   then
   echo "dbgen is expected, please make sure dbgen has been made"
fi
cp ${ssb_home}/dists.dss ${dir}
if [[ "$?" -ne 0 ]]
   then
   echo "dists.dss is expected, please make sure dists.dss has been made"
fi

for ((task=0; task < ${PARALLEL_TASKS}; task++))
do
    if [ ${task} == 0 ];then
        for tbl in customer part supplier date
        do
            #echo "Begin generating - $tbl"
            #echo "./dbgen -s ${SCALE} -T ${tbl}"
            ${dir}/dbgen -q -s ${scale} -c ./ssb.conf -T ${tbl}
            #echo "Finish generating and start to upload - ${tbl}"
            whoami
            hadoop fs -put ${tbl}.tbl* ${HDFS_BASE_DIR}/data/$tbl/
            if [[ "$?" -ne 0 ]]
            then
                echo "retrying hdfs put"
                hadoop fs -put ${tbl}.tbl* ${HDFS_BASE_DIR}/data/$tbl/
            fi
            rm -f ${tbl}.tbl* || exit 0
            #echo "Upload finished - $tbl"
        done
    else
        for tbl in lineorder
        do
            #echo "Begin generating - $tbl"
            #echo "./dbgen -C $((PARALLEL_TASKS-1)) -S $((TASK_NUM-1)) -s ${SCALE} -T ${tbl}"
            ${dir}/dbgen -q -c ./ssb.conf -C $((PARALLEL_TASKS-1)) -S $((task)) -s ${scale} -T ${tbl}
            #echo "Finish generating and start to upload - ${tbl}"
            hadoop fs -put ${tbl}.tbl* ${HDFS_BASE_DIR}/data/$tbl/
            rm -f ${tbl}.tbl* || exit 0
            #echo "Upload finished - $tbl"
        done
    fi
done

