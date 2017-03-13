#!/bin/bash

# begin generating
read TASK_NUM
read HDFS_BASE_DIR
read SCALE
read PARALLEL_TASKS
if [ $TASK_NUM == 1 ];then
	for tbl in customer part supplier date
	do
		#echo "Begin generating - $tbl"
		#echo "./dbgen -s ${SCALE} -T ${tbl}"
		./dbgen -q -s ${SCALE} -c ./ssb.conf -T ${tbl}
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
		./dbgen -q -c ./ssb.conf -C $((PARALLEL_TASKS-1)) -S $((TASK_NUM-1)) -s ${SCALE} -T ${tbl}
		#echo "Finish generating and start to upload - ${tbl}"
		hadoop fs -put ${tbl}.tbl* ${HDFS_BASE_DIR}/data/$tbl/
		rm -f ${tbl}.tbl* || exit 0
		#echo "Upload finished - $tbl"
	done
fi
