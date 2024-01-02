apiVersion: v1beta1
kind: AgentConfig
metadata:
  name: agent-config
  namespace: cluster0
## IP address of node0
## may be empty if `nmstateconfig` is provided
rendezvousIP: 192.168.1.222
additionalNTPSources:
- 0.rhel.pool.ntp.org
- 1.rhel.pool.ntp.org
## If a host is listed, then at least one interface needs to be specified.
hosts: []
