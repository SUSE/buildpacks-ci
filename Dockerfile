# docker build -t splatform/concourse-brats .
FROM opensuse:42.3

RUN zypper --non-interactive ar --no-gpgcheck http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Leap_42.3/Cloud:Tools.repo

RUN zypper --non-interactive in go cf-cli git tar
