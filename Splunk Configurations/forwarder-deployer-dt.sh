#!/bin/bash
 
# 20130404 Duncan Turnbull (Splunk) for Financial Services Customer
# This script installs a forwarder, the flavour being passed as a parameter.
# Assumes:
# - The forwarder rpm for the flavour has been scp'ed with this script on the target host.
# - Must be run by an account with infrastructure sudo privileges at least.
# - Requirements:
# - The host must be able to communicate with the indexers on port 9997.
# - The splunk account must be able to read the logs that it will monitor.
# - The host must be able to communicate with the deployment server on port 8089.
#
 
die () {
    echo >&2 "$@"
    exit 1
}
 
[ "$#" -eq 1 ] || die "1 argument required, $# provided"
 
BASEPATH=`dirname $0`
HFORWARDER=splunk
LFORWARDER=splunkforwarder
RPM_SUFFIX="-5.0.2-149561-linux-2.6-x86_64.rpm"
SPLUNK_HFORWARDER_RPM=$BASEPATH/$HFORWARDER$RPM_SUFFIX
SPLUNK_LFORWARDER_RPM=$BASEPATH/$LFORWARDER$RPM_SUFFIX
 
# Select the appropriate Splunk RPM depending on the parameter passed to the script
# ./deploy-fwd.sh HFORWARDER
# for the full Splunk package
# ./deploy-fwd.sh LFORWARDER
# for the Universal Forwarder package
echo $1 | grep -E -q 'HFORWARDER|LFORWARDER' || die "Invalid argument $1, expected HFORWARDER or LFORWARDER"
RPM_VAR=SPLUNK_$1_RPM
 
RPM=`eval echo \\$$RPM_VAR`
 
echo "Installing Package $RPM"
 
# Default prefix is /opt. If you need to install to another prefix, switch out the yum command for rpm --install $RPM --prefix $PREFIX.
 
PREFIX=/opt
SPLUNK_HOME=`eval echo $PREFIX/\\$$1`
 
SPLUNK=$SPLUNK_HOME/bin/splunk
SPLUNK_USER=splunk
SPLUNK_GROUP=splunk
SPLUNK_FLAGS=" --accept-license --answer-yes --no-prompt"
 
SUDO=sudo
SPLUNK_SUDO="sudo -u $SPLUNK_USER $SPLUNK"
 
# Install Splunk RPM
 
### $SUDO rpm --import $BASEPATH/splunk-publickey
$SUDO yum --nogpgcheck localinstall $RPM
 
# Copy deployment server configuration
 
$SUDO cp -r $BASEPATH/deployment-apps/deploymentclient $SPLUNK_HOME/etc/apps
 
# Copy user-seed.conf to customise default username/password combination
 
$SUDO cp -f $BASEPATH/deployment-apps/user-seed/user-seed.conf $SPLUNK_HOME/etc/system/default/user-seed.conf
$SUDO chown -R $SPLUNK_USER:$SPLUNK_GROUP $SPLUNK_HOME
 
 
# Set the default hostname to be the short hostname
# This will update $SPLUNK_HOME/etc/system/local/inputs.conf to have:
# [default]
# host = example_shortname
 
$SPLUNK_SUDO set default-hostname `hostname -s` $SPLUNK_FLAGS
 
# Set Splunk to use the default included forwarding licence
# (The Universal Forwarder should have this on by default, but a HForwarder will be on an enterprise trial license by default)
 
$SPLUNK_SUDO edit licenser-groups Forwarder -is_active 1 $SPLUNK_FLAGS
 
# Disable Splunkweb (Universal forwarders do not include Splunkweb, but a HForwarder will have it on by default)
 
$SPLUNK_SUDO disable webserver $SPLUNK_FLAGS
 
# Start Splunk
$SPLUNK_SUDO start $SPLUNK_FLAGS
 
# Start splunk on boot as the appropriate user
 
$SUDO $SPLUNK enable boot-start -user $SPLUNK_USER $SPLUNK_FLAGS
