FROM alpine:3.7

RUN apk --no-cache add bash jq tar lftp ca-certificates
ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*
