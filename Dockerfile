FROM ubuntu:latest AS development

ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-noninteractive} 
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

## Install all the dependencies
RUN apt-get update -yqq \
	&& apt-get upgrade -yqq \
	&& apt-get install -yqq --no-install-recommends \
	nginx openssl \
	mariadb-server mariadb-client \
	php-fpm php-cli php-mysql php-gd php-zip php-bcmath php-curl php-imagick php-xml php-mbstring php-xml php-intl php-xdebug php-soap \
    php-sqlite3 php-ldap php-redis php-predis php-memcached memcached \
	redis \
	supervisor \
    git curl ca-certificates less nano unzip sed gnupg postfix \
    phpmyadmin \
    gettext 

## Install specific dependencies
ARG DOCKER__ADDITIONAL_PACKAGES=${DOCKER__ADDITIONAL_PACKAGES:-""}
RUN if [ ! -z "$DOCKER__ADDITIONAL_PACKAGES" ]; then \
        apt-get install -yqq --no-install-recommends $DOCKER__ADDITIONAL_PACKAGES; \
    fi

## Install nodejs
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ARG NODE_MAJOR=${NODE_MAJOR:-20}
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update
RUN apt-get install nodejs -y

# Install PHP Composer
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
RUN php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

## Set the remaining build environment variables
# Project metadata
ARG DOCKER__PROJECT_ID=${DOCKER__PROJECT_ID:-"C3-project"}
ARG DOCKER__PROJECT_NAME=${DOCKER__PROJECT_NAME:-"C3 App"}
ARG DOCKER__PROJECT_ADMIN_USER=${DOCKER__PROJECT_ADMIN_USER:-"root"}
ARG DOCKER__PROJECT_ADMIN_PWD=${DOCKER__PROJECT_ADMIN_PWD:-"toor"}
ARG DOCKER__PROJECT_ADMIN_EMAIL=${DOCKER__PROJECT_ADMIN_EMAIL:-"cesperanc@gmail.com"}

# Project paths
ARG DOCKER__WORK_DIR=${DOCKER__WORK_DIR:-"/app/data"}
ARG DOCKER__WWW_DIR=${DOCKER__WWW_DIR:-"${DOCKER__WORK_DIR}/www"}
ARG DOCKER__MIRROR_DIR=${DOCKER__MIRROR_DIR:-"${DOCKER__WORK_DIR}/mirror"}
ARG DOCKER__PROJECT_FOLDER=${DOCKER__PROJECT_FOLDER:-"${DOCKER__PROJECT_ID}"}
ARG DOCKER__PROJECT_FOLDER_ABSOLUTE=${DOCKER__PROJECT_FOLDER_ABSOLUTE:-"${DOCKER__WWW_DIR}/${DOCKER__PROJECT_FOLDER}"}
ARG DOCKER__PROJECT_URL=${DOCKER__PROJECT_URL:-"localhost"}

# Stack variables
ARG DOCKER__MYSQL_HOST=${DOCKER__MYSQL_HOST:-"localhost"}
ARG DOCKER__MYSQL_DATABASE=${DOCKER__MYSQL_DATABASE:-"app_db"}
ARG DOCKER__MYSQL_USER=${DOCKER__MYSQL_USER:-"app_db_user"}
ARG DOCKER__MYSQL_PASSWORD=${DOCKER__MYSQL_PASSWORD:-"app_db_pwd"}
ARG DOCKER__PHP_VERSION=${DOCKER__PHP_VERSION:-"8.1"}

## Prepare the working directory
RUN mkdir -p "${DOCKER__WORK_DIR}" \
    && mkdir -p "${DOCKER__WWW_DIR}" \
    && chown -R www-data "${DOCKER__WWW_DIR}"

# ENV DOCKER__PROJECT_FOLDER=${DOCKER__PROJECT_FOLDER:-${DOCKER__PROJECT_ID}}
# ENV DOCKER__PROJECT_FOLDER_ABSOLUTE=${DOCKER__WWW_DIR}/${DOCKER__PROJECT_FOLDER}
# ARG DOCKER__PROJECT_FOLDER_ABSOLUTE=${DOCKER__PROJECT_FOLDER_ABSOLUTE}
RUN mkdir -p "${DOCKER__PROJECT_FOLDER_ABSOLUTE}" \
	&& chown -R www-data "${DOCKER__WWW_DIR}"

