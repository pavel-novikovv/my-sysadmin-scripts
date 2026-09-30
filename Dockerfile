FROM ubuntu:22.04
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*
COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh
WORKDIR /data
ENV MAX_ITERATIONS=1
CMD ["/usr/local/bin/script.sh"]
