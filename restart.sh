for container_id in $(docker ps  --filter="name=fluentd-normalizer" -q -a);
do
  docker stop $container_id &&
  docker rm $container_id;
  echo "Stopped & Removed the container!"
done

if [ "$DEBUG" = true ]; then
  ENV_DEBUG="-e DEBUG_FLUENTD=true"
  LOG=""
else
  ENV_DEBUG="-e DEBUG_FLUENTD=false"
  LOG=""
fi

echo "docker run -p 4000:4000/tcp -p 4000:4000/udp -v /home/centos/src/docker-rsyslog/data/:/data -e ES_HOST=elasticsearch.perf.lab.eng.bos.redhat.com -e ES_PORT=80 ${ENV_DEBUG} --name fluentd-normalizer t0ffel/rsyslog ${LOG}"
docker run -p 4000:4000/tcp -p 4000:4000/udp -v /home/centos/src/docker-fluentd/data/:/data -e ES_HOST=elasticsearch.perf.lab.eng.bos.redhat.com -e ES_PORT=80 ${ENV_DEBUG} --name fluentd-normalizer t0ffel/fluentd ${LOG}
