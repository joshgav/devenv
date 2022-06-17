#! /usr/bin/env bash

this_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
root_dir=$(cd ${this_dir}/.. && pwd)
source ${root_dir}/lib/requirements.sh
install_operator_sdk

namespace=podtatohead
operator_name=podtatohead-operator
kubectl create namespace ${namespace} &> /dev/null
kubectl config set-context --current --namespace ${namespace}

repo_url=https://github.com/podtato-head/podtato-head.git
pushd ${this_dir}
git clone ${repo_url} ${this_dir}/podtatohead
popd

mkdir -p ${this_dir}/${operator_name}
pushd ${this_dir}/${operator_name}

operator-sdk init --plugins 'helm.sdk.operatorframework.io/v1' --project-version=3 \
  --project-name ${operator_name} \
  --domain podtatohead.io \
  --group apps \
  --version v1alpha1 \
  --kind PodtatoHeadApp \
  --helm-chart ${this_dir}/podtatohead/delivery/chart

export IMAGE_TAG_BASE=quay.io/joshgav/podtatohead-operator
export IMG=${IMAGE_TAG_BASE}:latest
export VERSION=latest
make docker-build
make docker-push

make deploy

kubectl apply -f ${this_dir}/podtatoheadapp.yaml
