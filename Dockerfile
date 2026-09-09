FROM golang:1.26.5-bookworm@sha256:53eeac89074db483fdf0ab3be1df32bf6e47562263d2d0d6baa7f26acb4957dd AS build
ARG JOBD=github.com/openabstractions/service-jobd@v0.2.0
ARG TARGETARCH
# CGO off: a static binary any Linux kernel loads, including a 2019 DSM userland.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH:-amd64} \
    go install -trimpath -ldflags="-s -w" "$JOBD" \
 && install -m 755 "$(find /go/bin -name service-jobd)" /jobd \
 && mkdir -p /skeleton/store /skeleton/etc/ssl/certs

# Scratch cannot mkdir: /store is the mount point, /etc receives resolv.conf and
# the host's CA bundle. No CA bundle is compiled in; mount /etc/ssl/certs.
FROM scratch
COPY --from=build /skeleton/ /
COPY --from=build /jobd /jobd
ENV ABSTRACTION_STORE=/store
VOLUME /store
# Files this writes must stay writable by the machine reading the share, so run
# as the store folder's owner: `--user "$(id -u):$(id -g)"` overrides this.
USER 1024:100
# Healthy means a supervisor is announcing itself on the store, not that a
# process exists.
HEALTHCHECK --interval=60s --timeout=10s CMD ["/jobd", "status", "--exit-code"]
ENTRYPOINT ["/jobd"]
CMD ["run", "--interval", "30s"]
