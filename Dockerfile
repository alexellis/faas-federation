FROM golang:1.11 as build
ENV CGO_ENABLED=0

RUN mkdir -p /go/src/github.com/ewilde/faas-federation/

WORKDIR /go/src/github.com/ewilde/faas-federation

COPY .git     .git
COPY handlers handlers
COPY routing  routing
COPY testing  testing
COPY types    types
COPY vendor   vendor
COPY version  version
COPY main.go  main.go


RUN curl -sL https://github.com/alexellis/license-check/releases/download/0.2.2/license-check > /usr/bin/license-check \
   && chmod +x /usr/bin/license-check
RUN license-check -path ./ --verbose=false "Alex Ellis" "OpenFaaS Author(s)"

RUN gofmt -l -d $(find . -type f -name '*.go' -not -path "./vendor/*") \
    && go test $(go list ./... | grep -v /vendor/) -cover \
    && VERSION=$(git describe --all --exact-match `git rev-parse HEAD` | grep tags | sed 's/tags\///') \
    && GIT_COMMIT=$(git rev-list -1 HEAD) \
    && CGO_ENABLED=0 GOOS=linux go build --ldflags "-s -w \
    -X github.com/openfaas/faas-federation/version.GitCommit=${GIT_COMMIT}\
    -X github.com/openfaas/faas-federation/version.Version=${VERSION}" \
    -a -installsuffix cgo -o faas-federation .

# Release stage
FROM alpine:3.10 as ship

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/openfaas/faas-federation" \
      org.label-schema.vcs-type="Git" \
      org.label-schema.name="openfaas/faas-federation" \
      org.label-schema.vendor="openfaas" \
      org.label-schema.docker.schema-version="1.0"

RUN apk --no-cache add ca-certificates

WORKDIR /root/

EXPOSE 8080

ENV http_proxy      ""
ENV https_proxy     ""

COPY --from=build /go/src/github.com/ewilde/faas-federation/faas-federation    .

CMD ["./faas-federation"]
