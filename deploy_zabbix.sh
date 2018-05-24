#!/usr/bin/env ksh
SOURCE_DIR=$(dirname $0)
ZABBIX_DIR=/etc/zabbix

REDIS_ADDR=${1:-localhost}
REDIS_PORT=${2:-6379}
REDIS_PASS=${3:-`egrep "^requirepass" /etc/redis/redis.conf | awk '{print $2}'`}

mkdir -p ${ZABBIX_DIR}/scripts/agentd/zedisx
cp -rpv  ${SOURCE_DIR}/zedisx/zedisx.conf.example   ${ZABBIX_DIR}/scripts/agentd/zedisx/zedisx.conf
cp -rpv  ${SOURCE_DIR}/zedisx/zedisx.sh             ${ZABBIX_DIR}/scripts/agentd/zedisx/
cp -rpv  ${SOURCE_DIR}/zedisx/zabbix_agentd.conf    ${ZABBIX_DIR}/zabbix_agentd.d/zedisx.conf

regex_array[0]="s|REDIS_ADDR=.*|REDIS_ADDR=\"${REDIS_ADDR}\"|g"
regex_array[1]="s|REDIS_PORT=.*|REDIS_PORT=\"${REDIS_PORT}\"|g"
regex_array[1]="s|REDIS_PASS=.*|REDIS_PASS=\"${REDIS_PASS}\"|g"
for index in ${!regex_array[*]}; do
    sed -i "${regex_array[${index}]}" ${ZABBIX_DIR}/scripts/agentd/zedisx/zedisx.conf
done
