#!/bin/bash

source lib/functions.sh

#
#
# Patch inventory to bring back the data integration in ROKS, like IM <-> CP4MCM Dashboard; IM <-> SRE
#
#

if [[ "$ROKS" == "true" ]]; then 

log "Patching inventory in ROKS"
# Patch to disable ibm-sre-inventory-operator
kubectl patch deployment ibm-sre-inventory-operator -n kube-system -p '{"spec":{"replicas":0}}'
# Patch it to set proper securityContext
kubectl patch statefulset sre-inventory-inventory-redisgraph -n kube-system -p '{"spec":{"template":{"spec":{"securityContext":{"fsGroup":1001,"runAsUser":1001}}}}}'
# Delete to trigger a pod restart
kubectl delete pod "`kubectl get pod -n kube-system | grep sre-inventory-inventory-rhacmcollector | cut -d " " -f 1`" -n kube-system
kubectl delete pod "`kubectl get pod -n kube-system | grep sre-inventory-inventory-cfcollector | cut -d " " -f 1`" -n kube-system

fi


#
#
# Patch CAM TLS Cert to make sure it works under morden browsers like Chrome
#
#

# Prepare CAM route
CAM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}' | sed s/cp-console/cam/`

# Patching CAM TLS cert
# oc get -n management-infrastructure-management cert/cert -o yaml
log "Patching CAM TLS cert"
oc patch Certificate cert --type "json" -n management-infrastructure-management \
    -p "[
        {\"op\":\"add\",\"path\":\"/spec/dnsNames/-\",\"value\":\"${CAM_ROUTE}\"},
        {\"op\":\"add\",\"path\":\"/spec/duration\",\"value\":\"8760h0m0s\"},
        {\"op\":\"add\",\"path\":\"/spec/usages\",\"value\":[\"digital signature\",\"key encipherment\",\"server auth\"]}
    ]"
