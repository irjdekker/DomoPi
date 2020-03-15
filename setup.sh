#!/bin/bash
# shellcheck disable=SC2024
# shellcheck source=/dev/null
##
##  This version of the script (March 2020) includes changes to start initial setup on Raspbian for Domoticz
##
##  This script is the product of many, many months of work and includes
##  (Raspberry Pi - tested on Raspbian Stretch Lite - https://downloads.raspberrypi.org/raspbian_lite_latest)
##
## The easiest way to get the script on your machine is:
## wget -O - https://raw.githubusercontent.com/irjdekker/DomoPi/master/setup.sh 2>/dev/null | bash -s <password>
##
## 27/04/2019 Created initial script
## 26/02/2020 Change script to be more modular and simpler
## 06/03/2020 Added functionality (python script, backup)
##
## Typically, sitting in your home directory (/home/pi) as user Pi you might want to use NANO editor to install this script
## and after giving the script execute permission (sudo chmod 0744 /home/pi/setup.sh)
## you could run the file as ./setup.sh
##
## Updates needed
## - Remove history from both root and pi account
## - Add public key to authorized key file (done - testing required)
## - Configure backup towards S3 (done - testing required)
##
## ROUTINES
## Here at the beginning, a load of useful routines - see further down


# High Intensity
IRed='\e[0;31m'         # Red
IGreen='\e[0;32m'       # Green

# Reset
Reset='\e[0m'           # Reset

STARTSTEP=1
EXECUTIONSETUP=('1,true,true' '2,true,true' '3,true,true' '4,true,true' '5,true,true' '6,true,true' '7,true,true')
CONFIGFILE="$HOME/setup.conf"
SCRIPTFILE="$HOME/setup.sh"
SOURCEFILE="$HOME/source.sh"
ENCSOURCEFILE="$SOURCEFILE.enc"
SCRIPTNAME="$0"

do_test_internet() {
    local COUNT=0

    while true; do
        run_cmd "ping -c 1 8.8.8.8 > /tmp/setup.err 2>&1 && ! grep -q '100%' /tmp/setup.err" && break
        sleep 10

        COUNT=$(( COUNT + 1 ))
        if (( COUNT == 3 )) ; then print_task "$MESSAGE" 1 true ; fi
    done
}

do_change_passwd() {
    do_function_task "echo 'pi:$SETUP_PASSWD' | sudo -S /usr/sbin/chpasswd"
}

do_auto_login() {
    do_function_task "sudo systemctl set-default multi-user.target"
    do_function_task "sudo ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service"
    do_function_task "echo \"[Service]\" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null"
    do_function_task "echo \"ExecStart=\" | sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null"
    do_function_task "echo \"ExecStart=-/sbin/agetty --autologin pi --noclear %I linux\" | sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null"
}

do_update_boot() {
    if [ "$(sed -n '1{/console=serial0,115200/p};q' /boot/cmdline.txt)" ]; then
        do_function_task "sudo sed -i \"1 s|console=serial0,115200 ||\" /boot/cmdline.txt"
    fi
    if [ "$(sed -n '1{/ipv6.disable=1/p};q' /boot/cmdline.txt)" ]; then
        do_function_task "sudo sed -i \"1 s|\$| ipv6.disable=1|\" /boot/cmdline.txt"
    fi
    if [ "$(sed -n '1{/logo.nologo/p};q' /boot/cmdline.txt)" ]; then
        do_function_task "sudo sed -i \"1 s|\$| logo.nologo|\" /boot/cmdline.txt"
    fi
    if [ "$(sed -n '1{/loglevel=3/p};q' /boot/cmdline.txt)" ]; then
        do_function_task "sudo sed -i \"1 s|\$| loglevel=3|\" /boot/cmdline.txt"
    fi
    if [ "$(sed -n '1{/vt.global_cursor_default=0/p};q' /boot/cmdline.txt)" ]; then
        do_function_task "sudo sed -i \"1 s|\$| vt.global_cursor_default=0|\" /boot/cmdline.txt"
    fi
}

do_fstab() {
    do_function_task "echo \"tmpfs   /tmp                tmpfs   defaults,noatime,nosuid,size=100m 0 0\" | sudo tee -a /etc/fstab > /dev/null"
    do_function_task "echo \"tmpfs   /var/tmp            tmpfs   defaults,noatime,nosuid,size=30m 0 0\" | sudo tee -a /etc/fstab > /dev/null"
    do_function_task "echo \"tmpfs   /var/log            tmpfs   defaults,noatime,nosuid,mode=0755,size=100m 0 0\" | sudo tee -a /etc/fstab > /dev/null"
}

