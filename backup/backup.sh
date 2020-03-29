#!/bin/bash
DOMO_IP="<SYSTEM_IP>"
DOMO_PORT="443"

### END OF USER CONFIGURABLE PARAMETERS
TIMESTAMP=`/bin/date +%Y%m%d%H%M%S`
DBBACKUPFILE="domoticz_$TIMESTAMP.db"
ZWBACKUPFILE="ozwcache_0xdaa30a14_$TIMESTAMP.xml"
BACKUPFOLDER="/home/pi/s3/domoticz-backup"
SCRIPTSFOLDER="$BACKUPFOLDER/scripts"
CONFIGFOLDER="$BACKUPFOLDER/config"

#Create backup
/usr/bin/curl -k -s https://$DOMO_IP:$DOMO_PORT/backupdatabase.php > $BACKUPFOLDER/$DBBACKUPFILE
/bin/cp -bfp /home/pi/domoticz/Config/ozwcache_0xdaa30a14.xml $BACKUPFOLDER/$ZWBACKUPFILE
/bin/tar -zcf $SCRIPTSFOLDER/domoticz_scripts_$TIMESTAMP.tar.gz /home/pi/domoticz/scripts/
/bin/tar -zcf $CONFIGFOLDER/domoticz_config_$TIMESTAMP.tar.gz /home/pi/domoticz/Config/

#Create symbolic link to latest backup
/bin/ln -sf $DBBACKUPFILE $BACKUPFOLDER/domoticz.db
/bin/ln -sf $ZWBACKUPFILE $BACKUPFOLDER/ozwcache_0xdaa30a14.xml

#Delete backups older than 31 days
/usr/bin/find "$BACKUPFOLDER/" -name '*.db' -mtime +31 -delete
/usr/bin/find "$BACKUPFOLDER/" -name '*.xml' -mtime +31 -delete
/usr/bin/find "$SCRIPTSFOLDER/" -name '*.tar.gz' -mtime +31 -delete
/usr/bin/find "$CONFIGFOLDER/" -name '*.tar.gz' -mtime +31 -delete