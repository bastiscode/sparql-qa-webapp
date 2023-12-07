FROM ghcr.io/cirruslabs/flutter:3.13.0 AS build

WORKDIR /app
COPY . .
RUN flutter build web --release --web-renderer=canvaskit --no-tree-shake-icons

FROM nginx:alpine-slim
COPY --from=build /app/build/web /usr/share/nginx/html
