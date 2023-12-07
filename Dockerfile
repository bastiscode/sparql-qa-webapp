FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .
RUN flutter build web --release

FROM nginx:alpine-slim
COPY --from=build /app/build/web /usr/share/nginx/html
