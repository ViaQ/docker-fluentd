#!/bin/sh

set -euxo pipefail

# Elasticsearch plugin params
export ENABLE_ES=${ENABLE_ES:-true}
export ES_HOST=${ES_HOST:-viaq-elasticsearch}
export ES_PORT=${ES_PORT:-9200}
export LOGSTASH_PREFIX=${LOGSTASH_PREFIX:-viaq}
# other params available for ES output plugin
# ES_CA - CA cert file
# ES_CLIENT_CERT - client cert file
# ES_CLIENT_KEY - cilent key file
export ENABLE_SYSLOG=${ENABLE_SYSLOG:-true}
export SYSLOG_LISTEN_PORT=${SYSLOG_LISTEN_PORT:-10514}
# other params available for syslog input plugin
# SYSLOG_LISTEN_BIND_ADDR - ip address to bind to - default 0.0.0.0
# FLUENTD_SYSLOG_LOG_LEVEL - default is FLUENTD_LOG_LEVEL or warn
export ENABLE_FORWARD=${ENABLE_FORWARD:-true}
# other params available for forward input plugin
# FLUENTD_FORWARD_INPUT_PORT - default is 24224
# FLUENTD_FORWARD_INPUT_BIND_ADDR - default is 0.0.0.0
# FLUENTD_FORWARD_INPUT_LOG_LEVEL - default is FLUENTD_LOG_LEVEL or warn
export ENABLE_JOURNAL=${ENABLE_JOURNAL:-false}
# other params available for journal plugin
# JOURNAL_DIR - default is /run/log
# FLUENTD_JOURNAL_LOG_LEVEL - default is FLUENTD_LOG_LEVEL or warn
export ENABLE_TAIL=${ENABLE_TAIL:-false}
# other params available for tail input plugin
# FLUENTD_TAIL_LOG_DIR - default /var/log - reads messages*
# FLUENTD_TAIL_LOG_LEVEL - default is FLUENTD_LOG_LEVEL or warn
export ENABLE_AMQP_INPUT=${ENABLE_AMQP_INPUT:-true}
# other params available for amqp input plugin
# FLUENTD_AMQP_INPUT_URL - default is amqp://viaq-qpid-router:5672/viaq
# FLUENTD_AMQP_INPUT_LOG_LEVEL - default is FLUENTD_LOG_LEVEL or warn
export ENABLE_STDOUT=${ENABLE_STDOUT:-false}
export ENABLE_MONITOR=${ENABLE_MONITOR:-true}
# other params available for monitor
# MONITOR_PORT - default 24220
# MONITOR_BIND_ADDR - default is 0.0.0.0
export ENABLE_DEBUG=${ENABLE_DEBUG:-false}
# other params available for debug
# DEBUG_PORT - default 24230
# DEBUG_BIND_ADDR - default is 127.0.0.1

export FLUENTD_LOG_LEVEL=${FLUENTD_LOG_LEVEL:-warn}
export DEBUG_FLUENTD=${DEBUG_FLUENTD:-false}
export NORMALIZER_NAME=${NORMALIZER_NAME:-}
export NORMALIZER_IP=${NORMALIZER_IP:-}
export NORMALIZER_HOSTNAME=${NORMALIZER_HOSTNAME:-}


if [ "$DEBUG_FLUENTD" = true ]; then
    FLUENTD_ARGS="-vv"
    FLUENTD_LOG_LEVEL=trace
else
    FLUENTD_ARGS=""
fi

if [ -f /data/fluent.conf ]; then
    cp /data/fluent.conf /etc/fluent/fluent.conf
    if [ -d /data/config.d ]; then
        rm -rf /etc/fluent/config.d
        cp -R /data/config.d /etc/fluent/
    fi
    if [ -d /data/patterns.d ]; then
        cp -R /data/patterns.d /etc/fluent/
    fi
else
    set -- $ENABLE_SYSLOG /etc/fluent/configs.d/input/syslog.conf \
        $ENABLE_FORWARD /etc/fluent/configs.d/input/forward.conf \
        $ENABLE_JOURNAL /etc/fluent/configs.d/input/journal.conf \
        $ENABLE_TAIL /etc/fluent/configs.d/input/var-log-messages.conf \
        $ENABLE_AMQP_INPUT /etc/fluent/configs.d/input/amqp.conf \
        $ENABLE_ES /etc/fluent/configs.d/output/elasticsearch.conf \
        $ENABLE_STDOUT /etc/fluent/configs.d/output/stdout.conf \
        $ENABLE_MONITOR /etc/fluent/configs.d/input/monitor.conf \
        $ENABLE_DEBUG /etc/fluent/configs.d/input/debug.conf
    while [ -n "${1:-}" ] ; do
        t_or_f=$1 ; shift ; fn=$1
        if ! $t_or_f && test -f $fn ; then
            cp /dev/null $fn # disable this feature
        fi
        shift
    done
fi

find /etc/fluent -name \*.conf -exec sed -i \
     -e "s/%ES_HOST%/$ES_HOST/g" -e "s/%ES_PORT%/$ES_PORT/g" \
     -e "s/%SYSLOG_LISTEN_PORT%/$SYSLOG_LISTEN_PORT/g" \
     -e "s/%LOGSTASH_PREFIX%/$LOGSTASH_PREFIX/g" \
     -e "s/%NORMALIZER_NAME%/$NORMALIZER_NAME/g" \
     -e "s/%NORMALIZER_IP%/$NORMALIZER_IP/g" \
     -e "s/%NORMALIZER_HOSTNAME%/$NORMALIZER_HOSTNAME/g" \
     {} \;

fluentd ${FLUENTD_ARGS}
