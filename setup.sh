##
##  This version of the script (April 2019) includes changes to start initial setup on Raspbian 
##
##  This script is the product of many, many months of work and includes
##  (Raspberry Pi - tested on Raspbian Stretch Lite - https://downloads.raspberrypi.org/raspbian_lite_latest)
##
## The easiest way to get the script on your machine is:
## wget -O - https://raw.githubusercontent.com/irjdekker/DomoPi/master/setup.sh 2>/dev/null | bash
## 
## 27/04/2019 Created initial script
##
## Typically, sitting in your home directory (/home/pi) as user Pi you might want to use NANO editor to install this script
## and after giving the script execute permission (sudo chmod 0744 /home/pi/setup.sh)
## you could run the file as ./setup.sh
##
## ROUTINES
## Here at the beginning, a load of useful routines - see further down

# High Intensity
IRed='\e[0;31m'         # Red
IGreen='\e[0;32m'       # Green
IYellow='\e[0;33m'      # Yellow
IBlue='\e[0;34m'        # Blue
IPurple='\e[0;35m'      # Purple
ICyan='\e[0;36m'        # Cyan
IWhite='\e[0;97m'       # White

# Bold High Intensity
BIRed='\e[1;31m'        # Red
BIGreen='\e[1;32m'      # Green
BIYellow='\e[1;33m'     # Yellow
BIBlue='\e[1;34m'       # Blue
BIPurple='\e[1;35m'     # Purple
BICyan='\e[1;36m'       # Cyan
BIWhite='\e[1;97m'      # White

# Reset
Reset='\e[0m'           # Reset

STARTSTEP=1
CONFIGFILE=$HOME/setup.conf
SCRIPTFILE=$HOME/setup.sh
SOURCEFILE=$HOME/source.sh
ENCSOURCEFILE="$SOURCEFILE.enc"
SCRIPTNAME=$0

do_test_internet() {
    local COUNT=0

    print_task "Test internet connection" -1 false
    
    while true; do
        run_cmd "ping -c 1 8.8.8.8 > /tmp/setup.err 2>&1 && ! grep -q '100%' /tmp/setup.err" && break
        sleep 10
        
        COUNT=$(( $COUNT + 1 ))
        if (( $COUNT == 3 )) ; then
            print_task "Test internet connection" 1 true
        fi
    done
    
    print_task "Test internet connection" 0 true
}

do_s3fs_credentials() {
    print_task "Create s3fs credential file" -1 false
        
    sudo sh -c "echo $SETUP_S3FS > /etc/passwd-s3fs" > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Create s3fs credential file" 1 true ; fi
    
    sudo chmod 600 /etc/passwd-s3fs > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Create s3fs credential file" 1 true ; fi   
    
    print_task "Create s3fs credential file" 0 true
}

