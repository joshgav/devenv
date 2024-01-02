# schema: https://github.com/openshift/installer/blob/master/pkg/types/installconfig.go
apiVersion: v1
metadata:
  name: ${OPENSHIFT_CLUSTER_NAME}
baseDomain: ${OPENSHIFT_BASE_DOMAIN}
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: {}
  # must be '1' for SNO
  replicas: 1
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform: {}
  # must be '0' for SNO
  replicas: 0
networking:
  networkType: OVNKubernetes
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 192.168.1.0/24
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
publish: External
pullSecret: '${OPENSHIFT_PULL_SECRET}'
sshKey: '${SSH_PUBLIC_KEY}'
