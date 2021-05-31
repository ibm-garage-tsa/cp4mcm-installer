#!/bin/bash
source lib/functions.sh

log "Adding RemoteAgentDeploy CR to Monitoring installation"
export PLUGIN_REPO_URL=$(oc get route plugin-repo -n management-monitoring --template '{{.spec.host}}')

oc create -f - <<EOF
apiVersion: monitoring.management.ibm.com/v1alpha1
kind: RemoteAgentDeploy
metadata:
  name: remoteagentdeploy
  labels:
    app.kubernetes.io/instance: ibm-monitoring-dataprovider-mgmt-operator
    app.kubernetes.io/managed-by: ibm-monitoring-dataprovider-mgmt-operator
    app.kubernetes.io/name: ibm-monitoring-dataprovider-mgmt-operator
  namespace: management-monitoring
spec:
  targetNamespace: cp4mcm-cloud-native-monitoring
  uaPluginRepo: $PLUGIN_REPO_URL
EOF
progress-bar 60
