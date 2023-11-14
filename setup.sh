#!/bin/bash

# Запрашиваем данные у пользователя
read -p "Введите имя пользователя для Basic Auth: " BASIC_AUTH_USER
read -sp "Введите пароль для Basic Auth: " BASIC_AUTH_PASSWORD
echo
read -p "Введите ваш домен (например, example.com): " DOMAIN
read -p "Введите ваш email для Let's Encrypt: " EMAIL

# Создание директории для Basic Auth, если она еще не существует
mkdir -p basic-auth

# Создание файла .htpasswd
htpasswd -cb basic-auth/.htpasswd $BASIC_AUTH_USER $BASIC_AUTH_PASSWORD

# Создание конфигурационного файла для Traefik
cat << 'EOF' > basic-auth/traefik_dynamic.toml
[http.middlewares]
  [http.middlewares.basicauth.basicAuth]
    usersFile = "/etc/traefik/basic-auth/.htpasswd"
EOF

# Запись переменных в .env файл
cat << EOF > docker-compose.yml
version: '3'

services:
  traefik:
    image: traefik:v2.5
    container_name: traefik
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "./letsencrypt:/letsencrypt"
      - "./basic-auth:/etc/traefik/basic-auth"
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=${EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"

  shlink-web-client:
    image: shlinkio/shlink-web-client:latest
    container_name: shlink-web-client
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.shlink-web-client.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.shlink-web-client.entrypoints=websecure"
      - "traefik.http.routers.shlink-web-client.tls.certresolver=myresolver"
      - "traefik.http.routers.shlink-web-client.middlewares=basicauth@file"
EOF

echo "Настройка завершена."
