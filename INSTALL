Installation
============

Overview
--------

There are currently 3 methods to install OAR:

  - from the Debian packages
  - from the RPM packages
  - from sources


Before going further, please have in mind OAR's architecture. A common OAR
installation is composed of:

  - a **server** which will hold all of OAR "smartness". That host will run
    the OAR server daemon;
  - one or more **frontends**, which users will have to login to, in order
    to reserve computing nodes (oarsub, oarstat, oarnodes, ...);
  - **computing nodes** (or basically *nodes*), where the jobs will execute;
  - optionally a **visualisation server** which will host the
    visualisation webapps (monika, drawgantt, ...);
  - optionally an **API server**, which will host OAR restful API service.

Many OAR data are stored and archived in a database: you have the choice to use
either PostgreSQL or MySQL. We recommend using **PostgreSQL**.


Beside this documentation, please have a look at **OAR website**:
http://oar.imag.fr, which also provides a lot of information, espacially in the
**Download** and **Contribs** sections.


Computing nodes
---------------

Installation from the packages
______________________________

**Instructions**

*For RedHat like systems*::

        # OAR provides a Yum repository.
        # For more information see: http://oar.imag.fr/download#rpms

        # Install OAR node
        yum --enablerepo=OAR install oar-node

*For the Debian like systems*::

        # OAR is shipped as part of Debian official distributions (newer versions can be available in backports)
        # For more info see: http://oar.imag.fr/download#debian

        # Install OAR node
        apt-get install oar-node

Installation from the tarball
_____________________________

**Requirements**

*For RedHat like systems*::

          # Build dependencies
          yum install gcc make tar python-docutils

          # Common dependencies
          yum install Perl Perl-base openssh

*For Debian like system*::

          # Build dependencies
          apt-get install gcc make tar python-docutils

          # Common dependencies
          apt-get install perl perl-base openssh-client openssh-server

**Instructions**

Get the sources::

        OAR_VERSION=2.5.4
        wget -O - http://oar-ftp.imag.fr/oar/2.5/sources/stable/oar-${OAR_VERSION}.tar.gz | tar xzvf -
        cd oar-${OAR_VERSION}/

build/install/setup::

        # build
        make node-build
        # install
        make node-install
        # setup
        make node-setup


Configuration
_____________

Init.d scripts
~~~~~~~~~~~~~~

If you have installed OAR from sources, you need to become root user and
install manually the {init.d,default,sysconfig} scripts present in the folders::

    $PREFIX/share/doc/oar-node/examples/scripts/{init.d,default,sysconfig}

Then you just need to use the script ``/etc/init.d/oar-node`` to start
the SSH daemon dedicated to oar-node.

SSH setup
~~~~~~~~~

OAR uses SSH to connect from machine to machine (e.g. from server or frontend to
nodes or from nodes to nodes), using a dedicated SSH daemon usually running on
port 6667.

Upon installtion of the OAR server on the server machine, a SSH key pair along with an authorized_keys file is created for the oar user in ``/var/lib/oar/.ssh``. You need to copy that directory from the oar server to the nodes.

Please note that public key in the authorized_keys file must be prefixed with ``environment="OAR_KEY=1"``, e.g.::

      environment="OAR_KEY=1" ssh-rsa AAAAB3NzaC1yc2[...]6mIcqvcwG1K7V6CHLQKHKWo/ root@server
 
Also please make sure that the ``/var/lib/oar/.ssh`` directory and contained files have the right ownership (oar.oar) and permissions for SSH to function. 


Server
------

Installation from the packages
______________________________

**Instructions**

*For RedHat like systems*::

        # OAR provides a Yum repository.
        # For more information see: http://oar.imag.fr/download#rpms

        # Install OAR server for the PostgreSQL backend
        yum --enablerepo=OAR install oar-server oar-server-pgsql

        # or Install OAR server for the MySQL backend
        yum --enablerepo=OAR install oar-server oar-server-mysql

*For the Debian like systems*::

        # OAR is shipped as part of Debian official distributions (newer versions can be available in backports)
        # For more info see: http://oar.imag.fr/download#debian

        # Install OAR server for the PostgreSQL backend
        apt-get install oar-server oar-server-pgsql

        # or Install OAR server for the MySQL backend
        apt-get install oar-server oar-server-mysql

Installation from the tarball
_____________________________

**Requirements**

