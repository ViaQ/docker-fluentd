#!/bin/sh

set -e
set -x

ES_HOST=${ES_HOST:-viaq-elasticsearch}
ES_PORT=${ES_PORT:-9200}
SYSLOG_LISTEN_PORT=${SYSLOG_LISTEN_PORT:-4000}
DEBUG_FLUENTD=${DEBUG_FLUENTD:-false}
LOGSTASH_PREFIX=${LOGSTASH_PREFIX:-v2016.03.10.0-viaq}

if [ "$DEBUG_FLUENTD" = true ]; then
    FLUENTD_ARGS="-vv"
else
    FLUENTD_ARGS=""
fi

if [ -f "/data/fluent.conf" ]; then
    cp /data/fluent.conf /etc/fluent/fluent.conf
    if [ -d "/data/config.d" ]; then
        rm /etc/fluent/config.d/*.conf || true
        cp -R /data/config.d /etc/fluent/
    fi
    if [ -d "/data/patterns.d" ]; then
        cp -R /data/patterns.d /etc/fluent/
    fi
fi

for file in /etc/fluent/fluent.conf /etc/fluent/config.d/*.conf /etc/fluent/config.d/**/*.conf ; do
    if [ ! -f "$file" ] ; then continue ; fi
    sed -i -e "s/%ES_HOST%/$ES_HOST/g" -e "s/%ES_PORT%/$ES_PORT/g" \
        -e "s/%SYSLOG_LISTEN_PORT%/$SYSLOG_LISTEN_PORT/g" \
        -e "s/%LOGSTASH_PREFIX%/$LOGSTASH_PREFIX/g" \
        -e "s/%NORMALIZER_NAME%/$NORMALIZER_NAME/g" -e "s/%NORMALIZER_IP%/$NORMALIZER_IP/g" \
        -e "s/%NORMALIZER_HOSTNAME%/$NORMALIZER_HOSTNAME/g" \
        "$file"
done

fluentd ${FLUENTD_ARGS}