do_download_lua() {
    do_function_task "mkdir -p /home/pi/domoticz/scripts/lua"
    do_function_task "wget -O /home/pi/domoticz/scripts/lua/json.lua https://raw.githubusercontent.com/irjdekker/DomoPi/master/lua/json.lua"
    do_function_task "wget -O /home/pi/domoticz/scripts/lua/main_functions.lua https://raw.githubusercontent.com/irjdekker/DomoPi/master/lua/main_functions.lua"
    do_function_task "sed -i \"s/<MAIN_TOKEN>/$MAIN_TOKEN/\" /home/pi/domoticz/scripts/lua/main_functions.lua"
    do_function_task "sed -i \"s/<MAIN_USER>/$MAIN_USER/\" /home/pi/domoticz/scripts/lua/main_functions.lua"
    do_function_task "chmod 600 /home/pi/domoticz/scripts/lua/*.lua"
}

do_download_python() {
    CHECK_URL_ESCAPED="$(sed 's/[\/&]/\\&/g' <<< "$CHECK_URL")"
    do_function_task "mkdir -p /home/pi/domoticz/scripts/python"
    do_function_task "wget -O /home/pi/domoticz/scripts/python/checkZwJam.py https://raw.githubusercontent.com/irjdekker/DomoPi/master/python/checkZwJam.py"
    do_function_task "sed -i \"s/<CHECK_URL>/$CHECK_URL_ESCAPED/\" /home/pi/domoticz/scripts/python/checkZwJam.py"
    do_function_task "chmod 700 /home/pi/domoticz/scripts/python/checkZwJam.py"
}

do_download_nefit() {
    do_function_task "mkdir -p /home/pi/easy"
    do_function_task "wget -O /home/pi/easy/easy-server.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/easy/easy-server.sh"
    do_function_task "wget -O /home/pi/easy/easy-start.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/easy/easy-start.sh"
    do_function_task "wget -O /home/pi/easy/easy-stop.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/easy/easy-stop.sh"
    do_function_task "wget -O /home/pi/easy/easy-status.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/easy/easy-status.sh"
    do_function_task "sed -i \"s/<NEFIT_SERIAL_NUMBER>/$NEFIT_SERIAL_NUMBER/\" /home/pi/easy/easy-server.sh"
    do_function_task "sed -i \"s/<NEFIT_ACCESS_KEY>/$NEFIT_ACCESS_KEY/\" /home/pi/easy/easy-server.sh"
    do_function_task "sed -i \"s/<NEFIT_PASSWORD>/$NEFIT_PASSWORD/\" /home/pi/easy/easy-server.sh"
    do_function_task "chmod 700 /home/pi/easy/*.sh"
}

do_download_hue() {
    STRIP_URL_ESCAPED="$(sed 's/[\/&]/\\&/g' <<< "$STRIP_URL")"
    do_function_task "mkdir -p /home/pi/hue"
    do_function_task "wget -O /home/pi/hue/hue_bashlibrary.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/hue/hue_bashlibrary.sh"
    do_function_task "wget -O /home/pi/hue/strip.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/hue/strip.sh"
    do_function_task "sed -i \"s/<STRIP_IP>/$STRIP_IP/\" /home/pi/hue/strip.sh"
    do_function_task "sed -i \"s/<STRIP_USERNAME>/$STRIP_USERNAME/\" /home/pi/hue/strip.sh"
    do_function_task "sed -i \"s/<STRIP_URL>/$STRIP_URL_ESCAPED/\" /home/pi/hue/strip.sh"
    do_function_task "chmod 700 /home/pi/hue/*.sh"
}

do_download_certificate() {
    do_function_task "mkdir -p /home/pi/certificate"
    do_function_task "wget -O /home/pi/certificate/cf-auth.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/certificate/cf-auth.sh"
    do_function_task "wget -O /home/pi/certificate/cf-clean.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/certificate/cf-clean.sh"
    do_function_task "wget -O /home/pi/certificate/change-cert.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/certificate/change-cert.sh"
    do_function_task "sed -i \"s/<CERT_PASSWD>/$CERT_PASSWD/\" /home/pi/certificate/change-cert.sh"
    do_function_task "sed -i \"s/<CERT_API>/$CERT_API/\" /home/pi/certificate/cf-auth.sh"
    do_function_task "sed -i \"s/<CERT_EMAIL>/$CERT_EMAIL/\" /home/pi/certificate/cf-auth.sh"
    do_function_task "sed -i \"s/<CERT_API>/$CERT_API/\" /home/pi/certificate/cf-clean.sh"
    do_function_task "sed -i \"s/<CERT_EMAIL>/$CERT_EMAIL/\" /home/pi/certificate/cf-clean.sh"
    do_function_task "chmod 700 /home/pi/certificate/*.sh"
}

