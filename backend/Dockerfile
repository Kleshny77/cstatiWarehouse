# syntax=docker/dockerfile:1.7

# ---------- build ----------
FROM golang:1.26-alpine AS build
WORKDIR /src

# Кэшируем зависимости отдельным слоем.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

# distroless не умеет RUN, поэтому директорию для аплоадов подготавливаем здесь
# и переносим уже с правильным chown. Named volume при первом монтировании
# наследует owner/perm из этого шаблона, поэтому приложение от nonroot
# получит права на запись.
RUN mkdir -p /out/uploads

# ---------- runtime ----------
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app
COPY --from=build /out/server /app/server
COPY --from=build --chown=nonroot:nonroot /out/uploads /app/uploads

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/server"]