do_download_lua() {
    print_task "Download lua scripts" -1 false
    
    mkdir -p /home/pi/domoticz/scripts/lua > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download lua scripts" 1 true ; fi
    
    wget -O /home/pi/domoticz/scripts/lua/json.lua https://raw.githubusercontent.com/irjdekker/DomoPi/master/lua/json.lua > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download lua scripts" 1 true ; fi
    wget -O /home/pi/domoticz/scripts/lua/main_functions.lua https://raw.githubusercontent.com/irjdekker/DomoPi/master/lua/main_functions.lua > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download lua scripts" 1 true ; fi
    
    sed -i "s/<MAIN_TOKEN>/$MAIN_TOKEN/" /home/pi/domoticz/scripts/lua/main_functions.lua > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download lua scripts" 1 true ; fi
    sed -i "s/<MAIN_USER>/$MAIN_USER/" /home/pi/domoticz/scripts/lua/main_functions.lua > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download lua scripts" 1 true ; fi
    
    chmod 644 /home/pi/domoticz/scripts/lua/*.lua > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download lua scripts" 1 true ; fi

    print_task "Download lua scripts" 0 true 
}

do_download_hue() {
    print_task "Download hue scripts" -1 false
    
    mkdir -p /home/pi/hue > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download hue scripts" 1 true ; fi
    
    wget -O /home/pi/hue/hue_bashlibrary.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/hue/hue_bashlibrary.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download hue scripts" 1 true ; fi
    wget -O /home/pi/hue/strip.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/hue/strip.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download hue scripts" 1 true ; fi
    
    sed -i "s/<STRIP_IP>/$STRIP_IP/" /home/pi/hue/strip.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download hue scripts" 1 true ; fi
    sed -i "s/<STRIP_USERNAME>/$STRIP_USERNAME/" /home/pi/hue/strip.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download hue scripts" 1 true ; fi
    
    STRIP_URL_ESCAPED=$(sed 's/[\/&]/\\&/g' <<< $STRIP_URL)
    sed -i "s/<STRIP_URL>/$STRIP_URL_ESCAPED/" /home/pi/hue/strip.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download hue scripts" 1 true ; fi
    
    chmod 755 /home/pi/easy/*.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download hue scripts" 1 true ; fi

    print_task "Download hue scripts" 0 true 
}

do_download_nefit() {
    print_task "Download nefit easy scripts" -1 false
    
    mkdir -p /home/pi/easy > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi
    
    wget -O /home/pi/easy/easy-server.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/easy/easy-server.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi
    wget -O /home/pi/easy/easy-start.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/easy/easy-start.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi
    wget -O /home/pi/easy/easy-stop.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/easy/easy-stop.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi
    wget -O /home/pi/easy/easy-status.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/easy/easy-status.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi
    
    sed -i "s/<NEFIT_SERIAL_NUMBER>/$NEFIT_SERIAL_NUMBER/" /home/pi/easy/easy-server.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi
    sed -i "s/<NEFIT_ACCESS_KEY>/$NEFIT_ACCESS_KEY/" /home/pi/easy/easy-server.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi
    sed -i "s/<NEFIT_PASSWORD>/$NEFIT_PASSWORD/" /home/pi/easy/easy-server.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi
    
    chmod 755 /home/pi/easy/*.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Download nefit easy scripts" 1 true ; fi

    print_task "Download nefit easy scripts" 0 true 
}

do_unattended_domoticz() {
    print_task "Configure unattended Domoticz" -1 false
    
    sudo mkdir -p /etc/domoticz > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure unattended Domoticz" 1 true ; fi
    
    sudo sh -c 'cat > /etc/domoticz/setupVars.conf << EOF
Dest_folder=/home/pi/domoticz
Enable_http=false
HTTP_port=0
Enable_https=true
HTTPS_port=443
EOF' > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure unattended Domoticz" 1 true ; fi
    
    sudo chmod 644 /etc/domoticz/setupVars.conf > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure unattended Domoticz" 1 true ; fi   
    
    print_task "Configure unattended Domoticz" 0 true
}

do_install_domoticz() {
    print_task "Install Domoticz" -1 false
    
    wget -O /home/pi/domoticz_install.sh https://install.domoticz.com > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Install Domoticz" 1 true ; fi
    chmod 700 /home/pi/domoticz_install.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Install Domoticz" 1 true ; fi
    sed -i "/^\s*updatedomoticz$/s/updatedomoticz/installdomoticz/" /home/pi/domoticz_install.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Install Domoticz" 1 true ; fi
    
    sudo /bin/bash /home/pi/domoticz_install.sh --unattended > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Install Domoticz" 1 true ; fi
    
    sudo sed -i 's/DAEMON_ARGS -www 8080/DAEMON_ARGS -www 0/' /etc/init.d/domoticz.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Install Domoticz" 1 true ; fi
    sudo sed -i 's/DAEMON_ARGS -log /tmp/domoticz.txt/DAEMON_ARGS -log /tmp/domoticz.txt -debug -verbose -loglevel=3/' /etc/init.d/domoticz.sh > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Install Domoticz" 1 true ; fi
    sudo sed -i '/-loglevel=3/ s/^#//' /etc/locale.gen > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Install Domoticz" 1 true ; fi
    
    print_task "Install Domoticz" 0 true
}

do_restore_database() {
    print_task "Restore Domoticz database" -1 false
    
    sudo service domoticz.sh stop > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Restore Domoticz database" 1 true ; fi
    
    if [ -f "/home/pi/s3/domoticz-backup/domoticz.db" ]; then
        sudo cp -f /home/pi/s3/domoticz-backup/domoticz.db /home/pi/domoticz/domoticz.db > $LOGFILE 2>&1
        if [ $? -ne 0 ]; then print_task "Restore Domoticz database" 1 true ; fi
    else
        print_task "Restore Domoticz database" 1 true
    fi
    
    sudo chmod 644 /home/pi/domoticz/domoticz.db > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Restore Domoticz database" 1 true ; fi
    
    sudo chown pi:pi /home/pi/domoticz/domoticz.db > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Restore Domoticz database" 1 true ; fi
    
    sudo service domoticz.sh start > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Restore Domoticz database" 1 true ; fi    
    
    print_task "Restore Domoticz database" 0 true   
}

do_update_boot() {
    print_task "Update boot" -1 false
    
    [ "$(sed -n '1{/console=serial0,115200/p};q' /boot/cmdline.txt)" ] || sudo sed -i "1 s|console=serial0,115200 ||" /boot/cmdline.txt
    if [ $? -ne 0 ]; then print_task "Update boot" 1 true ; fi
    [ "$(sed -n '1{/logo.nologo/p};q' /boot/cmdline.txt)" ] || sudo sed -i "1 s|$| logo.nologo|" /boot/cmdline.txt
    if [ $? -ne 0 ]; then print_task "Update boot" 1 true ; fi
    [ "$(sed -n '1{/loglevel=3/p};q' /boot/cmdline.txt)" ] || sudo sed -i "1 s|$| loglevel=3|" /boot/cmdline.txt
    if [ $? -ne 0 ]; then print_task "Update boot" 1 true ; fi
    [ "$(sed -n '1{/vt.global_cursor_default=0/p};q' /boot/cmdline.txt)" ] || sudo sed -i "1 s|$| vt.global_cursor_default=0|" /boot/cmdline.txt
    if [ $? -ne 0 ]; then print_task "Update boot" 1 true ; fi  
    
    print_task "Update boot" 0 true
}

do_fstab() {
    print_task "Enable RAM drives" -1 false
    
    sudo sh -c 'cat >> /etc/fstab << EOF
tmpfs   /tmp                tmpfs   defaults,noatime,nosuid,size=100m 0 0
tmpfs   /var/tmp            tmpfs   defaults,noatime,nosuid,size=30m 0 0
tmpfs   /var/log            tmpfs   defaults,noatime,nosuid,mode=0755,size=100m 0 0
EOF' > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Enable RAM drives" 1 true ; fi
    
    print_task "Enable RAM drives" 0 true
}

do_fstab_s3fs() {
    print_task "Enable S3 bucket mount" -1 false
    
    sudo sh -c 'cat >> /etc/fstab << EOF
s3fs#domoticz-backup    /home/pi/s3/domoticz-backup     fuse    _netdev,allow_other,url=https://s3-eu-central-1.amazonaws.com,default_acl=private 0 0
EOF' > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Enable S3 bucket mount" 1 true ; fi
    
    print_task "Enable S3 bucket mount" 0 true
}

do_apt_no_add() {
    print_task "Disable additional packages (apt)" -1 false
    
    sudo sh -c 'cat > /etc/apt/apt.conf.d/80noadditional << EOF
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF' > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Disable additional packages (apt)" 1 true ; fi
    
    print_task "Disable additional packages (apt)" 0 true
}

do_ssh() {
    print_task "Enable SSH" -1 false
    
    if ! sudo pstree -p | egrep --quiet --extended-regexp ".*sshd.*\($$\)" > $LOGFILE 2>&1; then
        sudo update-rc.d ssh enable > $LOGFILE 2>&1
        if [ $? -ne 0 ]; then print_task "Enable SSH" 1 true ; fi
        sudo invoke-rc.d ssh start > $LOGFILE 2>&1
        if [ $? -ne 0 ]; then print_task "Enable SSH" 1 true ; fi
    fi
    
    print_task "Enable SSH" 0 true
}

do_change_passwd() {
    print_task "Change password for account pi" -1 false
    
    sudo sh -c "echo 'pi:$SETUP_PASSWD' | chpasswd" > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Change password for account pi" 1 true ; fi
    
    print_task "Change password for account pi" 0 true
}

do_change_hostname() {
    local NEW_HOSTNAME="$1"
    
    print_task "Change hostname" -1 false
    
    if ! CURRENT_HOSTNAME="$(cat /etc/hostname | tr -d ' \t\n\r')"; then
        print_task "Change hostname" 1 true
    fi
    
    sudo sed -i '/^\s*$/d' /etc/hosts > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Change hostname" 1 true ; fi
    sudo sh -c "echo $NEW_HOSTNAME > /etc/hostname" > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Change hostname" 1 true ; fi
    sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Change hostname" 1 true ; fi
    
    print_task "Change hostname" 0 true
}

do_auto_login() {
    print_task "Configure auto login" -1 false
    
    sudo systemctl set-default multi-user.target > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure auto login" 1 true ; fi
    sudo ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure auto login" 1 true ; fi
    sudo sh -c 'cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I linux
EOF' > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure auto login" 1 true ; fi

    print_task "Configure auto login" 0 true
}

do_auto_login_removal() {
    print_task "Remove auto login" -1 false
    
    sudo systemctl set-default multi-user.target > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Remove auto login" 1 true ; fi
    sudo ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Remove auto login" 1 true ; fi
    sudo rm /etc/systemd/system/getty@tty1.service.d/autologin.conf > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Remove auto login" 1 true ; fi

    print_task "Remove auto login" 0 true
}

do_change_timezone() {
    print_task "Change timezone" -1 false
    
    sudo ln -fs /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Change timezone" 1 true ; fi
    sudo dpkg-reconfigure -f noninteractive tzdata > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Change timezone" 1 true ; fi
    
    print_task "Change timezone" 0 true
}

do_change_locale() {
    local LOCALE="$1"
    
    print_task "Configure locale" -1 false
    
    if ! LOCALE_LINE="$(grep "^$LOCALE " /usr/share/i18n/SUPPORTED)"; then
        print_task "Configure locale" 1 true
    fi
    local ENCODING="$(echo $LOCALE_LINE | cut -f2 -d " ")"
    
    sudo sed -i '/^\s*$/d' /etc/locale.gen > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure locale" 1 true ; fi
    sudo sed -i '/^[^#]/ s/\(^.*\)/#\ \1/' /etc/locale.gen > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure locale" 1 true ; fi
    sudo sed -i '/^#.* en_GB.UTF-8 /s/^#\ //' /etc/locale.gen > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure locale" 1 true ; fi
    sudo sed -i "/^#.* $LOCALE /s/^#\ //" /etc/locale.gen > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure locale" 1 true ; fi
    
    sudo locale-gen > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure locale" 1 true ; fi
    sudo update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_TYPE=en_US.UTF-8 > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure locale" 1 true ; fi
    
    sudo dpkg-reconfigure -f noninteractive locales > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure locale" 1 true ; fi
    
    print_task "Configure locale" 0 true
}

do_configure_keyboard() {
    local MODEL="$1"
    local LAYOUT="$2"
    local ERROR="0"
    
    print_task "Configure keyboard" -1 false
    
    sudo sed -i /etc/default/keyboard -e "s/^XKBMODEL.*/XKBMODEL=\"$MODEL\"/" > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure keyboard" 1 true ; fi
    sudo sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$LAYOUT\"/" > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure keyboard" 1 true ; fi
    
    sudo dpkg-reconfigure -f noninteractive keyboard-configuration > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure keyboard" 1 true ; fi
    sudo invoke-rc.d keyboard-setup start > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure keyboard" 1 true ; fi
    sudo setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1' > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure keyboard" 1 true ; fi
    sudo udevadm trigger --subsystem-match=input --action=change > $LOGFILE 2>&1
    if [ $? -ne 0 ]; then print_task "Configure keyboard" 1 true ; fi
    
    print_task "Configure keyboard" 0 true
}

