This pipeline monitors the java buildpack repository for new releases. As soon as a new release is out it will rebase our fork against upstream, built the buildpack and upload it to s3.
It also tags the repo, creates a github release and triggers the final release pipeline.