*For RedHat like systems*::

        # Add the epel repository (choose the right version depending on your
        # operating system)
        yum install epel-release

        # Build dependencies
        yum install gcc make tar python-docutils

        # Common dependencies
        yum install Perl Perl-base openssh Perl-DBI perl-Sort-Versions

        # MySQL dependencies
        yum install mysql-server mysql perl-DBD-MySQL

        # PostgreSQL dependencies
        yum install postgresql-server postgresql perl-DBD-Pg

*For Debian like system*::

          # Build dependencies
          apt-get install gcc make tar python-docutils

          # Common dependencies
          apt-get install perl perl-base openssh-client openssh-server libdbi-perl libsort-versions-perl

          # MySQL dependencies
          apt-get install mysql-server mysql-client libdbd-mysql-perl

          # PostgreSQL dependencies
          apt-get install postgresql postgresql-client libdbd-pg-perl

**Instructions**

Get the sources::

        OAR_VERSION=2.5.4
        wget -O - http://oar-ftp.imag.fr/oar/2.5/sources/stable/oar-${OAR_VERSION}.tar.gz | tar xzvf -
        cd oar-${OAR_VERSION}/

Build/Install/Setup the OAR server::

        # build
        make server-build
        # install
        make server-install
        # setup
        make server-setup

Configuration
_____________

The oar database
~~~~~~~~~~~~~~~~

Define the database configuration in /etc/oar/oar.conf. You need to set the
variables ``DB_TYPE, DB_HOSTNAME, DB_PORT, DB_BASE_NAME, DB_BASE_LOGIN,
DB_BASE_PASSWD, DB_BASE_LOGIN_RO, DB_BASE_PASSWD_RO``::

        vi /etc/oar/oar.conf

Create the database and the database users::

        # General case
        oar-database --create --db-admin-user <ADMIN_USER> --db-admin-pass <ADMIN_PASS>

        # OR, for PostgreSQL, in case the database is installed locally
        oar-database --create --db-is-local


Init.d scripts
~~~~~~~~~~~~~~

If you have installed OAR from sources, you need to become root user and
install manually the init.d/default/sysconfig scripts present in the folders::

    $PREFIX/share/doc/oar-server/examples/scripts/{init.d,default,sysconfig}

Then use the script ``/etc/init.d/oar-server`` to start the OAR server daemon.

Adding resources to the system
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To **automatically** initialize resources for your cluster, you can run the
``oar_resources_init`` command. It will detect the resources from nodes set in
a file and give the OAR commands to initialize the database with the
appropriate values for the memory and the cpuset properties.

Another tool is also available to create resources beforehand: that tool does
not require nodes to be up and accessible by SSH.  See ``oar_resources_add``.

*Otherwise:*

To add resources to your system, you can use (as root) the ``oarnodesetting``
command.  For a complete understanding of what that command does, see the
manual page. For a basic usage, the main options are **-a** (means add a
resource) and **-h** (defines the resource hostname or ip adress).

For instance, to add a computing resource for node <NODE_IP> to your setup,
type::

        oarnodesetting -a -h <NODE_IP>

This adds a resource with <NODE_IP> as host IP address (network_address
property).


You can modify resources properties with **-p** option, for instance::

        oarnodesetting -r 1 -p "besteffort=YES"

This allows the resource #1 to accept jobs of type *besteffort* (an admission
rule forces besteffort jobs to execute on resources with the property
"besteffort=YES").

Notes
_____

Security issues
~~~~~~~~~~~~~~~

For security reasons it is hardly **recommended** to configure a read only
account for the OAR database (like the above example).  Thus you will be able
to add it in DB_BASE_LOGIN_RO and DB_BASE_PASSWD_RO in *oar.conf*.

PostgreSQL: autovacuum
~~~~~~~~~~~~~~~~~~~~~~~

Be sure to activate the "autovacuum" feature in the "postgresql.conf" file (OAR
creates and deletes a lot of records and this setting cleans the postgres
database from unneeded records).

PostgreSQL: authentication
~~~~~~~~~~~~~~~~~~~~~~~~~~~

In case you've installed a PostgreSQL database remotely, if your PostgreSQL
installation doesn't authorize the local connections by default, you need to
enable the connections to this database for the oar users. Assuming the OAR
server has the address <OAR_SERVER>, you can add the following lines in the
``pg_hba.conf`` file::

        # in /etc/postgresql/8.1/main/pg_hba.conf or /var/lib/pgsql/data/pg_hba.conf
        host    oar         oar_ro            <OAR_SERVER>/32    md5
        host    oar         oar               <OAR_SERVER>/32    md5

