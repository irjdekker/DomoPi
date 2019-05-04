#!/bin/bash
echo -e "\033[1;34mStopping domoticz service ...\033[0m"
sudo service domoticz.sh stop
echo -e "\033[1;34mRenewing certificate ...\033[0m"
sudo /usr/bin/certbot certonly --manual --preferred-challenges dns --manual-public-ip-logging-ok --manual-auth-hook /home/pi/certificate/cf-auth.sh --manual-cleanup-hook /home/pi/certificate/cf-clean.sh --rsa-key-size 2048 --renew-by-default --register-unsafely-without-email -d *.tanix.nl
rc=$?;
if [[ $rc != 0 ]]; then
  echo -e "\033[0;31mError occured ...\033[0m"
  echo -e "\033[1;34mStarting domoticz service ...\033[0m"
  sudo service domoticz.sh start
  echo -e "\033[0;31mScript failed ...\033[0m"  
  exit $rc
else
  echo -e "\033[1;34mUpdating domoticz certificate ...\033[0m"
  sudo rm /home/pi/domoticz/letsencrypt_server_cert.pem
  sudo cat /etc/letsencrypt/live/tanix.nl/privkey.pem >> /home/pi/domoticz/letsencrypt_server_cert.pem
  sudo cat /etc/letsencrypt/live/tanix.nl/fullchain.pem >> /home/pi/domoticz/letsencrypt_server_cert.pem
  sudo cat /etc/ssl/certs/dhparam.pem >> /home/pi/domoticz/letsencrypt_server_cert.pem
  sudo openssl pkcs12 -export -inkey /etc/letsencrypt/live/tanix.nl/privkey.pem -in /etc/letsencrypt/live/tanix.nl/fullchain.pem -out /home/pi/domoticz/letsencrypt_server_cert.p12 -name ubnt -password pass:<CERT_PASSWD>
  echo -e "\033[1;34mRestarting system ...\033[0m"
  sudo reboot
  echo -e "\033[1;34mScript ended succesfully ...\033[0m"
fi
