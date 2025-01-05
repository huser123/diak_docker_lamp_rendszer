#!/bin/bash

# Configuration
BASE_DOMAIN="teszt.hu"
NETWORK_NAME="diak-halo"
CSV_OUTPUT="diakok/diak_adatok.csv"
BASE_DIR="diakok"

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
    mkdir -p $BASE_DIR/docker
    cat > $BASE_DIR/docker/Dockerfile.php << 'EOF'
FROM php:8.3-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libxml2-dev \
    libicu-dev \
    libonig-dev \
    libxslt1-dev \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo \
    pdo_mysql \
    mysqli \
    gd \
    zip \
    bcmath \
    calendar \
    xml \
    intl \
    mbstring \
    gettext \
    soap \
    sockets \
    xsl \
    opcache

# Telepítsd és engedélyezd a PDO MySQL kiegészítőt
RUN docker-php-ext-install pdo pdo_mysql

# Install PECL extensions
RUN pecl install redis \
    && pecl install xdebug \
    && docker-php-ext-enable redis xdebug

# Configure Apache
RUN a2enmod rewrite headers

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set recommended PHP.ini settings
RUN { \
        echo 'upload_max_filesize = 64M'; \
        echo 'post_max_size = 64M'; \
        echo 'memory_limit = 256M'; \
        echo 'max_execution_time = 600'; \
        echo 'max_input_vars = 3000'; \
    } > /usr/local/etc/php/conf.d/custom.ini
EOF
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
        password=$(create_password "$lastname")

        # Create directories
        mkdir -p "$BASE_DIR/${username}/html"
        mkdir -p "$BASE_DIR/${username}/mysql"

        # Create index.php
        cat > "$BASE_DIR/${username}/html/index.php" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Üdvözlünk ${firstname}!</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .menu { margin: 20px 0; }
        .menu a { margin-right: 20px; }
    </style>
</head>
<body>
    <h1>Szia ${firstname}!</h1>
    <p>A webszerver működik!</p>
    <div class="menu">
        <a href="phpinfo.php">PHP információk</a>
        <a href="db.php">Adatbázis kapcsolat teszt</a>
        <a href="extensions.php">PHP Kiegészítők listája</a>
    </div>
</body>
</html>
EOF

        # Create phpinfo.php
        echo "<?php phpinfo(); ?>" > "$BASE_DIR/${username}/html/phpinfo.php"

        # Create extensions.php
        cat > "$BASE_DIR/${username}/html/extensions.php" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>PHP Kiegészítők</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .extension { margin: 5px 0; }
        .enabled { color: green; }
        .disabled { color: red; }
    </style>
</head>
<body>
    <h1>Telepített PHP Kiegészítők</h1>
    <?php
    $extensions = get_loaded_extensions();
    sort($extensions);
    foreach($extensions as $extension) {
        echo "<div class='extension enabled'>✓ " . htmlspecialchars($extension) . "</div>";
    }
    ?>
</body>
</html>
EOF

        # Create db.php
        cat > "$BASE_DIR/${username}/html/db.php" << EOF
<?php
\$host = '${username}-mysql';
\$db   = '${username}_db';
\$user = '${username}';
\$pass = '${password}';
\$charset = 'utf8mb4';

\$dsn = "mysql:host=\$host;dbname=\$db;charset=\$charset";
try {
    \$pdo = new PDO(\$dsn, \$user, \$pass);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "<div style='color:green; font-family: Arial, sans-serif; margin: 40px;'>";
    echo "<h1>✓ Adatbázis kapcsolat sikeres!</h1>";
    echo "<p>Szerver verzió: " . \$pdo->getAttribute(PDO::ATTR_SERVER_VERSION) . "</p>";
    echo "</div>";
} catch (PDOException \$e) {
    echo "<div style='color:red; font-family: Arial, sans-serif; margin: 40px;'>";
    echo "<h1>✗ Kapcsolódási hiba</h1>";
    echo "<p>" . htmlspecialchars(\$e->getMessage()) . "</p>";
    echo "</div>";
}
?>
EOF
    done
}

# Create docker-compose.yml
create_docker_compose() {
    cat > $BASE_DIR/docker-compose.yml << EOF
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

        cat >> $BASE_DIR/docker-compose.yml << EOF
  ${username}-web:
    build:
      context: ./docker
      dockerfile: Dockerfile.php
    container_name: ${username}-web
    hostname: ${username}-web
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
    hostname: ${username}-mysql
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
    hostname: ${username}-ftp
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
            echo "      - \"${port}:${port}\"" >> $BASE_DIR/docker-compose.yml
        done

        # Continue with the rest of the service definition
        cat >> $BASE_DIR/docker-compose.yml << EOF
    volumes:
      - ./${username}/html:/home/ftpusers/${username}
    networks:
      - diak-halo
    restart: always

EOF
        ((ftp_port++))
        passive_port_start=$((passive_port_end + 1))
    done

    # Add networks configuration
    cat >> $BASE_DIR/docker-compose.yml << EOF
networks:
  diak-halo:
    external: true
    name: ${NETWORK_NAME}
EOF
}

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

# Main setup function
setup_environment() {
    echo "Creating base directory..."
    mkdir -p $BASE_DIR

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

    # Change to the diakok directory before running docker-compose
    cd $BASE_DIR

    echo "Building and starting Docker containers..."
    docker compose up -d

    cd ..

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
