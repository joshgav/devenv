#! /usr/bin/env bash

this_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
root_dir=$(cd ${this_dir}/../../.. && pwd)
if [[ -f ${root_dir}/.env ]]; then source ${root_dir}/.env; fi
if [[ -f ${this_dir}/.env ]]; then source ${this_dir}/.env; fi

azure_location=${AZURE_LOCATION:-northcentralus}
azure_group_name=${AZURE_GROUP_NAME:-openshift-ipi}
azure_group_name_dns=${AZURE_GROUP_NAME_DNS:-openshift-dns}
azure_app_name=${AZURE_APP_NAME:-openshift-ipi-installer}
azure_app_credentials_path=${HOME}/.azure/osServicePrincipal.json

az configure --defaults location=${azure_location}

group_exists=$(az group exists --name ${azure_group_name})
if ! "${group_exists}"; then
    echo "INFO: creating group ${azure_group_name}"
    az group create --name ${azure_group_name}
else
    echo "INFO: using existing group ${azure_group_name}"
fi

group_exists=$(az group exists --name ${azure_group_name_dns})
if ! "${group_exists}"; then
    echo "INFO: creating group ${azure_group_name_dns}"
    az group create --name ${azure_group_name_dns}
else
    echo "INFO: using existing group ${azure_group_name_dns}"
fi

# to check name servers for zone try `echo "${dns_zone}" | jq -r '.nameServers[]'`
dns_zone_name=${OPENSHIFT_BASE_DOMAIN}
dns_zone=$(az network dns zone show --name ${dns_zone_name} --resource-group ${azure_group_name_dns} --output json)
if [[ -z "${dns_zone}" ]]; then
    az network dns zone create \
        --name ${dns_zone_name} \
        --resource-group ${azure_group_name_dns} \
        --if-none-match
fi

# for more info on quotas try `az quota list --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Compute/locations/${azure_location}"`
echo "INFO: checking registration of resource provider Microsoft.Quota"
registration_state=$(az provider show --namespace Microsoft.Quota --output json | jq -r '.registrationState')
if [[ ! "${registration_state}" == "Registered" ]]; then
    echo "INFO: registered resource provider Microsoft.Quota"
    az provider register --namespace Microsoft.Quota --wait
fi

echo "INFO: checking quotas"
# az extension add --upgrade --name quota
desired_cores_limit=200
cores_limit=$(az quota show --resource-name ""cores"" --output json \
    --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Compute/locations/${azure_location}" | \
        jq -r '.properties.limit.value')
if [[ "${cores_limit}" -lt "${desired_cores_limit}" ]]; then
    echo "INFO: updating limit for cores in ${azure_location} to ${desired_cores_limit}"
    az quota update --resource-name "cores" \
        --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Compute/locations/${azure_location}" \
        --limit-object value=${desired_cores_limit} limit-object-type=LimitValue limit-type=Independent
fi

# vm_types=("standardDSFamily" "standardDSv2Family" "standardDSv3Family" "standardDSv4Family")
vm_types=("standardDSv3Family")
desired_vms_limit=200
for vm_type in "${vm_types[@]}"; do
    vms_limit=$(az quota show --resource-name "${vm_type}" --output json \
        --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Compute/locations/${azure_location}" | \
            jq -r '.properties.limit.value')
    if [[ "${vms_limit}" -lt "${desired_vms_limit}" ]]; then
        echo "INFO: updating limit for ${vm_type} in ${azure_location} to ${desired_vms_limit}"
        az quota update --resource-name "${vm_type}" \
            --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Compute/locations/${azure_location}" \
            --limit-object value=${desired_vms_limit} limit-object-type=LimitValue limit-type=Independent
    fi
done

# create service principal with Contributor role
# we will add 'User Access Administrator' role next
exists=$(az ad sp list --display-name ${azure_app_name} | jq 'length')
if [[ ${exists} == 0 ]]; then
    echo "INFO: creating app named ${azure_app_name} in tenant"
    sp=$(az ad sp create-for-rbac \
        --name ${azure_app_name} \
        --role Contributor \
        --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID}" \
        --output json)
    export AZURE_APP_SECRET=$(echo "${sp}" | jq -r '.password')
    export AZURE_APP_ID=$(echo "${sp}" | jq -r '.appId')
else
    echo "INFO: finding existing app ${azure_app_name} in tenant"
    sp=$(az ad sp list --filter "displayname eq '${azure_app_name}'" | jq '.[0]')
    export AZURE_APP_ID=$(echo "${sp}" | jq -r '.appId')

    stored_app_id=$(cat ${azure_app_credentials_path} | jq -r '.clientId')
    if [[ "${stored_app_id}" == "${AZURE_APP_ID}" ]]; then
        echo "INFO: getting existing secret from ${azure_app_credentials_path}"
        stored_app_secret=$(cat ${azure_app_credentials_path} | jq -r '.clientSecret')
        if [[ -z "${stored_app_secret}" ]]; then
            echo "PANIC: could not find secret for app"
            echo "INFO: reset the secret by running \`az ad app credential reset --id ${AZURE_APP_ID}\`"
            exit 4
        fi
        export AZURE_APP_SECRET=${stored_app_secret}
    else
        echo "PANIC: found mismatching appId in ${azure_app_credentials_path}, please resolve and then continue"
        exit 4
    fi
fi

# add 'User Access Administrator' role
AZURE_SP_ID=$(az ad sp show --id ${AZURE_APP_ID} --output json | jq -r '.id')
# check if role assignment has already been created
az role assignment list --assignee ${AZURE_SP_ID} -o json | jq -r '.[].roleDefinitionName' | grep -q 'User Access Administrator'
if [[ $? == 1 ]]; then
    echo "INFO: Assigning User Access Administrator role to appId ${AZURE_APP_ID}, servicePrincipalId ${AZURE_SP_ID}"
    az role assignment create --role "User Access Administrator" --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}" \
        --assignee-object-id ${AZURE_SP_ID} --assignee-principal-type ServicePrincipal
else
    echo "INFO: User Access Administrator role already assigned"
fi

cat > ${azure_app_credentials_path} <<EOF
{
    "tenantId":       "${AZURE_TENANT_ID}",
    "subscriptionId": "${AZURE_SUBSCRIPTION_ID}",
    "clientId":       "${AZURE_APP_ID}",
    "clientSecret":   "${AZURE_APP_SECRET}"
}
EOF

echo "[INFO]: service principal metadata in use from ${azure_app_credentials_path}"
cat ${azure_app_credentials_path}
