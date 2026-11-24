# Serveur NautiLink : image arm64 (Raspberry Pi) et amd64, construite par
# .github/workflows/serveur.yml et publiée sur ghcr.io/gmoulard/nautilink-serveur.
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS construction
ARG TARGETOS TARGETARCH VERSION=dev
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags "-s -w -X main.version=$VERSION" -o /nautilink-server .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=construction /nautilink-server /nautilink-server
USER nonroot:nonroot
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s CMD ["/nautilink-server", "sante"]
ENTRYPOINT ["/nautilink-server"]
