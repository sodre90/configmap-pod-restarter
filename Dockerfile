FROM alpine:3.7

RUN apk update
RUN apk upgrade
RUN apk add bash
RUN apk add jq
RUN apk add curl

COPY configmap-pod-restarter.sh /configmap-pod-restarter.sh

ENTRYPOINT [ "/bin/bash" ]

CMD [ "/configmap-pod-restarter.sh" ]