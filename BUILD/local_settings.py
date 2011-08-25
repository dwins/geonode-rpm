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
GEONODE_CLIENT_LOCATION = SITEURL + "media/static/"

import logging, sys
for _module in ["geonode.maps.views", "geonode.maps.gs_helpers"]:
   _logger = logging.getLogger(_module)
   _logger.addHandler(logging.StreamHandler(sys.stderr))
   _logger.setLevel(logging.DEBUG)
EOF
