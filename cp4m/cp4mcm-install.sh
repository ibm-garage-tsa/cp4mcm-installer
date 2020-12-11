#!/bin/bash

source setup_env.sh

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
if [ "$answer" != "Y" -a "$answer" != "y" ]; then
    echo "Abort!"
    exit 99
fi

echo "Great! Let's proceed the installation... "

#
# RHACM Installation
#
if [[ "$CP4MCM_RHACM_ENABLED" == "true" ]];
then
  source rhacm/1-rhacm.sh
fi

#
# Create Operator Namespace
#
oc new-project $CP4MCM_NAMESPACE

#
# Create entitled registry secret
#
oc create secret docker-registry $ENTITLED_REGISTRY_SECRET --docker-username=cp --docker-password=$ENTITLED_REGISTRY_KEY --docker-email=$DOCKER_EMAIL --docker-server=$ENTITLED_REGISTRY -n $CP4MCM_NAMESPACE

#
# Create Catalog Sources
#

#
# Common Services CatalogSource
#
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: docker.io/ibmcom/ibm-common-service-catalog:3.5.6
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

#
# Wait for CatalogSource to be created
#
log "Waiting for Common Services CatalogSource (180 seconds)"
progress-bar 180

# CP4MCM CatalogSource
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-marketplace
spec:
  displayName: IBM Management Orchestrator Catalog
  publisher: IBM
  sourceType: grpc
  image: quay.io/cp4mcm/cp4mcm-orchestrator-catalog:2.2-latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

#
# Wait for CP4MCM CatalogSource to be created
#
log "Waiting for CP4MCM CatalogSource (180 seconds)"
progress-bar 180

#
# Create CP4MCM Subscription
#
# Add manual approval after the fact.
#
#
# Create CP4MCM Subscription
#
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-operators
spec:
  channel: 2.2-stable
  installPlanApproval: Automatic
  name: ibm-management-orchestrator
  source: ibm-management-orchestrator
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-management-orchestrator.v2.2.5
EOF

#
# Wait for CP4MCM Subscription to be created
#
log "Waiting for CP4MCM Subscription (180 seconds)"
progress-bar 180

#
# Create the Installation
#
log "Applying the CP4MCM 2.2 - Core Installation"
cat << EOF | oc apply -f -
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

#
# Enable the Monitoring Module adding Monitoring Storage Config
#
if [[ "$CP4MCM_MONITORING_ENABLED" == "true" ]];
then
log "Adding Monitoring Storage Config to Installation"
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
# Enable the Monitoring Module
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

#
# Enable the Infrastructure Management Module
#
#
# Updating Installation config with CAM config.
#
if [[ "$CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED" == "true" ]];
then

if [ $ROKS != "true" ]; 
then 
log "Adding CAM Config to Installation (ROKS = false)";
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
log "Adding CAM Config to Installation (ROKS = $ROKS)"
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
# Enable Infrastructure Management Module
#
log "Enabling the IM Module in the  Installation"
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
# Wait for CP4MCM Subscription to be created
#
log "Waiting for Installation to start. (180 seconds)"
progress-bar 180

#
# Keep waiting and checking the installation progress
#
status

#
# Print out the route for RHACM access
#
if [[ "$CP4MCM_RHACM_ENABLED" == "true" ]]; 
then
  rhacm_route
fi
#
# Keep waiting and checking the installation progress
#
cscred
