#!/bin/bash

source setup_env.sh

# Confirmation
log  "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
log  "Installation is starting with the following configuration:"
log  " ROKS                                   = $ROKS"
log  " CP4MCM Version                         = $CP4MCM_VERSION"
log  " CP4MCM Namespace                       = $CP4MCM_NAMESPACE"
log  " Block Storage Class                    = $CP4MCM_BLOCK_STORAGECLASS"
log  " File Storage Class                     = $CP4MCM_FILE_STORAGECLASS"
log  "----------------------------------------------------------------------"
log  " Module - RHACM: Enabled                = $CP4MCM_RHACM_ENABLED"
log  " Module - RHACM Observability: Enabled  = $CP4MCM_RHACM_OBSERVABILITY_ENABLED"
log  " Module - Infra Management: Enabled     = $CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED"
log  " Module - Monitoring: Enabled           = $CP4MCM_MONITORING_ENABLED"
log  "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -n "Are you sure to proceed installation with these settings [Y/N]: "
read answer
if [ "$answer" != "Y" -a "$answer" != "y" ]; then
    echo "Abort!"
    exit 99
fi

missed_tools=0
echo "Firstly, let's do a quick check for required tools..."
# check oc
if is_required_tool_missed "oc"; then missed_tools=$((missed_tools+1)); fi
# check cloudctl
if is_required_tool_missed "cloudctl"; then missed_tools=$((missed_tools+1)); fi
# check jq
if is_required_tool_missed "jq"; then missed_tools=$((missed_tools+1)); fi
# check helm
if is_required_tool_missed "helm"; then missed_tools=$((missed_tools+1)); fi
# final check
if [[ $missed_tools > 0 ]]; then
  echo "Abort! There are some required tools missing, please have a check."
  exit 98
fi

echo "Great! Let's proceed the installation... "

#
# RHACM Installation
#
if [[ "$CP4MCM_RHACM_ENABLED" == "true" ]]; then
  # install RHACM core components
  source rhacm/1-rhacm.sh

  # install MinIO and enable RHACM Observability if CP4MCM_RHACM_OBSERVABILITY_ENABLED is true
  if [ "${CP4MCM_RHACM_OBSERVABILITY_ENABLED}" == "true" ]; then
  source rhacm/2-minio.sh
  source rhacm/3-rhacm-observability.sh
  fi
  
fi

#
# Create Operator Namespace
#
oc new-project $CP4MCM_NAMESPACE

#
# Create entitled registry secret
#
oc create secret docker-registry $ENTITLED_REGISTRY_SECRET \
  --docker-username=$ENTITLED_REGISTRY_USER \
  --docker-password=$ENTITLED_REGISTRY_KEY \
  --docker-email=$DOCKER_EMAIL \
  --docker-server=$ENTITLED_REGISTRY \
  -n $CP4MCM_NAMESPACE

#
# Creating Common Services CatalogSource
#
log "Creating Common Services CatalogSource"
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: ${CS_CATALOGSOURCE_IMAGE}
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

#
# Creating Common Services Subscription
#
log "Creating Common Services Subscription"
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: openshift-operators
spec:
  channel: ${CS_SUBSCRIPTION_CHANNEL}
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: opencloud-operators
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-common-service-operator.v${CS_VERSION}
EOF

#
# Creating CP4MCM CatalogSource
#
log "Creating CP4MCM CatalogSource"
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-marketplace
spec:
  displayName: IBM Management Orchestrator Catalog
  publisher: IBM
  sourceType: grpc
  image: ${CP4MCM_CATALOGSOURCE_IMAGE}
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

#
# Creating CP4MCM Subscription
#
log "Creating CP4MCM Subscription"
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-operators
spec:
  channel: ${CP4MCM_SUBSCRIPTION_CHANNEL}
  installPlanApproval: Automatic
  name: ibm-management-orchestrator
  source: ibm-management-orchestrator
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-management-orchestrator.v${CP4MCM_SUBSCRIPTION_CSV}
EOF

#
# Waiting for both Common Services and CP4MCM Subscription to be ready
#
log "Waiting for both Common Services and CP4MCM Subscription to be ready (180 seconds)"
progress-bar 180

