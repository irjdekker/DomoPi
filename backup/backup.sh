#!/bin/bash
workdirectory=`dirname "$(readlink -f "$0")"`
current_user=$(whoami)
DOMO_IP="<SYSTEM_IP>"
DOMO_PORT="443"

### END OF USER CONFIGURABLE PARAMETERS
TIMESTAMP=`/bin/date +%Y%m%d%H%M%S`
BACKUPFOLDER="/home/$current_user/s3/domoticz-backup"
DBFOLDER="$BACKUPFOLDER/database"
ZWFOLDER="$BACKUPFOLDER/ozw"
SCRIPTSFOLDER="$BACKUPFOLDER/scripts"
CONFIGFOLDER="$BACKUPFOLDER/config"
DBBACKUPFILE="domoticz_$TIMESTAMP.db"
ZWBACKUPFILE="ozwcache_0xdaa30a14_$TIMESTAMP.xml"
SCRBACKUPFILE="domoticz_scripts_$TIMESTAMP.tar.gz"
CFGBACKUPFILE="domoticz_config_$TIMESTAMP.tar.gz"


#Create backup
/usr/bin/curl -k -s https://$DOMO_IP:$DOMO_PORT/backupdatabase.php > $DBFOLDER/$DBBACKUPFILE
/bin/cp -bfp /home/$current_user/domoticz/Config/ozwcache_0xdaa30a14.xml $ZWFOLDER/$ZWBACKUPFILE
/bin/tar -zcf $SCRIPTSFOLDER/$SCRBACKUPFILE /home/$current_user/domoticz/scripts/
/bin/tar -zcf $CONFIGFOLDER/$CFGBACKUPFILE /home/$current_user/domoticz/Config/

#Create symbolic link to latest backup that is greater than zero
if [ -s "$DBFOLDER/$DBBACKUPFILE" ]; then
    /bin/ln -sf $DBFOLDER/$DBBACKUPFILE $BACKUPFOLDER/domoticz.db
fi
if [ -s "$ZWFOLDER/$ZWBACKUPFILE" ]; then
    /bin/ln -sf $ZWFOLDER/$ZWBACKUPFILE $BACKUPFOLDER/ozwcache_0xdaa30a14.xml
fi

#Delete backups older than 31 days
/usr/bin/find "$BACKUPFOLDER/" -name '*.db' -mtime +31 -delete
/usr/bin/find "$BACKUPFOLDER/" -name '*.xml' -mtime +31 -delete
/usr/bin/find "$SCRIPTSFOLDER/" -name '*.tar.gz' -mtime +31 -delete
/usr/bin/find "$CONFIGFOLDER/" -name '*.tar.gz' -mtime +31 -delete