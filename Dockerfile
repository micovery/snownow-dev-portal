# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM debian:stretch-slim

ENV DEBIAN_FRONTEND noninteractive

# Base
RUN apt-get update && \
    apt-get -y --no-install-recommends \
             install software-properties-common wget apt-transport-https \
             gnupg2 lsb-release sudo && \
    \
    wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add - && \
    echo "deb https://packages.sury.org/php/ stretch main" | sudo tee /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    apt-get -y install -y --no-install-recommends \
              php7.3 php7.3-cli php7.3-bcmath php7.3-bz2 php7.3-intl php7.3-gd \
              php7.3-mbstring php7.3-mysql php7.3-zip php7.3-sqlite3 \
              php7.3-curl php7.3-xml php-intl \
              apache2 libapache2-mod-php7.3 \
              git unzip cron gnupg supervisor sendmail ssh-client \
              mysql-server mysql-client patch jq vim && \
    apt-get -y clean && \
    apt-get -y autoclean && \
    rm -rf /var/lib/apt/lists/*

# Add Drupal user
RUN useradd -p "$(openssl passwd -1 drupal)" -d /drupal -ms /bin/bash drupal && \
    usermod -aG sudo drupal && \
    echo "drupal ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ENV KICKSTART_VERSION 8.x-dev

ENV DRUPAL_PROJECT_DIR=/drupal/project
ENV DRUPAL_WEB_DIR=${DRUPAL_PROJECT_DIR}/web
ENV PATH="${DRUPAL_PROJECT_DIR}/vendor/bin:${PATH}"

# Downgrade PHP version to 7.3
RUN sudo update-alternatives --set php /usr/bin/php7.3 && \
    sudo update-alternatives --set phar /usr/bin/phar7.3 && \
    sudo update-alternatives --set phar.phar /usr/bin/phar.phar7.3 && \
    php --ini

# Setup Apigee kickstart project with composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    \
    sudo -u drupal composer -V && \
    \
    mkdir -p ${DRUPAL_PROJECT_DIR} && \
    chmod -R a+rw ${DRUPAL_PROJECT_DIR}  && \
    \
    sudo -u drupal composer create-project apigee/devportal-kickstart-project:${KICKSTART_VERSION} ${DRUPAL_PROJECT_DIR} --no-interaction && \
    \
    mkdir /root/.ssh && chmod 0700 /root/.ssh && \
    sudo ssh-keyscan -t rsa github.com > ~/.ssh/known_hosts && \
    cd ${DRUPAL_PROJECT_DIR} && \
    sudo -u drupal composer config repositories.repo-name vcs https://github.com/micovery/apigee-graphql-drupal-module.git && \
    sudo -u drupal composer require micovery/apigee-graphql-drupal-module:dev-master && \
    sudo -u drupal composer require drupal/devel && \
    sudo -u drupal composer require drupal/jsonapi_extras:3.14 && \
    \
    sudo -u drupal composer clear-cache

# Setup Apache settings
RUN echo "Enabling Apache mod rewrite ..." && \
    echo 'LoadModule rewrite_module /usr/lib/apache2/modules/mod_rewrite.so' \
       >> /etc/apache2/mods-available/rewrite.load && \
    cd /etc/apache2/mods-enabled && \
    ln -s ../mods-available/rewrite.load && \
    \
    echo "Enabling Apache mod ssl ..." && \
    echo 'LoadModule ssl_module /usr/lib/apache2/modules/mod_ssl.so' \
       >> /etc/apache2/mods-available/ssl.load && \
    cd /etc/apache2/mods-enabled && \
    ln -s ../mods-available/ssl.load  && \
    \
    echo "Setting up apache virtual hosts ..." && \
    echo '\
      ServerName localhost \n\
      <VirtualHost *:80> \n\
        ServerAdmin webmaster@localhost \n\
        DocumentRoot  /drupal/project/web  \n\
        <Directory  /drupal/project/web  > \n\
          Options Indexes FollowSymLinks \n\
          AllowOverride All \n\
          Require all granted \n\
        </Directory> \n\
        ErrorLog /apache-logs/http-error.log \n\
        CustomLog /apache-logs/http-access.log combined \n\
      </VirtualHost> \n\
      \n\
      <VirtualHost *:443>  \n\
        ServerAdmin webmaster@localhost \n\
        DocumentRoot  /drupal/project/web \n\
        <Directory  /drupal/project/web  >  \n\
            Options Indexes FollowSymLinks  \n\
            AllowOverride All  \n\
            Require all granted  \n\
        </Directory>  \n\
        ErrorLog /apache-logs/https-error.log  \n\
        CustomLog /apache-logs/https-access.log combined  \n\
        SSLEngine on \n\
        SSLCertificateFile /apache-certs/cert.pem \n\
        SSLCertificateKeyFile /apache-certs/privkey.pem \n\
        SSLCertificateChainFile /apache-certs/fullchain.pem \n\
      </VirtualHost>' > /etc/apache2/sites-available/000-default.conf && \
      \
      mkdir /apache-logs && \
      chown www-data:www-data /apache-logs

# Setup drupal permissions
RUN sudo -u drupal mkdir -p ${DRUPAL_WEB_DIR}/sites/default/files && \
	sudo -u drupal chmod a+w ${DRUPAL_WEB_DIR}/sites/default -R && \
	sudo -u drupal mkdir -p ${DRUPAL_WEB_DIR}/sites/all/modules/contrib && \
	sudo -u drupal mkdir -p ${DRUPAL_WEB_DIR}/sites/all/modules/custom && \
	sudo -u drupal mkdir -p ${DRUPAL_WEB_DIR}/sites/all/themes/contrib && \
	sudo -u drupal mkdir -p ${DRUPAL_WEB_DIR}/sites/all/themes/custom && \
	sudo -u drupal cp ${DRUPAL_WEB_DIR}/sites/default/default.settings.php ${DRUPAL_WEB_DIR}/sites/default/settings.php && \
	sudo -u drupal cp ${DRUPAL_WEB_DIR}/sites/default/default.services.yml ${DRUPAL_WEB_DIR}/sites/default/services.yml && \
	sudo -u drupal chmod a+w ${DRUPAL_WEB_DIR}/sites/default/settings.php && \
	sudo -u drupal chmod 0664 ${DRUPAL_WEB_DIR}/sites/default/services.yml && \
	sudo -u drupal echo '$settings["trusted_host_patterns"] = array("^.*$");' >> ${DRUPAL_WEB_DIR}/sites/default/settings.php


# Setup Private File System (Needed for Hybrid Credentials)
RUN mkdir -p ${DRUPAL_PROJECT_DIR}/private && \
    cp ${DRUPAL_WEB_DIR}/.htaccess ${DRUPAL_PROJECT_DIR}/private && \
    echo 'SetHandler Drupal_Security_Do_Not_Remove_See_SA_2013_003' >> ${DRUPAL_PROJECT_DIR}/private/.htaccess && \
    echo 'Deny from all' >> ${DRUPAL_PROJECT_DIR}/private/.htaccess && \
    echo '$settings["file_private_path"] = "/drupal/project/private";' >> ${DRUPAL_WEB_DIR}/sites/default/settings.php && \
    chmod -R 770 ${DRUPAL_PROJECT_DIR}/private && \
    chown -R www-data:www-data ${DRUPAL_PROJECT_DIR}/private

# Patch JSON:API
RUN wget https://www.drupal.org/files/issues/2019-05-29/3042467-31.patch && \
    mv 3042467-31.patch ${DRUPAL_PROJECT_DIR}/web && \
    cd ${DRUPAL_PROJECT_DIR}/web && \
    sudo -u drupal patch -p1 < 3042467-31.patch

# Configure Drupal site
COPY backup  ${DRUPAL_PROJECT_DIR}/backup

RUN service mysql start && \
    mysql -u root -e "\
       GRANT ALL PRIVILEGES ON *.* TO drupal@localhost IDENTIFIED BY 'drupal'; \
       CREATE DATABASE drupal;" && \
    cd ${DRUPAL_WEB_DIR} && \
    sudo -u www-data ${DRUPAL_PROJECT_DIR}/vendor/bin/drush site:install -y apigee_devportal_kickstart \
          --db-url=mysql://drupal:drupal@localhost/drupal \
          --account-mail admin@snownow.com --account-name=admin \
          --account-pass=SuperSecret123! && \
    \
    sudo -u www-data ${DRUPAL_PROJECT_DIR}/vendor/bin/drush en devel jsonapi jsonapi_extras basic_auth && \
    sudo -u www-data ${DRUPAL_PROJECT_DIR}/vendor/bin/drush en apigee_drupal8_graphql && \
    sudo -u www-data ${DRUPAL_PROJECT_DIR}/vendor/bin/drush config:set jsonapi.settings read_only 0 -y && \
    sudo -u www-data ${DRUPAL_PROJECT_DIR}/vendor/bin/drush config:set key.key.apigee_edge_connection_default key_provider 'apigee_edge_environment_variables' -y && \
    sudo -u drupal chmod o-w ${DRUPAL_WEB_DIR}/sites/default/settings.php && \
    sudo -u drupal chmod o-w ${DRUPAL_WEB_DIR}/sites/default && \
    \
    sudo chown www-data:www-data -R ${DRUPAL_PROJECT_DIR}/backup && \
    cd ${DRUPAL_PROJECT_DIR}/backup && \
    rsync -avh sites ${DRUPAL_WEB_DIR} && \
    drush config-import --source=${DRUPAL_PROJECT_DIR}/backup/config -y --partial && \
    drush sql-cli  < db.sql && \
    rm -rf ${DRUPAL_PROJECT_DIR}/backup

# Configure supervisor
RUN echo '\
[program:apache2]  \n\
command=/bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -DFOREGROUND" \n\
autorestart=true   \n\
                   \n\
[program:mysql]    \n\
command=/usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/sbin/mysqld \n\
autorestart=true   \n\
                   \n\
[program:cron]     \n\
command=cron -f    \n\
autorestart=false  \n\
' >> /etc/supervisor/supervisord.conf




ENV PATH="${DRUPAL_PROJECT_DIR}/vendor/bin:${PATH}"
ENV APIGEE_EDGE_INSTANCE_TYPE=${APIGEE_EDGE_INSTANCE_TYPE}
ENV APIGEE_EDGE_AUTH_TYPE=${APIGEE_EDGE_AUTH_TYPE}
ENV APIGEE_EDGE_ORGANIZATION=${APIGEE_EDGE_ORGANIZATION}
ENV APIGEE_EDGE_USERNAME=${APIGEE_EDGE_USERNAME}
ENV APIGEE_EDGE_PASSWORD=${APIGEE_EDGE_PASSWORD}
ENV APIGEE_EDGE_ENDPOINT=${APIGEE_EDGE_ENDPOINT}
ENV APIGEE_EDGE_AUTHORIZATION_SERVER=${APIGEE_EDGE_AUTHORIZATION_SERVER}
ENV APIGEE_EDGE_CLIENT_ID=${APIGEE_EDGE_CLIENT_ID}
ENV APIGEE_EDGE_CLIENT_SECRET=${APIGEE_EDGE_CLIENT_SECRET}
ENV APIGEE_EDGE_ACCOUNT_JSON_KEY=${APIGEE_EDGE_ACCOUNT_JSON_KEY}

RUN echo ' \
export APIGEE_EDGE_INSTANCE_TYPE=${APIGEE_EDGE_INSTANCE_TYPE} \n\
export APIGEE_EDGE_AUTH_TYPE=${APIGEE_EDGE_AUTH_TYPE} \n\
export APIGEE_EDGE_ORGANIZATION=${APIGEE_EDGE_ORGANIZATION} \n\
export APIGEE_EDGE_USERNAME=${APIGEE_EDGE_USERNAME} \n\
export APIGEE_EDGE_PASSWORD=${APIGEE_EDGE_PASSWORD} \n\
export APIGEE_EDGE_ENDPOINT=${APIGEE_EDGE_ENDPOINT} \n\
export APIGEE_EDGE_AUTHORIZATION_SERVER=${APIGEE_EDGE_AUTHORIZATION_SERVER} \n\
export APIGEE_EDGE_CLIENT_ID=${APIGEE_EDGE_CLIENT_ID} \n\
export APIGEE_EDGE_CLIENT_SECRET=${APIGEE_EDGE_CLIENT_SECRET} \n\
export APIGEE_EDGE_ACCOUNT_JSON_KEY=${APIGEE_EDGE_ACCOUNT_JSON_KEY}' > /drupal/env

# Create certs-gen.sh script
RUN  printf  '#!/bin/bash \n\
    if [[ ! -d "/apache-certs" ]] ; then \n\
      echo "Creating self-signed certificate ..." \n\
      mkdir /apache-certs \n\
      cd /apache-certs \n\
      export OPENSSL_CNF=$(openssl version -d | awk '"'"'{gsub("\\"", "", $2); print $2 "/openssl.cnf"}'"'"')  \n\
      openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \\\n\
          -subj "/C=US/ST=CA/L=San Jose/O=Apigee/CN=*.xip.io" \\\n\
          -extensions SAN \\\n\
          -reqexts SAN \\\n\
          -config <(cat ${OPENSSL_CNF}  <(printf "\\n[SAN]\\nsubjectAltName=DNS:*.xip.io")) \\\n\
          -keyout privkey.pem  -out cert.pem \n\
      cp cert.pem fullchain.pem \n\
    else \n\
      echo "Using provided certificates ..." \n\
    fi \n\
    cd / \n\
     ' > /usr/local/bin/certs-gen.sh && \
     chmod a+x /usr/local/bin/certs-gen.sh && \
     cat /usr/local/bin/certs-gen.sh

# Make drupal active user
USER drupal
WORKDIR /drupal

EXPOSE 80
EXPOSE 443

CMD sudo -E -u root sh -c 'certs-gen.sh' && \
    sudo -E -u root sh -c '\echo "source /drupal/env" >> /etc/apache2/envvars ' && \
    exec sudo -E -u root supervisord -n -c /etc/supervisor/supervisord.conf