Allstar bootstrap script
========================

Purpose
-------

When setting up a new repeater controller, at times it would be nice to be able to configure the
new raspberry pi image without needing to boot it up and dig through menus. In particular, it's
not always trivial to reconfigure the IP address "on the fly".

With this script installed in your allstar image you can drop a "bootstrap" folder on the root
of the FAT partition of the raspberry pi SD card (the partition that mounts easily on Mac or Windows)
with configuration files on it and it will automatically apply those the next boot.

Installation on the image
-------------------------

This tool was designed to be used with the 1.5rc2 RPi2-3 allstar image found at https://hamvoip.org

In order to use this you need to update your image and put the `preloadBootstrap.sh` file in
`/usr/local/sbin/` and the `preloadBootstrap.service` in `/etc/systemd/system/`. You then need
to either run `systemctl enable preloadBootstrap.service` or manually make a symlink from
`/etc/systemd/system/multi-user.target.wants/preloadBootstrap.service`
`->` `/etc/systemd/system/preloadBootstrap.service` so that it automatically runs at boot.

Note that this runs *before the network starts* which is necessary so that it can change your
network configuration.

Usage
-----

Once you have an image with the `preloadBootstrap` script installed on it all you need to do to use
it is drop a `bootstrap` folder in the root of the FAT partition (which mounts as `/boot` when the
raspberry pi starts up) with appropriate configuration files in it.

For an example, see the `sample_bootstrap` folder in this archive.

The only file which *must* exist inside the `bootstrap` folder is `bootstrap.conf`

On the next boot, the `bootstrap` configuration will be loaded and applied and the folder will be
moved to `/root/BOOTSTRAP_%m_%d_%Y_%s` where %m is month, %d is day, %Y is year, and %s is the 
unix timestamp in seconds. This is so that the config will not be reapplied on the next boot.

bootstrap.conf
--------------

The bootstrap.conf file is just a bash script which will be included by the `preloadBootstrap`
script that needs to contain some configuration variables.

It must have in it:

    # This is a key:value array we can use to indicate which files should go where
    # All template source files must be under the "templates" directory
    declare -A TPL

    # This is a key:value array we can use to indicate files which should merely be copied to a specific destination
    # All static source files must be under the "static" directory
    declare -A STATIC

Even if you do not use them, these variables must be defined.

All other variables and config are optional.  Variables you can define are:

* `ROOTPW='somepassword'` - if provided, the root password will be set to this value
* `TIMEZONE='region/timezone'` - if provided, the system timezone will be set to this value. Must be a [valid tz string](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).
* `CONFIGURE_ALLSTAR=true` - if set, the script will regenerate the `rpt.conf`, `extensions.conf`, and `iax2.conf` files from the allstar templates found in `/usr/local/etc/asterisk_tpl`.  Note that you can use Static file mappings to provide your own templates for this. See [Configuring allstar][Configuring allstar].

Configuring allstar
-------------------

If `CONFIGURE_ALLSTAR=true` then you need to provide the following variables in your bootstrap.conf file
which will be used to generate your core allstar configuration (`rpt.conf`, `extensions.conf`, and `iax2.conf`).
This uses a script very similar to the one built into the hamvoip image, but unfortunately can't use that one
as it is not callable in a non-interactive fashion.  I hope when they see this repo they'll be interested in
working with me (or letting me make the changes and submit a PR) to fix that =]

    # Allstar Node #:
    NODE1=44068
    # Allstar node password
    NODE1_PW=123456
    # Station Call sign
    STNCALL=K7UVA
    # Report online status to allstar?
    REPORTSTAT=y
    # IAX port to bind to
    BINDPORT=4569
    # Password for IAXRPT connections
    IAXRPT_PW=connect2me
    # Set this to what you want your ID to be
    IDREC="|i${STNCALL}/L"
    # 0, 1, 2, 3, 4 duplex mode; see app_rpt docs for details. Normal repeater is '2', full duplex w/out
    # repeating audio from main input is "3"
    DUPLEX="2"

Static files
------------

You can provide static files which you would like to have placed on the target system by adding
them to the "STATIC" associative array.  For example, to provide your own templates for the asterisk
config you could add these lines:

    STATIC["extensions.conf_tpl"]="/usr/local/etc/asterisk_tpl/extensions.conf_tpl";
    STATIC["iax.conf_tpl"]="/usr/local/etc/asterisk_tpl/iax.conf_tpl";
    STATIC["rpt.conf_tpl"]="/usr/local/etc/asterisk_tpl/rpt.conf_tpl";

You would then need to place those three files in the `static` directory as a sibling of `bootstrap.conf`.

Template files
--------------

You can provide template files which would be configured using variables from your `bootstrap.conf`
file by placing them in the `templates` directory as a sibling of `bootstrap.conf`. All variables
should be defined like `${VARNAME}` inside the template and they will be replaced with the value
when the bootstrap script is run. For example, if you want to update the `allstar.env` file, you
could provide a file `templates/allstar.env` like this:

    #!/bin/bash
    #
    # asterisk.env

    # This is the allstar environment file which defines global variables used by
    # allstar for the BeagleBone Black.

    # defines the primary node (node1) number
    export NODE1=${NODE1}

    # defines the start delay prior to staring asterisk
    export START_DELAY=${START_DELAY}

    # defines the firewall status (enabled or disabled)
    #  default="disabled"
    export FIREWALL="${FIREWALL}"

    # defines the virtual private network status (enabled or disabled)
    # default="disabled"
    export VPN_NETWORK="${VPN_NETWORK}"

    # defines the watchdog timer (enabled or disabled)
    # default="enabled"
    export WATCHDOG="${WATCHDOG}"

    # defines saying of local IP address at boot (enabled or disabled)
    # default="enabled"
    export SAY_IP_AT_BOOT="${SAY_IP_AT_BOOT}"

    # defines hardware type, either "BBB" for beaglebone black, or "RPi2"
    # for Raspberry Pi2
    export HWTYPE="RPi2"

    # Defines if the server is using ONLY private nodes
    # IF USING PUBLIC OR MIXED PUBLIC/PRIVATE SET TO "0"
    # IF USING STRICTLY PRIVATE NODES SET TO "1"
    EXPORT PRIVATE_NODE=${PRIVATE_NODE}

    # DEFINES THE OPTIONAL HALT SWITCH TO THE RPI2 (ENABLED OR DISABLED)
    # DEFAULT="DISABLED"
    EXPORT SHUTDOWN_MONITOR="DISABLED"

You would then of course have to define all of those variables in your `bootstrap.conf` file and
add an entry in the `TPL` associative array like this:

    TPL["allstar.env"]="/usr/local/etc/allstar.env"

Configuring network
-------------------

To configure the network, simply place an appropriate `eth0.network` file either as a static
or a template file.  If a template, you can define the specifics in your `bootstrap.conf` file.

In the example, `static.network` and `dhcp.network` files are provided which you can easily use
by uncommenting the appropriate line.  One of:

    TPL["static.network"]="/etc/systemd/network/eth0.network"

-or-

    TPL["dhcp.network"]="/etc/systemd/network/eth0.network"

As you can see, either will replace the `eth0.network` file.  If you use the `static.network` variant
then you need to provide four variables as well:

    IP_ADDRESS=172.19.32.243/24
    IP_GW=172.19.32.1
    IP_DNS1=75.75.75.75
    IP_DNS2=75.75.75.75

Obviously you should adjust to match your actual network.  A wireless network configuration can be
provided in a similar way by overriding the wireless configuration files.