do_download_bluetooth() {
    do_function_task "mkdir -p /home/pi/bluetooth"
    do_function_task "wget -O /home/pi/bluetooth/btlecheck.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/bluetooth/btlecheck.sh"
    do_function_task "sed -i \"s/<BLUETOOTH_IP>/$DOMOTICZ_IP/\" /home/pi/bluetooth/btlecheck.sh"
    do_function_task "chmod 700 /home/pi/bluetooth/*.sh"
}

do_download_backup() {
    do_function_task "mkdir -p /home/pi/backup"
    do_function_task "wget -O /home/pi/backup/backup.sh https://raw.githubusercontent.com/irjdekker/DomoPi/master/backup/backup.sh"
    do_function_task "sed -i \"s/<DOMOTICZ_IP>/$DOMOTICZ_IP/\" /home/pi/backup/backup.sh"
    do_function_task "chmod 700 /home/pi/backup/*.sh"
}

do_change_hostname() {
    local NEW_HOSTNAME="$1"
    if ! CURRENT_HOSTNAME="$(tr -d ' \t\n\r' < /etc/hostname)"; then print_task "$MESSAGE" 1 true; fi

    do_function_task "sudo sed -i '/^\\s*\$/d' /etc/hosts"
    do_function_task "sudo sed -i \"s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\\t$NEW_HOSTNAME/g\" /etc/hosts"    
    do_function_task "echo \"$NEW_HOSTNAME\" | sudo tee /etc/hostname > /dev/null"
}

do_apt_no_add() {
    do_function_task "echo \"APT::Install-Recommends \\\"0\\\";\" | sudo tee /etc/apt/apt.conf.d/80noadditional"
    do_function_task "echo \"APT::Install-Suggests \\\"0\\\";\" | sudo tee -a /etc/apt/apt.conf.d/80noadditional"
}

do_configure_keyboard() {
    local MODEL="$1"
    local LAYOUT="$2"

    do_function_task "sudo sed -i /etc/default/keyboard -e \"s/^XKBMODEL.*/XKBMODEL=\\\"$MODEL\\\"/\""
    do_function_task "sudo sed -i /etc/default/keyboard -e \"s/^XKBLAYOUT.*/XKBLAYOUT=\\\"$LAYOUT\\\"/\""
    do_function_task "sudo dpkg-reconfigure -f noninteractive keyboard-configuration"
    do_function_task "sudo invoke-rc.d keyboard-setup start"
    do_function_task "sudo setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1'"
    do_function_task "sudo udevadm trigger --subsystem-match=input --action=change"
}

do_change_timezone() {
    do_function_task "sudo ln -fs /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime"
    do_function_task "sudo dpkg-reconfigure -f noninteractive tzdata"
}

do_change_locale() {
    local LOCALE="$1"

    do_function_task "grep -q \"^$LOCALE \" /usr/share/i18n/SUPPORTED"
    do_function_task "sudo sed -i '/^\\s*\$/d' /etc/locale.gen"
    do_function_task "sudo sed -i '/^[^#]/ s/\\(^.*\\)/#\\ \\1/' /etc/locale.gen"
    do_function_task "sudo sed -i '/^#.* en_GB.UTF-8 /s/^#\\ //' /etc/locale.gen"
    do_function_task "sudo sed -i '/^#.* $LOCALE /s/^#\\ //' /etc/locale.gen"
    do_function_task "sudo locale-gen"
    do_function_task "sudo update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_TYPE=en_US.UTF-8"
    do_function_task "sudo dpkg-reconfigure -f noninteractive locales"
}

do_s3fs_credentials() {
    do_function_task "echo \"$SETUP_S3FS\" | sudo tee -a /etc/passwd-s3fs"
    do_function_task "sudo chmod 600 /etc/passwd-s3fs"
}

do_fstab_s3fs() {
    do_function_task "echo \"s3fs#domoticz-backup    /home/pi/s3/domoticz-backup     fuse    _netdev,allow_other,url=https://s3-eu-central-1.amazonaws.com,default_acl=private 0 0\" | sudo tee -a /etc/fstab > /dev/null"
}

