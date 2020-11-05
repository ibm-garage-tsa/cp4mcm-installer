#!/bin/bash

source setup_env.sh

YOUR_CLIENT_ID=`echo There is a huge white elephant in LA zoo | base64`
YOUR_CLIENT_SECRET=`echo 12345678901234567890123456789012345 | base64`
YOUR_CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
YOUR_IM_HTTPD_ROUTE=`echo $YOUR_CP4MCM_ROUTE |sed s/cp-console/inframgmtinstall/`
CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`

log YOUR_CLIENT_ID = $YOUR_CLIENT_ID
log YOUR_CLIENT_SECRET = $YOUR_CLIENT_SECRET
log YOUR_CP4MCM_ROUTE = $YOUR_CP4MCM_ROUTE
log YOUR_IM_HTTPD_ROUTE = $YOUR_IM_HTTPD_ROUTE
log CP_PASSWORD = $CP_PASSWORD
log ENTITLED_REGISTRY_SECRET = $ENTITLED_REGISTRY_SECRET

execlog cloudctl login -a $YOUR_CP4MCM_ROUTE --skip-ssl-validation -u admin -p $CP_PASSWORD -n ibm-common-services

#
# Register IAM OAUTH client
#
log "Registering IAM OAUTH client."
cat << EOF > registration.json
{
    "token_endpoint_auth_method": "client_secret_basic",
    "client_id": "$YOUR_CLIENT_ID",
    "client_secret": "$YOUR_CLIENT_SECRET",
    "scope": "openid profile email",
    "grant_types": [
        "authorization_code",
        "client_credentials",
        "password",
        "implicit",
        "refresh_token",
        "urn:ietf:params:oauth:grant-type:jwt-bearer"
    ],
    "response_types": [
        "code",
        "token",
        "id_token token"
    ],
    "application_type": "web",
    "subject_type": "public",
    "post_logout_redirect_uris": [
        "https://$YOUR_CP4MCM_ROUTE"
    ],
    "preauthorized_scope": "openid profile email general",
    "introspect_tokens": true,
    "trusted_uri_prefixes": [
        "https://$YOUR_CP4MCM_ROUTE/"
    ],
    "redirect_uris": ["https://$YOUR_CP4MCM_ROUTE/auth/liberty/callback", "https://$YOUR_IM_HTTPD_ROUTE/oidc_login/redirect_uri"]
}
EOF

execlog cloudctl iam oauth-client-register -f registration.json

#
# Create imconnectionsecret
#
log "Creating imconnectionsecret."
oc create -f - <<EOF
kind: Secret                                                                                                     
apiVersion: v1                                                                                                   
metadata:                                                                                                        
  name: imconnectionsecret   
  namespace: management-infrastructure-management                                                                                        
stringData:
  oidc.conf: |-                                                                                                  
    LoadModule          auth_openidc_module modules/mod_auth_openidc.so
    ServerName          https://$YOUR_IM_HTTPD_ROUTE
    LogLevel            debug
    OIDCCLientID                   $YOUR_CLIENT_ID
    OIDCClientSecret               $YOUR_CLIENT_SECRET
    OIDCRedirectURI                https://$YOUR_IM_HTTPD_ROUTE/oidc_login/redirect_uri
    OIDCCryptoPassphrase           alphabeta
    OIDCOAuthRemoteUserClaim       sub
    OIDCRemoteUserClaim            name
    # OIDCProviderMetadataURL missing
    OIDCProviderIssuer                  https://127.0.0.1:443/idauth/oidc/endpoint/OP
    OIDCProviderAuthorizationEndpoint   https://$YOUR_CP4MCM_ROUTE/idprovider/v1/auth/authorize
    OIDCProviderTokenEndpoint           https://$YOUR_CP4MCM_ROUTE/idprovider/v1/auth/token
    OIDCOAuthCLientID                   $YOUR_CLIENT_ID
    OIDCOAuthClientSecret               $YOUR_CLIENT_SECRET
    OIDCOAuthIntrospectionEndpoint      https://$YOUR_CP4MCM_ROUTE/idprovider/v1/auth/introspect
    # ? OIDCOAuthVerifyJwksUri          https://$YOUR_CP4MCM_ROUTE/oidc/endpoint/OP/jwk
    OIDCProviderJwksUri                 https://$YOUR_CP4MCM_ROUTE/oidc/endpoint/OP/jwk
    OIDCProviderEndSessionEndpoint      https://$YOUR_CP4MCM_ROUTE/idprovider/v1/auth/logout
    OIDCScope                        "openid email profile"
    OIDCResponseMode                 "query"
    OIDCProviderTokenEndpointAuth     client_secret_post
    OIDCOAuthIntrospectionEndpointAuth client_secret_basic
    OIDCPassUserInfoAs json
    OIDCSSLValidateServer off
    OIDCHTTPTimeoutShort 10
    OIDCCacheEncrypt On

    <Location /oidc_login>
      AuthType  openid-connect
      Require   valid-user
      LogLevel   debug
    </Location>
    <Location /ui/service/oidc_login>
      AuthType                 openid-connect
      Require                  valid-user
      Header set Set-Cookie    "miq_oidc_access_token=%{OIDC_access_token}e; Max-Age=10; Path=/ui/service"
    </Location>
    <LocationMatch ^/api(?!\/(v[\d\.]+\/)?product_info$)>
      SetEnvIf Authorization '^Basic +YWRtaW46'     let_admin_in
      SetEnvIf X-Auth-Token  '^.+$'                 let_api_token_in
      SetEnvIf X-MIQ-Token   '^.+$'                 let_sys_token_in
      SetEnvIf X-CSRF-Token  '^.+$'                 let_csrf_token_in
      AuthType     oauth20
      AuthName     "External Authentication (oauth20) for API"
      Require   valid-user
      Order          Allow,Deny
      Allow from env=let_admin_in
      Allow from env=let_api_token_in
      Allow from env=let_sys_token_in
      Allow from env=let_csrf_token_in
      Satisfy Any
      LogLevel   debug
    </LocationMatch>
    OIDCSSLValidateServer      Off
    OIDCOAuthSSLValidateServer Off
    RequestHeader unset X_REMOTE_USER                                                                            
    RequestHeader set X_REMOTE_USER           %{OIDC_CLAIM_PREFERRED_USERNAME}e env=OIDC_CLAIM_PREFERRED_USERNAME
    RequestHeader set X_EXTERNAL_AUTH_ERROR   %{EXTERNAL_AUTH_ERROR}e           env=EXTERNAL_AUTH_ERROR          
    RequestHeader set X_REMOTE_USER_EMAIL     %{OIDC_CLAIM_EMAIL}e              env=OIDC_CLAIM_EMAIL             
    RequestHeader set X_REMOTE_USER_FIRSTNAME %{OIDC_CLAIM_GIVEN_NAME}e         env=OIDC_CLAIM_GIVEN_NAME        
    RequestHeader set X_REMOTE_USER_LASTNAME  %{OIDC_CLAIM_FAMILY_NAME}e        env=OIDC_CLAIM_FAMILY_NAME       
    RequestHeader set X_REMOTE_USER_FULLNAME  %{OIDC_CLAIM_NAME}e               env=OIDC_CLAIM_NAME              
    RequestHeader set X_REMOTE_USER_GROUPS    %{OIDC_CLAIM_GROUPS}e             env=OIDC_CLAIM_GROUPS            
    RequestHeader set X_REMOTE_USER_DOMAIN    %{OIDC_CLAIM_DOMAIN}e             env=OIDC_CLAIM_DOMAIN
EOF


#
# Create IMInstall
#
log "Creating CloudForms IMInstall"
oc create -f - <<EOF
apiVersion: infra.management.ibm.com/v1alpha1
kind: IMInstall
metadata:
  labels:
    app.kubernetes.io/instance: ibm-infra-management-install-operator
    app.kubernetes.io/managed-by: ibm-infra-management-install-operator
    app.kubernetes.io/name: ibm-infra-management-install-operator
  name: im-iminstall
  namespace: management-infrastructure-management
spec:
  applicationDomain: $YOUR_IM_HTTPD_ROUTE
  imagePullSecret: $ENTITLED_REGISTRY_SECRET
  httpdAuthenticationType: openid-connect
  httpdAuthConfig: imconnectionsecret
  enableSSO: true
  initialAdminGroupName: operations
  license:
    accept: true
  orchestratorInitialDelay: '2400'
EOF

#
# Wait for IM
#
log "Sleeping for 30 seconds."
progress-bar 30
log "Creating IM Connection Resource"

#
# Create Connection
#
oc create -f - <<EOF
 apiVersion: infra.management.ibm.com/v1alpha1
 kind: Connection
 metadata:
   annotations:
     BypassAuth: "true"
   labels:
    controller-tools.k8s.io: "1.0"
   name: imconnection
   namespace: "management-infrastructure-management"
 spec:
   cfHost: web-service.management-infrastructure-management.svc.cluster.local:3000
EOF

#
# Wait for install
#
log "Waiting for installation to start. (180 seconds)"
progress-bar 180
status

#
# Create links in the UI
#
log "Applying navigation UI updates."
./cp4m/automation-navigation-updates.sh -p



