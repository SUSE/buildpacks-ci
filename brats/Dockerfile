# docker build -t splatform/concourse-brats .
FROM opensuse/leap:15.0

RUN zypper ar https://download.opensuse.org/repositories/devel:/languages:/go/openSUSE_Leap_15.0/ go
RUN zypper ar https://download.opensuse.org/repositories/Cloud:/Platform:/buildpacks:/build-requires/openSUSE_Leap_15.0/ buildpacks-build-requires
RUN zypper --gpg-auto-import-keys -n in go-buildpack-packager
RUN zypper --gpg-auto-import-keys -n in go1.11

# Needed for integration tests
RUN zypper in -y chromedriver
ENV PATH $PATH:/usr/lib64/chromium

# Store github.com ssh public key
RUN mkdir -p ~/.ssh
RUN echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> ~/.ssh/known_hosts

RUN zypper --non-interactive in git tar wget unzip hub aws-cli zip jq ruby ruby2.5-rubygem-bundler which curl docker gconf2 liberation-fonts

# We need the latest cf-cli version for brats
RUN zypper --non-interactive ar --no-gpgcheck http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Leap_15.0/Cloud:Tools.repo
RUN zypper --non-interactive in cf-cli
