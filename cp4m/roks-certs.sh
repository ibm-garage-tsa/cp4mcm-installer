#!/bin/bash

source lib/functions.sh

log "Extracting Let's Encrypt certificate from Openshift Ingress"
ingress_pod=$(oc get secrets -n openshift-ingress | grep tls | grep -v router-metrics-certs-default | awk '{print $1}')
oc get secret -n openshift-ingress -o 'go-template={{index .data "tls.crt"}}' ${ingress_pod} | base64 -d > cert.crt
oc get secret -n openshift-ingress -o 'go-template={{index .data "tls.key"}}' ${ingress_pod} | base64 -d > cert.key

log "Reconfiguring cp-console route"

oc -n ibm-common-services patch managementingress default --type merge --patch '{"spec":{"managementState":"Unmanaged"}}'

oc -n ibm-common-services get route cp-console -o jsonpath="{.spec.tls.destinationCACertificate}" > dest-ca.crt

url=$(oc -n ibm-common-services get route cp-console -o jsonpath="{.spec.host}")

# chain-ca.crt extracted from the browser (Firefox)

oc -n ibm-common-services create route reencrypt cp-console --service=icp-management-ingress  --cert=./cert.crt  --key=./cert.key  --ca-cert=./chain-ca.crt  --dest-ca-cert=./dest-ca.crt  --hostname=$url  --insecure-policy='Redirect'  --dry-run=client -o yaml  > cp-console.yaml

oc -n ibm-common-services  apply -f cp-console.yaml

oc -n ibm-common-services get certificate route-cert -o yaml  > route-cert.bak

oc -n ibm-common-services delete certificate route-cert

oc -n ibm-common-services delete secret route-tls-secret
oc -n ibm-common-services create secret generic route-tls-secret --from-file=ca.crt=./chain-ca.crt  --from-file=tls.crt=./cert.crt  --from-file=tls.key=./cert.key


oc -n ibm-common-services get secret ibmcloud-cluster-ca-cert -o yaml > ibmcloud-cluster-ca-cert.bak


oc -n ibm-common-services delete secret ibmcloud-cluster-ca-cert
oc -n ibm-common-services create secret generic ibmcloud-cluster-ca-cert --from-file=ca.crt=./chain-ca.crt

oc -n ibm-common-services delete pod -l app=auth-idp

#CAM part

log "Updating CAM route to use signed certificate"

mkdir backup
oc project management-infrastructure-management

camproxypod=$(oc get pods |grep cam-proxy |awk '{print $1}')

oc -n management-infrastructure-management cp $camproxypod:/var/camlog/cam-proxy/ssl/nginx.crt backup/nginx.crt

oc -n management-infrastructure-management cp $camproxypod:/var/camlog/cam-proxy/ssl/nginx.key backup/nginx.key

cp cert.crt custom_nginx.crt
cp cert.key custom_nginx.key

oc -n management-infrastructure-management cp custom_nginx.crt $camproxypod:/var/camlog/cam-proxy/ssl
oc -n management-infrastructure-management cp custom_nginx.key $camproxypod:/var/camlog/cam-proxy/ssl

oc -n management-infrastructure-management delete pod $camproxypod

#IM part

log "Updating IM route to use signed certificate"

oc -n management-infrastructure-management get secret tls-secret -o yaml > backup/tls-secret.yaml

#Update the tls.cert and tls.key with cert.crt and cert.key (right now done manually in UI)
oc -n management-infrastructure-management create secret generic new-tls-secret --from-file=ca.crt=./chain-ca.crt  --from-file=tls.crt=./cert.crt  --from-file=tls.key=./cert.key
