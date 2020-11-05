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

function rhacmstatus {
    # Sleep until the operator is running
    COUNT=0;
    for ((time=1;time<60;time++)); do
        WC=`oc get multiclusterhub multiclusterhub -o=jsonpath='{.status.phase}' | grep 'Running' | wc -l`
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo "Waiting for operator to change status to Running.. retry ($time of 60)(Consecutive tries $COUNT/5)"
        echo ""
        oc get multiclusterhub multiclusterhub -o=jsonpath='{.metadata.name} {.status.phase}'

        if [ $WC -eq 1 ]; then
            #  We are good
            break
        else
            ((COUNT++))

            if [ $COUNT -ge 5 ]; then
            break
            fi
        fi
        progress-bar 60
    done
}

function status {
    # Sleep until all pods are running.
    COUNT=0;
    for ((time=1;time<60;time++)); do
        # Added gateway-kong to the exclusion due to bug on ROKS.
        WC=`oc get po --no-headers=true -A | grep -v 'Running\|Completed\|gateway-kong\|selenium\|sre-bastion' | grep 'kube-system\|ibm-common-services\|management-infrastructure-management\|management-monitoring\|management-operations\|management-security-services' | wc -l`
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

function rhacm_route {
    RHACM_ROUTE=`oc get route -n $RHACM_NAMESPACE multicloud-console --template '{{.spec.host}}'`
    log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    log "RHACM installed. You can access it at https://$RHACM_ROUTE"
    log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
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

function detect_storage_classes {
    ##############################################################################
    # You Shouldn't need to modify anything below.
    ##############################################################################
    if [[ -z $CP4MCM_BLOCK_STORAGECLASS || -z $CP4MCM_FILE_STORAGECLASS ]];
    then
        echo "No storage classes provided. Let's see if we can find one we can use."
        #
        # Gather storage class information.
        #
        K8S_NODE=`oc get nodes | grep Ready | cut -d " " -f 1  | head -1`
        IBMROKS=`oc get nodes $K8S_NODE --template '{{.metadata.labels}}' | grep ibm-cloud.kubernetes.io`

        #
        # The cluster is not running on ROKS then we will assume it is using OCS
        #
        if [ -z "$IBMROKS" ]; then
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
    else
        echo "Storage classes provided. We will use the one you provided."
        ROKS="false"
        CUSTOM_STORAGE="true"
        CP4MCM_FILE_GID_STORAGECLASS=$CP4MCM_FILE_STORAGECLASS
    fi

}

function validate_storageclass {
    echo "Validating storage class: $1"
    if [ $(oc get sc $1 --no-headers | wc -l) -le 0 ]; then
        echo "Storage class $1 is not valid."
        exit 999
    else
        echo "Storage class $1 exists."
    fi
}

function entitled_registry_test {
    echo "Testing the entitled registry key provided by pulling a sample image."
}