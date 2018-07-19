# docker build -t splatform/concourse-brats .
FROM opensuse

RUN zypper --non-interactive ar http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Leap_42.3/Cloud:Tools.repo

RUN zypper --non-interactive in go cf-cli
