#!/usr/bin/env bash
###########################################################################
#
#     COPYRIGHT (C) 2024 - HCL Software
#
###########################################################################
#
#     Author:  Casey Cannady - casey.cannady@hcl-software.com
#
###########################################################################
#
#     Script:  reinstall_besclient_mac_osx.sh
#     Version: 1.8
#     Created: 08/01/2024
#     Updated: 08/05/2024
#
###########################################################################
#
#     NOTES:
#
#     (1) This script MUST be run as root on the BESClient endpoints.
#
#     (2) This bash script is provided "as-is" and without warranty.
#
###########################################################################

# Define the BigFix details for KeyStore
bes_key_store="/Library/Application Support/BigFix/BES Agent/KeyStorage"
besclient_ca_cert="__ClientCACertificate.crt"
besclient_cert_req="__ClientCertRequest.req"
besclient_cert="__ClientCertificate.crt"
besclient_pvk="__ClientKey.pvk"
besclient_resp_tmp="__certResponse.tmp"
besclient_key_store_exists=false

# Define the JAMF cache directory
jamf_cache="/Library/Application Support/JAMF/Waiting Room"
jamf_cache_exist=false

# FUNCTION: check if command exists
command_exists () {
  type "$1" &> /dev/null ;
}

# if $1 exists, then set MASTHEADURL
if [ -n "$1" ]; then
  MASTHEADURL="https://$1:52311/masthead/masthead.afxm"
  RELAYFQDN="$1:52311"
  # if parameter contains colon:
  if [[ "$1" == *":"* ]]; then
    MASTHEADURL="https://$1/masthead/masthead.afxm"
    RELAYFQDN=$1
  fi
else
  echo "Must provide FQDN of Root or Relay"
  exit 1
fi

# URLMAJORMINOR is the first two integers of URLVERSION
#  most recent version# found here under `Agent`:  http://support.bigfix.com/bes/release/
URLVERSION=11.0.2.125
URLMAJORMINOR=`echo $URLVERSION | awk -F. '{print $1 $2}'`

# check for x32bit or x64bit OS
MACHINETYPE=`uname -m`

# set OS_BIT variable based upon MACHINE_TYPE (this currently assumes either Intel 32bit or AMD 64bit)
# if machine_type does not contain 64 then 32bit else 64bit (assume 64 unless otherwise noted)
if [[ $MACHINETYPE != *"64"* ]]; then
  OSBIT=x32
else
  OSBIT=x64
fi

# set INSTALLDIR for OS X - other OS options will change this variable
#   This will also be used to create the default clientsettings.cfg file
INSTALLDIR="/tmp"

# Check for BESClient KeyStore files
if [ -f "${bes_key_store}/${besclient_ca_cert}" ] && \
   [ -f "${bes_key_store}/${besclient_cert_req}" ] && \
   [ -f "${bes_key_store}/${besclient_cert}" ] && \
   [ -f "${bes_key_store}/${besclient_pvk}" ] && \
   [ -f "${bes_key_store}/${besclient_resp_tmp}" ]; then
  besclient_key_store_exists=true
fi

# Exit if BESClient KeyStore and known files present
if [ $besclient_key_store_exists ]; then
  (>&2 echo BESClient KeyStore Files Present. ExitCode="2")
  exit 2
fi

# if clientsettings.cfg exists in CWD copy it
if [ -f clientsettings.cfg ] && [ ! -f $INSTALLDIR/clientsettings.cfg ] ; then
  cp clientsettings.cfg $INSTALLDIR/clientsettings.cfg
fi

if [ ! -f $INSTALLDIR/clientsettings.cfg ] ; then
  # create clientsettings.cfg file
  echo -n > $INSTALLDIR/clientsettings.cfg
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_RelaySelect_FailoverRelay=https://$RELAYFQDN/bfmirror/downloads/
  >> $INSTALLDIR/clientsettings.cfg echo __RelaySelect_Automatic=1
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Resource_StartupNormalSpeed=1
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Download_RetryMinutes=1
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Download_CheckAvailabilitySeconds=120
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Resource_WorkIdle=20
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Resource_SleepIdle=500
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Resource_PowerSaveEnable=1
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Query_SleepTime=500
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Query_WorkTime=250
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Query_NMOMaxQueryTime=30
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Resource_AccelerateForPendingMessage=1
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Comm_CommandPollEnable=1
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Comm_CommandPollIntervalSeconds=1800
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Log_Days=30
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Log_MaxSize=1536000
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Download_UtilitiesCacheLimitMB=500
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Download_DownloadsCacheLimitMB=5000
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_Download_MinimumDiskFreeMB=2000
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_ActionManager_HistoryKeepDays=1825
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_ActionManager_HistoryDisplayDaysTech=90
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_ActionManager_CompletionDialogTimeoutSeconds=30
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_PersistentConnection_Enabled=1
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_ActionManager_OverrideTimeoutSeconds=21600
  >> $INSTALLDIR/clientsettings.cfg echo _BESClient_InstallTime_User=`echo $SUDO_USER`
