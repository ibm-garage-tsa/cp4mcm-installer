FROM ubuntu:18.04 as osinstall

WORKDIR /usr/src/CP4MCM_20
COPY *.sh ./
COPY Makefile ./
RUN mkdir cp4m
RUN mkdir lib
RUN mkdir rhacm
WORKDIR /usr/src/CP4MCM_20/cp4m
COPY ./cp4m ./
WORKDIR /usr/src/CP4MCM_20/lib
COPY ./lib ./
WORKDIR /usr/src/CP4MCM_20/rhacm
COPY ./rhacm ./
WORKDIR /usr/src/CP4MCM_20

RUN apt-get update && apt-get install -y wget make

RUN wget -q https://github.com/openshift/okd/releases/download/4.5.0-0.okd-2020-09-18-202631/openshift-client-linux-4.5.0-0.okd-2020-09-18-202631.tar.gz
RUN tar -xzf openshift-client-linux-4.5.0-0.okd-2020-09-18-202631.tar.gz
RUN mv ./oc /usr/local/bin
RUN rm ./kubectl
RUN rm openshift-client-linux-4.5.0-0.okd-2020-09-18-202631.tar.gz

RUN wget -q https://github.com/IBM/cloud-pak-cli/releases/download/v3.4.4/cloudctl-linux-amd64.tar.gz
RUN tar -xzf cloudctl-linux-amd64.tar.gz
RUN mv ./cloudctl-linux-amd64 /usr/local/bin/cloudctl
RUN rm cloudctl-linux-amd64.tar.gz

RUN find /usr/src/CP4MCM_20 -type f -iname "*.sh" -exec chmod +x {} \;