print_task() {
    local TEXT="$1"
    local STATUS="$2"
    local NEWLINE="$3"
  
    if (( $STATUS == -2 )); then
        PRINTTEXT="\r         "  
    elif (( $STATUS == -1 )); then
        PRINTTEXT="\r[      ] "
    elif (( $STATUS == 0 )); then
        PRINTTEXT="\r[  ${IGreen}OK${Reset}  ] "
    elif (( $STATUS >= 1 )); then
        PRINTTEXT="\r[ ${IRed}FAIL${Reset} ] "
    else
        PRINTTEXT="\r         "
    fi  
    
    PRINTTEXT+="$TEXT"
    
    if [ "$NEWLINE" = "true" ] ; then
        PRINTTEXT+="\n"
    fi
    
    printf "$PRINTTEXT"
    
    if (( $STATUS == 1 )); then
        tput cvvis
        exit 1
    fi
}

run_cmd() {
    if eval "$@"; then
        return 0
    else
        return 1
    fi
}

do_task() {
    print_task "$1" -1 false
    run_cmd "$2" && print_task "$1" 0 true || print_task "$1" 1 true
}

get_config() {
    CONFIG=`cat $CONFIGFILE 2>/dev/null`
    
    LOGFILE=`echo $CONFIG | cut -f1 -d " "`
    [[ -z "$LOGFILE" ]] && LOGFILE=$HOME/setup-`date +%Y-%m-%d_%Hh%Mm`.log
    
    STEP=`echo $CONFIG | cut -f2 -d " "`
    [[ -z "$STEP" ]] && STEP=$STARTSTEP
    [[ $STEP != *[[:digit:]]* ]] && STEP=$STARTSTEP
}

