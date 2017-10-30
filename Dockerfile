FROM centos/ruby-24-centos7:latest
MAINTAINER The ViaQ Community <community@TBA>

# default syslog listener port
EXPOSE 10514
# monitor agent port
EXPOSE 24220
# default forwarder port
EXPOSE 24224
# default debug port
EXPOSE 24230
# in_tcp port
EXPOSE 20514

ENV HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    RUBY_VERSION=2.4 \
    FLUENTD_VERSION=0.12.39 \
    GEM_HOME=/opt/app-root/src \
    SYSLOG_LISTEN_PORT=10514 \
    RUBYLIB=/opt/app-root/src/amqp_qpid/lib

ARG SCL_VERSION=rh-ruby24

# use docker ... -e RUBY_SCL_VER=rh-ruby22 to use ruby 2.2

USER 0
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
# autoremove removes hostname, so have to add it back :P
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum update -y --setopt=tsflags=nodocs \
    && \
    mkdir -p ${HOME}/amqp_qpid \
    && \
    yum install -y --setopt=tsflags=nodocs \
        rubygem-qpid_proton \
    && \
    yum install -y --setopt=tsflags=nodocs --setopt=history_record=yes \
        cmake swig iproute bc \
    && \
    scl enable ${SCL_VERSION} -- gem install -N --conservative --minimal-deps --no-ri \
        fluentd:${FLUENTD_VERSION} \
        fluent-plugin-elasticsearch \
        'fluent-plugin-systemd:<0.1.0' systemd-journal \
        fluent-plugin-rewrite-tag-filter \
        fluent-plugin-parser \
        'fluent-plugin-grok-parser:<0.14' \
        fluent-plugin-kubernetes_metadata_filter \
        fluent-plugin-secure-forward \
        fluent-plugin-add \
        fluent-plugin-viaq_data_model \
        fluent-plugin-collectd-nest \
    && \
    yum -y history undo last \
    && \
    yum -y autoremove \
    && \
    yum -y install hostname \
    && \
    yum clean all

VOLUME /data

RUN  mkdir -p /etc/fluent/configs.d ${HOME}/forwarder-example
COPY data/ ${HOME}/forwarder-example/
COPY fluent.conf /etc/fluent/
COPY configs.d/ /etc/fluent/configs.d/
COPY amqp_qpid/ ${HOME}/amqp_qpid/
#ADD out_elasticsearch_dynamic.rb /opt/app-root/src/gems/fluent-plugin-elasticsearch-1.9.2/lib/fluent/plugin/out_elasticsearch_dynamic.rb
#ADD faraday.rb /opt/app-root/src/gems/elasticsearch-transport-1.0.18/lib/elasticsearch/transport/transport/http/faraday.rb

# Uncomment to install Multiprocess Input Plugin
# see http://docs.fluentd.org/articles/in_multiprocess
# RUN  fluent-gem install fluent-plugin-multiprocess

WORKDIR ${HOME}
ADD run.sh ${HOME}/
CMD ${HOME}/run.sh
