FROM php:7-apache
MAINTAINER ShizaCat

#fusiondirectory-smarty3-acl-render,

RUN apt-get -y update && \
    buildDeps=' \
		libarchive-extract-perl \
		libcrypt-cbc-perl \
		libdigest-sha-perl \
		libfile-copy-recursive-perl \
		libnet-ldap-perl \
		libpath-class-perl \
		libterm-readkey-perl \
		libxml-twig-perl \
		gettext \
		# javascript-common \
		# libjs-prototype \
		# libjs-scriptaculous \
		openssl \
 	 	schema2ldif \
 	 	ldap-utils \
		# smarty3 \
		wget \
		locales \
		git \
	' && \
    set -x && \
    apt-get install -y --no-install-recommends $buildDeps && \
	apt-get install -y --no-install-recommends \
	    libmcrypt-dev \
	    libssl-dev \
	    libldap2-dev \
	    libldb-dev \
	    libc-client2007e-dev \
	    libssl-dev \
	    libkrb5-dev \
	    libmagickwand-dev \
	    libgd-dev \
	    python-ldap && \
	docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
	docker-php-ext-configure imap --with-imap-ssl --with-kerberos && \
	docker-php-ext-install \
       gettext \
       mcrypt \
       ldap \
       imap \
       gd && \
    pecl install imagick && \
    docker-php-ext-enable imagick && \
	# pear install Net_IMAP
    rm -r /var/lib/apt/lists/*

RUN mkdir -p /var/www/fusiondirectory && \
    mkdir -p /var/spool/fusiondirectory && \
    mkdir -p /var/cache/fusiondirectory && \
    mkdir -p /etc/fusiondirectory

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN echo "TLS_REQCERT    never" >> /etc/ldap/ldap.conf

# install smarty3
RUN cd /tmp && \
	wget https://github.com/smarty-php/smarty/archive/v3.1.29.tar.gz -O smarty.tar.gz && \
	tar -xzf smarty.tar.gz && \
	mkdir -p /usr/share/php/smarty3 && \
	mv smarty-3.1.29/libs/* /usr/share/php/smarty3 && \
	rm -rf smarty-3.1.29 && \
	rm smarty.tar.gz

# install smarty3 gettext
RUN cd /tmp && \
	wget https://github.com/smarty-gettext/smarty-gettext/archive/1.3.0.tar.gz -O smarty-gettext.tar.gz && \
	tar -xzf smarty-gettext.tar.gz && \
	mv smarty-gettext-1.3.0/block.t.php /usr/share/php/smarty3/plugins/ && \
	mv smarty-gettext-1.3.0/function.locale.php /usr/share/php/smarty3/plugins/ && \
	rm -rf smarty-gettext-1.3.0/ && \
	rm smarty-gettext.tar.gz

# install and setup fusiondirectory
# RUN	shopt -s dotglob && \
# 	cd /tmp && \
# 	git clone https://github.com/fusiondirectory/fusiondirectory.git && \
# 	cd fusiondirectory && \
# 	git checkout 1.0.13-fixes && \
# 	rm -rf .git .gitignore && \
# 	cd /tmp && \
# 	mv /tmp/fusiondirectory /var/www/ && \
# 	chown -R www-data:www-data /var/www/fusiondirectory/  && \
#     chmod +x /var/www/fusiondirectory/contrib/bin/*

RUN wget http://repos.fusiondirectory.org/sources/1.0/fusiondirectory/fusiondirectory-1.0.15.tar.gz -O - | tar -xz -C /var/www/fusiondirectory && \
	shopt -s dotglob && \
	mv /var/www/fusiondirectory/fusiondirectory-1.0.15/* /var/www/fusiondirectory && \
	rmdir /var/www/fusiondirectory/fusiondirectory-1.0.15 && \
	chown -R www-data:www-data /var/www/fusiondirectory/ && \
	chmod +x /var/www/fusiondirectory/contrib/bin/*

RUN chmod 750 /var/www/fusiondirectory/contrib/bin/* && \
	mv /var/www/fusiondirectory/contrib/bin/* /usr/local/bin/ && \
	mkdir /usr/local/man/man1 && \
	mkdir /usr/local/man/man5 && \
	cd /var/www/fusiondirectory/ && \
	gzip contrib/man/fusiondirectory.conf.5 && \
	gzip contrib/man/fusiondirectory-setup.1 && \
	gzip contrib/man/fusiondirectory-insert-schema.1 && \
	mv contrib/man/fusiondirectory-setup.1.gz /usr/local/man/man1 && \
	mv contrib/man/fusiondirectory-insert-schema.1.gz /usr/local/man/man1/ && \
	mv contrib/man/fusiondirectory.conf.5.gz /usr/local/man/man5 && \
	ln -s /var/www/fusiondirectory/contrib/smarty/plugins/block.render.php /usr/share/php/smarty3/plugins/block.render.php && \
	ln -s /var/www/fusiondirectory/contrib/smarty/plugins/function.filePath.php /usr/share/php/smarty3/plugins/function.filePath.php && \
	ln -s /var/www/fusiondirectory/contrib/smarty/plugins/function.iconPath.php /usr/share/php/smarty3/plugins/function.iconPath.php && \
	ln -s /var/www/fusiondirectory/contrib/smarty/plugins/function.msgPool.php /usr/share/php/smarty3/plugins/function.msgPool.php && \
	#rm -f /var/www/fusiondirectory/include/class_databaseManagement.inc && \
	mkdir -p /etc/ldap/schema/fusiondirectory && \
	cp /var/www/fusiondirectory/contrib/openldap/*.schema /etc/ldap/schema/fusiondirectory && \
	fusiondirectory-setup --yes --check-directories --update-cache --update-locales && \
	cd /var/www/fusiondirectory/ && \
	cp contrib/fusiondirectory.conf /var/cache/fusiondirectory/template/

# install plugins fusiondirectory
# RUN wget http://integration.opensides.be/repos/fixes-releases/sources/fusiondirectory-plugins-1.0.12.tar.gz -O - | \
RUN wget http://repos.fusiondirectory.org/sources/1.0/fusiondirectory/fusiondirectory-plugins-1.0.15.tar.gz -O - | \
		tar -xz -C / && \
	mv /fusiondirectory-plugins-1.0.15 /fusiondirectory-plugins && \
	chown www-data:www-data -R /fusiondirectory-plugins

# install javascript librarys
RUN cd /tmp && \
	wget https://github.com/madrobby/scriptaculous/archive/v1.9.0.tar.gz -O 1.9.0.tar.gz && \
	tar -xzf 1.9.0.tar.gz && \
	mv scriptaculous-1.9.0/src/* /var/www/fusiondirectory/html/include/ && \
	mv scriptaculous-1.9.0/lib/* /var/www/fusiondirectory/html/include/ && \
	rm 1.9.0.tar.gz && \
	rm -rf scriptaculous-1.9.0/

# setup apache2
RUN rm -rf /etc/apache2/sites-enabled/*
COPY conf/default.conf /etc/apache2/sites-enabled/default.conf
# RUN ln -s /var/www/fusiondirectory/contrib/apache/fusiondirectory-apache.conf /etc/apache2/sites-enabled/fusiondirectory-apache.conf

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8 
ENV LC_ALL C.UTF-8

COPY ./scripts/plugin_install.sh /usr/bin/
COPY ./scripts/fusiondirectory-schema.py /usr/bin/

WORKDIR /var/www/fusiondirectory/

EXPOSE 80
CMD ["plugin_install.sh"]
