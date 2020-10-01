FROM ubuntu:18.04 as osinstall

WORKDIR /usr/src/CP4MCM_20
COPY . ./

# Install prerequisities for Ansible
RUN apt-get update
RUN apt-get -y install build-essential
RUN apt-get -y install python3 python3-nacl python3-pip libffi-dev

FROM osinstall as ansibleinstall
# Install ansible
RUN pip3 install ansible

# update 
RUN apt-get update
# install curl and wget
RUN apt install curl -y
RUN apt-get install wget

RUN wget https://github.com/openshift/okd/releases/download/4.5.0-0.okd-2020-09-18-202631/openshift-client-linux-4.5.0-0.okd-2020-09-18-202631.tar.gz
RUN tar -xzf openshift-client-linux-4.5.0-0.okd-2020-09-18-202631.tar.gz
RUN mv ./oc /usr/local/bin
RUN mv ./kubectl /usr/local/bin

FROM ansibleinstall as scriptinstall
# permissions for the bash scripts
RUN find /usr/src/CP4MCM_20 -type f -iname "*.sh" -exec chmod +x {} \;

CMD ./0-setup_env.sh && make mcmall
