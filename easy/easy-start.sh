#!/bin/bash
workdirectory=`dirname "$(readlink -f "$0")"`
current_user=$(whoami)

pm2 start $workdirectory/easy-server.sh
pm2 save