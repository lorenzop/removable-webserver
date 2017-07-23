#!/bin/bash


PHP_VERSION='7.1.7'
PMA_VERSION='4.7.2'
NGINX_VERSION='1.13.3'
MYSQL_VERSION='10.2'


##################################################
clear


export CWD=`\pwd`
export PATH_BUILD_TEMP="$CWD/build-temp"
export TEMP_PATH="$CWD/temp"

export CORES=`cat /proc/cpuinfo | grep processor | wc -l`
#export CORES='3'

export MKDIR_CMD=`which mkdir`
export SED_CMD=`which sed`


function INSTALL_REQUIRED_PACKAGES () {
	# find package manager
	YUM_CMD=`\which dnf 2>/dev/null`
	if [ -z $YUM_CMD ]; then
		YUM_CMD=`\which yum`
	fi
	if [ -z $YUM_CMD ]; then
		echo "Failed to find yum or dnf!"
		exit 1
	fi

	# get installed packages
	RPM_LIST_INSTALLED=`\rpm -qa`

	# find missing packages
	PACKAGES_MISSING=''
#	for ENTRY in $REQUIRED_PACKAGES; do
	while [[ $# -ge 1 ]]; do
		ENTRY="$1"
		shift
		if [[ ! -z $ENTRY ]]; then
			if [[ $RPM_LIST_INSTALLED != *"$ENTRY"* ]]; then
				PACKAGES_MISSING="$PACKAGES_MISSING $ENTRY "
			fi
		fi
	done

	# install missing packages
	if [[ ! -z $PACKAGES_MISSING ]]; then
		echo -ne " [[ Installing required packages.. ]] \n\n"
		# install epel repo
		eval `\cat /etc/os-release | \grep ^ID=`
		if [[ $ID == "centos" ]]; then
			if [[ ! -e /etc/yum.repos.d/epel.repo ]]; then
				sudo $YUM_CMD install https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm || exit 1
				echo
				sudo $YUM_CMD update epel-release || exit 1
				echo;echo
			fi
		fi
		echo;echo
		echo -ne "Required packages:\n"
		echo -ne " $PACKAGES_MISSING\n\n"
		echo -ne "Type your password to install:\n\n"
		sudo $YUM_CMD install $PACKAGES_MISSING || exit 1
		echo
		sudo $YUM_CMD groupinstall Development\ Tools || exit 1
		echo;echo
	fi

	# double check packages exist
	RPM_LIST_INSTALLED=`\rpm -qa`
	PACKAGES_MISSING=''
	for ENTRY in $REQUIRED_PACKAGES; do
		if [[ $RPM_LIST_INSTALLED != *"$ENTRY"* ]]; then
			PACKAGES_MISSING="$PACKAGES_MISSING $ENTRY "
		fi
	done
	if [[ ! -z $PACKAGES_MISSING ]]; then
		echo -ne "\n\nFailed to install required packages:\n$PACKAGES_MISSING\n\n";
		exit 1
	fi
	echo;echo
}


# clone sources
function CLONE_SOURCE() {
	USER="$1"
	NAME="$2"
	TAG="$3"
	DIR="$4"
	IS_BRANCH="$5"
	if [[ -z $DIR ]]; then
		DIR="${NAME}.git"
	fi
	if [[ -e "$PATH_BUILD_TEMP/${DIR}/" ]]; then
		echo -ne " [[ Updating $DIR sources.. ]] \n\n"
		pushd "$PATH_BUILD_TEMP/${DIR}/" || exit 1
			echo "Fetch and Checkout: $TAG"
			if [[ ! -z $IS_BRANCH ]]; then
				\git fetch    \
					--depth 1 \
					origin    \
					"$TAG"    \
						|| exit 1
			else
				\git fetch    \
					--depth 1 \
					origin    \
					"refs/tags/${TAG}":"refs/tags/${TAG}" \
						|| exit 1
			fi
			\git checkout "$TAG" || exit 1
		popd
	else
		echo -ne " [[ Getting $DIR sources.. ]] \n\n"
		pushd "$PATH_BUILD_TEMP/" || exit 1
			echo "Clone: $TAG"
			\git clone                               \
				-b "$TAG"                            \
				--depth 1                            \
				https://github.com/$USER/${NAME}.git \
				"$DIR"                               \
					|| exit 1
		popd
	fi
	# workspace cleanup
	pushd "$PATH_BUILD_TEMP/${DIR}/" || exit 1
		\git reset --hard   || exit 1
		\git clean -d -x -f || exit 1
	popd
	echo;echo
}


function GENERATE_CONFIGS() {
	NAME="$1"
	WEBPATH="$2"
	if [ -z $WEBPATH ]; then
		WEBPATH="$CWD/$NAME/"
	fi
	WEBPATH="${WEBPATH/\<CWD\>/$CWD}"
	echo "Creating configs for: $NAME"
	if [[ ! -e "$WEBPATH" ]]; then
		$MKDIR_CMD -pv "$WEBPATH" || exit 1
	fi
	# php-fpm.d
	if [[ -d "$CWD/conf/php-fpm.d/" ]]; then
		$SED_CMD \
			's|<PATH>|'"$WEBPATH"'|' \
			"$CWD/templates/php-fpm.d_website.conf.original" > \
			"$CWD/conf/php-fpm.d/$NAME.conf" \
				|| exit 1
		$SED_CMD -i \
			's|<NAME>|'"$NAME"'|' \
			"$CWD/conf/php-fpm.d/$NAME.conf" \
				|| exit 1
		$SED_CMD -i \
			's|<CWD>|'"$CWD"'|' \
			"$CWD/conf/php-fpm.d/$NAME.conf" \
				|| exit 1
	fi
	# mysql/mariadb
	# nginx.d
	if [[ -d "$CWD/conf/nginx.d" ]]; then
		$SED_CMD \
			's|<PATH>|'"$WEBPATH"'|' \
			"$CWD/templates/nginx.d_website.conf.original" > \
			"$CWD/conf/nginx.d/$NAME.conf" \
				|| exit 1
		$SED_CMD -i \
			's|<NAME>|'"$NAME"'|' \
			"$CWD/conf/nginx.d/$NAME.conf" \
				|| exit 1
		$SED_CMD -i \
			's|<CWD>|'"$CWD"'|' \
			"$CWD/conf/nginx.d/$NAME.conf" \
				|| exit 1
	fi
	echo
}


# parse arguments
while [[ $# -ge 1 ]]; do
	key="$1"
	case "$key" in
		clean|clear)
			shift
			DO_CLEAN=1
		;;
		all)
			shift
			DO_BUILD_PHP=1
			DO_BUILD_PHPMYADMIN=1
			DO_BUILD_MYSQL=1
			DO_BUILD_NGINX=1
		;;
		cnf|conf|config|configs|configure|configuration)
			shift
			DO_GEN_CONFIGS=1
		;;
		php)
			shift
			DO_BUILD_PHP=1
		;;
		pma|phpma|phpmyadmin|phpMyAdmin)
			shift
			DO_BUILD_PHPMYADMIN=1
		;;
		db|DB|mariadb|MariaDB|mysql|MySQL|sql|SQL)
			shift
			DO_BUILD_MYSQL=1
		;;
		nginx)
			shift
			DO_BUILD_NGINX=1
		;;
		*)
			echo -ne "\n\nUnknown argument: $key\n\n"
			exit 1
		;;
	esac
