#!/bin/bash

source lib/functions.sh

export LOGDIR="${LOGDIR:-$(PWD)/_logs}"
mkdir -p "$LOGDIR"
export LOGFILE="$LOGDIR/install-$(date +"%Y-%m-%d").log"

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
# CP4MCM versioning with relevant components
#
export CP4MCM_VERSION="${CP4MCM_VERSION:-2.3}"
if [[ "${CP4MCM_VERSION}" == "2.3" ]]; then 
  export CS_VERSION="3.6.4"
  export CS_SUBSCRIPTION_CHANNEL="stable-v1"
  export CP4MCM_SUBSCRIPTION_CHANNEL="2.3-stable"
  export CP4MCM_SUBSCRIPTION_CSV="2.3.2"
  export RHACM_VERSION="2.2"
  export CS_CATALOGSOURCE_IMAGE="docker.io/ibmcom/ibm-common-service-catalog:${CS_VERSION}"
  export CP4MCM_CATALOGSOURCE_IMAGE="quay.io/cp4mcm/cp4mcm-orchestrator-catalog:${CP4MCM_VERSION}-latest"
elif [[ "${CP4MCM_VERSION}" == "2.2" ]]; then 
  export CS_VERSION="3.5.6"
  export CS_SUBSCRIPTION_CHANNEL="stable-v1"
  export CP4MCM_SUBSCRIPTION_CHANNEL="2.2-stable"
  export CP4MCM_SUBSCRIPTION_CSV="2.2.5"
  export RHACM_VERSION="2.1"
  export CS_CATALOGSOURCE_IMAGE="docker.io/ibmcom/ibm-common-service-catalog:${CS_VERSION}"
  export CP4MCM_CATALOGSOURCE_IMAGE="quay.io/cp4mcm/cp4mcm-orchestrator-catalog:${CP4MCM_VERSION}-latest"
elif  [[ "${CP4MCM_VERSION}" == "2.1" ]]; then 
  export CS_VERSION="3.5.6"
  export CS_SUBSCRIPTION_CHANNEL="stable-v1"
  export CP4MCM_SUBSCRIPTION_CHANNEL="2.1-stable"
  export CP4MCM_SUBSCRIPTION_CSV="2.1.5"
  export RHACM_VERSION="2.0"
  export CS_CATALOGSOURCE_IMAGE="docker.io/ibmcom/ibm-common-service-catalog:${CS_VERSION}"
  export CP4MCM_CATALOGSOURCE_IMAGE="quay.io/cp4mcm/cp4mcm-orchestrator-catalog:${CP4MCM_VERSION}-latest"
else
  echo "The CP4MCM version is not supported by this script: ${CP4MCM_VERSION}"; exit 999;
fi

#
# Define you storage classes here. If you are running on ROKS or using OCS it should be 
# able to figure it out, but if you want something custom you can specify that here.
#
export CP4MCM_BLOCK_STORAGECLASS="${CP4MCM_BLOCK_STORAGECLASS:-}"
export CP4MCM_FILE_STORAGECLASS="${CP4MCM_FILE_STORAGECLASS:-}"

#
# Cloud Pak Modules to enable
#
export CP4MCM_RHACM_ENABLED="${CP4MCM_RHACM_ENABLED:-false}"
export CP4MCM_RHACM_OBSERVABILITY_ENABLED="${CP4MCM_RHACM_OBSERVABILITY_ENABLED:-false}"
export CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED="${CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED:-true}"
export CP4MCM_MONITORING_ENABLED="${CP4MCM_MONITORING_ENABLED:-true}"

#
# Cloud Pak namespace
#
export CP4MCM_NAMESPACE="${CP4MCM_NAMESPACE:-ibm-cp4mcm}"

#
# MinIO
#
export MINIO_NAMESPACE="${MINIO_NAMESPACE:-minio}"
export MINIO_CHART_NAME="${MINIO_CHART_NAME:-minio}"

#
# RHACM Parameters
#
export RHACM_NAMESPACE="${RHACM_NAMESPACE:-open-cluster-management}"
export RHACM_SECRET_NAME="rhacm-pull-secret"
export RHACM_OPERATOR_GROUP_NAME="rhacm-operator-group"

export RHACM_OBSERVABILITY_NAMESPACE="${RHACM_OBSERVABILITY_NAMESPACE:-open-cluster-management-observability}"

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

