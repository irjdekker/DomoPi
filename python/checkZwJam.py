#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Check a zwave device with polling enabled presence and trigger
# a virtual switch to indicate possible radio jam if not seen...
#
# Returns 0 if no jamming, 1 if jamming, -1 if an error occured.
# But return value cannot be used from Lua??? So use -s.
#
# Changelog : 21/01/2017, YL, 1st version.
#
# run at install on domoticz: sudo apt-get install python-requests

import getopt
import logging
import json
import sys
import requests
import datetime

#####################
# EDITABLE SETTINGS #
#####################

logLevel='DEBUG' # DEBUG / INFO

# Domoticz json API url
dmtJurl         = 'https://domoticz.tanix.nl/json.htm?'

# Command parameters in json format (only change if API change!)
dmtJsonGetZwNodes = {"type":"openzwavenodes", "idx":"999"}
dmtJsonSwitch = {"type":"command", "param":"switchlight", "idx":999, "switchcmd":"Off"}

# Domoticz time format on LUA side:
dmtLuaTimeFmt   = "%Y-%m-%d %H:%M:%S"

#####################
def usage():
    """
    Display usage
    """

    sys.stderr.write( "Usage: ChkZwJam.py [-h] [-c<CtrlIdx>] [-j<jamSwitchIdx>] [-n<DevName>] [-m<missedPollNbLimit>] -s[<0|1>]\n")
    sys.stderr.write( "       'c' = IDx of Z-Wave controller.\n")
    sys.stderr.write( "       'j' = IDx of Z-Wave jamming vSwitch.\n")
    sys.stderr.write( "       'n' = Z-Wave device name to monitor.\n")
    sys.stderr.write( "       'm' = Missed poll(s) nb for device not seen alert.\n")
    sys.stderr.write( "       's' = Current state from Lua (need update eval).\n")

#####################
def dmtJsonApi(url, jsonApiCmd, logger):
    """
    Send Domoticz json command
    """

    try:
        # Connect to Domoticz via JSON API and send data
        dmtRget=requests.get(url, params=jsonApiCmd)
    except requests.exceptions.RequestException as dmtErr:
        logger.log(logging.ERROR, "Unable to connect with URL=%s \nGet requests error %s" % (dmtRget.url, dmtErr))
    finally:
        logger.log(logging.DEBUG, "Sent data: [%s]" % (dmtRget.url))

	return dmtRget.json()

#####################
def main(argv):
    """
    Main
    """

    logging.basicConfig()
    logger = logging.getLogger()
    handler = logging.StreamHandler(sys.stdout)

    # Checks the parameters
    try:
        opts, args = getopt.getopt(argv, "h:c:j:n:m:s:",["help","ctlIdx","jamIdx","name","miss","state"])
    except getopt.GetoptError:
        usage()
        sys.exit(-1)

    # Defaults
    devName       = 'Trap'
    missPollLimit = 3
    ctlIdx        = '4'
    jamIdx        = '561'
    curState      = 0

    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit(-1)
        if o in ("-c", "--ctlIdx" ):
            ctlIdx=a
        if o in ("-j", "--jamIdx" ):
            jamIdx=a
        if o in ("-n", "--name" ):
            devName=a
        if o in ("-m", "--miss" ):
            missPollLimit=int(a)
        if o in ("-s", "--state" ):
            curState=int(a)

    # Configure the logger
    handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    logger.setLevel(logLevel)

    dmtJsonSwitch['idx'] = jamIdx
    logger.log(logging.DEBUG, "Controler IDx=%s, Jamming vSwitch IDx=%s, Device=%s, Miss Poll Limit=%ds." %(ctlIdx, jamIdx, devName, missPollLimit))

    # Get all zwave nodes data
    dmtJsonGetZwNodes['idx'] = ctlIdx
    zwNodesData = dmtJsonApi(dmtJurl, dmtJsonGetZwNodes, logger)
    # logger.log(logging.DEBUG, "Zwave Nodes: [%s]" % (zwNodesData))

    # Get devices nb...
    devNb=len(zwNodesData['result'])
    logger.log(logging.DEBUG, "Found %d nodes, extract data for %s" % (devNb, devName))

    if (devNb < 2):
        logger.log(logging.INFO, "%d < 2 devices found !!!", devNb)
        sys.exit(-1)

    # Get controller poll interval
    if (zwNodesData['result'][0]['config'][0]['label'] == 'Poll Interval'):
        pollSec = int(zwNodesData['result'][0]['config'][0]['value'])
        logger.log(logging.DEBUG, 'Controller Poll Interval = %dsec.', pollSec)
    else:
        logger.log(logging.INFO, "Cannot find controller poll interval config !!!")
        sys.exit(-1)

    # Find device to poll using it's name...
    devFound = 0
    for node in zwNodesData['result']:
        if (node['Name'] == devName):
            logger.log(logging.DEBUG, 'Found: %s ; PollEnabled=%s ; LastUpdate=%s',
                       node['Name'],
                       node['PollEnabled'],
                       node['LastUpdate'])
            devFound = 1
            break

    # Device name not found, exit...
    if (devFound == 0):
        logger.log(logging.INFO, "Device %s : NOT FOUND." % devName)
        sys.exit(-1)

    # If found node is poll enabled, check last seen time vs current...
    ret = 0
    if (node['PollEnabled'] == 'true'):
        curDate = datetime.datetime.now()
        lstDate = datetime.datetime.strptime(node['LastUpdate'], dmtLuaTimeFmt)
        lastSec = (curDate - lstDate).seconds
        logger.log(logging.DEBUG, "Current date/time : %s", curDate)
        logger.log(logging.DEBUG, "LastUpd date/time : %s (%s) ; Diff=%ssec.", node['LastUpdate'], node['Name'], lastSec)

        if (lastSec > (pollSec * missPollLimit)):
            logger.log(logging.INFO, "%s: No poll response since %dsec ; Jamming?", devName, lastSec)
            print('JAMMING')
            ret = 1
            if (curState == 0):
                dmtJsonSwitch['switchcmd'] = 'On'
                dmtJsonApi(dmtJurl, dmtJsonSwitch, logger)
        else:
            if (curState == 1):
                dmtJsonSwitch['switchcmd'] = 'Off'
                dmtJsonApi(dmtJurl, dmtJsonSwitch, logger)
    else:
        logger.log(logging.INFO, "Must enable device polling !!!")
        sys.exit(-1)

    # Happy ending!
    logger.log(logging.DEBUG, "%s: Last=%ds / Poll=%ds (Miss limit=%d).", devName, lastSec, pollSec, missPollLimit)

    sys.exit(ret)

if __name__ == "__main__":
    main(sys.argv[1:])
