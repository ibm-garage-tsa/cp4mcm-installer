#!/bin/bash

source lib/functions.sh

#
# cloudctl login
#
# Add admin user to LDAP schema
#
YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`
execlog cloudctl login -a $YOUR_CP4MCM_ROUTE --skip-ssl-validation -u admin -p $CP_PASSWORD -n default

#
# Create Ansible AWX Resources
#
log "Creating Ansible project"
execlog oc new-project ansible

log "Updating Ansible project SCC"
execlog oc adm policy add-scc-to-user privileged -z awx -n ansible

log "Creating AWX Operator Deployment"

oc apply -f - << EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: awx-operator
subjects:
  - kind: ServiceAccount
    name: awx-operator
    namespace: ansible
roleRef:
  kind: ClusterRole
  name: awx-operator
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: awx-operator
  namespace: ansible
EOF


oc apply -f https://raw.githubusercontent.com/ansible/awx-operator/0.9.0/deploy/awx-operator.yaml

log "Creating TLS secret for secure route"

log "Extracting Let's Encrypt certificate from Openshift Ingress"
ingress_pod=$(oc get secrets -n openshift-ingress | grep tls | grep -v router-metrics-certs-default | awk '{print $1}')
oc get secret -n openshift-ingress -o 'go-template={{index .data "tls.crt"}}' ${ingress_pod} | base64 -d > cert.crt
oc get secret -n openshift-ingress -o 'go-template={{index .data "tls.key"}}' ${ingress_pod} | base64 -d > cert.key

oc -n ansible create secret generic tls-secret  --from-file=tls.crt=./cert.crt  --from-file=tls.key=./cert.key --save-config --dry-run=client -o yaml | oc apply -f -

log "Creating AWX Instance"

oc apply -f - <<EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: ansible
spec:
  ingress_type: Route
  route_host: ansible${YOUR_CP4MCM_ROUTE:10}
  route_tls_secret: tls-secret
  postgres_resource_requirements:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      cpu: 1
      memory: 4Gi
  postgres_storage_requirements:
    requests:
      storage: 8Gi
    limits:
      storage: 50Gi
  web_resource_requirements:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
  task_resource_requirements:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  task_privileged: true
EOF

log "Sleeping while AWX is starting.. (600 seconds)"
progress-bar 600

#
# Configure CP4MCM Menu
#
log "Configuring Menu integration"
sed "s/ansible-tower-web-svc/awx/" cp4m/automation-navigation-updates.sh > awx.sh
chmod +x awx.sh
./awx.sh -a ansible

#
# List out what users in "operations" group that we've imported
#
log "Listing out the AWX admin user credentials."
execlog oc -n ansible get secret awx-admin-password -o jsonpath="{.data.password}" | base64 --decode
