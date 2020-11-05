#!/bin/bash

source lib/functions.sh

LOGFILE="install.log"
TMPDIR="./tmp"
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

#
# Define you storage classes here. If you are running on ROKS or using OCS it should be 
# able to figure it out, but if you want something custom you can specify that here.
#
CP4MCM_BLOCK_STORAGECLASS=""
CP4MCM_FILE_STORAGECLASS=""

#
# Cloud Pak Modules to enable
#
CP4MCM_RHACM_ENABLED="true"
CP4MCM_MONITORING="true"
CP4MCM_INFRASTRUCTUREMANAGEMENT="true"
CP4MCM_CLOUDFORMS="true"

#
# Cloud Pak namespace
#
CP4MCM_NAMESPACE="cp4m"

#
# RHACM Parameters
#
RHACM_NAMESPACE="rhacm"
RHACM_SECRET_NAME="rhacm-pull-secret"
RHACM_OPERATOR_GROUP_NAME="rhacm-operator-group"

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

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Installation is starting with the following configuration:"
echo " ROKS               = $ROKS"
echo " RHACM Core         = $CP4MCM_RHACM_ENABLED"
echo " Monitoring Module  = $CP4MCM_MONITORING"
echo " Infra Management   = $CP4MCM_INFRASTRUCTUREMANAGEMENT"
echo " CloudForms         = $CP4MCM_CLOUDFORMS"
echo " Namespace          = $CP4MCM_NAMESPACE"
echo " Block Storage      = $CP4MCM_BLOCK_STORAGECLASS"
echo " File Storage class = $CP4MCM_FILE_STORAGECLASS"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"


