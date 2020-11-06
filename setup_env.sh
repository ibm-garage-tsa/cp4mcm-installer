#!/bin/bash

source lib/functions.sh

LOGDIR="${LOGDIR:-$(PWD)/_logs}"
mkdir -p "$LOGDIR"
export LOGFILE="$LOGDIR/install.log"

##################################################################
# GLOBAL
# You shouldn't need to modify these if you don't want to.
# Just make sure you have exported the $ENTITLED_REGISTRY_KEY
#    
# ex. export ENTITLED_REGISTRY_KEY="YOUR ENTITLEMENT KEY"
##################################################################
if [ -z "${ENTITLED_REGISTRY_KEY}" ]; then 
  echo "You must export the ENTITLED_REGISTRY_KEY environment variable prior to running."; exit 999;
fi

export ENTITLED_REGISTRY="cp.icr.io"
export ENTITLED_REGISTRY_USER="${ENTITLED_REGISTRY_USER:-cp}"       # this may be cp or ekey
export ENTITLED_REGISTRY_SECRET="ibm-management-pull-secret"
export DOCKER_EMAIL="myemail@ibm.com"

#
# Define you storage classes here. If you are running on ROKS or using OCS it should be 
# able to figure it out, but if you want something custom you can specify that here.
#
export CP4MCM_BLOCK_STORAGECLASS="${CP4MCM_BLOCK_STORAGECLASS:-}"
export CP4MCM_FILE_STORAGECLASS="${CP4MCM_FILE_STORAGECLASS:-}"

#
# Cloud Pak Modules to enable
#
export CP4MCM_RHACM_ENABLED="${CP4MCM_RHACM_ENABLED:-true}"
export CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED="${CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED:-true}"
export CP4MCM_MONITORING_ENABLED="${CP4MCM_MONITORING_ENABLED:-true}"

#
# Cloud Pak namespace
#
export CP4MCM_NAMESPACE="${CP4MCM_NAMESPACE:-ibm-cp4mcm}"

#
# RHACM Parameters
#
export RHACM_NAMESPACE="${RHACM_NAMESPACE:-open-cluster-management}"
export RHACM_SECRET_NAME="rhacm-pull-secret"
export RHACM_OPERATOR_GROUP_NAME="rhacm-operator-group"

#
# Attempt to detect the storage classes if they are not explicitly defined.
#
detect_storage_classes

#
# Validate the storage classes detected\defined. Exist if they do not exist.
#
validate_storageclass $CP4MCM_BLOCK_STORAGECLASS || BAD_SC="true";
validate_storageclass $CP4MCM_FILE_STORAGECLASS || BAD_SC="true";
validate_storageclass $CP4MCM_FILE_GID_STORAGECLASS || BAD_SC="true";

if [ -z BAD_SC ]; then
  echo "One or more of your storage classes do ot exists. Please verify your storage configuration and retry."
  echo " Block Storage      = $CP4MCM_BLOCK_STORAGECLASS"
  echo " File Storage class = $CP4MCM_FILE_STORAGECLASS"
  if [ -z $CP4MCM_FILE_GID_STORAGECLASS ]; then
    echo " File Storage GID class = $CP4MCM_FILE_STORAGECLASS"
  fi
  exit;
fi

#
# Validate entitled registry key.
#
entitled_registry_test

# Confirmation
log  "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
log  "Installation is starting with the following configuration:"
log  " ROKS                               = $ROKS"
log  " CP4MCM Namespace                   = $CP4MCM_NAMESPACE"
log  " Block Storage Class                = $CP4MCM_BLOCK_STORAGECLASS"
log  " File Storage Class                 = $CP4MCM_FILE_STORAGECLASS"
log  "--------------------------------------"
log  " Module - RHACM: Enabled            = $CP4MCM_RHACM_ENABLED"
log  " Module - Infra Management: Enabled = $CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED"
log  " Module - Monitoring: Enabled       = $CP4MCM_MONITORING_ENABLED"
log  "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -n "Are you sure to proceed installation with these settings [Y/N]: "
read answer
if [ "$answer" != "Y" ]; then
    echo "Abort!"
    exit 0
fi

echo "Great! Let's proceed the installation... "
