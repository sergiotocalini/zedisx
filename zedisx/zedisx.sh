#!/usr/bin/env ksh
PATH=/usr/local/bin:${PATH}
IFS_DEFAULT="${IFS}"

#################################################################################

#################################################################################
#
#  Variable Definition
# ---------------------
#
APP_NAME=$(basename $0)
APP_DIR=$(dirname $0)
APP_VER="0.0.1"
APP_WEB="http://www.sergiotocalini.com.ar/"
TIMESTAMP=`date '+%s'`
CACHE_DIR=${APP_DIR}/tmp
CACHE_TTL=0                                      # IN MINUTES
#
#################################################################################

#################################################################################
#
#  Load Environment
# ------------------
#
[[ -f ${APP_DIR}/${APP_NAME%.*}.conf ]] && . ${APP_DIR}/${APP_NAME%.*}.conf

#
#################################################################################

#################################################################################
#
#  Function Definition
# ---------------------
#
usage() {
    echo "Usage: ${APP_NAME%.*} [Options]"
    echo ""
    echo "Options:"
    echo "  -a            Query arguments."
    echo "  -h            Displays this help message."
    echo "  -j            Jsonify output."
    echo "  -s ARG(str)   Section (default=stat)."
    echo "  -v            Show the script version."
    echo ""
    echo "Please send any bug reports to sergiotocalini@gmail.com"
    exit 1
}

version() {
    echo "${APP_NAME%.*} ${APP_VER}"
    exit 1
}

refresh_cache() {
    [[ -d ${CACHE_DIR} ]] || mkdir -p ${CACHE_DIR}
    file=${CACHE_DIR}/data.json
    if [[ $(( `stat -c '%Y' "${file}" 2>/dev/null`+60*${CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
        if [[ -n ${REDIS_PASS} ]]; then
	   REDIS_OPTS="-a ${REDIS_PASS}"
	fi
	redis-cli ${REDIS_OPTS} info 2>/dev/null > ${file}
    fi
    echo "${file}"
}

discovery() {
    resource=${1}

    IFS=${IFS_DEFAULT}
    cache=$(refresh_cache)
    if [[ ${resource} == 'databases' ]]; then
	while read line; do
	    name=`echo ${line} | awk -F: '{print $1}'`
	    attrs=`echo ${line} | awk -F: '{print $2}'`
	    keys=`echo ${attrs} | awk -F, '{print $1}' | awk -F= '{print $2}'`
	    expires=`echo ${attrs} | awk -F, '{print $2}' | awk -F= '{print $2}'`
	    echo "${name}|${keys}|${expires}"
	done < <(sed -n '/^# Keyspace/, /#.*/p' ${cache} | egrep -v "^$|^#" | grep '^db.:')
    fi
    return 0
}

get_info() {
    section=${1}
    name=${2}
    resource=${3}
    param1=${4}
    param2=${5}

    if [[ ${section} == 'count' ]]; then
       if [[ ${name} == 'databases' ]]; then
          raw=$(discovery databases)
          res=`echo "${raw}" | wc -l`
       fi
    else
       cache=$(refresh_cache)
       value_map=`sed -n "/^# ${section}/, /#.*/p" ${cache}`
       res=`echo "${value_map}" | egrep "^${name}:" | awk -F: '{print $2}' | awk '{$1=$1};1'`
    fi
    echo ${res:-0}
}

get_service() {
    resource=${1}

    port=`echo "${JENKINS_URL}" | sed -e 's|.*://||g' -e 's|/||g' | awk -F: '{print $2}'`
    pid=`sudo lsof -Pi :${port:-8080} -sTCP:LISTEN -t`
    rcode="${?}"
    if [[ ${resource} == 'listen' ]]; then
	if [[ ${rcode} == 0 ]]; then
	    res=1
	fi
    elif [[ ${resource} == 'uptime' ]]; then
	if [[ ${rcode} == 0 ]]; then
	    res=`sudo ps -p ${pid} -o etimes -h`
	fi
    fi
    echo ${res:-0}
    return 0
}

#
#################################################################################

#################################################################################
while getopts "s::a:s:uphvj:" OPTION; do
    case ${OPTION} in
	h)
	    usage
	    ;;
	s)
	    SECTION="${OPTARG}"
	    ;;
        j)
            JSON=1
            IFS=":" JSON_ATTR=(${OPTARG//p=})
            ;;
	a)
	    ARGS[${#ARGS[*]}]=${OPTARG//p=}
	    ;;
	v)
	    version
	    ;;
         \?)
            exit 1
            ;;
    esac
done

if [[ ${JSON} -eq 1 ]]; then
    rval=$(discovery ${ARGS[*]})
    echo '{'
    echo '   "data":['
    count=1
    while read line; do
	if [[ ${line} != '' ]]; then
        IFS="|" values=(${line})
        output='{ '
        for val_index in ${!values[*]}; do
            output+='"'{#${JSON_ATTR[${val_index}]:-${val_index}}}'":"'${values[${val_index}]}'"'
            if (( ${val_index}+1 < ${#values[*]} )); then
                output="${output}, "
            fi
        done 
        output+=' }'
        if (( ${count} < `echo ${rval}|wc -l` )); then
            output="${output},"
        fi
        echo "      ${output}"
        fi
	let "count=count+1"
    done <<< ${rval}
    echo '   ]'
    echo '}'
else
    if [[ ${SECTION} == 'discovery' ]]; then
        rval=$(discovery ${ARGS[*]})
        rcode="${?}"
    elif [[ ${SECTION} == 'service' ]]; then
	rval=$( get_service ${ARGS[*]} )
	rcode="${?}"	
    elif [[ ${SECTION} == 'info' ]]; then
	rval=$( get_info ${ARGS[*]} )
	rcode="${?}"
    fi
    echo ${rval:-0} | sed "s/null/0/g"
fi

exit ${rcode}