#
# Creating Common Services CR
# 
# To further customize Common Services, check this out:
# https://www.ibm.com/docs/en/cloud-paks/cp-management/2.3.x?topic=configuration-configuring-common-services
#
log "Creating Common Services CR"
oc apply -f yaml/common-services.yaml

log "Waiting for Common Services' CR to be ready (180 seconds)"
progress-bar 180

#
# Applying the CP4MCM Installation
#
log "Applying the CP4MCM ${CP4MCM_VERSION} - Core Installation"
oc apply -f - <<EOF
apiVersion: orchestrator.management.ibm.com/v1alpha1
kind: Installation
metadata:
  name: ibm-management
  namespace: $CP4MCM_NAMESPACE
spec:
  storageClass: $CP4MCM_BLOCK_STORAGECLASS
  imagePullSecret: $ENTITLED_REGISTRY_SECRET
  license:
    accept: true
  mcmCoreDisabled: $CP4MCM_RHACM_ENABLED
  pakModules:
    - config:
        - enabled: true
          name: ibm-management-im-install
          spec: {}
        - enabled: true
          name: ibm-management-infra-grc
          spec: {}
        - enabled: true
          name: ibm-management-infra-vm
          spec: {}
        - enabled: true
          name: ibm-management-cam-install
          spec: {}
        - enabled: true
          name: ibm-management-service-library
          spec: {}
      enabled: false
      name: infrastructureManagement
    - config:
        - enabled: true
          name: ibm-management-monitoring
          spec:
            operandRequest: {}
            monitoringDeploy:
              global:
                environmentSize: size0
                persistence:
                  storageClassOption:
                    cassandrabak: none
                    cassandradata: default
                    couchdbdata: default
                    datalayerjobs: default
                    elasticdata: default
                    kafkadata: default
                    zookeeperdata: default
                  storageSize:
                    cassandrabak: 50Gi
                    cassandradata: 50Gi
                    couchdbdata: 5Gi
                    datalayerjobs: 5Gi
                    elasticdata: 5Gi
                    kafkadata: 10Gi
                    zookeeperdata: 1Gi
      enabled: false
      name: monitoring
    - config:
        - enabled: true
          name: ibm-management-notary
          spec: {}
        - enabled: true
          name: ibm-management-image-security-enforcement
          spec: {}
        - enabled: false
          name: ibm-management-mutation-advisor
          spec: {}
        - enabled: false
          name: ibm-management-vulnerability-advisor
          spec:
            controlplane:
              esSecurityEnabled: true
              esServiceName: elasticsearch.ibm-common-services
              esSecretName: logging-elk-certs
              esSecretCA: ca.crt
              esSecretCert: curator.crt
              esSecretKey: curator.key
            annotator:
              esSecurityEnabled: true
              esServiceName: elasticsearch.ibm-common-services
              esSecretName: logging-elk-certs
              esSecretCA: ca.crt
              esSecretCert: curator.crt
              esSecretKey: curator.key
            indexer:
              esSecurityEnabled: true
              esServiceName: elasticsearch.ibm-common-services
              esSecretName: logging-elk-certs
              esSecretCA: ca.crt
              esSecretCert: curator.crt
              esSecretKey: curator.key
      enabled: false
      name: securityServices
    - config:
        - enabled: true
          name: ibm-management-sre-chatops
          spec: {}
      enabled: false
      name: operations
    - config:
        - enabled: true
          name: ibm-management-manage-runtime
          spec: {}
      enabled: false
      name: techPreview
EOF


if [[ "$CP4MCM_MONITORING_ENABLED" == "true" ]];
then

#
# Enabling the Monitoring Module by patching the Installation
#