done


if [[ ! -z $DO_CLEAN ]]; then
	echo -ne " [[ Removing directories.. ]] \n\n"
	if [ -d "$CWD/sockets" ]; then
		rm -Rvf --preserve-root "$CWD/sockets" || exit 1
	fi
	if [ -d "$CWD/pids" ]; then
		rm -Rvf --preserve-root "$CWD/pids" || exit 1
	fi
	if [ -d "$CWD/logs" ]; then
		rm -Rvf --preserve-root "$CWD/logs" || exit 1
	fi
	if [ -d "$CWD/temp" ]; then
		rm -Rvf --preserve-root "$CWD/temp" || exit 1
	fi
	echo;echo
	echo -ne " [[ Removing symlinks.. ]] \n\n"
	if [ -h "$CWD/php" ]; then
		rm -vf --preserve-root "$CWD/php" || exit 1
	fi
	if [ -h "$CWD/php-fpm" ]; then
		rm -vf --preserve-root "$CWD/php-fpm" || exit 1
	fi
	if [ -h "$CWD/phpdbg" ]; then
		rm -vf --preserve-root "$CWD/phpdbg" || exit 1
	fi
	if [ -h "$CWD/phpMyAdmin" ]; then
		rm -vf --preserve-root "$CWD/phpMyAdmin" || exit 1
	fi
	if [ -h "$CWD/nginx" ]; then
		rm -vf --preserve-root "$CWD/nginx" || exit 1
	fi
	if [ -h "$CWD/mysql" ]; then
		rm -vf --preserve-root "$CWD/mysql" || exit 1
	fi
	if [ -h "$CWD/mysqldump" ]; then
		rm -vf --preserve-root "$CWD/mysqldump" || exit 1
	fi
	if [ -h "$CWD/mysqldumpslow" ]; then
		rm -vf --preserve-root "$CWD/mysqldumpslow" || exit 1
	fi
	if [ -h "$CWD/mysqlimport" ]; then
		rm -vf --preserve-root "$CWD/mysqlimport" || exit 1
	fi
	if [ -h "$CWD/mysqlshow" ]; then
		rm -vf --preserve-root "$CWD/mysqlshow" || exit 1
	fi
	if [ -h "$CWD/mytop" ]; then
		rm -vf --preserve-root "$CWD/mytop" || exit 1
	fi
	echo;echo
	echo -ne " [[ Removing configs.. ]] \n\n"
	if [ -f "$CWD/php-removable.sh" ]; then
		rm -vf --preserve-root "$CWD/php-removable.sh" || exit 1
	fi
	if [ -f "$CWD/conf/php-fpm.conf" ]; then
		rm -vf --preserve-root "$CWD/conf/php-fpm.conf" || exit 1
	fi
	if [ -f "$CWD/conf/mariadb.conf" ]; then
		rm -vf --preserve-root "$CWD/conf/mariadb.conf" || exit 1
	fi
	if [ -f "$CWD/conf/nginx.conf" ]; then
		rm -vf --preserve-root "$CWD/conf/nginx.conf" || exit 1
	fi
	echo;echo
	echo -ne " [[ Removing build-temp.. ]] \n\n"
	if [ -d "$CWD/build-temp" ]; then
		rm -Rvf --preserve-root "$CWD/build-temp" || exit 1
	fi
	if [ -d "$CWD/mariadb" ]; then
		rm -Rvf --preserve-root "$CWD/mariadb" || exit 1
	fi
	echo;echo