############################################################################
##
## MAIN SECTION OF SCRIPT - action begins here
##
#############################################################################
##

tput civis
get_config

# start script for beginning when just downloaded
if [ "$SCRIPTNAME" != "/home/pi/setup.sh" ] ; then
    do_task "Remove script from home directory" "[ -f $SCRIPTFILE ] && rm -f $SCRIPTFILE || sleep 0.1 > $LOGFILE 2>&1"
    do_task "Remove script config file from home directory" "[ -f $CONFIGFILE ] && rm -f $CONFIGFILE || sleep 0.1> $LOGFILE 2>&1"
    do_task "Remove source file from home directory" "[ -f $SOURCEFILE ] && rm -f $SOURCEFILE || sleep 0.1> $LOGFILE 2>&1"    

    # save script in home directory
    do_task "Save script to home directory" "wget -O $SCRIPTFILE https://raw.githubusercontent.com/irjdekker/DomoPi/master/setup.sh > $LOGFILE 2>&1"
    do_task "Change permissions on script" "chmod 700 $SCRIPTFILE > $LOGFILE 2>&1"
    do_task "Save source file to home directory" "wget -O $ENCSOURCEFILE  https://raw.githubusercontent.com/irjdekker/DomoPi/master/source/source.sh.enc > $LOGFILE 2>&1"
    do_task "Decrypt source file" "/usr/bin/openssl enc -aes-256-cbc -d -in $ENCSOURCEFILE -out $SOURCEFILE > $LOGFILE 2>&1"
    do_task "Remove encrypted source file from home directory" "[ -f $ENCSOURCEFILE ] && rm -f $ENCSOURCEFILE || sleep 0.1 > $LOGFILE 2>&1"
    do_task "Change permissions on source file" "chmod 700 $SOURCEFILE > $LOGFILE 2>&1"
