#!/bin/bash

set -x
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. ${SCRIPTPATH}/../../common/helpers.sh


BASE_TAG=14.2.0-debian-10-r
INPUT_REGISTRY=docker.io
INPUT_ACCOUNT=bitnami
REPOSITORY=postgresql-repmgr
HELM_REPOSITORY=postgresql-ha

test()
{
    local IMAGE_REPOSITORY=$1
    local TAG=$2
    local HELM_RELEASE=postgresql-ha-release
    
    echo "Testing postgresql-ha"

    # upgrade helm
    helm repo update

    # Install postgresql
    helm install ${HELM_RELEASE} ${INPUT_ACCOUNT}/${HELM_REPOSITORY} --namespace ${NAMESPACE} --set postgresql.image.tag=${TAG} --set postgresql.image.repository=${IMAGE_REPOSITORY} -f ${SCRIPTPATH}/overrides.yml

    # waiting for pod to be ready
    echo "waiting for pod to be ready"
    kubectl wait pods ${HELM_RELEASE}-postgresql-0 -n ${NAMESPACE} --for=condition=ready --timeout=10m

    # get postgresql-ha password
    POSTGRES_PASSWORD=$(kubectl get secret --namespace ${NAMESPACE} ${HELM_RELEASE}-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)

    # create postgresql-ha client
    kubectl run -n ${NAMESPACE} ${HELM_RELEASE}-client \
        --restart='Never' \
        --env="PGPASSWORD=${POSTGRES_PASSWORD}" \
        --image ${INPUT_REGISTRY}/${INPUT_ACCOUNT}/${REPOSITORY}:${TAG} \
        --command -- /bin/bash -c "while true; do sleep 30; done;"

    # wait for postgresql-ha client to be ready
    kubectl wait pods ${HELM_RELEASE}-client -n ${NAMESPACE} --for=condition=ready --timeout=10m

    # copy test.psql into container
    kubectl -n ${NAMESPACE} cp ${SCRIPTPATH}/../../common/tests/test.psql ${HELM_RELEASE}-client:/tmp/test.psql

    # run script
    kubectl -n ${NAMESPACE} exec -i ${HELM_RELEASE}-client \
        -- /bin/bash -c "psql --host ${HELM_RELEASE}-pgpool -U postgres -d postgres -p 5432 -f /tmp/test.psql"

    # delete client container
    kubectl -n ${NAMESPACE} delete pod ${HELM_RELEASE}-client

    # bring down helm install
    helm delete ${HELM_RELEASE} --namespace ${NAMESPACE}

    # delete the PVC associated
    kubectl -n ${NAMESPACE} delete pvc --all
}

build_images ${INPUT_REGISTRY} ${INPUT_ACCOUNT} ${REPOSITORY} ${BASE_TAG} test