fi


# build php
if [[ ! -z $DO_BUILD_PHP ]] || [[ ! -z $DO_GEN_CONFIGS ]]; then
	# install profile.d script
	echo -ne " [[ Installing php-removable.sh ]] \n\n"
	if [[ -e "$CWD/php-removable.sh" ]]; then
		\rm -f --preserve-root "$CWD/php-removable.sh"
	fi
	$SED_CMD \
		's|<CWD>|'`pwd`'|' \
		"$CWD/templates/php-removable.sh.original" > \
		"$CWD/php-removable.sh" \
			|| exit 1
	echo "Created: php-removable.sh"
	echo "Installing php-removable.sh"
	echo "Password may be needed here:"
	echo
	sudo \mv -fv \
		"$CWD/php-removable.sh"\
		"/etc/profile.d/" \
			|| exit 1
	sudo chown -c root:root "/etc/profile.d/php-removable.sh" || exit 1
	sudo chmod -c +x        "/etc/profile.d/php-removable.sh" || exit 1
	echo;echo
fi
if [[ ! -z $DO_BUILD_PHP ]]; then
	if [ -z $PHP_VERSION ]; then
		echo "PHP Version is required!"
		exit 1
	fi
	# install packages
	INSTALL_REQUIRED_PACKAGES \
		git                 \
		gcc                 \
		gcc-c++             \
		bison               \
		re2c                \
		pkgconfig           \
		php-pecl-xdebug     \
		autoconf            \
		openssl-devel       \
		curl                \
		curl-devel          \
		libcurl             \
		libcurl-devel       \
		libc-client         \
		uw-imap-devel       \
		libpng-devel        \
		libjpeg-turbo-devel \
		freetype-devel      \
		aspell-devel        \
		aspell-en           \
		recode-devel        \
		libicu-devel        \
		gmp-devel           \
		libmcrypt-devel     \
		libxml2-devel       \
		libtidy-devel       \
		bzip2-devel