fi

# test internet connection
do_test_internet
[ -f $SOURCEFILE ] && source $SOURCEFILE

if (( $STEP == 1 )) ; then   
    # change pi password
    do_change_passwd
    
    # setup auto login
    do_auto_login
    
    # add login script to .bashrc
    do_task "Add script to .bashrc" "grep -qxF '/bin/bash /home/pi/setup.sh' /home/pi/.bashrc || echo '/bin/bash /home/pi/setup.sh' >> /home/pi/.bashrc"
    
    # Update boot configuration 
    do_update_boot
    
    # disable splash screen
    do_task "Disable splash screen" "grep -qxF 'disable_splash=1' /boot/config.txt || echo 'disable_splash=1' | sudo tee -a /boot/config.txt > $LOGFILE 2>&1"
    
    # disable warnings
    do_task "Disable warnings" "grep -qxF 'avoid_warnings=1' /boot/config.txt || echo 'avoid_warnings=1' | sudo tee -a /boot/config.txt > $LOGFILE 2>&1"
    
    # disable WiFi
    do_task "Disable onboard WiFi" "grep -qxF 'dtoverlay=pi3-disable-wifi' /boot/config.txt || echo 'dtoverlay=pi3-disable-wifi' | sudo tee -a /boot/config.txt > $LOGFILE 2>&1"

    # disable onboard bluetooth
    do_task "Disable onboard Bluetooth" "grep -qxF 'dtoverlay=pi3-disable-bt' /boot/config.txt || echo 'dtoverlay=pi3-disable-bt' | sudo tee -a /boot/config.txt > $LOGFILE 2>&1"
    
    # disable plymouth
    do_task "Disable Plymouth" "sudo systemctl mask plymouth-start.service > $LOGFILE 2>&1"

    # disable hciuart
    do_task "Disable hciuart" "sudo systemctl disable hciuart > $LOGFILE 2>&1"
    
    # change baud rate
    do_task "Set baud rate to 9600" "sudo stty -F /dev/ttyAMA0 9600 > $LOGFILE 2>&1"    
    
    # enable RAM drive
    do_fstab
    
    # download lua scripts from github
    do_download_lua
    
    # download nefit scripts from github
    do_download_nefit
    
    # download hue scripts from github
    do_download_hue
    
    # change hostname
    do_change_hostname "domoticz"
