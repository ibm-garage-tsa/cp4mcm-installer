#!/bin/bash

source setup_env.sh

#
# Delete instances of multiclusterhub
#
oc delete multiclusterhub --all
log "Waiting for instance delete (60 seconds)"
progress-bar 60

#
# Delete related components
#
oc delete subs --all
log "Waiting for deletion of related components (60 seconds)"
progress-bar 60

#
# Delete operator group
#
oc delete operatorgroup $RHACM_OPERATOR_GROUP_NAME
log "Waiting for deletion of operator group (5 seconds)"
progress-bar 5

#
# Delete secret
#
oc delete secret $RHACM_SECRET_NAME
log "Waiting for deletion of secrets (3 seconds)"
progress-bar 3

#
# Delete project
#
oc delete project $RHACM_NAMESPACE
log "Waiting for deletion of project (5 seconds)"
progress-bar 5
