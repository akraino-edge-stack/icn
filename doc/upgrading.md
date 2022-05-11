# Upgrading

The upgrade of the compute cluster components is managed via Flux
resources. Please refer to the [Flux](https://fluxcd.io) documentation
for more information.

The upgrade of jump server components is described below. In general
the safest path will be to first clean the component and then deploy
it; not all components support in-place upgrades so skipping the clean
step may lead to a broken deployment.

Please refer to the upstream component documentation for information
about support of in-place upgrades.

## Controllers

The jump server controllers include Flux, Cluster API, Bare Metal
Operator, cert-manager, and Ironic.

The Makefile `controllers` and `controllers_clean` targets deploy and
clean the controllers. To upgrade, first:

    make controllers_clean

followed by updating the ICN repository, and finally:

    make controllers

Individual controllers can be cleaned and deployed with the
`COMPONENT` and `COMPONENT_clean` targets.  Refer to the top-level
`Makefile` for a complete list of controller targets.

## Tools

The jump server tools include CLI tools used during deployment and
management of jump server controllers.  The tools include kustomize,
clusterctl, flux, sops, and emcoctl.

There is no clean step necessary for tools.  Deploying again simply
overwrites the existing tool versions:

    make tools

## Kubernetes

> NOTE: Upgrade of the base K8s components using the method describe
> below is destructive. Any information about the compute clusters
> will be destroyed.

The Makefile `management_cluster` and `management_cluster_clean`
targets deploy and clean the jump server K8s cluster. To upgrade,
first:

    make management_cluster_clean

followed by updating the ICN repository, and finally:

    make management_cluster

## All-in-one

> NOTE: Upgrade using the method describe below is destructive. Any
> information about the compute clusters will be destroyed.

The Makefile `jump_server` and `jump_server_clean` targets deploy and
clean the jump server. To upgrade, first:

    make jump_server_clean

followed by updating the ICN repository, and finally:

    make jump_server

