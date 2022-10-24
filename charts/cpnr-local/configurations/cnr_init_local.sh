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
#                       -N <username>   administrator username
#                       -P <password>   administrator password
#                       -i <ipaddress>  Regional Server IP Address
#                       -p <port>       Regional Server CCM Port. Default 1244.
#                 -l <port>      Local Server CCM Port. Default 1234.
#                 -d <port>      Local Server DNS Port. Default 53.
#                       -s <service>    Service to provision (dns, cdns or dhcp). Default cdns.
#
#                 Alternatively, the following environment variables can be set:
#
#               CNR_USERNAME                            administrator username
#                       CNR_PASSWORD                    administrator password
#                       CNR_REGIONAL_IP                 Regional Server IP Address
#                       CNR_REGIONAL_CCM_PORT           Regional Server CCM Port. Default 1244.
#                 CNR_LOCAL_CCM_PORT            Local Server CCM Port. Default 1234.
#                 CNR_DNS_PORT               DNS server port. Default 53.
#                 CNR_HTTPS_PORT               DNS server port. Default 8443. 
#                       CNR_SERVICE                     Service to provision (dns, cdns or dhcp). Default cdns.
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
logmsg "Beginning cnr_init_local..."
# 
# Read the input arguments
#
system_service=nwreglocal 

username=${CNR_USERNAME}
password=${CNR_PASSWORD}
regional_ip=${CNR_REGIONAL_IP}

regional_ccm_port=${CNR_REGIONAL_CCM_PORT}
if [[ -z "$regional_ccm_port" ]]; then
   regional_ccm_port=1244       # default regional ccm port
fi

local_ccm_port=${CNR_LOCAL_CCM_PORT}
if [[ -z "$local_ccm_port" ]]; then
   local_ccm_port=1234       # default local ccm port
fi

dns_port=${CNR_DNS_PORT}
if [[ -z "$dns_port" ]]; then
   dns_port=53       # default DNS port
fi

https_port=${CNR_HTTPS_PORT}
if [[ -z "$https_port" ]]; then
   https_port=8443       # default https port
fi

cnr_service=${CNR_SERVICE}
if [[ -z "$cnr_service" ]]; then
   cnr_service=cdns     # defaults to cdns service
fi

while getopts N:P:i:p:l:d:s: flag
do
    case "${flag}" in
        N) username=${OPTARG};; 
        P) password=${OPTARG};;
        i) regional_ip=${OPTARG};; 
        p) regional_ccm_port=${OPTARG};;
        l) local_ccm_port=${OPTARG};;
        d) dns_port=${OPTARG};;
        h) https_port=${OPTARG};;
        s) cnr_service=${OPTARG};; 
    esac
done


# Check that we have the appropriate input arguments
if [[ ! -z "$username" && ! -z "$password" && ! -z "$regional_ip" ]];
then
   dbug "-N: $username, -P: $password, -i: $regional_ip, -p: $regional_ccm_port, -s: $cnr_service"
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
# Start CNR Service, wait 5 seconds and create admin account
#
logmsg "Starting CNR service $system_service"
systemctl start $system_service
sleep 10


#
# Create admin account
#
logmsg "Creating administrator account for $username"
result=`/opt/nwreg2/local/usrbin/nrcmd -K -N $username -P $password << EOF
exit
EOF`
echo $result

#
# Update cnr.conf with the setting for cnr.services, cnr.regional-ip, cnr.regional-ccm-port
# 
conf_file="/var/nwreg2/local/conf/cnr.conf"
logmsg "Updating $conf_file"

# cnr.services
unset line
unset repl
line=`grep "cnr.services\=" $conf_file`
repl="cnr.services=$cnr_service"

if [ ! -z "$line" ]
then
   logmsg "replacing $line with $repl in $conf_file"
   sed -i "s/$line/$repl/g" $conf_file
else
   dbug "adding $repl to $conf_file"
   echo $repl >> $conf_file
fi


# cnr.regional-ip
unset line
unset repl
line=`grep "cnr.regional-ip\=" $conf_file`
repl="cnr.regional-ip=$regional_ip"

if [ ! -z "$line" ]
then
   logmsg "replacing $line with $repl in $conf_file"
   sed -i "s/$line/$repl/g" $conf_file
else
   dbug "adding $repl to $conf_file"
   echo $repl >> $conf_file
fi


# cnr.regional-ccm-port
unset line
unset repl
line=`grep "cnr.regional-ccm-port\=" $conf_file`
repl="cnr.regional-ccm-port=$regional_ccm_port"

if [ ! -z "$line" ]
then
   dbug "replacing $line with $repl in $conf_file"
   sed -i "s/$line/$repl/g" $conf_file
else
   dbug "adding $repl to $conf_file"
   echo $repl >> $conf_file
fi

# cnr.ccm-port
unset line
unset repl
line=`grep "cnr.ccm-port\=" $conf_file`
repl="cnr.ccm-port=$local_ccm_port"

if [ ! -z "$line" ]
then
   dbug "replacing $line with $repl in $conf_file"
   sed -i "s/$line/$repl/g" $conf_file
else
   dbug "adding $repl to $conf_file"
   echo $repl >> $conf_file
fi

# cnr.https-port
unset line
unset repl
line=`grep "cnr.https-port\=" $conf_file`
repl="cnr.https-port=$https_port"

if [ ! -z "$line" ]
then
   dbug "replacing $line with $repl in $conf_file"
   sed -i "s/$line/$repl/g" $conf_file
else
   dbug "adding $repl to $conf_file"
   echo $repl >> $conf_file
fi
 
#
# Restart CNR
#
logmsg "Restarting CNR service $system_service"
systemctl stop $system_service
systemctl start $system_service 
sleep 10

#
# Check if we need to change the DNS port
#
logmsg "Setting DNS port to $dns_port"
nrcmd_dnsport_script="/var/nwreg2/local/temp/cnr_dnsport.nrcmd"
rm -f $nrcmd_dnsport_script
echo "$cnr_service set port=$dns_port" >> $nrcmd_dnsport_script
echo "$cnr_service reload" >> $nrcmd_dnsport_script
/opt/nwreg2/local/usrbin/nrcmd -N $username -P $password -b < $nrcmd_dnsport_script
rm -f $nrcmd_dnsport_script
sleep 3

logmsg "Finished cnr_init_local."
exit 0
