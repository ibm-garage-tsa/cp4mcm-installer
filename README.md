# Installation assets for CP4MCM v2.x

**Note:** This project is NOT an IBM official project and is provided **AS-IS**. Support will be provided as possible via git issues.

**Updates:** 

18/11/2021

**WARNING** CP4MCM 2.3 FP2 released on Nov 5th, 2021 created several issues with this installer, especially when installing on ROKS. DO NOT expect smooth install until further notice.

10/07/2021
- Fixed the size of PVC for Kafka (10G -> 25G)
- Fixed the roks-certs.sh to handle Teleport (SRE Bastion console access) and AWX route
- Fixed the Common Services CRD to decrease a footprint (medium -> small with some changes)

5/27/2021
- Added RemoteAgentDeploy CR to allow automatic deployment of  IBM Monitoring DataProvider to managed clusters
- Added roks-certs.sh script that configures usage of Let's Encrypt signed certificates for Cloud Pak for MCM 2.3
  This script is not applied automatically due to 1 unresolved issue: applying the proper certs breaks functionality of SRE Bastion console access
  To use the script run `./cp4m/roks-certs.sh` after installation of Cloud Pak
- Added ansible.sh script (Experimental) to install and integrate AWX (Ansible Tower upstream project)
  To use the script run `./cp4m/ansible.sh` after installation of Cloud Pak

5/3/2021
- Added RHACM Observability support

4/15/2021
- Updated the installer to work with the latest CP4MCM 2.3 release. 

04/09/2021
- Updated the installer to make CP4MCM version configurable: **2.1** or **2.2**, it's your choice.

12/11/2020
- Updated the installer to work with the latest CP4MCM 2.2 release. 

11/22/2020
- As it turns out that RedHat Advanced Cluster Management is not supported on IBM Cloud RedHat Openshift clusters (ROKS) as a management hub, the default install method is change to use Core MCM instead of RHACM. In you plan to install on a supported cluster and want to use RHACM, export the variable CP4MCM_RHACM_ENABLED="true" (e.g. uncomment the relevant line in a _customizations.sh script shown below)

11/4/2020
- Added support for RedHat Advanced Cluster Management  
- Refactored installation process

## Overview:

This project is designed to provide an automated way to install the Cloud Pak for Multicloud Management (CP4MCM) v2.x.

### Scope:

Single replica (Non-HA) Configuration

This automation currently provides the following installation functionality:

- MCM Core / RHACM
- Monitoring Module
- Infrastructure Management Module (formerly CloudForms), [with sample LDAP](./ldap_schema.md))

## Usage:

There are two ways this automation can be used:
1. You can clone this repo and execute the commands locally
2. You can execute the installation from the Docker image that has been built (Beta)

### Executing locally

**Pre-reqs**

- `oc` command
- You must be authenticated to your OpenShift cluster
- `make` command
- [IBM Entitled Registry Key](https://myibm.ibm.com/products-services/containerlibrary) 
- If installing RHACM and planning to import non-OpenShift clusters, [Red Hat Pull Secret](https://cloud.redhat.com/openshift/install/pull-secret)

**Process**

#### 1. Clone repo locally:

```sh
$ git clone https://github.com/ibm-garage-tsa/cp4mcm-installer.git
$ cd cp4mcm-installer
```

#### 2. Export configurable variables:

There are quite some configurable variables to further customize the installation.

Please check out [setup_env.sh](./setup_env.sh) for details.

> Note: It's recommended to compile a local bash file so that we can export all customized variables without the need to change any existing files -- a file starting with `_` will be ignored by this repository so it's safe to keep it local and private only.

```sh
$ cat > _customization.sh <<EOF

#
# IBM Entitled Registry Credential
#
export ENTITLED_REGISTRY_USER="cp"
export ENTITLED_REGISTRY_KEY="<YOUR LONG ENTITLEMENT KEY GOES HERE>"

#
# Cloud Pak Version, defaults to 2.3 if not set
#
# There are some implications while picking the version. For example:
# - In CP4MCM v2.1.x: the RHACM, once enabled, will be v2.0
# - In CP4MCM v2.2.x: the RHACM, once enabled, will be v2.1
# - In CP4MCM v2.3.x: the RHACM, once enabled, will be v2.2
#
export CP4MCM_VERSION="2.3"

#
# Cloud Pak Modules to enable or disable:
# - true: to enable
# - false: to disable
#
# There are quite some modules can be enabled:
# - CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED
# - CP4MCM_MONITORING_ENABLED
# - CP4MCM_RHACM_ENABLED
# - CP4MCM_RHACM_OBSERVABILITY_ENABLED
# 
# Note: Monitoring requires RHACM Obseravability to be enabled and deployed too
#
export CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED="true"
export CP4MCM_MONITORING_ENABLED="true"
export CP4MCM_RHACM_ENABLED="true"
export CP4MCM_RHACM_OBSERVABILITY_ENABLED="true"

#
# (Optional) If RHACM is enabled, Red Hat Pull Secret must be set
#
export RED_HAT_PULL_SECRET_PATH="YOUR RED HAT PULL SECRET FILE PATH GOES HERE"

#
# Storage Classes
#
# Important notes:
# - If you are using ROKS you can just accept the defaults by setting it "" and it will use:
#   - ibmc-block-gold
#   - ibmc-file-gold
# - If you are using OpenShift Container Storage you can accept the defaults by setting it "" and it will use
#   - ocs-storagecluster-ceph-rbd
#   - ocs-storagecluster-cephfs
# - If you are using some other storage solution or you want to use storage other than the defaults, specify them here
#
export CP4MCM_BLOCK_STORAGECLASS=""
export CP4MCM_FILE_STORAGECLASS=""

EOF
```

#### 3. Make sure you are in the base project folder to execute commands

```sh
# Source the customization we've compiled
$ source _customization.sh

# Make sure we've logged into OCP, then kick it off
$ make
```

> Note: A `install.log` file will be generated to log the installation activities within the `_logs` folder under current folder, but you can change the folder by `export LOGDIR=<somewhere else>`.

#### 4. How to access?

The log file will generate the info for you to access the CP4MCM.

But you can always retrieve the required info by running this:

```sh
# CP4MCM URL
$ oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'
```

There are 2 major mechanisms to authenticate and access CP4MCM ans its components:

**Type 1: Default admin account with `Default authentication` authentication type**

```sh
# CP4MCM default admin user name
oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d
# CP4MCM default admin user password
oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d
```

**Type 2: LDAP users with `Enterprise LDAP` authentication type**

By default, the users within `operations` group are imported as admins as well:
- bob
- laura
- josie
- tom
- paula

The password for all these LDAP users is **`Passw0rd`**.

### Troubleshooting

If your installation hang with the following error:

```sh
Waiting for pods to start.. retry (28 of 60)(Pods remaining =        1)(Consecutive tries 0/3)

ibm-common-services                                ibm-monitoring-grafana-6958ff5fb7-szjqw                           0/3     Init:0/1           0          25m
```

it may be related to the timing issue during installation. To progress the installation you can go to the Openshift console -> Installed Operators and uninstall IBM Monitoring Prometheus Extension Operator. It will get recreated.

### Containerized execution

Coming soon

## Known limitations:

- Does not work on ROKS with VPC
- Supports online installation only
- Supports OpenShift 4.x

## Other Notes

- If you want to uninstall RHACM you can run `./rhacm/99-rhacm-uninstall.sh` (You need to change permissions to 755)
