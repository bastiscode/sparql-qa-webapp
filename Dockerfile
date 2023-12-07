FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .
RUN flutter build web --release --web-renderer=canvaskit --no-tree-shake-icons

FROM nginx:alpine-slim
COPY --from=build /app/build/web /usr/share/nginx/html
