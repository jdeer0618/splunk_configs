#!/bin/sh
#
# Splunk Forwarder Installer (self extracted)
# Updated: Sep/15
# Author: ateixeira@splunk.com
#
# Description: Follow the instructions below to end up with a install script + a tarball within the
#              same file, which will basically perform the following:
# 
#  1. Check dependencies for installing the Linux Universal Forwarder;
#  2. Uncompress the UF package to the /opt directory (by default);
#  3. Create the splunk user if not already there;
#  4. Set proper permissions to Splunk directories;
#  5. Enable the Deployment Client to pull configs from DS;
#  6. Change default Splunk user password;
#  7. Start Splunk and enable it after boot process.
# 
# Requirements: Linux UF package (tgz)
#
# Note: Make sure there is no blank/empty lines at the end of this script.
#       Tested it on the Linux (redhat & centos) but should work on any modern Linux distro.
#
# Instructions:
#
#  Adjust the 'DEST' variable below at 'variables defaults' section to reflect the destination install directory.
#  Optionally, adjust other variables: AUTOSTART, SPLUSER, SPLPW.
#
#  Build the self-extractor:
#
#  cat install-fwd.sh splunkforwarder-X.Y.Z-build-Linux-arch.tgz > spl-fwd-installer-X.Y.Z-build-Linux-arch.sh
# 
#  Use it:
# 
#  sh spl-fwd-installer-X.Y.Z-build-Linux-arch.sh your.ds.server:8089
#

echo "[*] Splunk Forwarder Installer"
echo "    Starting dependencies check..."

# check dependencies

[ -w /etc/ ] || { echo "    Admin access is needed. Exiting."; exit 1; } 

for p in tar gzip grep chown useradd groupadd awk tail; do
  which $p 2>&1 >/dev/null || { echo "    ${p} not found! Exiting."; exit 1; }
done

### variables defaults #######################################################

# automagically start splunk after installation (anything but 1 to avoid start)
AUTOSTART=1

# install target directory
DEST=/opt

# splunk service user
SPLUSER=splunk

# password to be used instead of changeme default
SPLPW=SplunkIsAwesomeSplunkIsAwesome

# DeploymentServer:PORT is the parameter
[ "$1" ] && DS="$1"

### end variables defaults ####################################################


###############################################################################
echo "[*] Starting execution..."
###############################################################################

grep -q "^${SPLUSER}:" /etc/group || {
  echo "    Creating group: ${SPLUSER}"
  groupadd $SPLUSER
}

grep -q "^${SPLUSER}:" /etc/passwd || {
  echo "    Creating user: ${SPLUSER}"
  useradd -m -g $SPLUSER $SPLUSER
}

[ -d $DEST ] || { echo "    Creating dir: ${DEST}"; mkdir $DEST; }

echo "    Extracting package..."
SKIP=$(awk '/^__TAKETHESHOUTOFIT__/ { print NR + 1; exit 0; }' $0)
THIS=$0
tail -n +$SKIP $THIS | tar -xz -C $DEST || {
  echo "    Problems exctractiing file! Exiting."
  exit 1
}

echo "    Setting permissions for extracted files"
chown -R ${SPLUSER}:${SPLUSER} $DEST/splunk*

# Below here is executed after the file extraction
echo "    Enabling Splunk service to run as ${SPLUSER} after boot process..."
$DEST/splunkforwarder/bin/splunk enable boot-start -user $SPLUSER --accept-license --answer-yes --no-prompt

if [ "$DS" ]; then

  # creates a temporary deployment cliente app (later removed/replaced by DS's deployed one)
  echo
  echo "[*] Configuring this instance as a deployment client of [${DS}] server..."
  echo
  DSLOCAL=$DEST/splunkforwarder/etc/apps/zzz_deploycli/local 
  DSMETA=$DEST/splunkforwarder/etc/apps/zzz_deploycli/metadata

  mkdir -p $DSLOCAL $DSMETA

  echo "[deployment-client]" > $DSLOCAL/deploymentclient.conf
  echo "[target-broker:deploymentServer]" >> $DSLOCAL/deploymentclient.conf
  echo "targetUri = ${DS}" >> $DSLOCAL/deploymentclient.conf
  echo "phoneHomeIntervalInSecs = 60" >> $DSLOCAL/deploymentclient.conf

  echo "[install]" > $DSLOCAL/app.conf
  echo "state = enabled" >> $DSLOCAL/app.conf
  echo "[package]" >> $DSLOCAL/app.conf
  echo "check_for_updates = false" >> $DSLOCAL/app.conf
  echo "[ui]" >> $DSLOCAL/app.conf
  echo "is_visible = false" >> $DSLOCAL/app.conf
  echo "is_manageable = false" >> $DSLOCAL/app.conf
  
  echo "[]" > $DSMETA/local.meta
  echo "access = read : [ * ], write : [ admin ]" >> $DSMETA/local.meta
  echo "export = system" >> $DSMETA/local.meta

fi

echo "    Setting permissions for ${DEST}/splunk*"
chown -R ${SPLUSER}:${SPLUSER} $DEST/splunk*

# ready to start
[ $AUTOSTART -eq 1 ] && /etc/init.d/splunk start

# change default password
echo "    Changing default password for admin user"
$DEST/splunkforwarder/bin/splunk edit user admin -password $SPLPW -auth admin:changeme

echo "[*] Finished!"
exit 0

__TAKETHESHOUTOFIT__