## Create the required PHP-FPM directories
RUN mkdir -p /run/php \
    && mkdir -p /var/log/php-fpm

## Create the required PHP-FPM directories
RUN mkdir -p /etc/nginx/sites-overrides

## Create SSL certificate
RUN export DOCKER__PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") && echo '[dn]\n\
CN='${DOCKER__PROJECT_URL}'\n\
C = PT\n\
O = C3\n\
\n\
[req]\n\
default_bits = 2048\n\
distinguished_name = dn\n\
req_extensions = req_ext\n\
x509_extensions = x509_ext\n\
string_mask = utf8only\n\
\n\
# Section x509_ext is used when generating a self-signed certificate. I.e., openssl req -x509 ...\n\
[ x509_ext ]\n\
subjectKeyIdentifier = hash\n\
authorityKeyIdentifier = keyid,issuer\n\
basicConstraints = CA:FALSE\n\
keyUsage = digitalSignature\n\
extendedKeyUsage=serverAuth\n\
subjectAltName = @alternate_names\n\
nsComment = "'${DOCKER__PROJECT_URL}' Certificate"\n\
\n\
# Section req_ext is used when generating a certificate signing request. I.e., openssl req ...\n\
[ req_ext ]\n\
subjectKeyIdentifier = hash\n\
basicConstraints = CA:FALSE\n\
keyUsage = digitalSignature\n\
extendedKeyUsage=serverAuth\n\
subjectAltName = @alternate_names\n\
nsComment = "'${DOCKER__PROJECT_URL}' Certificate"\n\
\n\
[ alternate_names ]\n\
DNS.1 = '${DOCKER__PROJECT_URL}'\n\
DNS.2 = www.'${DOCKER__PROJECT_URL}'\n\
DNS.3 = localhost\n\
DNS.4 = localhost.localdomain\n\
DNS.4 = dev-apps.local\n\
DNS.5 = 127.0.0.1\n\
\n\
' | openssl req -x509 -days 365 -out /etc/ssl/private/"${DOCKER__PROJECT_ID}".crt -keyout /etc/ssl/private/"${DOCKER__PROJECT_ID}".key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj "/CN=${DOCKER__PROJECT_URL}" -config /dev/stdin 2> /dev/null


## Configure nginx

