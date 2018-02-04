package main

import (
	"flag"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"fmt"
	"strings"
	"k8s.io/apimachinery/pkg/apis/meta/v1"
	"time"
)

//var kubernetesApi = flag.String("webhook-method", "POST", "the HTTP method url to use to send the webhook")

var configMapsString *string
var kubernetesNameSpace *string
var restartablePodName *string

var lastResourceVersions = make(map[string]string)

func checkResourceVersion(clientset kubernetes.Clientset, configMaps []string) {
	for _, configMap := range configMaps {
		describedConfigMap, getConfigMapError := clientset.CoreV1().ConfigMaps(*kubernetesNameSpace).Get(configMap, v1.GetOptions{})
		if getConfigMapError == nil {
			var currentResourceVersion = describedConfigMap.ObjectMeta.ResourceVersion
			if lastResourceVersion, ok := lastResourceVersions[configMap]; ok {
				if lastResourceVersion < currentResourceVersion {
					fmt.Printf("Configmap resourceversion changed, restart pod: %v\n", *restartablePodName)
					lastResourceVersions[configMap] = currentResourceVersion;
					deleteErr := clientset.CoreV1().Pods(*kubernetesNameSpace).Delete(*restartablePodName, &v1.DeleteOptions{})
					if deleteErr != nil {
						fmt.Printf("Cannot delete pod %v, error: %v\n", *restartablePodName, deleteErr)
					}
				}
			} else {
				fmt.Printf("Last resource version not found for '%v', save current: %v\n", configMap, currentResourceVersion)
				lastResourceVersions[configMap] = currentResourceVersion
			}
		} else {
			fmt.Printf("Cannot get config map %v, error: %v\n", configMap, getConfigMapError);
		}
	}
}

func main() {
	parseFlags()

	var configMaps = strings.Split(*configMapsString, ",")
	fmt.Printf("configMaps: %v\n", configMaps)
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err.Error())
	}

	// creates the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	for tick := range time.Tick(20 * time.Second) {
		fmt.Printf("Check resource version: %v\n", tick)
		checkResourceVersion(*clientset, configMaps);
	}
}

func parseFlags() {
	configMapsString = flag.String("configmaps", "", "configmaps to watch")
	kubernetesNameSpace = flag.String("namespace", "default", "kubernetes namespace for configmaps")
	restartablePodName = flag.String("podname", "", "podname to restart on configmap change")
	flag.Parse()
	fmt.Printf("configmaps: %v\n", *configMapsString)
	fmt.Printf("namespace: %v\n", *kubernetesNameSpace)
	fmt.Printf("podname: %v\n", *restartablePodName)
}