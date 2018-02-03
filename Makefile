BINARYNAME=configmap-pod-restarter

build:
	mkdir -p build/Linux  && GOOS=linux  go build -o build/Linux/$(BINARYNAME)
	mkdir -p build/Darwin && GOOS=darwin go build -o build/Darwin/$(BINARYNAME)

.PHONY: build