RUN rm /etc/nginx/sites-enabled/default && export DOCKER__PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") && echo '\
# Include custom overrides from host \n\
include /etc/nginx/sites-overrides/*;\n\
\n\
# Expires map \n\
map_hash_max_size 128; \n\
map_hash_bucket_size 128; \n\
map $sent_http_content_type $expires { \n\
    default                    off; \n\
    text/html                  epoch; \n\
    text/css                   1y; \n\
    application/javascript     1y; \n\
    ~image/                    1y; \n\
} \n\
 \n\
server { \n\
    listen 80; \n\
    listen [::]:80; \n\
    listen 443 ssl http2; \n\
    listen [::]:443 ssl http2; \n\
    \n\
    server_name "'${DOCKER__PROJECT_URL}'"; \n\
    server_tokens off; \n\
    # Max body size (for uploads) \n\
    client_max_body_size 2000M; \n\
    # SSL settings \n\
    ssl_certificate "/etc/ssl/private/'${DOCKER__PROJECT_ID}'.crt"; \n\
    ssl_certificate_key "/etc/ssl/private/'${DOCKER__PROJECT_ID}'.key"; \n\
    add_header Strict-Transport-Security "max-age=31536000"; \n\
    ssl_protocols TLSv1.2; \n\
    ssl_ciphers !aNULL:!eNULL:FIPS@STRENGTH; \n\
    ssl_prefer_server_ciphers on; \n\
    \n\
    # Enable compression \n\
    gzip on; \n\
    gzip_vary on; \n\
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript; \n\
    # File system structure \n\
    set $CUSTOM_ROOT '${DOCKER__PROJECT_FOLDER_ABSOLUTE}'; \n\
    root $CUSTOM_ROOT/public/; \n\
    index index.php index.html index.htm; \n\
    # Logs \n\
    access_log /var/log/nginx/localhost-access.log; \n\
    error_log /var/log/nginx/localhost-error.log; \n\
    \n\
    ## Restrictions ## \n\
    location ~ /\. { \n\
        deny all; \n\
    } \n\
	\n\
#    # Deny access of PHP files in the uploads and files directory \n\
#    location ~* /(?:uploads|files)/.*\.php$ { \n\
#        deny all; \n\
#    } \n\
	# Cache management \n\
	expires $expires; \n\
	\n\
    location ~* ^/phpmyadmin-v4(?<pmauri>/.*)? {\n\
        alias /usr/share/phpmyadmin/;\n\
        index index.php;\n\
        try_files $pmauri $pmauri/ =404;\n\
        location ~ \.php$ {\n\
            include fastcgi.conf;\n\
            fastcgi_index index.php;\n\
            fastcgi_param SCRIPT_FILENAME $document_root$pmauri;\n\
            fastcgi_pass unix:/var/run/php-fpm.sock;\n\
        }\n\
    }\n\
\n\
    error_page 404 /index.php;\n\
\n\
    #v4\n\
    location /v4 {\n\
        error_page 404 /v4/index.php;\n\
\n\
        alias $CUSTOM_ROOT/public/;\n\
        try_files $uri $uri/ @nested-v4;\n\
\n\
        # Deny access to dot (hidden) files\n\
        location ~ /\. {\n\
            access_log off;\n\
            log_not_found off;\n\
            deny all;\n\
        }\n\
        location ~ (/vendo_r/|/node_modules/|composer\.json|/readme|/README|readme\.txt|/upgrade\.txt|db/install\.xml|/fixtures/|/behat/|phpunit\.xml|\.lock|environment\.xml) {\n\
             deny all;\n\
             return 404;\n\
        }\n\
        #Accel redirect for static resources\n\
        location ~ ^/v4-static-data-(Modules|themes|Libraries)/([a-zA-Z0-9_-]+)/(.*)$ {\n\
             internal;\n\
             alias $CUSTOM_ROOT/app/$1/$2/Assets/$3;\n\
        }\n\
\n\
        location ~ \.php$ {\n\
            include snippets/fastcgi-php.conf;\n\
            fastcgi_param SCRIPT_FILENAME $request_filename;\n\
            fastcgi_pass unix:/var/run/php-fpm.sock;\n\
            fastcgi_read_timeout 3600;\n\
            fastcgi_intercept_errors on;\n\
            fastcgi_buffers 16 16k;\n\
            fastcgi_buffer_size 32k;\n\
\n\
            fastcgi_param SUPPORTS_X_ACCEL_REDIRECT true;\n\
        }\n\
    }\n\
    location @nested-v4 {\n\
        rewrite /v4/(.*)$ /v4/index.php?/$1 last;\n\
    }\n\
\n\
    #v3\n\
    location / {\n\
        proxy_pass https://intranet.uab.pt;\n\
        #proxy_pass http://intranet-uab-pt-v3:80;\n\
        proxy_set_header Host $host;\n\
        proxy_set_header X-Real-IP $remote_addr;\n\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n\
        proxy_set_header X-Forwarded-Proto https;\n\
        #proxy_set_header X-Forwarded-Proto $scheme;\n\
    }\n\
\n\
}' \
> /etc/nginx/sites-enabled/010-localhost.conf