Using Taktuk
~~~~~~~~~~~~

If you want to use taktuk to manage remote administration commands, you have to
install it. You can find information about taktuk from its website:
http://taktuk.gforge.inria.fr.

Then, you have to edit your oar configuration file and fill in the related
parameters:

  - ``TAKTUK_CMD`` (the path to the taktuk command)
  - ``PINGCHECKER_TAKTUK_ARG_COMMAND`` (the command used to check resources states)
  - ``SCHEDULER_NODE_MANAGER_SLEEP_CMD`` (command used for halting nodes)

CPUSET feature
~~~~~~~~~~~~~~

OAR uses the CPUSET features provided by the Linux kernel >= 2.6. This
enables to restrict user processes to reserved processors only and provides
a powerful clean-up mechanism at the end of the jobs.

For more information, have a look at the CPUSET file.

Energy saving
~~~~~~~~~~~~~

Starting with version 2.4.3, OAR provides a module responsible of advanced
management of wake-up/shut-down of nodes when they are not used.
To activate this feature, you have to:

    - provide 2 commands or scripts which will be executed on the oar server
      to shutdown (or set into standby) some nodes and to wake-up some nodes
      (configure the path of those commands into the
      ``ENERGY_SAVING_NODE_MANAGER_WAKE_UP_CMD`` and
      ``ENERGY_SAVING_NODE_MANAGER_SHUT_DOWN_CMD`` variables in oar.conf)
      Thes 2 commands are executed by the oar user.
    - configure the ``available_upto`` property of all your nodes:

      - ``available_upto=0``           : to disable the wake-up and halt
      - ``available_upto=1``           : to disable the wake-up (but not the halt)
      - ``available_upto=2147483647``  : to disable the halt (but not the wake-up)
      - ``available_upto=2147483646``  : to enable wake-up/halt forever
      - ``available_upto=<timestamp>`` : to enable the halt, and the wake-up until
        the date given by <timestamp>

      Ex: to enable the feature on every nodes forever:
        ::

            oarnodesetting --sql true -p available_upto=2147483646

    - activate the energy saving module by setting ``ENERGY_SAVING_INTERNAL="yes"``
      and configuring the ``ENERGY_*`` variables into oar.conf
    - configure the metascheduler time values into ``SCHEDULER_NODE_MANAGER_IDLE_TIME``,
      ``SCHEDULER_NODE_MANAGER_SLEEP_TIME`` and ``SCHEDULER_NODE_MANAGER_WAKEUP_TIME``
      variables of the oar.conf file.
    - restart the oar server (you should see an "Almighty" process more).

You need to restart OAR each time you change an ``ENERGY_*`` variable.
More informations are available inside the oar.conf file itself. For more
details about the mechanism, take a look at the "Hulot" module documentation.

Disabling SELinux
~~~~~~~~~~~~~~~~~

On some distributions, SELinux is enabled by default. There is currently no OAR
support for SELinux. So, you need to disable SELinux, if enabled.

Cpuset id issue
~~~~~~~~~~~~~~~

On some rare servers, the core ids are not persistent across reboot. So you need
to update the cpuset ids in the resource database at startup for each computing
node. You can do this by using the ``/etc/oar/update_cpuset_id.sh`` script. The
following page give more informations on how configuring it:

    http://oar.imag.fr/wiki:old:customization_tips#start_stop_of_nodes_using_ssh_keys

Frontends
---------

Installation from the packages
______________________________

**Instructions**

*For RedHat like systems*::

        # OAR provides a Yum repository.
        # For more information see: http://oar.imag.fr/download#rpms

        # Install OAR user for the PostgreSQL backend
        yum --enablerepo=OAR install oar-user oar-user-pgsql

        # or Install OAR user for the MySQL backend
        yum --enablerepo=OAR install oar-user oar-user-mysql

*For the Debian like systems*::

        # OAR is shipped as part of Debian official distributions (newer versions can be available in backports)
        # For more info see: http://oar.imag.fr/download#debian

        # Install OAR server for the PostgreSQL backend
        apt-get install oar-user oar-user-pgsql

        # or Install OAR server for the MySQL backend
        apt-get install oar-user oar-user-mysql

Installation from the tarball
_____________________________

**Requirements**

