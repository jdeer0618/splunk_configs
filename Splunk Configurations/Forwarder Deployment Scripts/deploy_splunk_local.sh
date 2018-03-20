#!/bin/sh

# Dritan Bitincka - 2011 - Splunk Inc.
#
# This script provides an example of how to deploy the Splunk universal forwarder
# to a hosts via common Unix commands - run it as root.
#
# ----------- Adjust the variables below -----------
# 

INSTALL_DIR="/opt"
# The path to Splunk install location 

SPLUNK_FILE=$1
# The splunk .tgz to be installed 

SPLUNK_USER="splunk"
# The splunk username

#### Initial Check 


if [ $# -ne 1 ]
then
    echo "\n---------------------"
    echo "Error in $0 - Invalid Argument Count"
    echo "\n"
    echo "Syntax: $0 input_file (usually a splunk*.tgz file)"
    echo "\n---------------------"
    exit
fi




#### Start the installation/configuration ####
##############################################

tar -C $INSTALL_DIR -zxf $SPLUNK_FILE 
# Untarring the tarball.

START="$INSTALL_DIR/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt"
# preliminary start of splunk to create all dirs, especially var/*

BOOT_START="$INSTALL_DIR/splunkforwarder/bin/splunk enable boot-start -user $SPLUNK_USER --accept-license --answer-yes --no-prompt"
# configure splunk to start at boot as user SPLUNK_USER

STOP="$INSTALL_DIR/splunkforwarder/bin/splunk stop"
# stop splunk 

CHOWN_1="chown -R $SPLUNK_USER:$SPLUNK_USER $INSTALL_DIR/splunkforwarder"
# change ownership of splunk dirs to user splunk use so that splunk can be started by said user

START_PROPER="/etc/init.d/splunk start "
# properly start the splunk process

$START
$BOOT_START
$STOP
$CHOWN_1
$START_PROPER