RUN export DOCKER__PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") && echo '\
server { \n\
    listen 80; \n\
    listen [::]:80; \n\
    listen 443 ssl http2; \n\
    listen [::]:443 ssl http2; \n\
    \n\
    server_name localhost.localdomain dev-apps.local formacao-alv.local eventos.local pagamentos.local; \n\
    server_tokens off; \n\
    # Max body size (for uploads) \n\
    client_max_body_size 2000M; \n\
    # SSL settings \n\
    ssl_certificate "/etc/ssl/private/'${DOCKER__PROJECT_ID}'.crt"; \n\
    ssl_certificate_key "/etc/ssl/private/'${DOCKER__PROJECT_ID}'.key"; \n\
    add_header Strict-Transport-Security "max-age=31536000"; \n\
    ssl_protocols TLSv1.2; \n\
    ssl_ciphers !aNULL:!eNULL:FIPS@STRENGTH; \n\
    ssl_prefer_server_ciphers on; \n\
    \n\
    # Enable compression \n\
    gzip on; \n\
    gzip_vary on; \n\
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript; \n\
    # File system structure \n\
    set $CUSTOM_ROOT '${DOCKER__PROJECT_FOLDER_ABSOLUTE}'; \n\
    root $CUSTOM_ROOT/public/; \n\
    index index.php index.html index.htm; \n\
    # Logs \n\
    access_log /var/log/nginx/localhost-access.log; \n\
    error_log /var/log/nginx/localhost-error.log; \n\
    \n\
    ## Restrictions ## \n\
    location ~ /\. { \n\
        deny all; \n\
    } \n\
	\n\
#    # Deny access of PHP files in the uploads and files directory \n\
#    location ~* /(?:uploads|files)/.*\.php$ { \n\
#        deny all; \n\
#    } \n\
	# Cache management \n\
	expires $expires; \n\
	\n\
\n\
    error_page 404 /index.php;\n\
\n\
    #v4\n\
    location / {\n\
        alias $CUSTOM_ROOT/public/;\n\
        try_files $uri $uri/ @nested-apps;\n\
\n\
        # Deny access to dot (hidden) files\n\
        location ~ /\. {\n\
            access_log off;\n\
            log_not_found off;\n\
            deny all;\n\
        }\n\
        location ~ (/vendo_r/|/node_modules/|composer\.json|/readme|/README|readme\.txt|/upgrade\.txt|db/install\.xml|/fixtures/|/behat/|phpunit\.xml|\.lock|environment\.xml) {\n\
             deny all;\n\
             return 404;\n\
        }\n\
        #Accel redirect for static resources\n\
        location ~ ^/v4-static-data-(Modules|themes|Libraries)/([a-zA-Z0-9_-]+)/(.*)$ {\n\
             internal;\n\
             alias $CUSTOM_ROOT/app/$1/$2/Assets/$3;\n\
        }\n\
\n\
        location ~ \.php$ {\n\
            include snippets/fastcgi-php.conf;\n\
            fastcgi_param SCRIPT_FILENAME $request_filename;\n\
            fastcgi_pass unix:/var/run/php-fpm.sock;\n\
            fastcgi_read_timeout 3600;\n\
            fastcgi_intercept_errors on;\n\
            fastcgi_buffers 16 16k;\n\
            fastcgi_buffer_size 32k;\n\
\n\
            fastcgi_param SUPPORTS_X_ACCEL_REDIRECT true;\n\
        }\n\
    }\n\
    location @nested-apps {\n\
        rewrite /(.*)$ /index.php?/$1 last;\n\
    }\n\
\n\
    #Accel redirect for static resources\n\
    location ~ ^/v4-static-data-(Modules|themes|Libraries)/([a-zA-Z0-9_-]+)/(.*)$ {\n\
            internal;\n\
            alias $CUSTOM_ROOT/app/$1/$2/Assets/$3;\n\
    }\n\
\n\
}' \
> /etc/nginx/sites-enabled/015-localhost.localdomain.conf

# Run nginx as root
RUN sed -i 's/user\s\+www-data;/user root;/' /etc/nginx/nginx.conf 

# Configure PHP-fpm
RUN export DOCKER__PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") && echo '\n\
catch_workers_output = yes \n\
listen = /var/run/php-fpm.sock \n\
' \
>> "/etc/php/${DOCKER__PHP_VERSION}/fpm/pool.d/www.conf"

# Run PHP-fpm as root
RUN sed -i 's/user = www-data/user = root/' /etc/php/$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')/fpm/pool.d/www.conf

# Disable php-xdebug
RUN phpdismod xdebug

