#! /usr/bin/env bash

this_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
root_dir=$(cd ${this_dir}/../../.. && pwd)
echo "root_dir: ${root_dir}"
if [[ -e "${root_dir}/.env" ]]; then source "${root_dir}/.env"; fi
if [[ -e "${this_dir}/.env" ]]; then source "${this_dir}/.env"; fi
source ${root_dir}/lib/kubernetes.sh
source ${root_dir}/lib/install.sh

install_openshift_install

workdir=${this_dir}/_workdir/

ssh_keypair_path=${root_dir}/.ssh
ensure_ssh_keypair ${ssh_keypair_path}
setup_workdir ${workdir}
mkdir ${workdir}/openshift

export SSH_PUBLIC_KEY="$(cat ${ssh_keypair_path}/id_rsa.pub)"
cat ${this_dir}/install-config.yaml.tpl | envsubst 1> ${workdir}/install-config.yaml
cat ${this_dir}/agent-config.yaml.tpl   | envsubst 1> ${workdir}/agent-config.yaml

# for file in $(find ${this_dir}/extras -type f -iname '*.yaml'); do 
#     cp "${file}" ${workdir}/openshift
# done

# openshift-install agent create cluster-manifests --dir ${workdir}
openshift-install agent create image --dir ${workdir}

# ssh -i ${root_dir}/.ssh/id_rsa core@192.168.122.210
# journalctl --follow
# openshift-install --dir ${workdir} agent wait-for bootstrap-complete
# openshift-install --dir ${workdir} agent wait-for install-complete
