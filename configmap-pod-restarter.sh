#!/bin/bash

: ${KUBERNETES_API_ENDPOINT:?"Please set KUBERNETES_API_ENDPOINT"}
: ${KUBERNETES_NAMESPACE:?"Please set KUBERNETES_NAMESPACE"}
: ${CONFIGMAP_NAME:?"Please set CONFIGMAP_NAME"}
: ${RESTARTABLE_POD_NAME:?"Please set RESTARTABLE_POD_NAME"}

KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

function get_configmap_resource_version() {
    configmap=$(curl -k -H "Authorization: Bearer $KUBE_TOKEN" $KUBERNETES_API_ENDPOINT/api/v1/namespaces/$KUBERNETES_NAMESPACE/configmaps?fieldSelector=metadata.name=$CONFIGMAP_NAME)
    echo $configmap | jq .items[0].metadata.resourceVersion
}

function main() {
    last_resource_version=$(get_configmap_resource_version)
    while true; do
        echo "last_resource_version: $last_resource_version"
        actual_resource_version=$(get_configmap_resource_version)
        echo "actual_resource_version: $actual_resource_version"
        if [[ $last_resource_version != $actual_resource_version ]]; then
            curl -X "DELETE" -k -H "Authorization: Bearer $KUBE_TOKEN" $KUBERNETES_API_ENDPOINT/api/v1/namespaces/$KUBERNETES_NAMESPACE/pods/$RESTARTABLE_POD_NAME
            echo "pod deleted"
            last_resource_version=$actual_resource_version
        fi
        sleep 10;
    done;
}

main