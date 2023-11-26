# Azure IPI

### Prerequisites

- Azure account (aka subscription) with permission to create a service account
  with 'Contributor' and 'User Access Administrator' privileged (tenant) roles.
- DNS zone for OpenShift base domain in Azure (see [this doc](https://docs.openshift.com/container-platform/4.12/installing/installing_azure/installing-azure-account.html#installation-azure-network-config_installing-azure-account))
- Ensure sufficient resource quotas in your target Azure region, particularly
for vCPUs. You can do this in the Azure portal [here](https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas).
See the picture at [./assets/quota_increase.png](./assets/quota_increase.png) for an example.
- Tools: [az](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli), [jq](https://stedolan.github.io/jq/download/), [openshift-install](https://console.redhat.com/openshift/downloadshttps://console.redhat.com/openshift/downloads#tool-x86_64-openshift-install), [oc](https://console.redhat.com/openshift/downloadshttps://console.redhat.com/openshift/downloads#tool-oc)

## Use

1. Set parameters and secrets in `.env` here or in the repo root
1. Login to Azure as a user with at least "Contributor" and "User Access Administrator" roles: `az login`
1. Run `./init.sh` to create a service principal with [required roles](https://docs.openshift.com/container-platform/4.12/installing/installing_azure/installing-azure-account.html#installation-azure-permissions_installing-azure-account)
1. Run `./deploy.sh` to deploy the cluster
1. Once deployment is complete find credentials here in `./_workdir/auth`

To destroy the cluster, run `openshift-install destroy cluster --dir ./_workdir/`.

## Notes

- A tenant in Azure is related to Azure's directory, Azure Active Directory. A tenant can be associated with many subscriptions.
- A subscription is the top-level container in Azure Resource Manager. Billing is applied to subscriptions. A subscription can contain many resource groups. A subscription can also be part of a management group, which is a container of subscriptions (introduced _after_ subscriptions).
- This process is based on the docs here:
  - Prerequisites: <https://docs.openshift.com/container-platform/4.12/installing/installing_azure/installing-azure-account.html>
  - Installation: <https://docs.openshift.com/container-platform/4.12/installing/installing_azure/installing-azure-default.html>
- Commands to delete the service principal created by `init.sh`:

  ```bash
  azure_app_id=$(az ad sp list --display-name openshift-ipi-admin -o json | jq -r '.[0].appId')
  az ad sp delete --id ${azure_app_id}
  ```