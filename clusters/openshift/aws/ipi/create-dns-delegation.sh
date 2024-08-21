#! /usr/bin/env bash

# hints for creating a hosted zone for the subdomain for an OpenShift cluster

subdomain=aws.joshgav.com.

caller_ref=$(uuid)

## create a hosted zone for the subdomain
aws route53 create-hosted-zone --name "${subdomain}" --caller-reference ${caller_ref}
## find the Zone ID for the created hosted zone
zone_id=$(aws route53 list-hosted-zones --output json | jq -r ".HostedZones[] | select( .Name == \"${subdomain}\" ) | .Id")
## output the delegation nameservers for the hosted zone
## create an NS record in the parent zone and add these as values
aws route53 get-hosted-zone --id "${zone_id}" --output json | jq -r '.DelegationSet.NameServers[]'