## Mirror DOCKER__WWW_DIR
RUN echo '#!/usr/bin/env bash\n\
\n\
# function unmount {\n\
#  umount "'${DOCKER__MIRROR_DIR}'/www/'${DOCKER__PROJECT_FOLDER}'"\n\
#  umount "'${DOCKER__MIRROR_DIR}'/www"\n\
#   exit 0\n\
# } \n\
# \n\
# trap unmount SIGTERM\n\
# \n\
# mkdir -p "'${DOCKER__MIRROR_DIR}'/www"\n\
# mkdir -p "'${DOCKER__WORK_DIR}'/null"\n\
# mount --bind "'${DOCKER__WWW_DIR}'" "'${DOCKER__MIRROR_DIR}'/www"\n\
# mount --make-shared "'${DOCKER__MIRROR_DIR}'/www"\n\
# mount --bind "'${DOCKER__WORK_DIR}'/null" "'${DOCKER__MIRROR_DIR}'/www/'${DOCKER__PROJECT_FOLDER}'"\n\
# touch "'${DOCKER__MIRROR_DIR}'/www/.gitkeep"\n\
# Do a composer install if composer install \n\
cd "'${DOCKER__PROJECT_FOLDER_ABSOLUTE}'" \n\
if [ -f composer.json ] && [ ! -f composer.lock ]; then \n\
    composer install; \n\
fi\n\
\n\
while true; do\n\
  sleep 1\n\
done\n\
' \
> "${DOCKER__WORK_DIR}"/bind_mount.bash && chmod +x "${DOCKER__WORK_DIR}"/bind_mount.bash

## Configure supervisord
RUN export DOCKER__PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") && echo '\
[unix_http_server] \n\
file=/var/run/supervisor.sock \n\
chmod=0700 \n\
chown= nobody:nogroup \n\
username = docker_services \n\
password = docker_services_pwd \n\
\n\
[supervisord] \n\
logfile=/var/log/supervisor/supervisord.log \n\
pidfile=/var/run/supervisord.pid \n\
childlogdir=/var/log/supervisor \n\
user=root \n\
#nodaemon=true \n\
\n\
[rpcinterface:supervisor] \n\
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface \n\
\n\
[supervisorctl] \n\
serverurl=unix:///var/run/supervisor.sock \n\
username = docker_services \n\
password = docker_services_pwd \n\
\n\
[program:mariadb]\n\
command=/usr/bin/mysqld_safe \n\
user=root \n\
autostart=true \n\
autorestart=true \n\
redirect_stderr=true \n\
priority=20 \n\
\n\
[program:php-fpm]\n\
command=/usr/sbin/php-fpm'${DOCKER__PHP_VERSION}' -R -F -O -d catch_workers_output=yes -d access.log=/proc/self/fd/2 -d error_log=/proc/self/fd/2 -d display_errors=yes\n\
user=root \n\
autostart=true \n\
autorestart=true \n\
redirect_stderr=true \n\
priority=30 \n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
\n\
[program:nginx]\n\
command=/usr/sbin/nginx -c /etc/nginx/nginx.conf -g "daemon off;" \n\
directory='${DOCKER__WWW_DIR}' \n\
user=root \n\
autostart=true \n\
autorestart=true \n\
redirect_stderr=true \n\
priority=40 \n\
\n\
[program:redis]\n\
command=/usr/bin/redis-server \n\
user=root \n\
autostart=true \n\
autorestart=true \n\
redirect_stderr=true \n\
priority=40 \n\
\n\
[program:memcached]\n\
command=memcached -m 128 -p 11211 -u memcache -l 127.0.0.1\n\
autostart=false\n\
autorestart=true\n\
startsecs=10\n\
startretries=3\n\
user=root\n\
redirect_stderr=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
\n\
[program:bindmount]\n\
command="'${DOCKER__WORK_DIR}'/bind_mount.bash" \n\
user=root \n\
stdout_logfile=/proc/self/fd/1 \n\
stdout_logfile_maxbytes=0 \n\
redirect_stderr=true \n\
\n\
[program:smtp-sink] \n\
command=smtp-sink -u root -c -D /dev/stdout 127.0.0.1:25 1000 \n\
redirect_stderr=true \n\
stdout_logfile=/proc/self/fd/1 \n\
stdout_logfile_maxbytes=0 \n\
autostart=false \n\
\n\
[group:web] \n\
programs=bindmount,redis,mariadb,php-fpm,nginx \n\
priority=999 \n\
\n\
' \
> "${DOCKER__WORK_DIR}/supervisord.conf" && ln -sf "${DOCKER__WORK_DIR}/supervisord.conf" /etc/supervisor/supervisord.conf \
&& echo '#!/usr/bin/env sh \n\
\n\
# Start supervisor in daemon mode \n\
/usr/bin/supervisord -c "'${DOCKER__WORK_DIR}'/supervisord.conf" \n\
' \
> "${DOCKER__WORK_DIR}/start-daemons.sh" && chmod +x "${DOCKER__WORK_DIR}/start-daemons.sh" \
&& echo '#!/usr/bin/env bash \n\
\n\
# Stop supervisord servives \n\
/usr/bin/supervisorctl -c "'${DOCKER__WORK_DIR}'/supervisord.conf" stop all \
&& kill -s SIGTERM $(supervisorctl -c "'${DOCKER__WORK_DIR}'/supervisord.conf" pid) \n\
' \
> "${DOCKER__WORK_DIR}/stop-daemons.sh" && chmod +x "${DOCKER__WORK_DIR}/stop-daemons.sh" \
&& echo '#!/usr/bin/env bash \n\
\n\
exec /usr/bin/supervisord -n -c "'${DOCKER__WORK_DIR}'/supervisord.conf" \n\
' \
> "/usr/bin/start_container_services.bash" && chmod +x "/usr/bin/start_container_services.bash"