do_unattended_domoticz() {
    do_function_task "sudo mkdir -p /etc/domoticz"
    do_function_task "echo \"Dest_folder=/home/pi/domoticz\" | sudo tee /etc/domoticz/setupVars.conf"
    do_function_task "echo \"Enable_http=false\" | sudo tee -a /etc/domoticz/setupVars.conf"
    do_function_task "echo \"HTTP_port=0\" | sudo tee -a /etc/domoticz/setupVars.conf"
    do_function_task "echo \"Enable_https=true\" | sudo tee -a /etc/domoticz/setupVars.conf"
    do_function_task "echo \"HTTPS_port=443\" | sudo tee -a /etc/domoticz/setupVars.conf"
    do_function_task "sudo chmod 600 /etc/domoticz/setupVars.conf"
}

do_install_domoticz() {
    do_function_task "wget -O /home/pi/domoticz_install.sh https://install.domoticz.com"
    do_function_task "chmod 700 /home/pi/domoticz_install.sh"
    do_function_task "sed -i \"/^\\s*updatedomoticz\$/s/updatedomoticz/installdomoticz/\" /home/pi/domoticz_install.sh"
    do_function_task "sudo /bin/bash /home/pi/domoticz_install.sh --unattended"
    do_function_task "sudo sed -i 's/DAEMON_ARGS -www 8080/DAEMON_ARGS -www 0/' /etc/init.d/domoticz.sh"
    do_function_task "sudo sed -i 's/DAEMON_ARGS -sslwww 443/DAEMON_ARGS -sslwww 443 -sslcert \\/home\\/pi\\/domoticz\\/letsencrypt_server_cert.pem/' /etc/init.d/domoticz.sh"
    do_function_task "sudo sed -i 's/DAEMON_ARGS -log \\/tmp\\/domoticz.txt/DAEMON_ARGS -log \\/tmp\\/domoticz.txt -debug -verbose -loglevel=3/' /etc/init.d/domoticz.sh"
    do_function_task "sudo sed -i '/-loglevel=3/ s/^#//' /etc/init.d/domoticz.sh"
    do_function_task "sudo systemctl daemon-reload"
    
    if [ -f /home/pi/domoticz_install.sh ]; then
        do_function_task "rm -f /home/pi/domoticz_install.sh"
    fi
}

do_restore_database() {
    do_function_task "sudo service domoticz.sh stop"

    if [ -f "/home/pi/s3/domoticz-backup/domoticz.db" ]; then
        do_function_task "sudo cp -f -H /home/pi/s3/domoticz-backup/domoticz.db /home/pi/domoticz/domoticz.db"
    else
        print_task "$MESSAGE" 1 true
    fi

    do_function_task "sudo chown root:root /home/pi/domoticz/Config/ozwcache_0xdaa30a14.xml"
    do_function_task "sudo chmod 600 /home/pi/domoticz/domoticz.db"

    if [ -f "/home/pi/s3/domoticz-backup/ozwcache_0xdaa30a14.xml" ]; then
        do_function_task "sudo cp -f -H /home/pi/s3/domoticz-backup/ozwcache_0xdaa30a14.xml /home/pi/domoticz/Config/ozwcache_0xdaa30a14.xml"
    else
        print_task "$MESSAGE" 1 true
    fi

    do_function_task "sudo chown root:root /home/pi/domoticz/Config/ozwcache_0xdaa30a14.xml"
    do_function_task "sudo chmod 600 /home/pi/domoticz/Config/ozwcache_0xdaa30a14.xml"
    do_function_task "sudo service domoticz.sh start"
}

do_configure_postfix() {
    do_function_task "sudo postconf -e \"relayhost = smtp.gmail.com:587\""
    do_function_task "sudo postconf -e \"smtp_sasl_auth_enable = yes\""
    do_function_task "sudo postconf -e \"smtp_sasl_password_maps = hash:/etc/postfix/sasl/sasl_passwd\""
    do_function_task "sudo postconf -e \"smtp_sasl_security_options = noanonymous\""
    do_function_task "sudo postconf -e \"smtp_tls_security_level = may\""
    do_function_task "sudo postconf -e \"header_size_limit = 4096000\""
    do_function_task "echo \"$POSTFIX_PASSWD\" | sudo tee -a /etc/postfix/sasl/sasl_passwd"
    do_function_task "sudo postmap /etc/postfix/sasl/sasl_passwd"
    do_function_task "sudo chown root:root /etc/postfix/sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd.db"
    do_function_task "sudo chmod 600 /etc/postfix/sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd.db"
    do_function_task "sudo service postfix reload"
    do_function_task "sudo systemctl restart postfix"
}

