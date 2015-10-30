FROM centos:centos7
MAINTAINER The BitScout Community <community@TBA>

ENV HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    RUBY_VERSION=2.0 \
    FLUENTD_VERSION=0.12.6 \
    GEM_HOME=/opt/app-root/src

RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

# Update packages
RUN yum update -y --setopt=tsflags=nodocs

# Install run-time dependencies
RUN yum install -y --setopt=tsflags=nodocs \
    ruby && \
    mkdir -p ${HOME}

# Install tools and dependencies for building ruby extensions. Ensure that
# yum records history in this run.
RUN yum install -y --setopt=tsflags=nodocs --setopt=history_record=yes \
    gcc-c++ \
    ruby-devel \
    libcurl-devel \
    make

# Install fluend with required plugins and the base configuration file
RUN gem install \
    fluentd \
    fluent-plugin-elasticsearch \
    fluent-plugin-kubernetes_metadata_filter

COPY fluent.conf /etc/fluent/fluent.conf
RUN  mkdir /etc/fluent/config.d

# Cleanup:
# - rollback the last yum transaction to uninstall ruby extension build
#   dependencies
RUN yum -y history undo last

# - yum autoremove
RUN yum -y autoremove

# - remove yum caches
RUN yum clean all


WORKDIR ${HOME}
CMD ["fluentd"]

