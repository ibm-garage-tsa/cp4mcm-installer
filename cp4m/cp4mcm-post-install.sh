#!/bin/bash

source setup_env.sh

#YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
#CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`



#
# Monitoring Module Post Install Config
#
if [[ "$CP4MCM_MONITORING" == "true" ]];
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
if [[ "$CP4MCM_INFRASTRUCTUREMANAGEMENT" == "true" ]];
then
     #
     # Placeholder for future
     #
     log "No post configuration tasks for Infastructure Management Module"
fi


if [[ "$CP4MCM_CLOUDFORMS" == "true" ]];
then
    ./cp4m/ldap.sh
    ./cp4m/CloudFormsandOIDC.sh
fi