## Copy the project to the container
COPY . "${DOCKER__PROJECT_FOLDER_ABSOLUTE}"

## Prepare the database
RUN echo '#!/usr/bin/env bash \n\
/usr/bin/mysqld_safe > /dev/null & \n\
while ! mysqladmin ping -h"'${DOCKER__MYSQL_HOST}'" --silent -s; do \n\
    sleep 1 \n\
done \n\
\n\
echo "CREATE DATABASE IF NOT EXISTS \\`'${DOCKER__MYSQL_DATABASE}'\\` ;" | /usr/bin/mysql \n\
echo "CREATE USER /*M!100103 IF NOT EXISTS */ \\"'${DOCKER__MYSQL_USER}'\\"@\\"'${DOCKER__MYSQL_HOST}'\\" IDENTIFIED BY \\"'${DOCKER__MYSQL_PASSWORD}'\\" ; \
	  GRANT ALL ON \\`'${DOCKER__MYSQL_DATABASE}'\\`.* TO \\"'${DOCKER__MYSQL_USER}'\\"@\\"'${DOCKER__MYSQL_HOST}'\\" WITH GRANT OPTION ; \
	  FLUSH PRIVILEGES;" | /usr/bin/mysql \n\
\n\
cd "'${DOCKER__PROJECT_FOLDER_ABSOLUTE}'" \n\
if [ -f composer.json ] && [ ! -f composer.lock ]; then \n\
    composer install; \n\
fi \n\
\n\
php spark migrate --all \n\
\n\
mysqladmin shutdown \n\
' \
> "${DOCKER__WORK_DIR}"/prepare-db.bash && chmod +x "${DOCKER__WORK_DIR}"/prepare-db.bash && "${DOCKER__WORK_DIR}"/prepare-db.bash && rm -f "${DOCKER__WORK_DIR}"/prepare-db.bash

### If you need something to replace something on the database
##RUN git clone "https://github.com/interconnectit/Search-Replace-DB.git" "${DOCKER__WORK_DIR}/Search-Replace-DB"

RUN cd "${DOCKER__PROJECT_FOLDER_ABSOLUTE}" && composer install

RUN cd "${DOCKER__PROJECT_FOLDER_ABSOLUTE}" && composer install && php spark migrate --all

WORKDIR "${DOCKER__PROJECT_FOLDER_ABSOLUTE}"

#VOLUME "${DOCKER__WWW_DIR}"
VOLUME "/var/lib/mysql/"

# Create the entrypoint script
RUN echo '#!/usr/bin/env sh \n\
exec "$@"\n\
' \
> /usr/bin/entrypoint.sh && chmod +x /usr/bin/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
# Start the daemons
CMD ["/usr/bin/start_container_services.bash"]
EXPOSE 80 443