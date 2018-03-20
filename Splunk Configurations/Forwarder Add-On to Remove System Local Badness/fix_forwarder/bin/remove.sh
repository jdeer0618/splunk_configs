if [ -d $SPLUNK_HOME/junk ]
then
	exit
fi
mkdir $SPLUNK_HOME/junk
mv $SPLUNK_HOME/etc/system/local/deploymentclient.conf $SPLUNK_HOME/junk
mv $SPLUNK_HOME/etc/apps/search/local/outputs.conf $SPLUNK_HOME/junk