#!/bin/bash

source 0-setup_env.sh

YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`

#
# Adding Monitoring Storage Config.
#
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
# Updating Installation config with CAM config.
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

log "Sleeping until install starts. (180 seconds)"
progress-bar 180
status


#
# Patching the CNMonitoring deployable secret.
#
log "Docker config for SECRET=$ENTITLED_REGISTRY_SECRET in NAMESPACE=$CP4MCM_NAMESPACE"
ENTITLED_REGISTRY_DOCKERCONFIG=`oc get secret $ENTITLED_REGISTRY_SECRET -n $CP4MCM_NAMESPACE -o jsonpath='{.data.\.dockerconfigjson}'`
log "ENTITLED_REGISTRY_DOCKERCONFIG=$ENTITLED_REGISTRY_DOCKERCONFIG"
execlog oc patch deployable.app.ibm.com/cnmon-pullsecret-deployable -p `echo {\"spec\":{\"template\":{\"data\":{\".dockerconfigjson\":\"$ENTITLED_REGISTRY_DOCKERCONFIG\"}}}}` --type merge -n management-monitoring