#mariadb-devel
	echo -ne "\n [[ Building PHP.. ]] \n\n"
	# create directories
	$MKDIR_CMD -pv "$PATH_BUILD_TEMP"     || exit 1
	$MKDIR_CMD -pv "$CWD/conf/php-fpm.d/" || exit 1
	$MKDIR_CMD -pv "$CWD/sockets/"        || exit 1
	$MKDIR_CMD -pv "$CWD/pids/"           || exit 1
	echo;echo
	# get source code
	CLONE_SOURCE \
		php      \
		php-src  \
		"php-$PHP_VERSION"
	echo;echo
	# compile
	pushd "$PATH_BUILD_TEMP/php-src.git/" || exit 1
		echo -ne " [[ Preparing build.. ]] \n\n"
		./buildconf --force || exit 1
		echo;echo
		./configure \
			--prefix="$CWD/"           \
			--bindir="$CWD/"           \
			--sbindir="$CWD/"          \
			--sysconfdir="$CWD/conf/"  \
			--libdir=/usr/lib64/       \
			--with-config-file-path="$CWD/conf/"            \
			--with-config-file-scan-dir="$CWD/conf/php-fpm.d/"  \
			--enable-fpm               \
			--disable-cgi              \
			--disable-rpath            \
			--with-openssl             \
			--enable-sockets           \
			--disable-ipv6             \
			--disable-short-tags       \
			--enable-opcache           \
			--enable-debug             \
			--enable-phpdbg            \
			--enable-phpdbg-webhelper  \
			--with-gd                  \
			--enable-gd-native-ttf     \
			--with-freetype-dir        \
			--with-jpeg-dir            \
			--with-png-dir             \
			--enable-mysqlnd           \
			--with-mysqli=mysqlnd      \
			--with-pdo-mysql=mysqlnd   \
			--with-pdo-sqlite          \
			--with-sqlite3             \
			--with-kerberos            \
			--with-mhash               \
			--with-mcrypt              \
			--with-xmlrpc              \
			--enable-simplexml         \
			--enable-xml               \
			--enable-xmlreader         \
			--enable-xmlwriter         \
			--enable-dom               \
			--enable-fileinfo          \
			--enable-bcmath            \
			--with-bz2                 \
			--with-curl                \
			--enable-filter            \
			--enable-json              \
			--enable-mbstring          \
			--enable-phar              \
			--enable-zip               \
			--with-zlib                \
				|| exit 1
#--with-mysql-sock="$CWD/socks/mysql.sock"
#--enable-intl
#--with-tidy
#--with-fpm-user=lop
#--with-fpm-group=lop
		echo;echo
		echo -ne " [[ Compiling.. ]] \n\n"
		\make -j "$CORES" || exit 1
	popd
	echo;echo
	# create symlinks
	echo -ne " [[ Creating symlinks.. ]] \n\n"
	\ln -svf "$PATH_BUILD_TEMP/php-src.git/sapi/cli/php" \
		"$CWD/php" || exit 1
	\ln -svf "$PATH_BUILD_TEMP/php-src.git/sapi/fpm/php-fpm" \
		"$CWD/php-fpm" || exit 1
	\ln -svf "$PATH_BUILD_TEMP/php-src.git/sapi/phpdbg/phpdbg" \
		"$CWD/phpdbg" || exit 1
	echo;echo
