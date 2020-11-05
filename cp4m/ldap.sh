#!/bin/bash

source setup_env.sh

#
# cloudctl login
#
# Add admin user to LDAP schema
#
YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`
execlog cloudctl login -a $YOUR_CP4MCM_ROUTE --skip-ssl-validation -u admin -p $CP_PASSWORD -n default

#
# Create LDAP Resources
#
log "Creating LDAP project"
execlog oc new-project ldap

log "Updating LDAP project SCC"
execlog oc adm policy add-scc-to-user anyuid -z default -n ldap

log "Creating LDAP Deployment"

oc create -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ldap
  namespace: ldap
  labels:
    app: ldap
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ldap
  template:
    metadata:
      labels:
        app: ldap
    spec:
      containers:
        - name: ldap
          image: johnowebb/openldap:latest
          ports:
            - containerPort: 389
              name: openldap
EOF

log "Creating LDAP Service"

oc create -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: ldap
  name: ldap-service
  namespace: ldap
spec:
  ports:
    - port: 389
  selector:
    app: ldap
EOF

log "Sleeping while LDAP is starting.. (60 seconds)"
progress-bar 60

#
# Configure CP4MCM LDAP 
#
log "Configuring LDAP connection for Common Services."
execlog cloudctl iam ldap-create my_ldap --basedn 'dc=ibm,dc=com' --binddn 'cn=admin,dc=ibm,dc=com' --binddn-password Passw0rd --server ldap://ldap-service.ldap.svc.cluster.local:389 --group-filter '(&(cn=%v)(objectclass=groupOfUniqueNames))' --group-id-map '*:cn' --group-member-id-map 'groupOfUniqueNames:uniqueMember' --user-filter '(&(uid=%v)(objectclass=inetOrgPerson))' --user-id-map '*:uid'
execlog cloudctl iam team-create operations
execlog cloudctl iam group-import --group operations -f
execlog cloudctl iam team-add-groups operations Administrator -g operations


