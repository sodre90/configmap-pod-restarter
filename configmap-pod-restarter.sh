#!/bin/bash

: ${KUBERNETES_API_ENDPOINT:?"Please set KUBERNETES_API_ENDPOINT"}
: ${KUBERNETES_NAMESPACE:?"Please set KUBERNETES_NAMESPACE"}
: ${CONFIGMAPS_NAME:?"Please set CONFIGMAPS_NAME"}
: ${RESTARTABLE_POD_NAME:?"Please set RESTARTABLE_POD_NAME"}

KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

function get_configmap_resource_version() {
    CONFIGMAP_NAME=$1
    configmap=$(curl -k -H "Authorization: Bearer $KUBE_TOKEN" $KUBERNETES_API_ENDPOINT/api/v1/namespaces/$KUBERNETES_NAMESPACE/configmaps?fieldSelector=metadata.name=$CONFIGMAP_NAME)
    echo $configmap | jq .items[0].metadata.resourceVersion
}

function main() {
    IFS=',' read -r -a config_map_array <<< "$CONFIGMAPS_NAME"
    last_resource_version=()
    for index in "${!config_map_array[@]}"
    do
        config_map=${config_map_array[index]}
        last_resource_version[$index]=`get_configmap_resource_version $config_map`
    done
    while true; do
        for index in "${!config_map_array[@]}"
        do
            config_map=${config_map_array[index]}
            echo "last_resource_version for $config_map: ${last_resource_version[index]}"
            actual_resource_version=`get_configmap_resource_version $config_map`
            echo "actual_resource_version for $config_map: $actual_resource_version"
            if [[ ${last_resource_version[index]} && 
                  $actual_resource_version &&
                  ${last_resource_version[index]} != $actual_resource_version ]]; then
                curl -X "DELETE" -k -H "Authorization: Bearer $KUBE_TOKEN" $KUBERNETES_API_ENDPOINT/api/v1/namespaces/$KUBERNETES_NAMESPACE/pods/$RESTARTABLE_POD_NAME
                echo "pod deleted"
                last_resource_version[$config_map]=$actual_resource_version
            fi
        done
        sleep 10;
    done;
}

main