fi
# php configs
if [[ ! -z $DO_BUILD_PHP ]] || [[ ! -z $DO_GEN_CONFIGS ]]; then
	echo -ne " [[ Configuring php.. ]] \n\n"
	$MKDIR_CMD -pv "$CWD/conf/php-fpm.d/" || exit 1
	$SED_CMD \
		's|<CWD>|'`pwd`'|' \
		"$CWD/templates/php-fpm.conf.original" > \
		"$CWD/conf/php-fpm.conf" \
			|| exit 1
	echo "Created: php-fpm.conf"
	\cp -vf \
		"$CWD/templates/php.ini" \
		"$CWD/conf/" \
			|| exit 1
	echo;echo
	# update composer
	if [[ -e /usr/bin/composer ]]; then
		echo -ne " [[ Updating composer.. ]] \n\n"
		sudo "$CWD/php" /usr/bin/composer self-update \
			|| exit 1
		echo;echo
	fi
fi


# build phpMyAdmin
if [[ ! -z $DO_BUILD_PHPMYADMIN ]]; then
	if [ -z $PMA_VERSION ]; then
		echo "phpMyAdmin Version is required!"
		exit 1
	fi
	echo -ne "\n [[ Building phpMyAdmin.. ]] \n\n"
	# create directories
	$MKDIR_CMD -pv "$PATH_BUILD_TEMP" || exit 1
	echo;echo
	# cleanup
	if [[ -e "$PATH_BUILD_TEMP/phpMyAdmin-${PMA_VERSION}-all-languages/" ]]; then
		pushd "$PATH_BUILD_TEMP" || exit 1
			\rm -Rvf --preserve-root "phpMyAdmin-${PMA_VERSION}-all-languages/"
		popd
		echo;echo
	fi
	# download phpMyAdmin..zip
	if [[ ! -e "$PATH_BUILD_TEMP/phpMyAdmin-${PMA_VERSION}-all-languages.zip" ]]; then
		echo -ne " [[ Downloading zip.. ]] \n\n"
		\wget "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.zip" \
			-O "$PATH_BUILD_TEMP/phpMyAdmin-${PMA_VERSION}-all-languages.zip" \
			--show-progress  \
			--tries=3        \
				|| exit 1
		echo;echo
	fi
	# extract zip files
	echo -ne " [[ Extracting files.. ]] \n\n"
	pushd "$PATH_BUILD_TEMP" || exit 1
		\unzip "$PATH_BUILD_TEMP/phpMyAdmin-${PMA_VERSION}-all-languages.zip" \
			|| exit 1
		echo;echo
	popd
	echo;echo
	# create symlinks
	echo -ne " [[ Creating symlinks.. ]] \n\n"
	\ln -svf "$PATH_BUILD_TEMP/phpMyAdmin-${PMA_VERSION}-all-languages/" \
		"$CWD/phpMyAdmin" || exit 1
	echo;echo
fi
# phpMyAdmin configs
if [[ ! -z $DO_BUILD_PHPMYADMIN ]] || [[ ! -z $DO_GEN_CONFIGS ]]; then
	if [[ -e "$CWD/phpMyAdmin/" ]]; then
		echo -ne " [[ Configuring phpMyAdmin.. ]] \n\n"
		\cp -vf \
			"$CWD/templates/pma-config.inc.php" \
			"$CWD/phpMyAdmin/config.inc.php" \
				|| exit 1
		echo;echo
	fi
fi


