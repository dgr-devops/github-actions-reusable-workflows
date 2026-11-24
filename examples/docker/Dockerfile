# Imagen mínima usada como fixture de docker-build-scan-push.
FROM alpine:3.24

# Aplica los parches de seguridad disponibles en la capa base.
RUN apk upgrade --no-cache \
    && adduser -D -u 10001 app

USER app
CMD ["echo", "Hola desde el contenedor de ejemplo"]