log "Enabling the Monitoring Module by patching the Installation for storage configuration"
oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p="[
 {"op": "test",
  "path": "/spec/pakModules/1/name",
  "value": "monitoring" },
 {"op": "replace",
  "path": "/spec/pakModules/1/config/0/spec",
  "value": 
    {
      "monitoringDeploy": {
        "cnmonitoringimagesource": {
          "deployMCMResources": true
        },
        "global": {
          "environmentSize": size0,
          "persistence": {
            "storageClassOption": {
              "cassandrabak": none,
              "cassandradata": $CP4MCM_BLOCK_STORAGECLASS,
              "couchdbdata": $CP4MCM_BLOCK_STORAGECLASS,
              "datalayerjobs": $CP4MCM_BLOCK_STORAGECLASS,
              "elasticdata": $CP4MCM_BLOCK_STORAGECLASS,
              "kafkadata": $CP4MCM_BLOCK_STORAGECLASS,
              "zookeeperdata": $CP4MCM_BLOCK_STORAGECLASS
            },
            "storageSize": {
              "cassandrabak": 50Gi,
              "cassandradata": 50Gi,
              "couchdbdata": 5Gi,
              "datalayerjobs": 5Gi,
              "elasticdata": 5Gi,
              "kafkadata": 10Gi,
              "zookeeperdata": 1Gi
            }
          }
        }
      }
    }
  }
]"

#
# And then enabling it
#
log "Enabling Monitoring Module"
oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p='[
 {"op": "test",
  "path": "/spec/pakModules/1/name",
  "value": "monitoring" },
 {"op": "replace",
  "path": "/spec/pakModules/1/enabled",
  "value": true }
]'

fi


if [[ "$CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED" == "true" ]];
then

#
# Enabling the Infrastructure Management Module
#

log "Adding CAM Config to Installation (ROKS = $ROKS)";

if [ $ROKS != "true" ]; 
then 

oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p="[
 {"op": "test",
  "path": "/spec/pakModules/0/name",
  "value": "infrastructureManagement" },
 {"op": "add",
  "path": "/spec/pakModules/0/config/3/spec",
  "value": 
        { "manageservice": {
            "camMongoPV": {"persistence": { "storageClassName": $CP4MCM_BLOCK_STORAGECLASS, "accessMode": "ReadWriteOnce"}},
            "camTerraformPV": {"persistence": { "storageClassName": $CP4MCM_FILE_GID_STORAGECLASS}},
            "camLogsPV": {"persistence": { "storageClassName": $CP4MCM_FILE_GID_STORAGECLASS}},
            "license": {"accept": true}
            }
        }
  }
]";

else

#
# Updating Installation config with CAM config with ROKS.
#
oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p="[
 {"op": "test",
  "path": "/spec/pakModules/0/name",
  "value": "infrastructureManagement" },
 {"op": "add",
  "path": "/spec/pakModules/0/config/3/spec",
  "value": 
        { "manageservice": {
            "camMongoPV": {"persistence": { "storageClassName": $CP4MCM_FILE_GID_STORAGECLASS}},
            "camTerraformPV": {"persistence": { "storageClassName": $CP4MCM_FILE_GID_STORAGECLASS}},
            "camLogsPV": {"persistence": { "storageClassName": $CP4MCM_FILE_GID_STORAGECLASS}},
            "global": { "iam": { "deployApiKey": $CAM_API_KEY}},
            "license": {"accept": true},
            "roks": true,
            "roksRegion": "$ROKSREGION",
            "roksZone": "$ROKSZONE"
            }
        }
  }
]"

fi

#
# Enabling Infrastructure Management Module by patching the Installation
#
log "Enabling Infrastructure Management Module by patching the Installation"
oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p='[
 {"op": "test",
  "path": "/spec/pakModules/0/name",
  "value": "infrastructureManagement" },
 {"op": "replace",
  "path": "/spec/pakModules/0/enabled",
  "value": true }
]'

fi

#
# Waiting for Installation to start
#
log "Waiting for Installation to start. (180 seconds)"
progress-bar 180

#
# Keep waiting and checking the installation progress
#
log "Checking the installation progress till completion...be patient!"
status

#
# Print out the route for RHACM access, if RHACM is enabled
#
if [[ "$CP4MCM_RHACM_ENABLED" == "true" ]]; 
then
  rhacm_route
fi

#
# Print out the admin credential for CP4MCM access
#
cscred