# build mysql/mariadb
if [[ ! -z $DO_BUILD_MYSQL ]]; then
	if [ -z $MYSQL_VERSION ]; then
		echo "MySQL/MariaDB Version is required!"
		exit 1
	fi
	# install packages
	INSTALL_REQUIRED_PACKAGES \
		git      \
		gcc      \
		gcc-c++  \
		autoconf \
		cmake    \
		ncurses-devel \
		openssl-devel
	echo -ne "\n [[ Building MySQL/MariaDB.. ]] \n\n"
	# create directories
	$MKDIR_CMD -pv "$PATH_BUILD_TEMP" || exit 1
	$MKDIR_CMD -pv "$CWD/mariadb/"    || exit 1
	$MKDIR_CMD -pv "$CWD/conf/my.cnf.d/" || exit 1
	$MKDIR_CMD -pv "$CWD/sockets/"    || exit 1
	$MKDIR_CMD -pv "$CWD/logs/"       || exit 1
	$MKDIR_CMD -pv "$CWD/pids/"       || exit 1
	$MKDIR_CMD -pv "$CWD/mysql-data/" || exit 1
	echo;echo
	# get source code
	CLONE_SOURCE \
		MariaDB  \
		server   \
		"$MYSQL_VERSION" \
		"mariadb.git" \
		"branch"
	echo;echo
	# compile
	pushd "$PATH_BUILD_TEMP/mariadb.git/" || exit 1
		\mkdir -pv "output/" || exit 1
		pushd "output/" || exit 1
			echo -ne " [[ Preparing build.. ]] \n\n"
			cmake ../ \
				-DCMAKE_INSTALL_PREFIX="$CWD/mariadb/" \
				-DMYSQL_DATADIR="$CWD/mysql-data/"     \
				-DSYSCONFDIR="$CWD/conf/"              \
				-DDTMPDIR="$TEMP_PATH"                 \
				-DWITH_SSL=yes                         \
					|| exit 1
			echo;echo
		echo -ne " [[ Compiling.. ]] \n\n"
		make -j "$CORES"         || exit 1
		make -j "$CORES" install || exit 1
	popd
	echo;echo
	# create symlinks
	echo -ne " [[ Creating symlinks.. ]] \n\n"
	\ln -svf "$CWD/mariadb/bin/mysql" \
		"$CWD/mysql" || exit 1
#	\ln -svf "$CWD/mariadb/bin/mysqld" \
#		"$CWD/mysqld" || exit 1
#	\ln -svf "$CWD/mariadb/bin/mysqld_safe" \
#		"$CWD/mysqld_safe" || exit 1
	\ln -svf "$CWD/mariadb/bin/mysqldump" \
		"$CWD/mysqldump" || exit 1
	\ln -svf "$CWD/mariadb/bin/mysqldumpslow" \
		"$CWD/mysqldumpslow" || exit 1
	\ln -svf "$CWD/mariadb/bin/mysqlimport" \
		"$CWD/mysqlimport" || exit 1
	\ln -svf "$CWD/mariadb/bin/mysqlshow" \
		"$CWD/mysqlshow" || exit 1
	\ln -svf "$CWD/mariadb/bin/mytop" \
		"$CWD/mytop" || exit 1
	echo;echo
fi
# mysql/mariadb configs
if [[ ! -z $DO_BUILD_MYSQL ]] || [[ ! -z $DO_GEN_CONFIGS ]]; then
	echo -ne " [[ Configuring MySQL/MariaDB.. ]] \n\n"
	$MKDIR_CMD -pv "$CWD/conf/my.cnf.d/" || exit 1
	$SED_CMD \
		's|<CWD>|'`pwd`'|' \
		"$CWD/templates/my.cnf.original" > \
		"$CWD/conf/my.cnf" \
			|| exit 1
	echo "Created: my.cnf"
#	\cp -vf \
#		"$CWD/templates/mysql-clients.cnf.original" \
#		"$CWD/conf/my.cnf.d/mysql-clients.cnf" \
#			|| exit 1
#	\cp -vf \
#		"$CWD/templates/client.cnf.original" \
#		"$CWD/conf/my.cnf.d/client.cnf" \
#			|| exit 1
#	\cp -vf \
#		"$CWD/templates/enable_encryption.preset.original" \
#		"$CWD/conf/my.cnf.d/enable_encryption.preset" \
#			|| exit 1
	echo;echo
fi


