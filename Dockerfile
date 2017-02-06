FROM php:7-apache

MAINTAINER Pha Vo <phavo@minhhungland.vn>

# Ensure UTF-8
RUN apt-get clean && apt-get -y update && apt-get -y install apt-utils &&\
    apt-get -y update && \
    apt-get -y install locales && \
    dpkg-reconfigure locales && \
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen en_US.UTF-8

ENV LANGUAGE   en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

ENV HOME /root

ENV DEBIAN_FRONTEND noninteractive

RUN echo "Asia/Ho_Chi_Minh" > /etc/timezone \
    dpkg-reconfigure -f noninteractive tzdata
# Install apache, and supplimentary programs. curl and lynx-cur are for debugging the container.
RUN apt-get -y upgrade && \
    apt-get -y install libmcrypt-dev mcrypt libcurl3 lynx-cur python-setuptools python-pip supervisor collectd && \
    docker-php-ext-install -j$(nproc) mcrypt  curl gd intl tidy \
    bz2 mbstring gettext zip  mysqli pdo pdo_mysql shmop && \
    pecl install imagick && \
    docker-php-ext-enable imagick && \
    docker-php-ext-enable rewrite && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    rm -r /var/lib/apt/lists/*
    #&& apk del autoconf g++ libtool make \
    #&& rm -rf /tmp/* /var/cache/apk/*

#RUN for i in /etc/php/7.0/mods-available/*.ini;do phpenmod $(basename $i .ini); done

# Enable mod_expires
RUN cp /etc/apache2/mods-available/expires.load /etc/apache2/mods-enabled/
ADD docker/apache-config.conf /etc/apache2/sites-enabled/000-default.conf
ENV APACHE_LOG_DIR /var/log/apache2

#remove default html folder
RUN rm -r /var/www/html
# Copy source directory to default apache root directory
ADD ./docker/www /var/www/web
RUN service apache2 restart && \
    sed -ie 's/memory_limit\ =\ 128M/memory_limit\ =\ 2G/g' /etc/php/7.0/apache2/php.ini && \
	sed -ie 's/\;date\.timezone\ =/date\.timezone\ =\ Asia\/Ho_Chi_Minh/g' /etc/php/7.0/apache2/php.ini && \
	sed -ie 's/upload_max_filesize\ =\ 2M/upload_max_filesize\ =\ 200M/g' /etc/php/7.0/apache2/php.ini && \
	sed -ie 's/post_max_size\ =\ 8M/post_max_size\ =\ 200M/g' /etc/php/7.0/apache2/php.ini && \
	sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php/7.0/apache2/php.ini && \
	sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /etc/php/7.0/apache2/php.ini

# Manually set up the apache environment variables
ENV "APACHE_RUN_USER"="www-data" "APACHE_RUN_GROUP"="www-data" \
	"APACHE_LOG_DIR"="/var/log/apache2" "APACHE_LOCK_DIR"="/var/lock/apache2" \
	"APACHE_PID_FILE"="/var/run/apache2.pid"

EXPOSE 80

ADD docker/supervisord.conf /etc/supervisord.conf
ADD	docker/collectd-config.conf.tpl /etc/collectd/configs/collectd-config.conf.tpl
RUN pip install --upgrade pip && pip install envtpl

RUN mkdir /etc/service/myservice
ADD docker/start.sh /etc/service/myservice/run
ADD docker/foreground.sh /etc/apache2/foreground.sh
RUN chmod +x /etc/service/myservice/run && \
	chmod +x /etc/apache2/foreground.sh

