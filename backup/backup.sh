#!/bin/bash

### backup.sh
### @author : Remb0
### @since : 29-11-2016
### @updated: 28-12-2016
### Script to backup up Domoticz database, lua, bash, python script, just in case something goes wrong.

# Additional you can install a dropbox uploader so this script can upload your backups to Dropbox as a offside backup
# It is not mandatory, its just na extra service
# Script is looking for it and skips the uploading if you didn't want to use Dropbox
# Installing Dropbox_Uploader is very easy.
# Download dropbox_uploader.sh, install it and your done
# More information here: https://github.com/andreafabrizi/Dropbox-Uploader

<code></code>### This will backup your database, scripts and LUA to your NAS drive
### USER CONFIGURABLE PARAMETERS
DESTDIR="/home/pi/domoticz/backup2Nas" # used for: NAS
IP_NAS="192.168.0.10"
MOUNTPATH="//$IP_NAS/Storage/domoticz"
USERNAME="USERNAME"
PASSWORD="PASSWORD"
PI="pi1_"

DOMO_IP="127.0.0.1" # Domoticz IP
DOMO_PORT="8080"
HOME_DIR="/home/pi"

### Which unwanted files to remove from the backup
files_exclude=".get/*"

### Retrieve current and updated Domoticz version number
DOMO_JSON_CURRENT=`curl -s -X GET "http://$DOMO_IP:$DOMO_PORT/json.htm?type=command&param=getversion"`
DOMO_CURRENT_VERSION=$(echo $DOMO_JSON_CURRENT |grep -Po '(?<="version" : "3.)[^"]*')

### Retrieve current Timestamp
TIMESTAMP=`/bin/date +%Y%m%d-%Huur-%M`
BACKUPFILE="domoticz.db"
BACKUPFILEGZ="$BACKUPFILE".gz

### Domoticz Various Backup Folders

#DROPBOX_UPLOADER="/home/pi/domoticz/scripts/bash/dropbox_uploader.sh"

###############################################################################################################################################################
### END OF USER CONFIGURABLE PARAMETERS
###############################################################################################################################################################

###############################################################################################################################################################

### Do not edit anything below this line unless your knowing what to do!

###############################################################################################################################################################

