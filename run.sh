#!/bin/sh

set -e
set -x

ES_HOST=${ES_HOST:-viaq-elasticsearch}
ES_PORT=${ES_PORT:-9200}
SYSLOG_LISTEN_PORT=${SYSLOG_LISTEN_PORT:-10514}
DEBUG_FLUENTD=${DEBUG_FLUENTD:-true}

if [ "$DEBUG_FLUENTD" = true ]; then
    FLUENTD_ARGS="-vv"
else
    FLUENTD_ARGS=""
fi

if [ -f "/data/fluent.conf" ]; then
    cp /data/fluent.conf /etc/fluent/fluent.conf
    if [ -d "/data/config.d" ]; then
        rm /etc/fluent/config.d/*.conf || true
        for config in /data/config.d/*.conf; do
            cp "$config" /etc/fluent/config.d/
        done
    fi
fi

#for file in /etc/rsyslog.conf /etc/rsyslog.d/*.conf ; do
#    if [ ! -f "$file" ] ; then continue ; fi
#    sed -i -e "s/%ES_HOST%/$ES_HOST/g" -e "s/%ES_PORT%/$ES_PORT/g" \
#        -e "s/%SYSLOG_LISTEN_PORT%/$SYSLOG_LISTEN_PORT/g" \
#        "$file"
#done

fluentd ${FLUENTD_ARGS}

