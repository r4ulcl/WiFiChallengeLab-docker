FROM chainguard/git:latest as repo
RUN git clone --depth 1 --branch 1.2.2 https://github.com/nzymedefense/nzyme.git


FROM maven:3.8.3-adoptopenjdk-11 as build
COPY --from=repo /home/git/nzyme /nzyme
WORKDIR /nzyme
RUN mvn jdeb:jdeb


FROM ubuntu:20.04
COPY --from=build /nzyme/target/nzyme_1.2.2_all.deb nzyme.deb
RUN apt-get update && apt-get install -y --no-install-recommends python3 libpcap0.8 openjdk-11-jre-headless wireless-tools gettext-base curl git \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && dpkg -i nzyme.deb && rm nzyme.deb

# Entrypoint: Replace variables in config 
COPY docker-entrypoint.sh /bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD /bin/bash /usr/share/nzyme/bin/nzyme