fi    

if (( $STEP == 2 )) ; then
    # disable install of additional packages
    do_apt_no_add
    
    # update and upgrade raspberry pi
    do_task "Update raspberry pi" "sudo apt-get -qq -y update > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"
    do_task "Upgrade raspberry pi" "sudo apt-get -qq -y dist-upgrade > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

    # mark all libraries as autoinstalled
    do_task "Mark libraries as autoinstalled" "sudo dpkg-query -Wf '\${binary:Package}\n' 'lib*[!raspberrypi-bin]' | sudo xargs apt-mark auto > $LOGFILE 2>&1"
    
    # remove unused packages
    do_task "Remove unused packages" "sudo apt-get -qq -y autoremove --purge > $LOGFILE 2>&1"
fi

if (( $STEP == 3 )) ; then
    # update raspberry pi firmware
    do_task "Install raspberry pi firmware updater" "sudo apt-get -qq -y install rpi-update > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"
    do_task "Update raspberry pi firmware" "sudo SKIP_WARNING=1 rpi-update > $LOGFILE 2>&1"
fi

if (( $STEP == 4 )) ; then
    # configure keyboard (Logitech G11)
    do_configure_keyboard "pc105" "us"

    # change timezone
    do_change_timezone
    
    # change locale
    do_change_locale "en_US.UTF-8"
    
    # change default language environment
    do_task "Change LANGUAGE environment" "grep -qxF 'LANGUAGE=en_US.UTF-8' /etc/environment || echo 'LANGUAGE=en_US.UTF-8' | sudo tee -a /etc/environment > $LOGFILE 2>&1"
    do_task "Change LC_ALL environment" "grep -qxF 'LC_ALL=en_US.UTF-8' /etc/environment || echo 'LC_ALL=en_US.UTF-8' | sudo tee -a /etc/environment > $LOGFILE 2>&1"
    do_task "Change LANG environment" "grep -qxF 'LANG=en_US.UTF-8' /etc/environment || echo 'LANG=en_US.UTF-8' | sudo tee -a /etc/environment > $LOGFILE 2>&1"
    do_task "Change LC_TYPE environment" "grep -qxF 'LC_TYPE=en_US.UTF-8' /etc/environment || echo 'LC_TYPE=en_US.UTF-8' | sudo tee -a /etc/environment > $LOGFILE 2>&1"