# build nginx
if [[ ! -z $DO_BUILD_NGINX ]]; then
	if [ -z $NGINX_VERSION ]; then
		echo "Nginx Version is required!"
		exit 1
	fi
	# install packages
	INSTALL_REQUIRED_PACKAGES \
		git      \
		gcc      \
		gcc-c++  \
		autoconf \
		openssl-devel
	echo -ne "\n [[ Building Nginx.. ]] \n\n"
	# create directories
	$MKDIR_CMD -pv "$PATH_BUILD_TEMP"               || exit 1
	$MKDIR_CMD -pv "$CWD/conf/nginx.d/"             || exit 1
	$MKDIR_CMD -pv "$CWD/sockets/"                  || exit 1
	$MKDIR_CMD -pv "$CWD/logs/"                     || exit 1
	$MKDIR_CMD -pv "$CWD/pids/"                     || exit 1
	$MKDIR_CMD -pv "$TEMP_PATH/nginx/client_temp/"  || exit 1
	$MKDIR_CMD -pv "$TEMP_PATH/nginx/proxy_temp/"   || exit 1
	$MKDIR_CMD -pv "$TEMP_PATH/nginx/fastcgi_temp/" || exit 1
	$MKDIR_CMD -pv "$TEMP_PATH/nginx/uwsgi_temp/"   || exit 1
	$MKDIR_CMD -pv "$TEMP_PATH/nginx/scgi_temp/"    || exit 1
	echo;echo
	# get source code
	CLONE_SOURCE \
		nginx \
		nginx \
		"release-$NGINX_VERSION"
	echo;echo
	# compile
	pushd "$PATH_BUILD_TEMP/nginx.git/" || exit 1
		echo -ne " [[ Preparing build.. ]] \n\n"
		./auto/configure \
			--prefix="$CWD/"                                             \
			--error-log-path="$CWD/logs/nginx-error.log"                 \
			--http-log-path="$CWD/logs/nginx-access.log"                 \
			--sbin-path="$CWD/"                                          \
			--conf-path="$CWD/conf/nginx.conf"                           \
			--pid-path="$CWD/pids/nginx.pid"                             \
			--http-client-body-temp-path="$TEMP_PATH/nginx/client_temp/" \
			--http-proxy-temp-path="$TEMP_PATH/nginx/proxy_temp/"        \
			--http-fastcgi-temp-path="$TEMP_PATH/nginx/fastcgi_temp/"    \
			--http-uwsgi-temp-path="$TEMP_PATH/nginx/uwsgi_temp/"        \
			--http-scgi-temp-path="$TEMP_PATH/nginx/scgi_temp/"          \
				|| exit 1
# --without-http_rewrite_module
# --without-http_gzip_module
		echo;echo
		echo -ne " [[ Compiling.. ]] \n\n"
		make -j "$CORES" || exit 1
	popd
	echo;echo
	# create symlinks
	echo -ne " [[ Creating symlinks.. ]] \n\n"
	\ln -svf "$PATH_BUILD_TEMP/nginx.git/objs/nginx" \
		"$CWD/nginx" || exit 1
	echo;echo
fi
# nginx configs
if [[ ! -z $DO_BUILD_NGINX ]] || [[ ! -z $DO_GEN_CONFIGS ]]; then
	echo -ne " [[ Configuring nginx.. ]] \n\n"
	$MKDIR_CMD -pv "$CWD/conf/nginx.d/" || exit 1
	$SED_CMD \
		's|<CWD>|'`pwd`'|' \
		"$CWD/templates/nginx.conf.original" > \
		"$CWD/conf/nginx.conf" \
			|| exit 1
	echo "Created: nginx.conf"
	\cp -vf \
		"$CWD/templates/nginx-mime.types" \
		"$CWD/conf/" \
			|| exit 1
	echo "Created: nginx-mime.types"
	echo;echo
fi


# website configs
if [[ ! -z $DO_BUILD_NGINX ]] || [[ ! -z $DO_BUILD_PHP ]] || [[ ! -z $DO_BUILD_MYSQL ]] || [[ ! -z $DO_GEN_CONFIGS ]]; then
	if [[ ! -e "$CWD/websites.conf" ]]; then
		echo;echo
		echo "website.conf file not found!"
		echo;echo
		exit 1
	fi
	echo -ne " [[ Configuring websites.. ]] \n\n"
	source "$CWD/websites.conf"
	echo;echo
fi


echo;echo
echo " [[ Finished! ]] "
echo;echo
exit 0