do_configure_unattended() {
    do_function_task "sudo sed -i 's/\\/\\/\\( \\+\"origin=Debian,codename=\${distro_codename}-updates\";\\)/  \\1/' /etc/apt/apt.conf.d/50unattended-upgrades"
    do_function_task "sudo sed -i 's/\\/\\/\\(Unattended-Upgrade::Mail \\+\\).*/\\1\"ir.j.dekker@gmail.com\";/' /etc/apt/apt.conf.d/50unattended-upgrades"
    do_function_task "sudo sed -i 's/\\/\\/\\(Unattended-Upgrade::MailOnlyOnError \\+\\).*/\\1\"true\";/' /etc/apt/apt.conf.d/50unattended-upgrades"
    do_function_task "sudo sed -i 's/\\/\\/\\(Unattended-Upgrade::Remove-Unused-Kernel-Packages \\+\\).*/\\1\"true\";/' /etc/apt/apt.conf.d/50unattended-upgrades"
    do_function_task "sudo sed -i 's/\\/\\/\\(Unattended-Upgrade::Remove-Unused-Dependencies \\+\\).*/\\1\"true\";/' /etc/apt/apt.conf.d/50unattended-upgrades"
    do_function_task "sudo sed -i 's/\\/\\/\\(Unattended-Upgrade::Automatic-Reboot \\+\\).*/\\1\"false\";/' /etc/apt/apt.conf.d/50unattended-upgrades"
    do_function_task "sudo sed -i 's/\\/\\/\\(Unattended-Upgrade::Automatic-Reboot-Time \\+\\).*/\\1\"02:00\";/' /etc/apt/apt.conf.d/50unattended-upgrades"
    do_function_task "echo 'APT::Periodic::Download-Upgradeable-Packages \"1\";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades"
    do_function_task "echo 'APT::Periodic::AutocleanInterval \"7\";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades"
}

do_ssh_key() {
    do_function_task "mkdir -p /home/pi/.ssh"
    do_function_task "chown pi:pi /home/pi/.ssh"
    do_function_task "chmod 700 /home/pi/.ssh"
    do_function_task "wget -O /home/pi/.ssh/authorized_keys https://raw.githubusercontent.com/irjdekker/DomoPi/master/ssh/authorized_keys"
    do_function_task "chmod 600 /home/pi/.ssh/authorized_keys"
}

do_auto_login_removal() {
    do_function_task "sudo systemctl set-default multi-user.target"
    do_function_task "sudo ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service"
    do_function_task "sudo rm /etc/systemd/system/getty@tty1.service.d/autologin.conf"
}

do_ssh() {
    if ! run_cmd "sudo pstree -p | grep -q -E \".*sshd.*\($$\)\""; then
        do_function_task "sudo update-rc.d ssh enable"
        do_function_task "sudo invoke-rc.d ssh start"
    fi
}

print_task() {
    local TEXT="$1"
    local STATUS="$2"
    local NEWLINE="$3"

    if (( STATUS == -2 )); then
        PRINTTEXT="\r         "
    elif (( STATUS == -1 )); then
        PRINTTEXT="\r[      ] "
    elif (( STATUS == 0 )); then
        PRINTTEXT="\r[  ${IGreen}OK${Reset}  ] "
    elif (( STATUS >= 1 )); then
        PRINTTEXT="\r[ ${IRed}FAIL${Reset} ] "
    else
        PRINTTEXT="\r         "
    fi

    PRINTTEXT+="$TEXT"

    if [ "$NEWLINE" = "true" ] ; then
        PRINTTEXT+="\n"
    fi

    printf "%b" "$PRINTTEXT"

    if (( STATUS == 1 )); then
        tput cvvis
        exit 1
    fi
}

run_cmd() {
    if eval "$@" >> "$LOGFILE" 2>&1; then
        return 0
    else
        return 1
    fi
}

do_task() {
    print_task "$1" -1 false
    if run_cmd "$2"; then
        print_task "$1" 0 true
    else
        print_task "$1" 1 true
    fi
}

do_function_task() {
    if ! run_cmd "$1"; then
        print_task "$MESSAGE" 1 true
    fi
}

do_function() {
    MESSAGE="$1"

    print_task "$MESSAGE" -1 false
    eval "$2"
    print_task "$MESSAGE" 0 true
}

get_config() {
    CONFIG=$(cat "$CONFIGFILE" 2>/dev/null)

    LOGFILE=$(echo "$CONFIG" | cut -f1 -d " ")
    [[ -z "$LOGFILE" ]] && LOGFILE="$HOME/setup-$(date +%Y-%m-%d_%Hh%Mm).log"

    STEP=$(echo "$CONFIG" | cut -f2 -d " ")
    [[ -z "$STEP" ]] && STEP=$STARTSTEP
    [[ $STEP != *[[:digit:]]* ]] && STEP=$STARTSTEP
}

