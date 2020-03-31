#!/bin/bash
workdirectory=`dirname "$(readlink -f "$0")"`
current_user=$(whoami)

pm2 stop $workdirectory/easy-server.sh
pm2 save