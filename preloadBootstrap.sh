#!/bin/bash

SRCDIR=/boot/bootstrap
DATESTR=$(date +"%m_%d_%Y_%s")

ConvertFile () {
  file_input=$1
  file_output=$2
  # echo "file_input=$file_input"
  # echo "file_output=$file_output"

  eval "echo \"$( < $file_input)\"" > $file_output
}

if [ ! -d "${SRCDIR}" ]; then
    # No bootstrap config to apply
    exit 0
fi

if [ ! -f "${SRCDIR}/bootstrap.conf" ]; then
    echo Could not find bootstrap.conf file! Aborting...
    exit 1
fi

# load the config variables in the bootstrap config file
. /boot/bootstrap/bootstrap.conf

# set the root password if desired:
if [ ! -z "$ROOTPW" ]; then
    echo -e "${ROOTPW}\n${ROOTPW}" | passwd root
fi
if [ ! -z "$TIMEZONE" ]; then
    /usr/bin/timedatectl set-timezone "${TIMEZONE}"
fi

# iterate over all static files and copy them in place, overwriting the original if needed
for F in "${!STATIC[@]}"; do
    SRCFILE="${SRCDIR}/static/${F}"
    if [ ! -f "${SRCFILE}" ]; then
        echo "Could not load static file ${F}!"
    else
        DESTNAME="${STATIC[$F]}"
        DESTDIR=$(dirname "${DESTNAME}")
        if [ ! -d ${DESTDIR} ]; then
            echo "Warning: creating ${DESTDIR}"
            mkdir -p ${DESTDIR}
        fi
        cp -v "${SRCFILE}" "${STATIC[$F]}"
    fi
done

# iterate over all of the config files and copy them in place, performing bash variable
# substitutions as we go
for F in "${!TPL[@]}"; do
    SRCFILE="${SRCDIR}/templates/${F}"
    if [ ! -f "${SRCFILE}" ]; then
        echo "Could not load template file ${F}!"
    else
        echo "Configuring ${SRCFILE} -> ${TPL[$F]}"
        ConvertFile "${SRCFILE}" "${TPL[$F]}"
    fi
done

echo "Done copying files, now attempting to run allstar config stuff"
TPLSRCDIR=/usr/local/etc/asterisk_tpl
CONVDIR=/etc/asterisk

# this is taken from the node-config.sh script packaged with allstar 1.5; unfortunately,
# they didn't write the script to be called programatically (without any UI), so I couldn't
# just call it directly.  I have hopes that when they see this script they might change that.

# back backup of old config files
if [ ! -f /etc/asterisk/rpt.conf_orig ] ; then
    cp /etc/asterisk/rpt.conf /etc/asterisk/rpt.conf_orig
    cp /etc/asterisk/iax.conf /etc/asterisk/iax.conf_orig
    cp /etc/asterisk/extensions.conf /etc/asterisk/extensions.conf_orig
fi
# back backup existing config files
if [ ! -f /etc/asterisk/rpt.conf_${DATE} ] ; then
    cp /etc/asterisk/rpt.conf /etc/asterisk/rpt.conf_${DATE}
    cp /etc/asterisk/iax.conf /etc/asterisk/iax.conf_${DATE}
    cp /etc/asterisk/extensions.conf /etc/asterisk/extensions.conf_${DATE}
fi

cat << _EOF > /tmp/tpl_info.txt
; WARNING - THIS FILE WAS AUTOMATICALLY CONFIGURED FROM A
; TEMPLATE FILE IN /usr/local/etc/asterisk_tpl BY KD7BBC's
; bootstrap SCRIPT AND WILL BE UPDATED BY NODE_CONFIG.SH.
;
S EACH TIME NODE-CONFIG.SH IS RUN, THIS FILE WILL BE OVERWRITTEN.
; IF YOU CHANGE ANYTHING IN THIS FILE AND RUN THE NODE-CONFIG.SH
; SCRIPT, IT WILL BE LOST.
;
; IF YOU INTEND TO USE THE NODE-CONFIG.SH SCRIPT,  THEN YOU SHOULD
; MAKE MODIFICATIONS TO THE ACTUAL TEMPLATE FILES LOCATED IN
; /usr/local/etc/asterisk_tpl directory.
;
_EOF

##############################################################
# rpt.conf
# NODE1;NODE2;STNCALL
# change number 1999 to <nodenumber>
# change WA3ZYZ to <stncall>

# then convert the template using ConverFile and save in /tmp 
ConvertFile "$TPLSRCDIR"/rpt.conf_tpl /tmp/rpt.conf_main

# cat the header file with the converted tpl file and save to 
# "$CONVDIR"/rpt.conf
cat /tmp/tpl_info.txt  /tmp/rpt.conf_main > "$CONVDIR"/rpt.conf

# setup report status

if [ "$REPORTSTAT" = "y" ] ; then
    sed 's/;statpost_/statpost_'/g "$CONVDIR"/rpt.conf > "$CONVDIR"/rpt.conf_1
    mv "$CONVDIR"/rpt.conf_1 "$CONVDIR"/rpt.conf
fi


##############################################################
# extensions
# change 1999 to <nodenumber>
# had to use sed since eval failed to convert the file correctly.
# ConvertFile "$TPLSRCDIR"/extensions.conf_tpl "$CONVDIR"/extensions.conf
sed "s/_NODE1_/${NODE1}/g" "$TPLSRCDIR"/extensions.conf_tpl > /tmp/extensions.conf_main

# add the tpl info and conf file
cat /tmp/tpl_info.txt /tmp/extensions.conf_main > "$CONVDIR"/extensions.conf


##############################################################
# iax.conf
# bindport
# register
# iphone/secret

ConvertFile "$TPLSRCDIR"/iax.conf_tpl  /tmp/iax.conf_main

cat /tmp/tpl_info.txt /tmp/iax.conf_main > "$CONVDIR"/iax.conf

##############################################################
# clean up tmp
rm -f /tmp/tpl_info.txt /tmp/extensions.conf_main /tmp/iax.conf_main /tmp/rpt.conf_main

echo Moving the bootstrap folder to a "safe" location

BACKUPDIR="/root/BOOTSTRAP_${DATESTR}"
mv -v -f ${SRCDIR} "${BACKUPDIR}"

# disable the default startup thingies
rm -fv /node_config
rm -fv /firsttime