*For RedHat like systems*::

          # Build dependencies
          yum install gcc make tar python-docutils

          # Common dependencies
          yum install Perl Perl-base openssh Perl-DBI

          # MySQL dependencies
          yum install mysql perl-DBD-MySQL

          # PostgreSQL dependencies
          yum install postgresql perl-DBD-Pg


*For Debian like system*::

          # Build dependencies
          apt-get install gcc make tar python-docutils

          # Common dependencies
          apt-get install perl perl-base openssh-client openssh-server libdbi-perl

          # MySQL dependencies
          apt-get install mysql-client libdbd-mysql-perl

          # PostgreSQL dependencies
          apt-get install postgresql-client libdbd-pg-perl

**Instructions**

Get the sources::

        OAR_VERSION=2.5.4
        wget -O - http://oar-ftp.imag.fr/oar/2.5/sources/stable/oar-${OAR_VERSION}.tar.gz | tar xzvf -
        cd oar-${OAR_VERSION}/

Build/Install/setup::

        # build
        make user-build
        # install
        make user-install
        # setup
        make user-setup


Configuration
_____________

SSH setup
~~~~~~~~~

OAR uses SSH to connect from machine to machine (e.g. from server or frontend to
nodes or from nodes to nodes), using a dedicated SSH daemon usually running on
port 6667.

Upon installtion of the OAR server on the server machine, a SSH key pair along with an authorized_keys file is created for the oar user in ``/var/lib/oar/.ssh``. You need to copy that directory from the oar server to the frontend (if not the same machine).

Please note that public key in the authorized_keys file must be prefixed with ``environment="OAR_KEY=1"``, e.g.::

      environment="OAR_KEY=1" ssh-rsa AAAAB3NzaC1yc2[...]6mIcqvcwG1K7V6CHLQKHKWo/ root@server
 
Also please make sure that the ``/var/lib/oar/.ssh`` directory and contained files have the right ownership (oar.oar) and permissions for SSH to function. 

Coherent configuration files between server node and user nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You need to have a coherent oar configuration between the server node and the
user nodes. So you can just copy the /etc/oar/oar.conf directory from to server node to
the user nodes.

About X11 usage in OAR
~~~~~~~~~~~~~~~~~~~~~~

The easiest and scalable way to use X11 application on cluster nodes is to open
X11 ports and set the right DISPLAY environment variable by hand.  Otherwise
users can use X11 forwarding via SSH to access cluster frontends. You
must configure the SSH server on the frontends nodes with::

    X11Forwarding yes
    X11UseLocalhost no

With this configuration, users can launch X11 applications after a 'oarsub -I'
on the given node or "oarsh -X node12".

API server
----------

Description
___________

Since the version 2.5.3, OAR offers an API for users and admins interactions.
This api must be installed on a frontend node (with the user module installed).

Installation from the packages
______________________________

**Instructions**

*For RedHat like systems*::

        # OAR provides a Yum repository.
        # For more information see: http://oar.imag.fr/download#rpms

        # Install apache FastCGI and Suexec modules (optional but highly recommended)

        # Install OAR Restful api
        yum --enablerepo=OAR install oar-restful-api

*For the Debian like systems*::

        # OAR is shipped as part of Debian official distributions (newer versions can be available in backports)
        # For more info see: http://oar.imag.fr/download#debian

        # Install apache FastCGI and Suexec modules (optional but highly recommended)

        # Install OAR Restful api
        apt-get install oar-restful-api

Installation from the tarball
_____________________________

**Requirements**

*For RedHat like systems*::

          # Build dependencies
          yum install gcc make tar python-docutils

          # Common dependencies
          yum install perl perl-base perl-DBI perl-CGI perl-JSON perl-YAML perl-libwww-perl httpd

          # Install apache FastCGI and Suexec modules (optional but highly recommended)

          # MySQL dependencies
          yum install perl-DBD-MySQL

          # PostgreSQL dependencies
          yum install perl-DBD-Pg


*For Debian like system*::

          # Build dependencies
          apt-get install gcc make tar python-docutils

          # Common dependencies
          apt-get install perl perl-base libdbi-perl libjson-perl libyaml-perl libwww-perl apache2 libcgi-fast-perl

          # Install apache FastCGI and Suexec modules (optional but highly recommended)

          # MySQL dependencies
          apt-get install libdbd-mysql-perl

          # PostgreSQL dependencies
          apt-get install libdbd-pg-perl

**Instructions**

