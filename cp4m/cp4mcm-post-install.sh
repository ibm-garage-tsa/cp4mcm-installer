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
    # Patching CAM
    #
    log "Patching CP4MCM IM's CAM"
    ./cp4m/patch-im-cam.sh
fi


#
# Monitoring Module Post Install Config
#
if [[ "$CP4MCM_MONITORING_ENABLED" == "true" ]];
then
    log "Adding Monitoring Storage Config to Installation"

    #
    # Patching the CNMonitoring deployable secret.
    #
    log "Docker config for SECRET=$ENTITLED_REGISTRY_SECRET in NAMESPACE=$CP4MCM_NAMESPACE"
    ENTITLED_REGISTRY_DOCKERCONFIG=`oc get secret $ENTITLED_REGISTRY_SECRET -n $CP4MCM_NAMESPACE -o jsonpath='{.data.\.dockerconfigjson}'`
    log "ENTITLED_REGISTRY_DOCKERCONFIG=$ENTITLED_REGISTRY_DOCKERCONFIG"
    execlog oc patch deployable.app.ibm.com/cnmon-pullsecret-deployable -p `echo {\"spec\":{\"template\":{\"data\":{\".dockerconfigjson\":\"$ENTITLED_REGISTRY_DOCKERCONFIG\"}}}}` --type merge -n management-monitoring
fi
