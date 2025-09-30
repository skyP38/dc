FROM alpine:3.22

RUN apk --no-cache --update add \
    tzdata openssl unzip nginx bash ca-certificates s6 curl ssmtp mailx php84 php84-phar php84-curl \
    php84-fpm php84-json php84-zlib php84-xml php84-dom php84-ctype php84-opcache php84-zip php84-iconv \
    php84-pdo php84-pdo_mysql php84-pdo_sqlite php84-pdo_pgsql php84-mbstring php84-session php84-bcmath \
    php84-gd php84-openssl php84-sockets php84-posix php84-ldap php84-simplexml php84-xmlwriter && \
    rm -rf /var/www/localhost && \
    rm -f /etc/php84/php-fpm.d/www.conf && \
    ln -sf /usr/bin/php84 /usr/bin/php

ARG KANBOARD_VERSION=1.2.30
RUN curl -L https://github.com/kanboard/kanboard/archive/v${KANBOARD_VERSION}.tar.gz -o /tmp/kanboard.tar.gz && \
    tar -xzf /tmp/kanboard.tar.gz -C /var/www/app --strip-components=1 && \
    rm /tmp/kanboard.tar.gz && \
    chown -R www:www /var/www/app && \
    chmod -R 755 /var/www/app

CMD ["php84", "-S", "0.0.0.0:8000", "-t", "/var/www/app"]