Get the sources::

        OAR_VERSION=2.5.4
        wget -O - http://oar-ftp.imag.fr/oar/2.5/sources/stable/oar-${OAR_VERSION}.tar.gz | tar xzvf -
        cd oar-${OAR_VERSION}/

build/install/setup::

        # build
        make api-build
        # install
        make api-install
        # setup
        make api-setup

Configuration
_____________

*Configuring OAR*

    For the moment, the API needs the user tools to be installed on the same
    host ('``make user-install``' or oar-user packages). A suitable
    ``/etc/oar/oar.conf`` should be present. For the API to work, you should have
    the oarstat/oarnodes/oarsub commands to work (on the same host you installed
    the API)

*Configuring Apache*

    The api provides a default configuration file (``/etc/oar/apache-api.conf``) that
    is using an identd user identification enabled only from localhost.  Edit the
    ``/etc/oar/apache-api.conf`` file and customize it to reflect the authentication
    mechanism you want to use. For ident, you may have to install a "identd" daemon
    on your distrib. The steps may be:

        - Install and run an identd daemon on your server (like *pidentd*).
        - Activate the ident auth mechanism into apache (``a2enmod ident``).
        - Activate the headers apache module (``a2enmod headers``).
        - Activate the rewrite apache module (``a2enmod rewrite``).
        - Customize apache-api.conf to allow the hosts you trust for ident.

*YAML, JSON, XML*

    You need at least one of the YAML or JSON perl module to be installed on
    the host running the API.

*Test*

    You may test the API with a simple wget::

        wget -O - http://localhost/oarapi/resources.html

    It should give you the list of resources in the yaml format but enclosed in an
    html page.  To test if the authentication works, you need to post a new job.
    See the example.txt file that gives you example queries with a ruby rest
    client.

Visualization server
--------------------

Description
___________

OAR provides two webapp tools for visualizing the resources utilization::

  - monika which displays the current state of resources as well as all running and waiting jobs
  - drawgantt-svg which displays gantt chart of nodes and jobs for the past and future.

Installation from the packages
______________________________

**Instructions**

*For RedHat like systems*::

        # OAR provides a Yum repository.
        # For more information see: http://oar.imag.fr/download#rpms

        # Install OAR web status package
        yum --enablerepo=OAR install oar-web-status

*For the Debian like systems*::

        # OAR is shipped as part of Debian official distributions (newer versions can be available in backports)
        # For more info see: http://oar.imag.fr/download#debian

        # Install OAR web status package
        apt-get install oar-web-status

Installation from the tarball
_____________________________

**Requirements**

*For RedHat like systems*::

          # Build dependencies
          yum install gcc make tar python-docutils

          # Common dependencies
          yum install perl perl-base perl-DBI ruby-GD ruby-DBI perl-Tie-IxHash perl-Sort-Naturally perl-AppConfig php

          # MySQL dependencies
          yum install mysql perl-DBD-MySQL ruby-mysql php-mysql

          # PostgreSQL dependencies
          yum install postgresql perl-DBD-Pg ruby-pg php-pgsql


*For Debian like system*::

          # Build dependencies
          apt-get install gcc make tar python-docutils

          # Common dependencies
          apt-get install perl perl-base ruby libgd-ruby1.8 libdbi-perl libtie-ixhash-perl libappconfig-perl libsort-naturally-perl libapache2-mod-php5

          # MySQL dependencies
          apt-get install libdbd-mysql-perl libdbd-mysql-ruby php5-mysql

          # PostgreSQL dependencies
          apt-get install libdbd-pg-perl libdbd-pg-ruby php5-pgsql

**Instructions**

Get the sources::

        OAR_VERSION=2.5.4
        wget -O - http://oar-ftp.imag.fr/oar/2.5/sources/stable/oar-${OAR_VERSION}.tar.gz | tar xzvf -
        cd oar-${OAR_VERSION}/

build/install/setup::

        # build
        make monika-build drawgantt-build drawgantt-svg-build www-conf-build
        # install
        make monika-install drawgantt-install drawgantt-svg-install www-conf-install
        # setup
        make monika-setup drawgantt-setup drawgantt-svg-setup www-conf-setup

Configuration
_____________

**Monika configuration**

 - Edit ``/etc/oar/monika.conf`` to fit your configuration.

**Drawgantt-SVG configuration**

 - Edit ``/etc/oar/drawgantt-config.inc.php`` to fit your configuration.

**httpd configuration**

 - You need to edit ``/etc/oar/apache.conf`` to fit your needs and verify that you
   http server configured.
