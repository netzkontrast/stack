#!/usr/bin/env bash

set -e
cat <<EOF > foo
Host *
  IdentityFile ~/.ssh/key.pem
  User ubuntu
EOF


DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:ondrej/php
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get -y install curl git php7.1-cli php7.1-dev php7.1-mbstring php7.1-xml php-mongodb php7.1-zip php-ssh2 php-xdebug
DEBIAN_FRONTEND=noninteractive apt-get -y install php-memcached php-memcache php-imagick php-gettext php-apcu php-mysql unzip php7.1-curl
