Name: geonode
Version: 1.1
Release: rc1.pre
Summary: Allows the creation, sharing, and collaborative use of geospatial data.
License: see /usr/share/doc/geonode/copyright
Distribution: Debian
Group: Converted/science
Requires(post): bash
Requires(preun): bash
Requires: python26, tomcat5, httpd, python26-virtualenv, python26-mod_wsgi, java-1.6.0-openjdk, postgresql84, postgresql84-server, gcc, postgresql84-python, postgresql84-libs, postgresql84-devel, python26-devel, geos
Conflicts: mod_python

%define _rpmdir ../
%define _rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm
%define __jar_repack %{nil}

%description
At its core, the GeoNode has a stack based on GeoServer,
Django, and GeoExt that provides a platform for sophisticated
web browser spatial visualization and analysis. Atop this stack,
the project has built a map composer and viewer, tools for
analysis, and reporting tools.


%install
	rm -rf $RPM_BUILD_ROOT
	mkdir -p $RPM_BUILD_ROOT/usr/share/geonode
        # RELEASE=GeoNode-%{version}-
	RELEASE=GeoNode-1.0.1-2011-08-23
        for f in bootstrap.py deploy.ini.ex deploy-libs.txt geonode-webapp.pybundle pavement.py README.rst
        do
            cp "$RELEASE/$f" "$RPM_BUILD_ROOT"/usr/share/geonode/
        done
	cp -rp scripts/* $RPM_BUILD_ROOT/usr/share/geonode/.

        #Deploy Java webapps (WAR files)
        TC="$RPM_BUILD_ROOT"/var/lib/tomcat5/webapps/
        GS_DATA="$RPM_BUILD_ROOT"/var/lib/geonode-geoserver-data/
        mkdir -p "$TC"
        unzip -qq $RELEASE/geoserver.war -d $TC/geoserver/
        cp -R "$TC"/geoserver/data/ "$GS_DATA"
        (cd "$TC"/geoserver/WEB-INF/ && patch -p0) < geoserver.patch
        unzip -qq $RELEASE/geonetwork.war -d $TC/geonetwork/
%post

cat << EOF >> /etc/sysconfig/tomcat5
# Next line added for GeoNode services
JAVA_OPTS="-Xmx1024m -XX:MaxPermSize=256m -XX:CompileCommand=exclude,net/sf/saxon/event/ReceivingContentHandler.startElement"
EOF
echo "GEONODE: you will need to run /usr/share/geonode/setup.sh to complete this installation"


%preun
# stop services
        if [ -e /etc/httpd/conf/geonode.conf ]; then
                service httpd stop
                rm -rf /etc/httpd/conf/geonode.conf
                service httpd start
        fi

        rm -rf /var/www/geonode

        # turn off error trapping, one of these may fail
        set +e
        su - postgres -c "dropdb geonode"
        su - postgres -c "dropuser geonode"
        set -e
        # turn it back on

        if [ -e /var/lib/tomcat5/geonetwork ]; then
                service tomcat5 stop
                rm -rf  /var/lib/tomcat5/webapps/geoserver-geonode-dev /var/lib/tomcat5/webapps/geonetwork
                rm -rf /var/lib/tomcat5/webapps/geoserver-geonode-dev.war /var/lib/tomcat5/webapps/geonetwork.war
                service tomcat5 start
        fi

        rm -rf /usr/share/geonode/role.sql /usr/share/geonode/django.configured /usr/share/geonode/*.gz
	mv -f /usr/share/geonode/tomcat5.original-settings /etc/sysconfig/tomcat5
	service tomcat5 restart


%postun
# remove files
# remove users

%clean

%files
%defattr(-,root,root,-)
%dir /usr/share/geonode/*
%config /var/lib/tomcat5/webapps/*/WEB-INF/web.xml
%attr(-,tomcat,tomcat) %config %dir /var/lib/geonode-geoserver-data
%attr(-,tomcat,tomcat) %config /var/lib/geonode-geoserver-data/*
%dir /var/lib/tomcat5/webapps/geoserver
/var/lib/tomcat5/webapps/geoserver/*
%attr(-,tomcat,tomcat) %dir /var/lib/tomcat5/webapps/geonetwork
%attr(-,tomcat,tomcat) /var/lib/tomcat5/webapps/geonetwork/*
