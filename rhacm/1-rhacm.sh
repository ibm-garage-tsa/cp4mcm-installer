#!/bin/bash

source lib/functions.sh

if [ -z "${RED_HAT_PULL_SECRET_PATH}" ]; then 
echo -e "\e[33m" "If you are planning to impornt Kubernetes cluster that are not OpenShift you must export the RED_HAT_PULL_SECRET_PATH environment variable. Installing RHACM without pull secret...\e[0m"
fi

#
# Create Operator Namespace
#
oc new-project $RHACM_NAMESPACE

#
# Create RH pull secret
#
if [ "${RED_HAT_PULL_SECRET_PATH}" ]; then 
  oc create secret generic $RHACM_SECRET_NAME -n $RHACM_NAMESPACE --from-file=.dockerconfigjson=$RED_HAT_PULL_SECRET_PATH --type=kubernetes.io/dockerconfigjson
fi

#
# Create Operator Group
#
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: $RHACM_OPERATOR_GROUP_NAME
spec:
  targetNamespaces:
  - $RHACM_NAMESPACE
EOF

#
# Apply the subscription
#
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: acm-operator-subscription
spec:
  sourceNamespace: openshift-marketplace
  source: redhat-operators
  channel: release-2.0
  installPlanApproval: Automatic
  name: advanced-cluster-management
EOF

#
# Wait for RHACM Subscription to be created
#
log "Waiting for RHACM Subscription (180 seconds)"
progress-bar 180

#
# Create the Installation
#
log "Applying the RHACM 2.0 - Multiclusterhub Installation"

if [ "${RED_HAT_PULL_SECRET_PATH}" ]; then 

cat << EOF | oc apply -f -
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: $RHACM_NAMESPACE
spec:
  imagePullSecret: $RHACM_SECRET_NAME
EOF

else

cat << EOF | oc apply -f -
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: $RHACM_NAMESPACE
EOF

fi

#
# Wait for Installation to be created
#
log "Waiting for multiclusterhub to start (5 minutes)"
progress-bar 300

rhacmstatus

log "RHACM has been deployed"
