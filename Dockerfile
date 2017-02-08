FROM debian:jessie

# insert Grafana version into environment for use by derived containers
ARG GRAFANA_VERSION
ENV GRAFANA_VERSION ${GRAFANA_VERSION}

# URL where a grafana .deb of GRAFANA_VERSION can be retrieved via curl
ARG DEB_URL
ENV DEB_URL ${DEB_URL}

# Additional curl options such as -u credentials if needed
ARG CURL_OPTS
ENV CURL_OPTS ${CURL_OPTS}

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