fi

if (( $STEP == 5 )) ; then
    # create s3 backup folder
    do_task "Create s3 backup folder" "sudo mkdir -p /home/pi/s3/domoticz-backup > $LOGFILE 2>&1"
    
    # install s3fs
    do_task "Install s3fs" "sudo apt-get -qq -y install s3fs > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"
    
    # create s3fs credential file
    do_s3fs_credentials
    
    # add mount to fstab
    do_fstab_s3fs
fi

if (( $STEP == 6 )) ; then
    # install nodejs
    do_task "Install nodejs" "sudo apt-get -qq -y install nodejs > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err" 

    # install npm (Node Package Manager)
    do_task "Install npm (Node Package Manager)" "sudo apt-get -qq -y install npm > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"     

    # update npm (Node Package Manager)
    do_task "Update npm (Node Package Manager)" "sudo npm install npm@latest -g > $LOGFILE 2>&1"
    
    # install pm2 (Production Process Manager)
    do_task "Install pm2 (Production Process Manager)" "sudo npm install pm2@latest -g > $LOGFILE 2>&1"
    
    # configure autostart for pm2 (Production Process Manager)
    do_task "Configure autostart for pm2 (Production Process Manager)" "sudo pm2 startup systemd –u pi --hp /home/pi > $LOGFILE 2>&1"
    
    # install nefit easy server
    do_task "Install nefit easy server" "sudo npm install nefit-easy-http-server -g > $LOGFILE 2>&1"
    
    # configure autostart for nefit easy server
    do_task "Start for nefit easy server" "/home/pi/easy/easy-start.sh > $LOGFILE 2>&1"

    # configure unattended Domoticz
    do_unattended_domoticz
    
    # install required library
    do_task "Install library for Domoticz" "sudo apt-get -qq -y install libusb-0.1-4 > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err" 
    
    # install Domoticz
    do_install_domoticz
    
    # update Domoticz to BETA
    do_task "Change folder" "cd /home/pi/domoticz > $LOGFILE 2>&1"
    do_task "Update Domoticz to BETA release" "/home/pi/domoticz/updatebeta > $LOGFILE 2>&1"
    
    # restore database
    do_restore_database
fi

if (( $STEP == 7 )) ; then
    # remove auto login
    do_auto_login_removal
    
    # remove login script from .bashrc
    do_task "Remove script from .bashrc" "sed -i '/\/bin\/bash \/home\/pi\/setup.sh/d' /home/pi/.bashrc"
    
    # remove script/config file
    do_task "Remove script from home directory" "[ -f $SCRIPTFILE ] && rm -f $SCRIPTFILE || sleep 0.1 > $LOGFILE 2>&1"
    do_task "Remove script config file from home directory" "[ -f $CONFIGFILE ] && rm -f $CONFIGFILE || sleep 0.1> $LOGFILE 2>&1"
    do_task "Remove source file from home directory" "[ -f $SOURCFILE ] && rm -f $SOURCFILE || sleep 0.1> $LOGFILE 2>&1" 
    
    # enable ssh
    do_ssh
    
    # reboot at end
    do_task "Reboot" "sleep 10 && reboot"
fi

# used for test purposes
if (( $STEP == 0 )) ; then
    exit 0
fi

STEP=$(( $STEP + 1 ))
echo "$LOGFILE $STEP" > $CONFIGFILE
do_task "Reboot" "sleep 10 && reboot"