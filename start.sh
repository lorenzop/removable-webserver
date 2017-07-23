#!/bin/bash


##################################################
clear


CWD=`\pwd`
TEMP_PATH="$CWD/temp"
USERNAME='lop'


function cleanup_files() {
	echo;echo
	echo " [[ Cleanup.. ]] "
	rm -vf --preserve-root "$CWD/log/*"
	rm -vf --preserve-root "$CWD/sockets/*"
	rm -vf --preserve-root "$CWD/pid/*"
	rm -vf --preserve-root "$TEMP_PATH/client_temp/*"
	rm -vf --preserve-root "$TEMP_PATH/fastcgi_temp/*"
	rm -vf --preserve-root "$TEMP_PATH/proxy_temp/*"
	rm -vf --preserve-root "$TEMP_PATH/scgi_temp/*"
	rm -vf --preserve-root "$TEMP_PATH/uwsgi_temp/*"
	echo;echo
}
function do_stop() {
	echo;echo
	echo " [[ Stopping web server processes.. ]] "
	echo
	if [[ ! -z $MYSQL_PIDF ]]; then
		kill -15 -- "$MYSQL_PIDF"
	fi
	if [[ ! -z $NGINX_PIDF ]]; then
		kill -15 -- "$NGINX_PIDF"
	fi
	if [[ ! -z $PHP_PIDF ]]; then
		kill -15 -- "$PHP_PIDF"
	fi
#	mysqladmin --socket=/mnt/usb16/nginx/sockets/db.sock -u root shutdown
	sleep 0.5
	echo
	while true; do
		JOB_COUNT=`jobs -p | wc -l`
		if [ $JOB_COUNT -eq 0 ]; then
			cleanup_files
			exit 0
		fi
		echo " [[ Waiting for $JOB_COUNT web server processes to stop.. ]] "
		jobs
		echo
		sleep 1
	done
	exit 0
}
trap ctrl_c INT
function ctrl_c() {
	do_stop
}


# start mysqld
echo " [[ Starting MySQL.. ]] "
sleep 1
if [ ! -e "$CWD/mysql-data/" ]; then
	mkdir -pv "$CWD/mysql-data/" || exit 1
fi
export MYSQL_HOME="$CWD/mariadb/bin/"
pushd "$CWD/mariadb/bin/" || exit 1
	./mysqld_safe \
		--skip-syslog                        \
		--bind-address=127.0.0.1             \
		--port=93306                         \
		--socket="$CWD/sockets/mysql.socket" \
		--tmpdir="$TEMP_PATH"                \
		--user="$USERNAME"                   \
		--pid-file="$CWD/pids/mariadb.pid"   \
		--skip-grant-tables                  \
		&
	MYSQL_PID=$!
popd
echo "MySQL PID: $MYSQL_PID"
sleep 0.5
echo;echo


# start php-fpm
echo " [[ Starting php-fpm.. ]] "
sleep 1
#	--nodaemonize
"$CWD/php-fpm" \
	--force-stderr                         \
	--prefix "$CWD/"                       \
	-c "$CWD/conf/php.ini"                 \
	--fpm-config "$CWD/conf/php-fpm.conf"  \
	--pid "$CWD/pids/php-fpm.pid"          \
	|| do_stop &
PHP_PID=$!
echo "Starting PID: $PHP_PID"
sleep 0.5
echo;echo


# start nginx
echo " [[ Starting nginx.. ]] "
sleep 1
"$CWD/nginx" \
	|| do_stop &
NGINX_PID=$!
echo "Starting PID: $NGINX_PID"
sleep 0.5
echo;echo


sleep 1
PHP_PIDF=`cat $CWD/pids/php-fpm.pid`
NGINX_PIDF=`cat $CWD/pids/nginx.pid`
MYSQL_PIDF=`cat $CWD/pids/mariadb.pid`
echo "PID's from files:"
echo "  PHP PID: $PHP_PIDF"
echo "Nginx PID: $NGINX_PIDF"
echo "MySQL PID: $MYSQL_PIDF"
echo;echo


ls -1 "$CWD/sockets/"*.sock


echo
echo " [[ Ready! ]] "
echo
echo " websites   - http://127.0.0.1:9888/"
echo "              http://<website>.localhost:9888/"
echo
echo " phpMyAdmin - http://127.0.0.1:9888/"
echo "   user: root  pass: -blank-"
echo
echo "Press <enter> to stop the web server.."
echo


while true; do
#	clear
#	jobs
#	read -t1 -p "Press enter to stop.." ANSWER
	read -t1 ANSWER
	RESULT=$?
	if [ $RESULT -ne 142 ]; then
		do_stop
	fi
done

