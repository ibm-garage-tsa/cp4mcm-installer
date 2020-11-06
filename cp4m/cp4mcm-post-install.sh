#!/bin/bash

source lib/functions.sh

#YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
#CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`



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

#
# Updating Installation config with CAM config.
#
if [[ "$CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED" == "true" ]];
then
    #
    # Placeholder for future
    #
    log "No post configuration tasks for Infastructure Management Module"
fi

#
# LDAP is required for IM or Monitoring module to function
#
if [[ "$CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED" == "true" ]] ||
   [[ "$CP4MCM_MONITORING_ENABLED" == "true" ]];
then
    #
    # Setting up LDAP instance for CP4MCM IAM to integrate with
    #
    log "Setting up LDAP instance for IAM to integrate with"
    ./cp4m/ldap.sh

    #
    # Integrating CP4MCM IAM with LDAP
    #
    log "Integrating CP4MCM IAM with LDAP"
    ./cp4m/CloudFormsandOIDC.sh
fi