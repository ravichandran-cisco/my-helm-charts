#!/bin/sh

#
# Copyright (C) 2022 by Cisco Systems, Inc. All rights reserved
# This program contains proprietary and confidential information.
#
# Purpose: This script initializes a CNR instance by creating
#          an administrator account (username and password),
#          and registering the instance with a regional server.
#          
#          The following are input options:
#
#        -N <username>     administrator username
#        -P <password>   administrator password
#        -p <port>       Regional Server CCM Port. Default 1244.
#        -f <file>       CNR license file
#
#       Alternatively, the following environment variables can be set:
#
#        CNR_USERNAME          administrator username
#        CNR_PASSWORD          administrator password
#         CNR_REGIONAL_CCM_PORT  Regional Server CCM Port. Default 1244.
#        CNR_LICENSE_FILE      CNR license file.
#

dbug()
{
  DEBUG=0
  if [ $DEBUG -ne 0 ]
  then
   echo "debug: $1"
  fi
  return 1
}

logmsg()
{
   ts=`date`
    echo "$ts: $1"
    return 1
}


##########################################################
# Start
#
logmsg "Beginning cnr_init_regional..."

# 
# Read the input arguments
#
system_service=nwregregional

username=${CNR_USERNAME}
password=${CNR_PASSWORD}
cnr_license_file=${CNR_LICENSE_FILE}

regional_ccm_port=${CNR_REGIONAL_CCM_PORT}
if [[ -z "$regional_ccm_port" ]]; then
   regional_ccm_port=1244  # default regional ccm port
fi

while getopts N:P:f:p: flag
do
    case "${flag}" in
        N) username=${OPTARG};; 
        P) password=${OPTARG};;
        p) regional_ccm_port=${OPTARG};; 
        f) cnr_license_file=${OPTARG};; 
    esac
done


# Check that we have the appropriate input arguments
if [[ ! -z "$username" && ! -z "$password" && ! -z "$cnr_license_file" ]];
then
   dbug "-N: $username, -P: $password, -p: $regional_ccm_port, -f: $cnr_license_file"
else
   dbug "Missing required settings in input arguments and environment variables"
   exit 1
fi

#
# Check that the service is enabled
#
logmsg "Checking that $system_service is enabled"

system_service_enabled=`systemctl is-enabled $system_service`
dbug "systemctl is-enabled $system_service"

# check if we got anything from the command
if [ -z $system_service_enabled ] 
then 
   system_service_enabled="disabled"
fi

if [ $system_service_enabled = "enabled" ]; then 
   dbug "system-service: $system_service status: $system_service_enabled"
else
   dbug "CNR SERVICE $system_service IS DISABLED"
   exit 1
fi

#
# Check if license file exists
#
if [ -f $cnr_license_file ]; 
then
  dbug "License file $cnr_license_file was found"
else
  logmsg "License file $cnr_license_file not found"
  exit 1
fi

# 
# Start CNR Service, wait 10 seconds 
#
logmsg "Starting CNR service $system_service"
systemctl start $system_service
sleep 10

#
# Update cnr.conf with the setting for cnr.ccm-port
# 
conf_file="/var/nwreg2/regional/conf/cnr.conf"
logmsg "Updating cnr.ccm-port in $conf_file"
# cnr.ccm-port
unset line
unset repl
line=`grep "cnr.ccm-port\=" $conf_file`
repl="cnr.ccm-port=$regional_ccm_port"

if [ ! -z "$line" ]
then
   dbug "replacing $line with $repl in $conf_file"
   sed -i "s/$line/$repl/g" $conf_file
else
   dbug "adding $repl to $conf_file"
   echo $repl >> $conf_file
fi

#
# Create admin account
#
logmsg "Creating administrator account for $username"
result=`/opt/nwreg2/regional/usrbin/nrcmd -R -K -N $username -P $password << EOF
exit
EOF`
echo $result

#
# Disable smart licensing
#
logmsg "Disabling Smart Licensing"
nrcmd_license_script="/var/nwreg2/regional/temp/cnr_license.nrcmd"
rm -f $nrcmd_license_script
echo "smart" >> $nrcmd_license_script
echo "no license smart enable" >> $nrcmd_license_script
echo "exit" >> $nrcmd_license_script
/opt/nwreg2/regional/usrbin/nrcmd -R -N $username -P $password -b < $nrcmd_license_script
rm -f $nrcmd_license_script


#
# Copy the license file to /var/nwreg2/regional/conf/product.licenses
#
sleep 10
logmsg "Making a copy of license file $cnr_license_file"
cnr_product_licenses="/var/nwreg2/regional/conf/product.licenses"
cp -f $cnr_license_file $cnr_product_licenses

#
# Restart CNR
#
logmsg "Restarting CNR service $system_service"
systemctl stop $system_service
systemctl start $system_service 
sleep 10


logmsg "Finished cnr_init_regional."
exit 0
