# docker build -t splatform/concourse-brats .
FROM registry.opensuse.org/opensuse/leap:15.1

RUN zypper ar https://download.opensuse.org/repositories/devel:/languages:/go/openSUSE_Leap_15.1/devel:languages:go.repo
RUN zypper --gpg-auto-import-keys -n in --from=devel_languages_go go1.13
RUN zypper ar https://download.opensuse.org/repositories/Cloud:/Platform:/buildpacks:/build-requires/openSUSE_Leap_15.0/ buildpacks-build-requires
RUN zypper --gpg-auto-import-keys -n in --from=buildpacks-build-requires go-buildpack-packager
RUN zypper ar https://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Leap_15.1/Cloud:Tools.repo
RUN zypper --gpg-auto-import-keys -n in cf-cli

# Needed for integration tests
RUN zypper in -y chromedriver make git tar wget unzip hub aws-cli zip jq ruby ruby2.5-rubygem-bundler which curl docker gconf2 liberation-fonts gzip
ENV PATH $PATH:/usr/lib64/chromium

# Update bundler for php
RUN zypper ar https://download.opensuse.org/repositories/devel:/languages:/ruby:/extensions/openSUSE_Leap_15.1/devel:languages:ruby:extensions.repo
RUN zypper --gpg-auto-import-keys -n in --from=devel_languages_ruby_extensions ruby2.5-rubygem-bundler

# Store github.com ssh public key
RUN mkdir -p ~/.ssh
RUN echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> ~/.ssh/known_hosts
