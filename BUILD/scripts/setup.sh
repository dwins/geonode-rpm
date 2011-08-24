#!/bin/bash
# postinst script for geonode
#

myhost=`echo $(ifconfig eth0 | awk -F: '/inet addr:/ {print $2}' | awk '{ print $1 }')`
username="admin"
password="admin"
exit=0
set -e

function randpass() {
  [ "$2" == "0" ] && CHAR="[:alnum:]" || CHAR="[:graph:]"
    cat /dev/urandom | tr -cd "$CHAR" | head -c ${1:-32}
    echo
}

function configuretomcat() {

# configure tomcat
#
if [ ! -e /usr/share/geonode/tomcat5.original-settings ]; then

cp  /etc/sysconfig/tomcat5 /usr/share/geonode/tomcat5.original-settings
cat << EOF >> /etc/sysconfig/tomcat5
JAVA_OPTS="-Xmx1024m -XX:MaxPermSize=256m -XX:CompileCommand=exclude,net/sf/saxon/event/ReceivingContentHandler.startElement"
EOF

fi

# stop the tomcat process to prevent it from automatically unpacking the war files
#
service tomcat5 stop

# set file permissions and copy the war files in
#
chown tomcat. /usr/share/geonode/*.war
cp /usr/share/geonode/geonetwork.war /var/lib/tomcat5/webapps
cp /usr/share/geonode/geoserver.war /var/lib/tomcat5/webapps

# perform geonode specific customizations on geoserver
#
unzip -qq /var/lib/tomcat5/webapps/geoserver.war -d /var/lib/tomcat5/webapps/geoserver
patch -l /var/lib/tomcat5/webapps/geoserver/WEB-INF/web.xml < /usr/share/geonode/patch.me
mkdir -p /opt/geoserver_data
cp -rp /var/lib/tomcat5/webapps/geoserver/data/* /opt/geoserver_data/.
chown tomcat. /opt/geoserver_data/ -R

chkconfig tomcat5 on
service tomcat5 start
}

function configurepostgres() {

# configure postgres user and database
#
chkconfig postgresql on

if [ ! -e /var/lib/pgsql/data/pg_hba.conf ]; then
	service postgresql initdb
fi

if ! grep geonode -qs /var/lib/pgsql/data/pg_hba.conf
then

HBA=/var/lib/pgsql/data/pg_hba.conf
cp $HBA $HBA.orig

cat << EOF > $HBA
local all geonode               ident
host  all geonode  127.0.0.1/32 md5
host  all geonode  ::1/128      md5
EOF

cat $HBA.orig >> $HBA

fi

service postgresql start

echo "please wait while the database initializes"
sleep 5

set +e
useradd geonode
su - postgres -c "createdb geonode"
psqlpass=$(randpass 8 0)
#md5pgsql="md5`echo $psqlpass | md5sum | awk '{print $1}'`"
echo "CREATE ROLE geonode with login password '$psqlpass' SUPERUSER INHERIT;" > /usr/share/geonode/role.sql
su - postgres -c "psql < /usr/share/geonode/role.sql"
set -e

}

function configuredjango() {

# set up django
#
mkdir -p /var/www/geonode/{htdocs,htdocs/media,wsgi/geonode/}
cp /usr/share/geonode/bootstrap.py /var/www/geonode/wsgi/geonode/.
cp /usr/share/geonode/geonode-webapp.pybundle /var/www/geonode/wsgi/geonode/.
cp /usr/share/geonode/pavement.py /var/www/geonode/wsgi/geonode/.
cd /var/www/geonode/wsgi/geonode
#virtualenv /var/www/geonode/wsgi/geonode
#source /var/www/geonode/wsgi/geonode/bin/activate
python26 bootstrap.py

curl http://initd.org/psycopg/tarballs/psycopg2-2.2.2.tar.gz -o  /usr/share/geonode/psycopg2-2.2.2.tar.gz
/var/www/geonode/wsgi/geonode/bin/pip install /usr/share/geonode/psycopg2-2.2.2.tar.gz
source /etc/profile

	cd /var/www/geonode/wsgi/geonode/src/GeoNodePy
	patch -l -p3 < /usr/share/geonode/patch.django

	cat <<- EOF > /var/www/geonode/wsgi/geonode/src/GeoNodePy/geonode/local_settings.py
	DEBUG = TEMPLATE_DEBUG = False
	MINIFIED_RESOURCES = True
	SERVE_MEDIA=False

	SITENAME = "GeoNode"
	SITEURL = "http://$myhost/"

	DATABASE_ENGINE = 'postgresql_psycopg2'
	DATABASE_NAME = 'geonode'
	DATABASE_USER = 'geonode'
	DATABASE_PASSWORD = "$psqlpass"
	DATABASE_HOST = 'localhost'
	DATABASE_PORT = '5432'

	LANGUAGE_CODE = 'en'

	# the filesystem path where uploaded data should be saved
	MEDIA_ROOT = "/var/www/geonode/htdocs/media/"

	# the web url to get to those saved files
	MEDIA_URL = SITEURL + "media/"

	GEONODE_UPLOAD_PATH = "/var/www/geonode/htdocs/media/"

	# secret key used in hashing, should be a long, unique string for each
	# site.  See http://docs.djangoproject.com/en/1.2/ref/settings/#secret-key
	#
	# Here is one quick way to randomly generate a string for this use:
	# python -c 'import random, string; print "".join(random.sample(string.printable.strip(), 50))'
	SECRET_KEY = ''

	# The FULLY QUALIFIED url to the GeoServer instance for this GeoNode.
	GEOSERVER_BASE_URL = SITEURL + "geoserver/"

	# The FULLY QUALIFIED url to the GeoNetwork instance for this GeoNode
	GEONETWORK_BASE_URL = SITEURL + "geonetwork/"

	# The username and password for a user with write access to GeoNetwork
	GEONETWORK_CREDENTIALS = "admin", 'admin'

	# A Google Maps API key is needed for the 3D Google Earth view of maps
	# See http://code.google.com/apis/maps/signup.html
	GOOGLE_API_KEY = ""

	ADMIN_MEDIA_PREFIX="/admin-media/"

#       GEOS_LIBRARY_PATH = '/usr/lib/libgeos_c.so.1.5.0'

	DEFAULT_LAYERS_OWNER='admin'
	GEONODE_CLIENT_LOCATION = SITEURL

	import logging, sys
	for _module in ["geonode.maps.views", "geonode.maps.gs_helpers"]:
	   _logger = logging.getLogger(_module)
	   _logger.addHandler(logging.StreamHandler(sys.stderr))
	   _logger.setLevel(logging.DEBUG)
	EOF

	cat <<- EOF > /var/www/geonode/wsgi/geonode.wsgi
	import site, os

	site.addsitedir('/var/www/geonode/wsgi/geonode/lib/python2.6/site-packages')
	os.environ['DJANGO_SETTINGS_MODULE'] = 'geonode.settings'

	from django.core.handlers.wsgi import WSGIHandler
	application = WSGIHandler()
	EOF

}

function configureapache() {
	# Setup apache
	#
	chown apache. -R /var/www/geonode/

	if [ -z "$(which setsebool)" ]; then
		setsebool -P httpd_can_network_connect=1
	fi

	cat <<- EOF > /etc/httpd/conf.d/geonode.conf
	<VirtualHost *:80>
	   Servername $myhost
	   ServerAdmin webmaster@localhost
	   DocumentRoot /var/www/geonode/htdocs/
	   <Directory />
	       Options FollowSymLinks
	       AllowOverride None
	   </Directory>
	   <Directory /var/www/geonode/htdocs>
	       Options Indexes FollowSymLinks MultiViews
	       AllowOverride None
	       Order allow,deny
	       allow from all
	   </Directory>
	   <Proxy *>
	       Order allow,deny
	       Allow from all
	   </Proxy>

	   Alias /media/ /var/www/geonode/wsgi/geonode/src/GeoNodePy/geonode/media/
	   Alias /admin-media/ /var/www/geonode/wsgi/geonode/lib/python2.6/site-packages/django/contrib/admin/media/

	   WSGIPassAuthorization On
	   WSGIScriptAlias / /var/www/geonode/wsgi/geonode.wsgi

	   ProxyPreserveHost On

	   ProxyPass /geoserver http://localhost:8080/geoserver
	   ProxyPassReverse /geoserver http://localhost:8080/geoserver
	   ProxyPass /geonetwork http://localhost:8080/geonetwork
	   ProxyPassReverse /geonetwork http://localhost:8080/geonetwork
	</VirtualHost>
	EOF

	chkconfig httpd on
	service httpd start


}

respond() {
  printf "$1: [$2] "
  read choice
  if [  "$choice" = "" ] || [ ${#choice} -lt $3  ]; then
    choice=$2
  fi
}


menu() {

  printf "
  ----------------------
  1. hostname/ip         : $myhost
  2. geonode username    : $username
  3. geonode password    : $password

  9. accept config and continue
  0. abort/quit

  choice: "

  read menuchoice

case "$menuchoice" in
    "1")
	printf "please provide the ipaddress or hostname of this machine\ndo *NOT* put http:// or a / after (no spaces)\n"
	respond "hostname" "$myhost" "3"
	myhost=$choice
	;;

    "2")
        printf "please choose a username to log into geonode with\n"
        respond "username" "$username" "3"
        username=$choice
        ;;

    "3")
        printf "please choose a password to log into geonode with\n"
        respond "password" "$password" "3"
        password=$choice
        ;;

    "9")
	exit=1
    ;;

    "0")
	echo "aborting, changes not saved"
	exit 255
    ;;
  esac
}

while [ $exit -eq 0 ]; do
  menu
done

configuretomcat
configurepostgres
configuredjango
configureapache

#TODO configure a check to prevent rerunning this

if [ ! -e /usr/share/geonode/django.configured ]; then 
	/var/www/geonode/wsgi/geonode/bin/django-admin.py syncdb --noinput --settings=geonode.settings
	/var/www/geonode/wsgi/geonode/bin/django-admin.py batchcreatesuperuser $username $password --settings=geonode.settings
	touch /usr/share/geonode/django.configured
fi

service tomcat5 restart

exit 0
