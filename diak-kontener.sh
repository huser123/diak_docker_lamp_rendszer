#!/bin/bash

# Configuration
BASE_DOMAIN="teszt.hu"
NETWORK_NAME="diak-halo"
CSV_OUTPUT="diak_adatok.csv"

# Function to convert accented characters to normal ones
remove_accents() {
    echo "$1" | sed 'y/áéíóöőúüűÁÉÍÓÖŐÚÜŰ/aeiooouuuAEIOOOUUU/'
}

# Function to create username from full name
create_username() {
    lastname=$(remove_accents "$1")
    firstname=$(remove_accents "$2")
    echo "${lastname}${firstname}" | tr '[:upper:]' '[:lower:]'
}

# Function to create password from lastname
create_password() {
    lastname=$(remove_accents "$1")
    echo "$lastname" | tr '[:upper:]' '[:lower:]'
}

# Create Dockerfile for PHP with all extensions
create_php_dockerfile() {
    mkdir -p docker
    cat > docker/Dockerfile.php << 'EOF'
FROM php:8.3-apache
# ... [rest of the Dockerfile remains the same]
EOF
}

# Create docker-compose.yml with modified network and FTP settings
create_docker_compose() {
    cat > docker-compose.yml << 'EOF'
version: '3.9'
services:
  traefik:
    image: traefik:v2.6
    container_name: traefik
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./traefik:/etc/traefik
    networks:
      - diak-halo

EOF

    # Add services for each user
    declare -a users=(
        "Kálmán Péter"
        "Nagy Ádám"
        "Szép Anna"
        "Tóth Emese"
        "Varga Bence"
    )

    local port=2121
    for user in "${users[@]}"; do
        lastname=$(echo "$user" | cut -d' ' -f1)
        firstname=$(echo "$user" | cut -d' ' -f2)
        username=$(create_username "$lastname" "$firstname")
        password=$(create_password "$lastname")
        domain="${username}.${BASE_DOMAIN}"

        cat >> docker-compose.yml << EOF
  ${username}-web:
    build:
      context: ./docker
      dockerfile: Dockerfile.php
    container_name: ${username}-web
    volumes:
      - ./${username}/html:/var/www/html
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${username}-web.rule=Host(\`${domain}\`)"
      - "traefik.http.services.${username}-web.loadbalancer.server.port=80"
    networks:
      - diak-halo
    restart: always

  ${username}-mysql:
    image: mariadb:latest
    container_name: ${username}-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${password}
      MYSQL_DATABASE: ${username}_db
      MYSQL_USER: ${username}
      MYSQL_PASSWORD: ${password}
    volumes:
      - ./${username}/mysql:/var/lib/mysql
    networks:
      - diak-halo
    restart: always

  ${username}-ftp:
    image: stilliard/pure-ftpd
    container_name: ${username}-ftp
    environment:
      PUBLICHOST: ${domain}
      FTP_USER_NAME: ${username}
      FTP_USER_PASS: ${password}
      FTP_USER_HOME: /home/ftpusers/${username}
      FTP_PASSIVE_PORTS: "30000:30009"
    ports:
      - "${port}:21"
      - "30000-30009:30000-30009"
    volumes:
      - ./${username}/html:/home/ftpusers/${username}
    networks:
      - diak-halo
    restart: always

EOF
        ((port++))
    done

    # Add networks configuration with external setting
    cat >> docker-compose.yml << EOF
networks:
  diak-halo:
    external: true
    name: ${NETWORK_NAME}
EOF
}

# Generate CSV with student data
create_csv() {
    # Create CSV header
    echo "Aldomain,FTP_Felhasznalo,FTP_Jelszo,FTP_Port,MySQL_Host,MySQL_Felhasznalo,MySQL_Jelszo,MySQL_Root_Jelszo" > "$CSV_OUTPUT"

    # Add data for each user
    local port=2121
    declare -a users=(
        "Kálmán Péter"
        "Nagy Ádám"
        "Szép Anna"
        "Tóth Emese"
        "Varga Bence"
    )

    for user in "${users[@]}"; do
        lastname=$(echo "$user" | cut -d' ' -f1)
        firstname=$(echo "$user" | cut -d' ' -f2)
        username=$(create_username "$lastname" "$firstname")
        password=$(create_password "$lastname")
        domain="${username}.${BASE_DOMAIN}"
        mysql_host="${username}-mysql"

        echo "${domain},${username},${password},${port},${mysql_host},${username},${password},${password}" >> "$CSV_OUTPUT"
        ((port++))
    done

    echo "CSV fájl létrehozva: $CSV_OUTPUT"
}

# Main setup function
setup_environment() {
    echo "Creating Docker network..."
    docker network create "$NETWORK_NAME" 2>/dev/null || true

    echo "Creating PHP Dockerfile..."
    create_php_dockerfile

    echo "Generating docker-compose.yml..."
    create_docker_compose

    echo "Creating test files..."
    create_test_files

    echo "Generating CSV with student data..."
    create_csv

    echo "Building and starting Docker containers..."
    docker-compose up -d

    echo -e "\nKörnyezet beállítása kész!"
    echo -e "\nElérhető URL-ek:"
    declare -a users=(
        "Kálmán Péter"
        "Nagy Ádám"
        "Szép Anna"
        "Tóth Emese"
        "Varga Bence"
    )
    for user in "${users[@]}"; do
        lastname=$(echo "$user" | cut -d' ' -f1)
        firstname=$(echo "$user" | cut -d' ' -f2)
        username=$(create_username "$lastname" "$firstname")
        echo "http://${username}.${BASE_DOMAIN}"
    done

    echo -e "\nHosts fájl bejegyzések:"
    update_hosts_file
}

# Run setup
setup_environment
