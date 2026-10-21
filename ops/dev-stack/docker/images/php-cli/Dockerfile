FROM node:22.22.2-bookworm-slim@sha256:9f6d5975c7dca860947d3915877f85607946403fc55349f39b4bc3688448bb6e AS node

FROM ubuntu:22.04@sha256:b8b6ee6aa931ecd9d0d952abc34dc0e5f7c6a30c6bb71b079fe399fde0329c02


WORKDIR /var/www/html

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
# Fingerprint of the signing key for the third-party PHP package archive; the download is verified against it.
ARG PHP_PPA_KEY_FINGERPRINT=14AA40EC0831756756D7F66C4F4EA0AAE5267A6C


RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 \
        libcap2-bin libpng-dev libonig-dev libxml2-dev \
    && mkdir -p ~/.gnupg \
    && chmod 600 ~/.gnupg \
    && curl -fsSL -o /tmp/php-ppa.asc "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${PHP_PPA_KEY_FINGERPRINT}" \
    && gpg --batch --with-colons --show-keys /tmp/php-ppa.asc | grep -q "^fpr:::::::::${PHP_PPA_KEY_FINGERPRINT}:" \
    && gpg --batch --dearmor --yes --output /usr/share/keyrings/php-ppa.gpg /tmp/php-ppa.asc \
    && echo "deb [signed-by=/usr/share/keyrings/php-ppa.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu jammy main" > /etc/apt/sources.list.d/php-ppa.list \
    && apt-get update \
    && apt-get install -y \
        php8.3-cli php8.3-dev \
        php8.3-sqlite3 php8.3-gd \
        php8.3-curl \
        php8.3-imap php8.3-mysql php8.3-mbstring \
        php8.3-xml php8.3-zip php8.3-bcmath php8.3-soap \
        php8.3-intl php8.3-readline \
        php8.3-ldap \
        php8.3-msgpack php8.3-igbinary php8.3-redis \
        php8.3-memcached php8.3-pcov \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY --from=composer:2@sha256:9715c7f69044da2a212a5fbde29ee7da24e364d426560ae6367b060236f847d7 /usr/bin/composer /usr/bin/composer

EXPOSE 80

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=80"]
