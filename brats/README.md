# Brats pipeline

The brats pipeline can be locally or deployed internally using [Catapult](https://github.com/SUSE/catapult) and [EKCP](https://github.com/mudler/ekcp).

## Deployment instructions

### Install ekcp

Ekcp has to be installed in a node which is reachable from the concourse workers. Instructions can be found [here](https://github.com/mudler/ekcp/wiki/Single-node-setup).

### Adapt the pipeline to point to a cluster

- Choose a unique name for your cluster, e.g. *brats* , and replace  accordingly `CLUSTER_NAME` value in the pipeline.
- Define `EKCP_HOST` to point where you deployed ekcp. e.g. *ip:port*
- Deploy the brats pipeline with `TARGET=concourse ./deploy.sh brats`

You can specify in this step also a `SCF_CHART` in the `force_redeploy_cluster` job which points to the SCF chart you wish to deploy.

### Create the cluster suitable for running BRATS tests

At this point, what is you need to do is just to trigger the `force_redeploy_cluster` job in the pipeline, which will create a new cluster configured for brats.

### Deploy the nginx proxy

Some BRATS tests might need an nginx proxy on the cluster to test redacted credentials from output, when downloading buildpack dependencies.

To setup the proxy, there is a make target to do that in [Catapult](https://github.com/SUSE/catapult), which is `module-extra-brats-setup`, for reference [here is defined the source code and the steps](https://github.com/SUSE/catapult/blob/46328a500e2dd75d3e437a8156963bc221bdd76e/modules/scf/brats_setup.sh), which includes the deployment of an nginx proxy.

In case the brats setup needs to be run manually, note that it needs to connect directly to SCF, and the make target might need to be run inside a pod in the cluster. (you an do that with `make module-extra-terminal` in Catapult).