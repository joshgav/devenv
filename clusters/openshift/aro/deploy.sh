#! /usr/bin/env bash

this_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
root_dir=$(cd ${this_dir}/../.. && pwd)
if [[ -f ${root_dir}/.env ]]; then source ${root_dir}/.env; fi
if [[ -f ${this_dir}/.env ]]; then source ${this_dir}/.env; fi

az login --service-principal &> /dev/null \
    --tenant   ${AZURE_TENANT_ID} \
    --username ${AZURE_PRINCIPAL_ID} \
    --password ${AZURE_PRINCIPAL_SECRET}
if [[ $? != 0 ]]; then
    echo "ERROR: failed to login"
    exit 2
fi

group_name=openenv-${AZURE_GROUP_ID}
vnet_name=aro-vnet-${AZURE_GROUP_ID}
cluster_name=aro-cluster-${AZURE_GROUP_ID}

az network vnet show --resource-group ${group_name} --name ${vnet_name} --output none &> /dev/null
if [[ $? != 0 ]]; then
    echo "INFO: creating vnet and subnets for cluster"
    az network vnet create --name ${vnet_name} \
        --resource-group ${group_name} \
        --address-prefixes 10.0.0.0/22
    az network vnet subnet create --name master-subnet \
        --resource-group ${group_name} --vnet-name ${vnet_name} \
        --address-prefixes 10.0.0.0/23 --service-endpoints Microsoft.ContainerRegistry
    az network vnet subnet update --name master-subnet \
        --resource-group ${group_name} --vnet-name ${vnet_name} \
        --disable-private-link-service-network-policies true
    az network vnet subnet create --name worker-subnet \
        --resource-group ${group_name} --vnet-name ${vnet_name} \
        --address-prefixes 10.0.2.0/23 --service-endpoints Microsoft.ContainerRegistry
fi

az aro show --resource-group ${group_name} --name ${cluster_name} --output none &> /dev/null
if [[ $? != 0 ]]; then
    az aro create --resource-group ${group_name} --name ${cluster_name} \
        --vnet ${vnet_name} --master-subnet master-subnet --worker-subnet worker-subnet \
        --client-id "${AZURE_ARO_PRINCIPAL_ID}" \
        --client-secret "${AZURE_ARO_PRINCIPAL_SECRET}" \
        --pull-secret "${OPENSHIFT_PULL_SECRET}" \
        --no-wait
fi
az aro wait --created -g ${group_name} -n ${cluster_name} &> /dev/null
if [[ $? != 0 ]]; then
    echo "ERROR: failed to wait for ready cluster"
    exit 3
fi

cluster_info=$(az aro show --resource-group ${group_name} --name ${cluster_name} --output json)
cluster_creds=$(az aro list-credentials --resource-group ${group_name} --name ${cluster_name} --output json)
apiserver_url=$(echo "${cluster_info}" | jq -r '.apiserverProfile.url')
console_url=$(echo "${cluster_info}" | jq -r '.consoleProfile.url')
kubeadmin_password=$(echo "${cluster_creds}" | jq -r '.kubeadminPassword')

echo ""
echo "Cluster INFO"
echo "API server: ${apiserver_url}"
echo "Console: ${console_url}"
echo "kubeadmin password: ${kubeadmin_password}"

echo ""
echo "To login via the CLI run:"
echo "oc login --server ${apiserver_url} --username kubeadmin --password '${kubeadmin_password}'"
echo ""
