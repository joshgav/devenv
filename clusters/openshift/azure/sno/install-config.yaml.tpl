# schema: https://github.com/openshift/installer/blob/master/pkg/types/installconfig.go
apiVersion: v1
metadata:
  name: ${OPENSHIFT_CLUSTER_NAME}
baseDomain: ${OPENSHIFT_BASE_DOMAIN}
platform:
  azure:
    resourceGroupName: ${AZURE_GROUP_NAME}
    baseDomainResourceGroupName: ${AZURE_GROUP_NAME_DNS}
    # networkResourceGroupName: ${AZURE_GROUP_NAME}
    region: ${AZURE_LOCATION}
    # _not_ a misspelling - the 'b' is small
    outboundType: Loadbalancer
pullSecret: '${OPENSHIFT_PULL_SECRET}'
sshKey: '${SSH_PUBLIC_KEY}'
publish: External
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: 1
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 0
networking:
  networkType: OVNKubernetes
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  serviceNetwork:
  - 172.30.0.0/16
