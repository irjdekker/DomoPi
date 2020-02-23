#!/bin/bash

while [[ $# > 1 ]]
do
  key="$1"

  case $key in
    -m1|--mac1)
      MACADDRESS1="$2"
      shift
      ;;
    -i1|--id1)
      DOMOID1="$2"
      shift
      ;;
    -m2|--mac2)
      MACADDRESS2="$2"
      shift
      ;;
    -i2|--id2)
      DOMOID2="$2"
      shift
      ;;
    *)
      # unknown option
      ;;
  esac

  shift
done

SERVER="<DOMOTICZ_IP>"
PORT="443"
CHECK=0

Tag() {
  CHECK=$1
  MACADDRESS=$2
  DOMOID=$3

  curl -k -s "https://$SERVER:$PORT/json.htm?type=devices&rid=$DOMOID" | grep "Status" | grep "On" > /dev/null
 
  if [[ $? -eq 0 ]]; then
    TAG_STATUS="online"
  else
    TAG_STATUS="offline"
  fi

  if [[ $CHECK -eq 1 ]]; then
    if [[ -f /tmp/$MACADDRESS.up ]]; then
      LASTUPDATE=$(stat -c %Y /tmp/$MACADDRESS.up)
      NOW=$(date +%s)
      DIFF=$(( NOW-LASTUPDATE ))

      if [[ "${DIFF:-0}" -gt 15 ]]; then
        if [[ $TAG_STATUS == "offline" ]]; then
          curl -k -s "Accept: application/json" "https://$SERVER:$PORT/json.htm?type=command&param=switchlight&idx=$DOMOID&switchcmd=On"
        fi
      fi
    else
       touch /tmp/$MACADDRESS.up

       if [[ -f /tmp/$MACADDRESS.down ]]; then
         rm -f /tmp/$MACADDRESS.down
       fi
    fi
  else
    if [[ -f /tmp/$MACADDRESS.down ]]; then
      LASTUPDATE=$(stat -c %Y /tmp/$MACADDRESS.down)
      NOW=$(date +%s)
      DIFF=$(( NOW-LASTUPDATE ))

      if [[ "${DIFF:-0}" -gt 15 ]]; then
        if [[ $TAG_STATUS == "online" ]]; then
          curl -k -s "Accept: application/json" "https://$SERVER:$PORT/json.htm?type=command&param=switchlight&idx=$DOMOID&switchcmd=Off"
        fi
      fi
    else
       touch /tmp/$MACADDRESS.down

       if [[ -f /tmp/$MACADDRESS.up ]]; then
         rm -f /tmp/$MACADDRESS.up
       fi
    fi
  fi
}

while :
do
  sudo hcitool lescan --passive > /tmp/lescan.tmp &
  sleep 5

  if [ "$(pidof hcitool)" ]; then
    sudo pkill --signal SIGINT hcitool
    sleep 1

    CHECK1=0
    CHECK2=0

    while read line
    do
      if [[ $line =~ ^$MACADDRESS1.*$ ]]; then
        CHECK1=1
      fi

      if [[ $line =~ ^$MACADDRESS2.*$ ]]; then
        CHECK2=1
      fi
    done < /tmp/lescan.tmp

    Tag $CHECK1 $MACADDRESS1 $DOMOID1
    Tag $CHECK2 $MACADDRESS2 $DOMOID2
  fi

  sleep 5
done
