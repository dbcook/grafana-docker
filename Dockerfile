FROM debian:jessie

ARG GRAFANA_VERSION
ENV GRAFANA_VERSION ${GRAFANA_VERSION}

# URL where a grafana .deb of GRAFANA_VERSION can be retrieved via curl
#   Original curl URL pointing to grafana AWS S3 bucket
#ENV DEB_URL ${DEB_URL:-https://grafanarel.s3.amazonaws.com/builds/grafana_${GRAFANA_VERSION}_amd64.deb}
ARG DEB_URL
ENV DEB_URL ${DEB_URL:-https://artifactory.viasat.com/artifactory/databus-deb/grafana/grafana_${GRAFANA_VERSION}_amd64.deb}

# username/password if needed for curl command (e.g. for Artifactory)
ARG CURL_USERNAME
ARG CURL_PASSWORD
ARG CURL_OPTS
ENV CURL_OPTS ${CURL_OPTS:--u ${CURL_USERNAME}:${CURL_PASSWORD}}

RUN apt-get update && \
    apt-get -y --no-install-recommends install libfontconfig curl ca-certificates && \
    apt-get clean && \
    curl ${CURL_OPTS} ${DEB_URL} > /tmp/grafana.deb && \
    dpkg -i /tmp/grafana.deb && \
    rm /tmp/grafana.deb && \
    curl -L https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64 > /usr/sbin/gosu && \
    chmod +x /usr/sbin/gosu && \
    apt-get remove -y curl && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

VOLUME ["/var/lib/grafana", "/var/lib/grafana/plugins", "/var/log/grafana", "/etc/grafana"]

EXPOSE 3000

COPY ./run.sh /run.sh

ENTRYPOINT ["/run.sh"]
