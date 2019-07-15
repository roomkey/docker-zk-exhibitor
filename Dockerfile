FROM debian
MAINTAINER Mike Babineau michael.babineau@gmail.com

ENV \
    ZK_RELEASE="http://www.apache.org/dist/zookeeper/zookeeper-3.5.5/apache-zookeeper-3.5.5-bin.tar.gz" \
    EXHIBITOR_POM="https://raw.githubusercontent.com/soabase/exhibitor/9cf9c84e4c48f8883bccb869e9ef7c2c1ac03ab1/exhibitor-standalone/src/main/resources/buildscripts/standalone/maven/pom.xml" \
    # Append "+" to ensure the package doesn't get purged
    BUILD_DEPS="curl maven openjdk-8-jdk+" \
    DEBIAN_FRONTEND="noninteractive"

# Use one step so we can remove intermediate dependencies and minimize size
RUN apt-get update \
    && apt-get install -y --allow-unauthenticated --no-install-recommends $BUILD_DEPS \
    && grep '^networkaddress.cache.ttl=' /etc/java-8-openjdk/security/java.security || echo 'networkaddress.cache.ttl=60' >> /etc/java-8-openjdk/security/java.security \
    && apt-get install default-jre \
    && apt-get install -y procps \

    # Install ZK
    && curl -Lo /tmp/zookeeper.tgz $ZK_RELEASE \
    && mkdir -p /opt/zookeeper/transactions /opt/zookeeper/snapshots \
    && tar -xzf /tmp/zookeeper.tgz -C /opt/zookeeper --strip=1 \
    && mv /opt/zookeeper/lib/zookeeper-*.jar /opt/zookeeper \
    && rm /tmp/zookeeper.tgz \

    # Install Exhibitor
    && mkdir -p /opt/exhibitor \
    && curl -Lo /opt/exhibitor/pom.xml $EXHIBITOR_POM \
    && mvn -f /opt/exhibitor/pom.xml package \
    && ln -s /opt/exhibitor/target/exhibitor*jar /opt/exhibitor/exhibitor.jar \

    # Remove build-time dependencies
    && apt-get purge -y --auto-remove $BUILD_DEPS \
    && rm -rf /var/lib/apt/lists/*

# Add the wrapper script to setup configs and exec exhibitor
ADD include/wrapper.sh /opt/exhibitor/wrapper.sh

# Add the optional web.xml for authentication
ADD include/web.xml /opt/exhibitor/web.xml

USER root
WORKDIR /opt/exhibitor
EXPOSE 2181 2888 3888 8181

ENTRYPOINT ["bash", "-ex", "/opt/exhibitor/wrapper.sh"]