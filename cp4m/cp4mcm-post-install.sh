#!/bin/bash

source setup_env.sh

#YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
#CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`

#
# LDAP is required for either IM or Monitoring module to function well
#
if [[ "$CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED" == "true" ]] ||
   [[ "$CP4MCM_MONITORING_ENABLED" == "true" ]];
then
    #
    # Setting up LDAP instance for CP4MCM IAM to integrate with
    #
    log "Setting up LDAP instance for IAM to integrate with"
    ./cp4m/ldap.sh
fi

#
# IM post actions
#
if [[ "$CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED" == "true" ]];
then
    #
    # Integrating CP4MCM IAM with LDAP for IM
    #
    log "Integrating CP4MCM IAM with LDAP"
    ./cp4m/CloudFormsandOIDC.sh

    #
    # Patching IM
    #
    log "Patching CP4MCM IM module"
    ./cp4m/patch-im.sh
fi


#
# Monitoring Module Post Install Config
#
if [[ "$CP4MCM_MONITORING_ENABLED" == "true" && "$CP4MCM_VERSION" == "2.3" ]];
then
    ./cp4m/monitoring-post-install.sh
fi
