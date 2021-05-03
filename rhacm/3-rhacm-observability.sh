#!/bin/bash

#
# RHACM Observability is included by not enabled by default
# For details of RHACM Observability, check it out here:
# - https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.2/html-single/observing_environments/index
#
# This script is to enable RHACM Observability based on specific configured paramaters
# 

source lib/functions.sh

#
# Creating RHACM Observability namespace
#
log "Creating RHACM Observability namespace"
oc new-project $RHACM_OBSERVABILITY_NAMESPACE

# Creating pull-secret
log "Creating pull-secret"
docker_config_json="$( oc extract secret/rhacm-pull-secret -n ${RHACM_NAMESPACE} --to=- | base64 -w 0)"
oc -n $RHACM_OBSERVABILITY_NAMESPACE apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: rhacm-pull-secret
  namespace: $RHACM_OBSERVABILITY_NAMESPACE
data:
  .dockerconfigjson: $docker_config_json
type: kubernetes.io/dockerconfigjson
EOF

# Creating secret to connect to S3 store
log "Creating secret to connect to S3 store"
minio_accesskey=`oc -n $MINIO_NAMESPACE get secret minio -o json | jq -r .data.accesskey | base64 -d`
minio_secretkey=`oc -n $MINIO_NAMESPACE get secret minio -o json | jq -r .data.secretkey | base64 -d`
oc -n $RHACM_OBSERVABILITY_NAMESPACE apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: thanos-object-storage
type: Opaque
stringData:
  thanos.yaml: |
    type: s3
    config:
      bucket: rhacm-bucket
      endpoint: minio.$MINIO_NAMESPACE.svc:9000
      insecure: true
      access_key: $minio_accesskey
      secret_key: $minio_secretkey
EOF

# Creating the MultiClusterObservability CR
log "Creating the MultiClusterObservability CR"
oc -n $RHACM_OBSERVABILITY_NAMESPACE apply -f - <<EOF
apiVersion: observability.open-cluster-management.io/v1beta1
kind: MultiClusterObservability
metadata:
  name: observability
spec:
  availabilityConfig: Basic             # Available values are High or Basic
  enableDownSampling: false             # The default value is false. This is not recommended as querying long-time ranges without non-downsampled data is not efficient and useful.
  imagePullPolicy: Always
  imagePullSecret: rhacm-pull-secret    # The pull secret generated above
  observabilityAddonSpec:               # The ObservabilityAddonSpec defines the global settings for all managed clusters which have observability add-on enabled
    enableMetrics: true                 # EnableMetrics indicates the observability addon push metrics to hub server
    interval: 60                        # Interval for the observability addon push metrics to hub server
  retentionResolution1h: 5d             # How long to retain samples of 1 hour in bucket
  retentionResolution5m: 2d
  retentionResolutionRaw: 2d
  storageConfigObject:                  # Specifies the storage to be used by Observability
    metricObjectStorage:
      name: thanos-object-storage
      key: thanos.yaml
    statefulSetSize: 10Gi               # The amount of storage applied to the Observability StatefulSets, i.e. Amazon S3 store, Rule, compact and receiver.
    statefulSetStorageClass: $CP4MCM_BLOCK_STORAGECLASS
EOF

log "Waiting for MultiClusterObservability to finish (5 minutes)"
progress-bar 300
