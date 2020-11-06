# Installation assets for CP4MCM 2.1

**Note:** This project is provided **AS-IS**. Support will be provided as possible via git issues.

**Updates:**  
11/4/2020
- Added support for RedHat Advanced Cluster Management  
- Refactored installation process

## Overview:

This project is designed to provide an automated way to install the Cloud Pak for Multicloud Management (CP4MCM) v2.1.

### Scope:

Single replica (Non-HA) Configuration

This automation currently provides the following installation functionality:

- MCM Core / RHACM
- Monitoring Module
- Infrastructure Management Module (formerly CloudForms), [with sample LDAP](./ldap_schema.md))

In development:

- Ansible Tower

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

1. Clone repo locally:

```sh
$ git clone https://github.com/ibm-garage-tsa/cp4mcm-installer.git
$ cd cp4mcm-installer
```

2. Export configurable variables:

There are quite some configurable variables to further customize the installation.

Please check out [setup_env.sh](./setup_env.sh) for details.

> Note: It's recommended to compile a local bash file so that we can export all customized variables without the need to change any existing files -- a file starting with `_` will be ignored by this repository so it's safe to keep it local and private only.

```sh
$ cat > _customization.sh <<EOF

#
# IBM Entitled Registry Credential
#
export ENTITLED_REGISTRY_USER="cp"
export ENTITLED_REGISTRY_KEY="Your long entitlement key here"

#
# Cloud Pak Modules to enable or disable:
# - true: to enable
# - false: to disable
#
export CP4MCM_RHACM_ENABLED="true"
export CP4MCM_INFRASTRUCTUREMANAGEMENT_ENABLED="true"
export CP4MCM_MONITORING_ENABLED="true"

#
# (Optional) If RHACM is enabled, Red Hat Pull Secret must be set
#
export RED_HAT_PULL_SECRET_PATH="Your Red Hat pull secret file path"

#
# Storage Classes
#
# Important notes:
# - If you are using ROKS you can just accept the defaults by setting it "" and it will use:
#   - ibmc-block-gold
#   - ibmc-file-gold
#   - ibmc-file-gold-gid
# - If you are using OpenShift Container Storage you can accept the defaults by setting it "" and it will use
#   - ocs-storagecluster-ceph-rbd
#   - ocs-storagecluster-cephfs
# - If you are using some other storage solution or you want to use storage other than the defaults, specify them here
#
export CP4MCM_BLOCK_STORAGECLASS=""
export CP4MCM_FILE_STORAGECLASS=""

EOF
```

3. Make sure you are in the base project folder and execute the install using the Makefile

```sh
# Source the customization we've compiled
$ source _customization.sh

# Then kick it off
$ make
```

> Note: A `install.log` file will be generated to log the installation activities within the `_logs` folder under current folder, but you can change the folder by `export LOGDIR=<somewhere else>`.

### Containerized execution

Coming soon

## Known limitations:

- Does not work on ROKS with VPC
- Supports online installation only
- Supports OpenShift 4.x

## Other Notes

- If you want to uninstall RHACM you can run `./rhacm/99-rhacm-uninstall.sh` (You need to change permissions to 755)
