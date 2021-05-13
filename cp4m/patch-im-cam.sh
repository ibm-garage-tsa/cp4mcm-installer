#!/bin/bash

source lib/functions.sh

# Prepare CAM route
CAM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}' | sed s/cp-console/cam/`

# Patching CAM cert
# oc get -n management-infrastructure-management cert/cert -o yaml
log "Patching CAM cert"
oc patch Certificate cert --type "json" -n management-infrastructure-management \
    -p "[
        {\"op\":\"add\",\"path\":\"/spec/dnsNames/-\",\"value\":\"${CAM_ROUTE}\"},
        {\"op\":\"add\",\"path\":\"/spec/duration\",\"value\":\"8760h0m0s\"},
        {\"op\":\"add\",\"path\":\"/spec/usages\",\"value\":[\"digital signature\",\"key encipherment\",\"server auth\"]}
    ]"
