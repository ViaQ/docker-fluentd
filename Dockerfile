FROM centos:centos7
MAINTAINER The ViaQ Community <community@TBA>

EXPOSE 10514
EXPOSE 24220

ENV HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    RUBY_VERSION=2.0 \
    FLUENTD_VERSION=0.12.26 \
    GEM_HOME=/opt/app-root/src \
    SYSLOG_LISTEN_PORT=10514 \
    RUBYLIB=/opt/app-root/src/amqp_qpid/lib

RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

# 1. Update packages
# 2. Install run-time dependencies
# 3. Install tools and dependencies for building ruby extensions. Ensure that
#    yum records history in this run.
# 4. Install fluend with required plugins
# 5. Cleanup:
#    - rollback the last yum transaction to uninstall ruby extension build
#      dependencies
#    - yum autoremove
#    - remove yum caches
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum update -y --setopt=tsflags=nodocs \
    && \
    mkdir -p ${HOME}/amqp_qpid \
    && \
    yum install -y --setopt=tsflags=nodocs \
        ruby rubygem-qpid_proton \
    && \
    yum install -y --setopt=tsflags=nodocs --setopt=history_record=yes \
        gcc-c++ ruby-devel libcurl-devel make cmake swig \
    && \
    gem install \
        fluentd:${FLUENTD_VERSION} \
        fluent-plugin-elasticsearch \
        fluent-plugin-systemd systemd-journal \
        fluent-plugin-parser \
        fluent-plugin-grok-parser \
        rspec simplecov \
    && \
    yum -y history undo last \
    && \
    yum -y autoremove \
    && \
    yum clean all

VOLUME /data

RUN  mkdir -p /etc/fluent/config.d
COPY amqp_qpid/ ${HOME}/amqp_qpid/

# Uncomment to install Multiprocess Input Plugin
# see http://docs.fluentd.org/articles/in_multiprocess
# RUN  fluent-gem install fluent-plugin-multiprocess

WORKDIR ${HOME}
ADD run.sh /usr/sbin/
CMD /usr/sbin/run.sh


