# SUSE buildpack ci

This repository hosts the definitions for the pipelines that:

- [brats dir] test the buildpacks shipped with [SCF](https://github.com/suse/scf).
- [buildpacks dir] create the dependency and buildpack packages on OBS for the buildpacks built on OBS (e.g. Ruby)

There is also a fork or the upstream pipelines that, among other files, hosts the pipelines that build the non-OBS buildpacks here: https://github.com/suse/cf-buildpacks-ci.
As soon as we build all buildpacks on OBS, this pipeline will not be needed.
