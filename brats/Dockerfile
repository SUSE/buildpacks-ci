# docker build -t splatform/concourse-brats .
FROM opensuse/leap:15.0

RUN zypper --non-interactive ar --no-gpgcheck http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Leap_15.0/Cloud:Tools.repo

RUN zypper --non-interactive in go cf-cli git tar
RUN zypper --non-interactive in wget unzip
