#!/bin/bash

#
# RHACM Observability is included by not enabled by default
# Once it's enabled, a persistent storage is required and it currently supports:
# - Amazon S3 (or other S3 compatible object stores like Ceph)
# - Google Cloud Storage
# - Azure storage
# - OpenShift Container Storage
# 
# This script is to install MinIO as a S3 compatible object store for RHACM Observability
#

source lib/functions.sh

#
# Creating MinIO Namespace
#
log "Creating MinIO Namespace"
oc new-project $MINIO_NAMESPACE

#
# Creating SA and granting proper permissions
#
log "Creating SA and granting proper permissions"
oc create sa $MINIO_CHART_NAME -n $MINIO_NAMESPACE
oc adm policy add-scc-to-user anyuid system:serviceaccount:$MINIO_NAMESPACE:$MINIO_CHART_NAME

#
# Installing MinIO Helm Chart
# TODO(Bright): To use MinIO Operator instead
#
log "Adding stable Helm Chart repo, if needed"
helm repo add stable https://charts.helm.sh/stable
log "Updating Helm repo"
helm repo update
log "Installing MinIO Helm Chart"
helm install $MINIO_CHART_NAME stable/minio \
  --namespace $MINIO_NAMESPACE \
  --set persistence.enabled=true \
  --set persistence.size=50Gi \
  --set persistence.storageClass=$CP4MCM_BLOCK_STORAGECLASS \
  --set serviceAccount.create=false \
  --set serviceAccount.name=$MINIO_CHART_NAME \
  --set "buckets[0].name=rhacm-bucket" \
  --set "buckets[0].policy=none"

log "Waiting for MinIO to finish (3 minutes)"
progress-bar 180

#
# If `mc` exists, let's have a check
# 
if [ -x "$(command -v mc)" ]; then
  # run port-forward at background
  oc -n $MINIO_NAMESPACE port-forward svc/minio 9000:9000 > /dev/null 2>&1 &
  port_forward_pid=$!

  minio_accesskey=`oc -n $MINIO_NAMESPACE get secret minio -o json | jq -r .data.accesskey | base64 -d`
  minio_secretkey=`oc -n $MINIO_NAMESPACE get secret minio -o json | jq -r .data.secretkey | base64 -d`
  mc config host rm minio
  mc config host add minio http://localhost:9000 $minio_accesskey $minio_secretkey --api "s3v4"

  # copy a file
  mc cp README.md minio/rhacm-bucket

  # list the folder
  mc ls -r minio
  # we should see somethihg like
  #[2021-05-05 10:44:42 +08]    133B rhacm-bucket/README.md

  # kill port-forward process
  kill -9 $port_forward_pid
fi
