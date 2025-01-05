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

#!/bin/bash

# ... [previous functions remain the same until create_docker_compose]

create_docker_compose() {
    cat > docker-compose.yml << EOF
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

    local ftp_port=2121
    local passive_port_start=30000
    for user in "${users[@]}"; do
        lastname=$(echo "$user" | cut -d' ' -f1)
        firstname=$(echo "$user" | cut -d' ' -f2)
        username=$(create_username "$lastname" "$firstname")
        password=$(create_password "$lastname")
        domain="${username}.${BASE_DOMAIN}"

        # Calculate passive port range for this user
        local passive_port_end=$((passive_port_start + 9))

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
      FTP_PASSIVE_PORTS: "${passive_port_start}:${passive_port_end}"
    ports:
      - "${ftp_port}:21"
EOF

        # Add passive port mappings individually
        for port in $(seq $passive_port_start $passive_port_end); do
            echo "      - \"${port}:${port}\"" >> docker-compose.yml
        done

        # Continue with the rest of the service definition
        cat >> docker-compose.yml << EOF
    volumes:
      - ./${username}/html:/home/ftpusers/${username}
    networks:
      - diak-halo
    restart: always

EOF
        ((ftp_port++))
        passive_port_start=$((passive_port_end + 1))
    done

    # Add networks configuration with external setting
    cat >> docker-compose.yml << EOF
networks:
  diak-halo:
    external: true
    name: ${NETWORK_NAME}
EOF
}

# ... [rest of the script remains the same]

# Generate CSV with student data
create_csv() {
    # Create CSV header
    echo "Aldomain,FTP_Felhasznalo,FTP_Jelszo,FTP_Port,FTP_Passziv_Portok,MySQL_Host,MySQL_Felhasznalo,MySQL_Jelszo,MySQL_Root_Jelszo" > "$CSV_OUTPUT"

    # Add data for each user
    local ftp_port=2121
    local passive_port_start=30000
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

        local passive_port_end=$((passive_port_start + 9))
        local passive_ports="${passive_port_start}-${passive_port_end}"

        echo "${domain},${username},${password},${ftp_port},${passive_ports},${mysql_host},${username},${password},${password}" >> "$CSV_OUTPUT"

        ((ftp_port++))
        passive_port_start=$((passive_port_end + 1))
    done

    echo "CSV fájl létrehozva: $CSV_OUTPUT"
}

# Create test files for each user
create_test_files() {
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

        # Create directories
        mkdir -p "${username}/html"
        mkdir -p "${username}/mysql"

        # Create index.php and other test files
        # ... [rest of the function remains the same]
    done
}

# Main setup function
setup_environment() {
    echo "Creating Docker network..."
    docker network create "$NETWORK_NAME" 2>/dev/null || true

    echo "Creating PHP Dockerfile..."
    create_php_dockerfile

    echo "Generating docker-compose.yml..."
    create_docker_compose

    echo "Creating test files and directories..."
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
