#!/bin/bash

# Hue WakeUpLight, version 1.0
# Written 2013 by Markus Proske, released under GNU GENERAL PUBLIC LICENSE v2, see LICENSE 
# Google+: https://plus.google.com/+MarkusProske
# Github: https://github.com/markusproske
# -----------------------------------------------------------------------------------------

# Note: the library relies on curl to be installed on your system.
# Type which curl or curl --help in your Terminal to see if it is installed
# If not, install with sudo apt-get install curl

# CONFIGURATION
# -----------------------------------------------------------------------------------------
workdirectory=`dirname "$(readlink -f "$0")"`
current_user=$(whoami)
source $workdirectory/hue_bashlibrary.sh

# Mind the gap: do not change the names of these variables, the bash_library needs those...
ip='<STRIP_IP>'						# IP of hue bridge, enter your bridge IP here!
devicetype='raspberry'				# Link with bridge: type of device
username='<STRIP_USERNAME>'				# Link with bridge: username / app name (min 10 characters)
loglevel=2							# 0 all logging off, # 1 gossip, # 2 verbose, # 3 errors

# Variables of this scripts
lights='4'					# Define the lights you want to use, e.g. '3' or '3 4' or '3 4 7 9'

# MAIN
# -----------------------------------------------------------------------------------------

minbri=0
maxbri=255
minsat=192
maxsat=255
changetime=80
totaltime=50

let satdelta=$maxsat-$minsat+1
let bridelta=$maxbri-$minbri+1

log 2 "StripLight started (lights: $lights)."

let curhue=$RANDOM*2
let cursat=$minsat+$RANDOM%$satdelta
let curbri=$minbri+$RANDOM%$bridelta
let huestep=32767/$changetime

hue_on_hue_sat_brightness $curhue $cursat $curbri $lights

for i in `seq 1 $totaltime`;
do
	let newsat=$minsat+$RANDOM%$satdelta
        let satstep=$newsat-$cursat
	let newbri=$minbri+$RANDOM%$bridelta
        let bristep=$newbri-$curbri

	for j in `seq 1 $changetime`;
	do
                let curhue=$curhue+$huestep
                if [ $curhue -gt 65535 ]
                then
                       let curhue=$curhue-65535
                fi

		let calcsat=$cursat+$j*$satstep/$changetime
		let calcbri=$curbri+$j*$bristep/$changetime
		hue_setstate_hue_sat $curhue $calcsat $lights
		hue_setstate_brightness $calcbri $lights
	done

	let cursat=$newsat
	let curbri=$newbri
done

curl "<STRIP_URL>"
log 2 "StripLight finished, lights turned off."