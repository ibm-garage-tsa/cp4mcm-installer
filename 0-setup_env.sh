#!/bin/bash

LOGFILE="install.log"
##################################################################
# GLOBAL
# You shouldn't need to modify these if you don't want to.
# Just make sure you have exported the $ENTITLED_REGISTRY_KEY
#    
# ex. export ENTITLED_REGISTRY_KEY="YOUR ENTITLEMENT KEY"
##################################################################
if [ -z "${ENTITLED_REGISTRY_KEY}" ]; then echo "You must export the ENTITLED_REGISTRY_KEY environment variable prior to running."; exit 999; fi

ENTITLED_REGISTRY="cp.icr.io"
ENTITLED_REGISTRY_SECRET="ibm-management-pull-secret"
DOCKER_EMAIL="myemail@ibm.com"

ibmroks=$(oc cluster-info | grep "cloud.ibm.com" )
storclass=$(oc get storageclass --no-headers | grep "(default)" | cut -f1 -d" " )
if [ -z storclass ]; then
  storclass=$(oc get storageclass --no-headers | head -n 1 | cut -f1 -d" " )
  if [ -z storclass ]; then
    echo "NO storage class existed - cannot install using this script"
    exit 999
  fi
fi

if [ -z "$ibmroks" ]; then
  ROKS="false"
  ROKSREGION=""
  ROKSZONE=""
  # check storage class
  CP4MCM_BLOCK_STORAGECLASS="ocs-storagecluster-ceph-rbd"
  CP4MCM_FILE_STORAGECLASS="ocs-storagecluster-cephfs"
  CP4MCM_FILE_GID_STORAGECLASS="ocs-storagecluster-cephfs"
else
  ROKS="true"
  ROKSREGION=$(oc get node -o yaml | grep region | cut -d: -f2 | head -1 | tr -d '[:space:]')
  # ROKSZONE for storage does not seems to be used anymore
  ROKSZONE=""
  # check storage class
  CP4MCM_BLOCK_STORAGECLASS="ibmc-block-gold"
  CP4MCM_FILE_STORAGECLASS="ibmc-file-gold"
  CP4MCM_FILE_GID_STORAGECLASS="ibmc-file-gold-gid"
fi

CP4MCM_NAMESPACE="cp4m"

if [ $(oc get sc $CP4MCM_BLOCK_STORAGECLASS --no-headers | wc -l) -le 0 ]; then
  CP4MCM_BLOCK_STORAGECLASS=$storclass
fi
if [ $(oc get sc $CP4MCM_FILE_STORAGECLASS --no-headers | wc -l) -le 0 ]; then
  CP4MCM_FILE_STORAGECLASS=$storclass
fi
if [ $(oc get sc $CP4MCM_FILE_GID_STORAGECLASS --no-headers | wc -l) -le 0 ]; then
  CP4MCM_FILE_GID_STORAGECLASS=$storclass
fi

# Additional packages can be found here: 
ANSIBLE_SETUP_PACKAGE="ansible-tower-openshift-setup-3.7.2-1.tar.gz"
ANSIBLE_NAMESPACE="ansible-tower"
ANSIBLE_PASSWORD="Passw0rd"

###########################
# CP4I Parameters
###########################
CP4I_NAMESPACE="cp4i"
#CP4I_BLOCK_STORAGECLASS="ibmc-block-gold"
#CP4I_FILE_STORAGECLASS="ibmc-file-gold"
#CP4I_FILE_GID_STORAGECLASS="ibmc-file-gold-gid"

CP4I_BLOCK_STORAGECLASS="thin"
CP4I_FILE_STORAGECLASS="ocs-storagecluster-cephfs"
CP4I_FILE_GID_STORAGECLASS="ocs-storagecluster-cephfs"


###################################################
# Common functions
###################################################

function log {
    echo "$(date): $@"
    echo "$(date): $@" >> $LOGFILE
}


function cssstatus {
    for ((time=1;time<60;time++)); do
        WC=`oc get css --no-headers=true | grep -v "Running\|Succeeded" | wc -l`
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo "Waiting for installation to complete.. retry ($time of 60)(Pods remaining = $WC)"
        echo ""
        oc get css | grep -v "Running" 
        
        if [ $WC -le 0 ]; then
            break
        fi

        sleep 60
    done
}

function status {
    # Sleep until all pods are running.
    COUNT=0;
    for ((time=1;time<60;time++)); do
        # Added gateway-kong to the exclusion due to bug on ROKS.
        WC=`oc get po --no-headers=true -A | grep -v 'Running\|Completed\|gateway-kong\|selenium' | grep 'kube-system\|ibm-common-services\|management-infrastructure-management\|management-monitoring\|management-operations\|management-security-services' | wc -l`
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo "Waiting for pods to start.. retry ($time of 60)(Pods remaining = $WC)(Consecutive tries $COUNT/3)"
        echo ""
        oc get po -A | grep -v 'Running\|Completed' | grep 'kube-system\|ibm-common-services\|management-infrastructure-management\|management-monitoring\|management-operations\|management-security-services'
        
        if [ $WC -le 0 ]; then
            ((COUNT++))

            if [ $COUNT -ge 3 ]; then
            break
            fi
        else
            COUNT=0
        fi
        progress-bar 180
    done
}

function cscred {
    # Get the CP Route
    YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`

    # Get the CP Password
    CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`

    log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    log "Installation complete."
    log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    log " You can access your cluster with the URL and credentials below:"
    log " URL=$YOUR_CP4MCM_ROUTE"
    log " User=admin"
    log " Password=$CP_PASSWORD"
}

SLEEP_DURATION=1

function progress-bar {
  local duration
  local columns
  local space_available
  local fit_to_screen  
  local space_reserved

  space_reserved=6   # reserved width for the percentage value
  duration=${1}
  columns=$(tput cols)
  space_available=$(( columns-space_reserved ))

  if (( duration < space_available )); then 
  	fit_to_screen=1; 
  else 
    fit_to_screen=$(( duration / space_available )); 
    fit_to_screen=$((fit_to_screen+1)); 
  fi

  already_done() { for ((done=0; done<(elapsed / fit_to_screen) ; done=done+1 )); do printf "▇"; done }
  remaining() { for (( remain=(elapsed/fit_to_screen) ; remain<(duration/fit_to_screen) ; remain=remain+1 )); do printf " "; done }
  percentage() { printf "| %s%%" $(( ((elapsed)*100)/(duration)*100/100 )); }
  clean_line() { printf "\r"; }

  for (( elapsed=1; elapsed<=duration; elapsed=elapsed+1 )); do
      already_done; remaining; percentage
      sleep "$SLEEP_DURATION"
      clean_line
  done
  clean_line
  printf "\n";
}

function execlog {
    log "Executing command: $@"
    $@ | tee -a $LOGFILE
}

function cclogin {
    YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
    CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`
    execlog cloudctl login -a $YOUR_CP4MCM_ROUTE --skip-ssl-validation -u admin -p $CP_PASSWORD -n default
}
