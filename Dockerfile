FROM centos:centos7
MAINTAINER The BitScout Community <community@TBA>

EXPOSE 10514

ENV HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    RUBY_VERSION=2.0 \
    FLUENTD_VERSION=0.12.17 \
    GEM_HOME=/opt/app-root/src \
    SYSLOG_LISTEN_PORT=10514

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
    yum install -y --setopt=tsflags=nodocs \
        ruby \
    && \
    mkdir -p ${HOME} \
    && \
    yum install -y --setopt=tsflags=nodocs \
        python-qpid-proton \
    && \
    yum install -y --setopt=tsflags=nodocs --setopt=history_record=yes \
        gcc-c++ \
        ruby-devel \
        libcurl-devel \
        make \
    && \
    gem install \
        fluentd \
        fluent-plugin-elasticsearch \
        fluent-plugin-kubernetes_metadata_filter \
    && \
    yum -y history undo last \
    && \
    yum -y autoremove \
    && \
    yum clean all
#
# Install the base configuration file and create the directory for "dynamic"
# configuration files.
#
COPY fluent.conf /etc/fluent/fluent.conf
RUN  mkdir /etc/fluent/config.d
COPY config.d/*.conf /etc/fluent/config.d/
COPY simple_recv.py /opt/app-root/bin/

WORKDIR ${HOME}
CMD ["fluentd"]
#CMD ["fluentd", "-vv"]