fi

if [[ $OSTYPE == darwin* ]]; then
  # Mac OS X
  INSTALLERURL="https://software.bigfix.com/download/bes/$URLMAJORMINOR/BESAgent-$URLVERSION-BigFix_MacOS11.0.pkg"
  INSTALLER="/tmp/BESAgent.pkg"
else
  echo "Supports Mac OS only."
  exit 3
fi

# MUST HAVE ROOT PRIV
if [ "$(id -u)" != "0" ]; then
  # dump out data for debugging
  echo
  echo OSTYPE=$OSTYPE
  echo MACHINETYPE=$MACHINETYPE
  echo OSBIT=$OSBIT
  echo INSTALLDIR=$INSTALLDIR
  echo INSTALLER=$INSTALLER
  echo INSTALLERURL=$INSTALLERURL
  echo URLBITS=$URLBITS
  echo URLVERSION=$URLVERSION
  echo URLMAJORMINOR=$URLMAJORMINOR
  echo MASTHEADURL=$MASTHEADURL
  echo DEBDIST=$DEBDIST
  echo
  echo "Sorry, you are not root. Exiting."
  echo
  exit 4
fi

# Create $INSTALLDIR folder if missing
if [ ! -d "$INSTALLDIR" ]; then
  # Control will enter here if $INSTALLDIR doesn't exist.
  mkdir $INSTALLDIR
fi

# Check for existance of BESClient log file and installer in local JAMF cache
if [find "$jamf_cache" -maxdepth 1 -name "BESAgent-*-BigFix_MacOS11.0.pkg" -print -quit | grep -q .]; then
    echo "BESAgent installer package found in Jamf Pro cache.";
    INSTALLER=$(find "$jamf_cache" -maxdepth 1 -name "BESAgent-*-BigFix_MacOS11.0.pkg" -print -quit)
    jamf_cache_exist=true
fi

DLEXITCODE=0
if (! $jamf_cache_exist) then
  if command_exists curl ; then
    curl -o "$INSTALLER" "$INSTALLERURL"
    DLEXITCODE=$(( DLEXITCODE + $? ))

    curl --insecure -o "$INSTALLDIR/actionsite.afxm" "$MASTHEADURL"
    DLEXITCODE=$(( DLEXITCODE + $? ))
  else
    if command_exists wget ; then
      # this is run if curl doesn't exist, but wget does download using wget
      wget "$MASTHEADURL" -O "$INSTALLDIR/actionsite.afxm" --no-check-certificate
      DLEXITCODE=$(( DLEXITCODE + $? ))

      wget "$INSTALLERURL" -O "$INSTALLER"
      DLEXITCODE=$(( DLEXITCODE + $? ))
    else
      echo neither wget nor curl is installed.
      echo not able to download required files.
      echo exiting...
      exit 4
    fi
  fi

  # Exit if download failed
  if [ $DLEXITCODE -ne 0 ]; then
    (>&2 echo Download Failed. ExitCode=$DLEXITCODE)
    exit $DLEXITCODE
  fi
fi

# Reinstall BigFix client
if [[ $INSTALLER == *.pkg ]]; then
  # PKG type
  #   Could be Mac OS X
  if command_exists installer ; then
    #  Mac OS X
    installer -pkg $INSTALLER -target /
  fi # installer
fi # *.pkg install file

# if missing, create besclient.config file based upon /tmp/clientsettings.cfg
if [ ! -f /var/opt/BESClient/besclient.config ]; then
  cat /tmp/clientsettings.cfg | awk 'BEGIN { print "[Software\\BigFix\\EnterpriseClient]"; print "EnterpriseClientFolder = /opt/BESClient"; print; print "[Software\\BigFix\\EnterpriseClient\\GlobalOptions]"; print "StoragePath = /var/opt/BESClient"; print "LibPath = /opt/BESClient/BESLib"; } /=/ {gsub(/=/, " "); print "\n[Software\\BigFix\\EnterpriseClient\\Settings\\Client\\" $1 "]\nvalue = " $2;}' > /var/opt/BESClient/besclient.config
  chmod 600 /var/opt/BESClient/besclient.config
fi

### start the BigFix client
echo "Restarting BESClient..."
if launchctl unload /Library/LaunchDaemons/com.bigfix.BESAgent.plist && launchctl load /Library/LaunchDaemons/com.bigfix.BESAgent.plist; then
    echo "BESClient restarted successfully."
else
    echo "Failed to restart BESClient. Please check the system logs for more information."
    exit 5
fi

# pause 30 seconds to wait for bigfix to get going a bit
echo "sleep for 60 seconds"
sleep 60

# Tail the last 25 lines of today's BESClient log file
if [ -f "/var/opt/BESClient/__BESData/__Global/Logs/`date +%Y%m%d`.log" ]; then
  tail --lines=25 --verbose "/var/opt/BESClient/__BESData/__Global/Logs/`date +%Y%m%d`.log"
fi