execute_step() {
    local EXECUTIONSTEP="$1"
    
    for item in "${EXECUTIONSETUP[@]}"
    do
        if [[ $item == *","* ]]
        then
            IFS=',' read -ra tmpArray <<< "$item"
            tmpStep=${tmpArray[0]}
            tmpExecute=${tmpArray[1]}

            if (( EXECUTIONSTEP == tmpStep )) ; then
                if [ "$tmpExecute" = "true" ] ; then
                    echo "OK"
                    return 1
                else
                    return 0
                fi
            fi
        fi
    done    
}

reboot_step() {
    local EXECUTIONSTEP="$1"
    STEP=$(( STEP + 1 ))
    
    for item in "${EXECUTIONSETUP[@]}"
    do
        if [[ $item == *","* ]]
        then
            IFS=',' read -ra tmpArray <<< "$item"
            tmpStep=${tmpArray[0]}
            tmpExecute=${tmpArray[1]}
            tmpReboot=${tmpArray[2]}
            
            if (( EXECUTIONSTEP == tmpStep )) ; then
                if [ "$tmpExecute" = "true" ] ; then
                    if [ "$tmpReboot" = "true" ] ; then
                        echo "$LOGFILE $STEP" > "$CONFIGFILE"
                        do_task "Reboot" "sleep 10 && reboot"
                        exit 0
                    fi
                fi
            fi
        fi
    done    
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
    # check if argument has been provided
    if [[ $# -eq 0 ]]
    then
        echo "No password supplied"
        exit 1
    fi

    do_task "Remove script from home directory" "[ -f $SCRIPTFILE ] && rm -f $SCRIPTFILE || sleep 0.1"
    do_task "Remove script config file from home directory" "[ -f $CONFIGFILE ] && rm -f $CONFIGFILE || sleep 0.1"
    do_task "Remove source file from home directory" "[ -f $SOURCEFILE ] && rm -f $SOURCEFILE || sleep 0.1"

    # save script in home directory
    do_task "Save script to home directory" "wget -O $SCRIPTFILE https://raw.githubusercontent.com/irjdekker/DomoPi/master/setup.sh"
    do_task "Change permissions on script" "chmod 700 $SCRIPTFILE"
    do_task "Save source file to home directory" "wget -O $ENCSOURCEFILE  https://raw.githubusercontent.com/irjdekker/DomoPi/master/source/source.sh.enc"
    do_task "Decrypt source file" "/usr/bin/openssl enc -aes-256-cbc -d -in $ENCSOURCEFILE -out $SOURCEFILE -pass pass:$1"
    do_task "Remove encrypted source file from home directory" "[ -f $ENCSOURCEFILE ] && rm -f $ENCSOURCEFILE || sleep 0.1"
    do_task "Change permissions on source file" "chmod 700 $SOURCEFILE"
fi

# test internet connection
do_function "Test internet connection" "do_test_internet"
[ -f "$SOURCEFILE" ] && source "$SOURCEFILE"

if (( STEP == 1 )) ; then
    if execute_step "$STEP"; then
        # change pi password
        do_function "Change password for account pi" "do_change_passwd"

        # setup auto login
        do_function "Configure auto login" "do_auto_login"

        # add login script to .bashrc
        do_task "Add script to .bashrc" "grep -qxF '/bin/bash /home/pi/setup.sh' /home/pi/.bashrc || echo '/bin/bash /home/pi/setup.sh' >> /home/pi/.bashrc"

        # update boot configuration
        do_function "Update boot configuration" "do_update_boot"

        # disable splash screen
        do_task "Disable splash screen" "grep -qxF 'disable_splash=1' /boot/config.txt || echo 'disable_splash=1' | sudo tee -a /boot/config.txt"

        # disable warnings
        do_task "Disable warnings" "grep -qxF 'avoid_warnings=1' /boot/config.txt || echo 'avoid_warnings=1' | sudo tee -a /boot/config.txt"

        # disable WiFi
        do_task "Disable onboard WiFi" "grep -qxF 'dtoverlay=pi3-disable-wifi' /boot/config.txt || echo 'dtoverlay=pi3-disable-wifi' | sudo tee -a /boot/config.txt"

        # disable onboard bluetooth
        do_task "Disable onboard Bluetooth" "grep -qxF 'dtoverlay=pi3-disable-bt' /boot/config.txt || echo 'dtoverlay=pi3-disable-bt' | sudo tee -a /boot/config.txt"

        # disable plymouth
        do_task "Disable Plymouth" "sudo systemctl mask plymouth-start.service"

        # disable hciuart
        do_task "Disable hciuart" "sudo systemctl disable hciuart"

        # change baud rate
        do_task "Set baud rate to 9600" "sudo stty -F /dev/ttyAMA0 9600"

        # enable RAM drive
        do_function "Enable RAM drives" "do_fstab"

        # download lua scripts from github
        do_function "Download lua scripts" "do_download_lua"

        # download python scripts from github
        do_function "Download python scripts" "do_download_python"

        # download nefit scripts from github
        do_function "Download nefit easy scripts" "do_download_nefit"

        # download hue scripts from github
        do_function "Download hue scripts" "do_download_hue"

        # download certificate scripts from github
        do_function "Download certificate scripts" "do_download_certificate"

        # download bluetooth scripts from github
        do_function "Download bluetooth scripts" "do_download_bluetooth"

        # download backup scripts from github
        do_function "Download backup scripts" "do_download_backup"

        # change hostname
        do_function "Change hostname" "do_change_hostname \"domoticz\""
    fi
    reboot_step "$STEP"
fi

if (( STEP == 2 )) ; then
    if execute_step "$STEP"; then
        # disable install of additional packages
        do_function "Disable additional packages (apt)" "do_apt_no_add"

        # update and upgrade raspberry pi
        do_task "Update raspberry pi" "sudo apt-get -qq -y update > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"
        do_task "Upgrade raspberry pi" "sudo apt-get -qq -y dist-upgrade > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # mark all libraries as autoinstalled
        do_task "Mark libraries as autoinstalled" "sudo dpkg-query -Wf '\${binary:Package}\n' 'lib*[!raspberrypi-bin]' | sudo xargs apt-mark auto"

        # remove unused packages
        do_task "Remove unused packages" "sudo apt-get -qq -y autoremove --purge"

        # install rpi-update package (*** not required - creates network issue with hue ***)
        do_task "Install rpi-update package" "sudo apt-get -qq -y install rpi-update > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # update raspberry pi to latest kernel and boot (*** not required - creates network issue with hue ***)
        do_task "Update raspberry pi to latest kernel and boot" "sudo SKIP_WARNING=1 rpi-update"
    fi
    reboot_step "$STEP"
fi

if (( STEP == 3 )) ; then
    if execute_step "$STEP"; then
        # configure keyboard (Logitech G11)
        do_function "Configure keyboard" "do_configure_keyboard \"pc105\" \"us\""

        # change timezone
        do_function "Change timezone" "do_change_timezone"  

        # change locale
        do_function "Configure locale" "do_change_locale \"en_US.UTF-8\""

        # change default language environment
        do_task "Change LANGUAGE environment" "grep -qxF 'LANGUAGE=en_US.UTF-8' /etc/environment || echo 'LANGUAGE=en_US.UTF-8' | sudo tee -a /etc/environment"
        do_task "Change LC_ALL environment" "grep -qxF 'LC_ALL=en_US.UTF-8' /etc/environment || echo 'LC_ALL=en_US.UTF-8' | sudo tee -a /etc/environment"
        do_task "Change LANG environment" "grep -qxF 'LANG=en_US.UTF-8' /etc/environment || echo 'LANG=en_US.UTF-8' | sudo tee -a /etc/environment"
        do_task "Change LC_TYPE environment" "grep -qxF 'LC_TYPE=en_US.UTF-8' /etc/environment || echo 'LC_TYPE=en_US.UTF-8' | sudo tee -a /etc/environment"
    fi
    reboot_step "$STEP"
fi

if (( STEP == 4 )) ; then
    if execute_step "$STEP"; then
        # create s3 backup folder
        do_task "Create s3 backup folder" "sudo mkdir -p /home/pi/s3/domoticz-backup"

        # install s3fs
        do_task "Install s3fs" "sudo apt-get -qq -y install s3fs > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # create s3fs credential file
        do_function "Create s3fs credential file" "do_s3fs_credentials"

        # add mount to fstab
        do_function "Enable S3 bucket mount" "do_fstab_s3fs"
    fi
    reboot_step "$STEP"
fi

if (( STEP == 5 )) ; then
    if execute_step "$STEP"; then
        # autostart bluetooth script
        do_task "Configure auto start for bluetooth script" "sudo sed -i 's/^exit 0$/\/home\/pi\/bluetooth\/btlecheck.sh -m1 7C:2F:80:96:37:2C -i1 35 -m2 7C:2F:80:9D:40:A1 -i2 36 2>\&1 \&\n\nexit 0/' /etc/rc.local"

        # install python-requests
        do_task "Install python-requests" "sudo apt-get -qq -y install python-requests > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # install let's encrypted
        do_task "Install certbot" "sudo apt-get -qq -y install certbot > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # install nodejs
        do_task "Install nodejs" "sudo apt-get -qq -y install nodejs > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # install npm (Node Package Manager)
        do_task "Install npm (Node Package Manager)" "sudo apt-get -qq -y install npm > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # update npm (Node Package Manager)
        do_task "Update npm (Node Package Manager)" "sudo npm install npm@latest -g"

        # install pm2 (Production Process Manager)
        do_task "Install pm2 (Production Process Manager)" "sudo npm install pm2@latest -g"

        # configure autostart for pm2 (Production Process Manager)
        do_task "Configure autostart for pm2 (Production Process Manager)" "sudo pm2 startup systemd –u pi --hp /home/pi"

        # change openssl.cnf MinProtocol (for nefit easy server)
        do_task "Change openssl.cnf MinProtocol" "sudo sed -i 's/\(MinProtocol *= *\).*/\1None /' /etc/ssl/openssl.cnf"

        # change openssl.cnf CipherString (for nefit easy server)
        do_task "Change openssl.cnf CipherString" "sudo sed -i 's/\(CipherString *= *\).*/\1DEFAULT /' /etc/ssl/openssl.cnf"

        # install nefit easy server
        do_task "Install nefit easy server" "sudo npm install nefit-easy-http-server -g"

        # configure autostart for nefit easy server
        do_task "Start for nefit easy server" "/home/pi/easy/easy-start.sh"

        # configure unattended Domoticz
        do_function "Configure unattended Domoticz" "do_unattended_domoticz"

        # install required packages
        do_task "Install required packages for Domoticz" "sudo apt-get -qq -y install libusb-0.1-4 python3.5-dev > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # install Domoticz
        do_function "Install Domoticz" "do_install_domoticz"

        # update Domoticz to BETA
        do_task "Change folder" "cd /home/pi/domoticz"
        do_task "Update Domoticz to BETA release" "/home/pi/domoticz/updatebeta"

        # install Mechanon theme
        do_task "Change folder" "cd /home/pi/domoticz/www/styles"
        do_task "Install Mechanon theme" "git clone https://github.com/EdddieN/machinon-domoticz_theme.git machinon"

        # restore database
        do_function "Restore Domoticz database" "do_restore_database"

        # install ssl certificate
        do_task "Install ssl certificate" "/home/pi/certificate/change-cert.sh"

        # configure daily backup
        do_task "Configure daily backup" "sudo ln -sf /home/pi/backup/backup.sh /etc/cron.daily/domo-backup"

        # install postfix
        do_task "Pre-configure postfix domain" "sudo debconf-set-selections <<< 'postfix postfix/mailname string tanix.nl'"
        do_task "Pre-configure postfix domain" "sudo debconf-set-selections <<< 'postfix postfix/main_mailer_type string Internet Site'"
        do_task "Install postfix" "sudo apt-get -qq -y install --assume-yes postfix mailutils > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # configure postfix
        do_function "Configure Postfix" "do_configure_postfix"

        # install unattended-upgrades
        do_task "Install unattended-upgrades" "sudo apt-get -qq -y install unattended-upgrades > /tmp/setup.err 2>&1 && ! grep -q '^[WE]' /tmp/setup.err"

        # configure unattended-upgrades
        do_function "Configure unattended upgrades" "do_configure_unattended"
    fi
    reboot_step "$STEP"
fi

if (( STEP == 6 )) ; then
    if execute_step "$STEP"; then
        # install ssh key
        do_function "Install SSH key" "do_ssh_key"
        
        # enable ssh
        do_funtion "Enable SSH" "do_ssh"

        # harden ssh !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        # remove auto login
        do_function "Remove auto login" "do_auto_login_removal"

        # remove login script from .bashrc
        do_task "Remove script from .bashrc" "sed -i '/\/bin\/bash \/home\/pi\/setup.sh/d' /home/pi/.bashrc"

        # remove script/config file
        do_task "Remove script from home directory" "[ -f $SCRIPTFILE ] && rm -f $SCRIPTFILE || sleep 0.1"
        do_task "Remove script config file from home directory" "[ -f $CONFIGFILE ] && rm -f $CONFIGFILE || sleep 0.1"
        do_task "Remove source file from home directory" "[ -f $SOURCEFILE ] && rm -f $SOURCEFILE || sleep 0.1"

        # reboot at end
        do_task "Reboot" "sleep 10 && reboot"
        exit 0
    fi
    reboot_step "$STEP"
fi

if (( STEP == 7 )) ; then # Only here to store functionality
    if execute_step "$STEP"; then
        do_task "Remove sudo permissions from user pi" "sudo sed -i 's/^/#/g' /etc/sudoers.d/010_pi-nopasswd"
    fi
    reboot_step "$STEP"
fi