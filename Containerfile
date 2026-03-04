FROM registry.access.redhat.com/ubi10/ubi-minimal

LABEL maintainer="fatherlinux <scott.mccarty@crunchtools.com>"
LABEL description="Zabbix Agent2 7.0 on UBI 10 for host monitoring"
LABEL org.opencontainers.image.source=https://github.com/crunchtools/zabbix-agent2
LABEL org.opencontainers.image.description="Zabbix Agent2 7.0 on UBI 10 for host monitoring"
LABEL org.opencontainers.image.licenses=AGPL-3.0-or-later

# Copy Zabbix repo and default config
COPY rootfs/ /

# Install shadow-utils first (provides useradd/groupadd needed by RPM scriptlets)
RUN microdnf install -y shadow-utils && \
    microdnf install -y zabbix-agent2 && \
    microdnf clean all

EXPOSE 10050

ENTRYPOINT ["/usr/sbin/zabbix_agent2", "-f", "-c", "/etc/zabbix/zabbix_agent2.conf"]
