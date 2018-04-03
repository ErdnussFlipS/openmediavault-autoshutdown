#!/bin/bash

# https://stackoverflow.com/questions/40350456/docker-any-way-to-list-open-sockets-inside-a-running-docker-container

# functions

function _parseConfig() {
    local CONFIGURATION="$1"

    # (?<containerid>[^:]*):(?<containerports>.*)[\n\r]*
    local CONTAINER_ID_OR_NAME=$(expr match "$CONFIGURATION" '\([^:]*\):.*[\n\r]*')
    local CONTAINER_PORTS=$(expr match "$CONFIGURATION" '[^:]*:\(.*\)[\n\r]*')
    # echo "Container id or name: $CONTAINER_ID_OR_NAME"
    # echo "Container ports: $CONTAINER_PORTS"

    # local CONTAINER_PORTS_ARRAY;
    # IFS=','; CONTAINER_PORTS_ARRAY=($CONTAINER_PORTS); unset IFS;

    CONTAINER_CONFIG_IDS=("${CONTAINER_CONFIG_IDS[@]}" "$CONTAINER_ID_OR_NAME")
    CONTAINER_CONFIG_PORTS=("${CONTAINER_CONFIG_PORTS[@]}" "$CONTAINER_PORTS")
}

# _checkContainer(id, ports)
function _checkContainer() {
    local CONTAINER_ID=$1
    local CONTAINER_PORTS=$2

    local CONTAINER_NAME=$(docker inspect -f '{{.Name}}' $CONTAINER_ID)
    echo "Open ports in container '$CONTAINER_NAME'"

    local CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER_ID)
    sudo nsenter --target $CONTAINER_PID --net netstat
}

# script

#env

SCRIPTPLUGIN_DOCKER_CONTAINER_CONFLIST=""


declare -a CONTAINER_CONFIG_IDS
declare -a CONTAINER_CONFIG_PORTS

index=0
for SCRIPTPLUGIN_DOCKER_CONTAINER_CONF in $SCRIPTPLUGIN_DOCKER_CONTAINER_CONFLIST
do
    echo "Container conf: $SCRIPTPLUGIN_DOCKER_CONTAINER_CONF"
    _parseConfig "$SCRIPTPLUGIN_DOCKER_CONTAINER_CONF"
    _checkContainer "${CONTAINER_CONFIG_IDS[$index]}" "${CONTAINER_CONFIG_PORTS[$index]}"

    echo
    ((index++))
done

echo ${CONTAINER_CONFIG_IDS[@]}
echo ${CONTAINER_CONFIG_PORTS[@]}

# RUNNING_CONTAINERS=$(docker ps -q --no-trunc)

exit 1