echo "
____ _ _ ____ _
| _ \ ___ _ __ ___ ___ | |_(_) ___ ____ | __ ) __ _ ___| | ___ _ _ __
| | | |/ _ \| _ _ \ / _ \| __| |/ __|_ / | _ \ / _ |/ __| |/ / | | | _ \
| |_| | (_) | | | | | | (_) | |_| | (__ / / | |_) | (_| | (__| <| |_| | |_) |
|____/ \___/|_| |_| |_|\___/ \__|_|\___/___| |____/ \____|\___|_|\_\\____| ___/
|_|
"
sleep 2

echo "::: Checking dependencies"
# apt-get install -y cifs-utils
MOUNTCOMMAND="sudo mount -t cifs -o username=$USERNAME,password=$PASSWORD $MOUNTPATH $DESTDIR"
$MOUNTCOMMAND

### Check if location is mounted
if [ -d "$DESTDIR" ] ; then
echo "$DESTDIR directory exists!"
echo " "
echo "::: Make backup folder structure"
echo "---------------------------------------------------"
cd /tmp
mkdir /tmp/backup
mkdir /tmp/backup/izsynth
mkdir /tmp/backup/habridge
mkdir /tmp/backup/habridge/data
mkdir /tmp/backup/phrases
mkdir /tmp/backup/scripts
#mkdir /tmp/backup/plugins
mkdir /tmp/backup/Logs
mkdir /tmp/backup/Config
mkdir /tmp/backup/www/
mkdir /tmp/backup/www/styles/
mkdir /tmp/backup/www/images/
mkdir /tmp/backup/www/images/floorplans
mkdir /tmp/backup/www/templates
mkdir /tmp/backup/plugins
mkdir /tmp/backup/www/dashboard/
mkdir /tmp/backup/www/dashboard/custom

echo " "
echo "::: Backing up Domoticz"
echo "---------------------------------------------------"
/usr/bin/curl -s http://127.0.0.1:8080/backupdatabase.php > /tmp/backup/$BACKUPFILE

echo " "
echo "::: Backing up files"
echo "---------------------------------------------------"

rsync -av /home/pi/domoticz/scripts/* /tmp/backup/scripts --exclude='.git' > /dev/null 2>&1

rsync -av /home/pi/domoticz/plugins/* /tmp/backup/plugins --exclude='.git' > /dev/null 2>&1

cp -r /home/pi/domoticz/Logs/* /tmp/backup/Logs
cp -r /home/pi/domoticz/www/styles/* /tmp/backup/www/styles
cp -r /home/pi/domoticz/www/images/floorplans/* /tmp/backup/www/images/floorplans
cp -r /home/pi/domoticz/www/templates/* /tmp/backup/www/templates

cp -r /home/pi/domoticz/private_cert.pem /tmp/backup
cp -r /home/pi/domoticz/server_cert.pem /tmp/backup
cp -r /home/pi/domoticz/domoticz.sh /tmp/backup

sudo cp -r /etc/monit/monitrc /tmp/backup
sudo cp -r /home/pi/domoticz/Config/zwcfg* /tmp/backup/Config/

echo "--- Backing up .bash_profile"
cp -R /etc/profile.d/motd.sh /tmp/backup/.bash_profile

cp -r /home/pi/domoticz/www/dashboard/custom/* /tmp/backup/www/dashboard/custom

cp -r /home/pi/habridge/data/* /tmp/backup/habridge/data
cp -r /home/pi/.config/izsynth/* /tmp/backup/izsynth

crontab -u pi -l > /tmp/backup/$(date +%Y%m%d).crontab

sleep 1
echo " "
echo "::: Zipping backup"
echo "---------------------------------------------------"
echo "--- Zipping Domoticz backup files"
echo "--- Please standby..."

cd /tmp/backup/
#echo compress with tar the database, scripts and files.
#sudo tar -zcvf $PI$TIMESTAMP.tar.gz /tmp/backup/*
sudo tar pcfz $PI$TIMESTAMP.tar.gz *

echo "--- Done zipping!"
sleep 1

echo "::: Transfer backup"
echo "---------------------------------------------------"
echo "--- transferring backups to NAS drive "
echo "--- Please standby..."
if ping -c 1 $IP_NAS >/dev/null ;then
cp $PI$TIMESTAMP.tar.gz $DESTDIR
echo "A copy of database, scripts and LUA are now on your NAS"
else
echo "NAS is offline"
exit 1
fi

### Uploading backup to Dropbox
# echo " "
# echo "::: Dropbox"
# echo "---------------------------------------------------"
# echo "--- Uploading backup to Dropbox"
# echo "--- Please standby..."
# $DROPBOX_UPLOADER upload $MOUNT/$DOMO_BACKUP_HOME/$DOMO_BACKUP_ZIP.tar.gz /
# echo "--- Done!"
# else
# echo " "
# echo "::: Dropbox"
# echo "---------------------------------------------------"
# echo "--- Skipping uploading to Dropbox as it seems it ain't installed"
# echo "--- Skipped!"
# sleep 2
# fi

### Removing backups older then 31 days
echo " "
echo "::: Removing backups older then 30 days from NAS"
echo "---------------------------------------------------"
echo "--- Cleaning old backups packages"
echo "--- Please standby..."
sudo find /$DESTDIR/$PI* -name '*.gz' -mtime +30 -delete
echo deleting old files used in backups
sudo /bin/rm -rf /tmp/backup
sudo /bin/rm -rf /tmp/$PI$TIMESTAMP.tar.gz
sleep 2

### unmount
sudo umount $DESTDIR

else

echo "---------------------------------------------------"
echo "--- Backup location isn't mounted"
echo "--- Please mount your backup location"
echo " "
exit 1
fi

exit