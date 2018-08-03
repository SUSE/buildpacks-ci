This pipeline monitors the upstream buildpack repositories for new releases. As soon as a new release is out,
it will look for dependencies that are not built on OBS and create packages for them using [this tool](https://github.com/suse/cf-obs-binary-builder). If a template doesn't exist in the tool, the pipeline will fail sending a notification email.
The pipeline also builds the buildpack package for the new version on OBS. As soon as it's built, it uploads the artifact to S3 and updates the relevant *buildpack-release repository.
