# Installation assets for CP4MCM 2.1

**Note:** This project is provided **AS-IS**. Support will be provided as possible via git issues.

**Updates:**  
11/4/2020
- Added support for RedHat Advanced Cluster Management  
- Refactored installation process

## Overview:

This project is designed to provide an automated way to install the Cloud Pak for Multi Cloud Management v 2.1.

### Scope:

Single replica (Non-HA) Configuration

This automation currently provides the following installation functionality:

- MCM Core\RHACM
- MCM Monitoring Module
- MCM Infrastructure Management Module
- CloudForms ([with sample LDAP](./ldap_schema.md))

In development:

- Ansible Tower

## Usage:

There are two ways this automation can be used.
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
```
git clone git@github.com:ibm-garage-tsa/cp4mcm-installer.git
```

2. Export your entitled registy key:
```
export ENTITLED_REGISTRY_KEY="Your long key here"
```

_(Optional)_ If you are installing RHACM and will import other clusters, export the path to your Red Hat Pull Secret:

```
export RED_HAT_PULL_SECRET_PATH="/opt/downloads/pull-secret.txt"
```

3. Set installation parameters in the `setup_env.sh` file:

   **Storage Classes**

   Modify the following parameters to configure the required storage classes.

   CP4MCM_BLOCK_STORAGECLASS=""    
   CP4MCM_FILE_STORAGECLASS=""  

   * If you are using ROKS you can just accept the defaults and it will use ibmc-block-gold, ibmc-file-gold and ibmc-file-gold-gid
   * If you are using OpenShift Container Storage you can accept the defaults and it will use ocs-storagecluster-ceph-rbd and ocs-storagecluster-cephfs
   * If you are using some other storage solution or you want to use storage outside of the defaults you will need to customize the storage classes

   **CP4MCM Config**

   Modify the following values to enable\disable each of the components.

   CP4MCM_RHACM_ENABLED="true"  
   CP4MCM_MONITORING="true"  
   CP4MCM_INFRASTRUCTUREMANAGEMENT="true"  
   CP4MCM_CLOUDFORMS="true"  

4. Make sure you are in the base project folder and execute the install using the Makefile

- If you want to install all of the components you can run `make all`

### Containerized execution

Coming soon

## Known limitations:

- Does not work on ROKS with VPC
- Supports online installation only
- Supports OpenShift 4.x

## Other Notes

- If you want to uninstall RHACM you can run `./rhacm/99-rhacm-uninstall.sh` (You need to change permissions to 755)
