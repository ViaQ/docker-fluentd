# docker-fluentd [![Build Status](https://travis-ci.org/ViaQ/docker-fluentd.svg?branch=master)](https://travis-ci.org/ViaQ/docker-fluentd)
ViaQ Fluentd docker container - can be used as either a local collector, or as an aggregator/formatter/normalizer, for feeding data into Elasticsearch.

## Environmental variables:
Elasticsearch output
* `ENABLE_ES` - use Elasticsearch for output.  Defaults to `true`
* `LOGSTASH_PREFIX` - Elasticsearch index name prefix.  Defaults to `viaq`
* `ES_HOST` must be FQDN of ElasticSearch server.  Defaults to `viaq-elasticsearch`.
* `ES_PORT` must be the port on which the ElasticSearch server is listening.  Defaults to `9200`.

Syslog input
* `ENABLE_SYSLOG` - use syslog (RFC5424) listener for tcp/udp input.  Defaults to `true`.
* `SYSLOG_LISTEN_PORT` the port this rsyslog instance is listening for. both TCP and UDP.  Defaults to `10514`.
* `SYSLOG_LISTEN_BIND_ADDR` - ip address to bind to.  Defaults to `0.0.0.0`
* `FLUENTD_SYSLOG_LOG_LEVEL` - default is `FLUENTD_LOG_LEVEL` or `warn`

Forwarder input
* `ENABLE_FORWARD` - use fluentd forwarder listener (e.g. for fluent-cat) for tcp/udp input.  Defaults to `true`.
* `FLUENTD_FORWARD_INPUT_PORT` - default is `24224`
* `FLUENTD_FORWARD_INPUT_BIND_ADDR` - default is `0.0.0.0`
* `FLUENTD_FORWARD_INPUT_LOG_LEVEL` - default is `FLUENTD_LOG_LEVEL` or `warn`

Journal input
* `ENABLE_JOURNAL` - read from systemd journal - default `false`
* `JOURNAL_DIR` - default is `/run/log`
* `FLUENTD_JOURNAL_LOG_LEVEL` - default is `FLUENTD_LOG_LEVEL` or `warn`

Tail/file input
* `ENABLE_TAIL` - default is `false`
* `FLUENTD_TAIL_LOG_DIR` - default `/var/log` - reads the file(s) `messages*` in that dir
* `FLUENTD_TAIL_LOG_LEVEL` - default is `FLUENTD_LOG_LEVEL` or `warn`

AMQP input
* `ENABLE_AMQP_INPUT` - read from AMQP queue - default `true`
* `FLUENTD_AMQP_INPUT_URL` - default is `amqp://viaq-qpid-router:5672/viaq`
* `FLUENTD_AMQP_INPUT_LOG_LEVEL` - default is `FLUENTD_LOG_LEVEL` or `warn`

Stdout output (for debugging)
* `ENABLE_STDOUT` - default `false`

If you want to use fluentd with or as a normalizer, you must define the following:

* `NORMALIZER_NAME` - The string name of the normalize reported in the ES record as `"pipeline_metadata":{"normalizer":{"name": "NORMALIZER_NAME"}}`.  This is a descriptive string used for searching and filtering.
* `NORMALIZER_IP` - not currently used
* `NORMALIZER_HOSTNAME` - hostname of the normalizer node/machine.  This is reported in the ES record as `"pipeline_metadata":{"normalizer":{"hostname": "NORMALIZER_HOSTNAME"}}`.

## External Fluentd config
In order to add own Fluentd configuration file please add the configuration files to a local directory and map in to `/data` docker volume.
The following files are taken form the local directory:
`fluent.conf, config.d/*, patterns.d/*`
In case `fluent.conf` exists, the default `config.d/*.conf` is removed and not used in the container.


## Running:

Using plain docker, default arguments::

    # docker run -d -p 10514:10514/udp -p 24224:24224/udp \
      -e FLUENTD_LOG_LEVEL=info --name viaq-fluentd viaq/fluentd

Using specified syslog listen host, fluentd config dir, normalizer configuration::

    # docker run -d -p $syslog_listen_port:$syslog_listen_port/tcp \
      -p $syslog_listen_port:$syslog_listen_port/udp -v $local_dir:/data \
      -u $uid -e ES_HOST=$elasticsearchhost -e ES_PORT=$port \
      -e SYSLOG_LISTEN_PORT=$syslog_listen_port \
      -e NORMALIZER_NAME=container-rsyslog8.17 -e NORMALIZER_IP=$normalizer_ip \
      -e LOGSTASH_PREFIX=v2016.03.10.0-viaq --name viaq-fluentd viaq/docker-fluentd
