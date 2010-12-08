Name: geonode
Version: 1.0
Release: final
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
%define _unpackaged_files_terminate_build 0

%description
At its core, the GeoNode has a stack based on GeoServer,
Django, and GeoExt that provides a platform for sophisticated
web browser spatial visualization and analysis. Atop this stack,
the project has built a map composer and viewer, tools for
analysis, and reporting tools.


%install
	rm -rf $RPM_BUILD_ROOT
	mkdir -p $RPM_BUILD_ROOT/usr/share/geonode
	sourcefiles=`ls -1dt Ge* | tail -1`
	echo "using $sourcefiles for package contents"
	cp -rp  $sourcefiles/* $RPM_BUILD_ROOT/usr/share/geonode/.
	cp -rp scripts/* $RPM_BUILD_ROOT/usr/share/geonode/.

%post
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
                invoke-rc.d tomcat5 stop
                rm -rf  /var/lib/tomcat6/webapps/geoserver-geonode-dev /var/lib/tomcat6/geonetwork
                rm -rf /var/lib/tomcat6/webapps/geoserver-geonode-dev.war /var/lib/tomcat6/webapps/geonetwork.war
                invoke-rc.d tomcat5 start
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
%dir "/usr/share/geonode/*"
