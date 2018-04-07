#!/bin/bash

# https://stackoverflow.com/questions/40350456/docker-any-way-to-list-open-sockets-inside-a-running-docker-container

# functions

function regextool() {
    local REGEX=$1
    perl -wnE "say for /${REGEX}/g"
}

# _parseConfig(configuration)
function _parseConfig() {
    local CONFIGURATION="$1"

    local CONTAINER_ID_OR_NAME=$(expr match "$CONFIGURATION" '\([^:]*\):.*[\n\r]*')
    local CONTAINER_PORTS=$(expr match "$CONFIGURATION" '[^:]*:\(.*\)[\n\r]*')
    
    CONTAINER_CONFIG_IDS=("${CONTAINER_CONFIG_IDS[@]}" "$CONTAINER_ID_OR_NAME")
    CONTAINER_CONFIG_PORTS=("${CONTAINER_CONFIG_PORTS[@]}" "$CONTAINER_PORTS")
}

# _checkContainerPort(containerPid, containerPort, connectionState)
function _checkContainerPort() {
    local CONTAINER_PID="$1"
    local CHECKED_PORT="$2"
    local CHECKED_STATE="$3"
    local SS_REGEX_FOR_LOCAL_PORT='([^\s]*[\s]+'${CHECKED_STATE}'(?:[\s]+[^\s]*){2}[\s]+(?:[^\s]+:'${CHECKED_PORT}')[\s]+(?:[^\s]+)[\n\r]*)'

    #echo "nsenter --target $CONTAINER_PID --net ss -n"
    sudo nsenter --target $CONTAINER_PID --net ss -n | regextool "$SS_REGEX_FOR_LOCAL_PORT"
}

# _checkContainer(id, ports)
function _checkContainer() {
    local CONTAINER_ID=$1
    local CONTAINER_PORTS=$2
    local CONTAINER_NAME=$(docker inspect -f '{{.Name}}' $CONTAINER_ID)
    local CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER_ID)
    
    echo "Active ports in container '$CONTAINER_NAME'"

    local RETURN_CODE=0
    for PORT in ${CONTAINER_PORTS//,/ }
    do
        local CHECK_RESULT
        mapfile CHECK_RESULT < <(_checkContainerPort "$CONTAINER_PID" "$PORT" "ESTAB")

        if [ "#${CHECK_RESULT[0]}" == "#" ]; then
            continue
        else
            printf '%s' "${CHECK_RESULT[@]}"
        fi

        ((RETURN_CODE++))
    done

    if [ "${RETURN_CODE}" == "0" ]; then
        echo "No active ports"
    fi

    return $RETURN_CODE
}

# script

#env
#declare -p

SCRIPTPLUGIN_DOCKER_CONTAINER_CONFLIST=${SCRIPTPLUGIN_DOCKER_CONTAINER_CONFLIST:-""}

declare -a CONTAINER_CONFIG_IDS
declare -a CONTAINER_CONFIG_PORTS

echo ">>>>>>> Plugin start"; echo

PLUGIN_RESULT_CODE=0

if [ "#$SCRIPTPLUGIN_DOCKER_CONTAINER_CONFLIST" == "#" ]; then
    echo "Plugin not configured."; echo
else
    INDEX=0
    for SCRIPTPLUGIN_DOCKER_CONTAINER_CONF in $SCRIPTPLUGIN_DOCKER_CONTAINER_CONFLIST
    do
        echo "Container conf: $SCRIPTPLUGIN_DOCKER_CONTAINER_CONF"
        _parseConfig "$SCRIPTPLUGIN_DOCKER_CONTAINER_CONF"
        _checkContainer "${CONTAINER_CONFIG_IDS[$INDEX]}" "${CONTAINER_CONFIG_PORTS[$INDEX]}"
        CONTAINER_CHECK_RTCODE=$?

        if [ $CONTAINER_CHECK_RTCODE -ne 0 ]; then
            PLUGIN_RESULT_CODE=1
        fi

        echo
        ((INDEX++))
    done

    if [ $PLUGIN_RESULT_CODE -eq 1 ]; then
        echo "Some container ports are active, plugin want prevent shutdown"
    else
        echo "No container ports are active."
    fi
fi

echo "<<<<<<< Plugin end"

exit $PLUGIN_RESULT_CODE
