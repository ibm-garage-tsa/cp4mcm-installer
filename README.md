# CP4MCM_20

[![Build Status](https://travis.ibm.com/Andrew-Nguyen/CP4MCM_20.svg?token=KDx7UxuaEtyDyAGKT6Ai&branch=master)](https://travis.ibm.com/Andrew-Nguyen/CP4MCM_20)

Installation assets for CP4MCM 2.0

Note: This project is provided AS-IS. Support will be provided as possible via git issues.

Overview:
This project is designed to provide an automated way to install the Cloud Pak for Multi Cloud Management v 2.0.

Scope:
CP4MCM 2.0 Online Installation
Single replica (Non-HA) Configuration

This automation currently provides the following functionality
    - MCM Core
    - MCM Monitoring Module
    - MCM Infrastructure Management Module
    - CloudForms (with sample LDAP)

In development
    - Ansible Tower

Usage:
There are two ways this automation can be used.
    1. You can clone this repo and execute the commands locally
    2. You can execute the installation from the Docker image that has been built (Beta)

Executing locally
    Pre-reqs
        - oc command
        - You must be authenticated to your OpenShift cluster
        - make
        - IBM Entitled Registry Key

    1. Clone repo locally:
        Git clone

    2. Export your entitled registy key:
        export ENTITLED_REGISTRY_KEY="Your long key here"

    3. Setup the storage classes:
        If you are using ROKS you can just accept the defaults
        If you are using OpenShift Container Storage you can accept the defaults
        If you are using some other storage solution you will need to customize the storage classes

    4. Execute the install using the Makefile
        make mcmcore
            Common Services
            MCM Core components

        make mcmenablemonitoring
            Installs the Monitoring Module

        make mcmenableim
            Will install Sample LDAP, Infrastructure management and CloudForms

        make all
            Will install all  of the CP4MCM components

Containerized execution


Known limitations:
    Does not work on ROKS with VPC
    Supports online installation only





