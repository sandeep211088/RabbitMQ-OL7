# V3.7.13 RMQ
# Dockerfile to build basic RabbitMQ container Based on Oracle Linux 7 - Slim
FROM cne-repos1.us.oracle.com:7744/apps/cgbu/omc/common/keep/oracle/oraclelinux:7-slim

# File Author/Maintainer: Sandeep Kumar
LABEL maintainer="sandeep.j.kumar@oracle.com"

# Create Directories to contain RabbitMQ, Erlang and its dependent RPMs
RUN     mkdir -p /ugbu-server/temp/rpm-deps && \
        mkdir -p /ugbu-server/service/dataraker/bin && \
        mkdir -p /ugbu-server/chassis && \
        mkdir -p /ugbu-server/secrets && \
        mkdir -p /ugbu-server/config/rabbitmq && \
        mkdir -p /ugbu-server/embedded_jre

# Copy the RPM file from Server to RabbitMQ Container
COPY    rpm-deps/*.rpm /ugbu-server/temp/rpm-deps/
COPY    rpm-deps/*.asc /ugbu-server/temp/rpm-deps/
COPY    bin/*.ez /usr/lib/rabbitmq/lib/rabbitmq_server-3.7.4/plugins/

# Setup RabbitMQ Server
RUN     useradd -d /var/lib/rabbitmq -u 1001 -o -g 0 ugbu_apps
RUN     rpm --import /ugbu-server/temp/rpm-deps/rabbitmq-release-signing-key.asc && \
        rpm -Uvh /ugbu-server/temp/rpm-deps/*.rpm && \
        gpg2 --import /ugbu-server/temp/rpm-deps/rabbitmq-release-signing-key.asc && \
        gpg --verify /ugbu-server/temp/rpm-deps/rabbitmq-server-3.7.13-1.el7.noarch.rpm.asc /ugbu-server/temp/rpm-deps/rabbitmq-server-3.7.13-1.el7.noarch.rpm && \
        rm -rf /ugbu-server/temp/rpm-deps

# Enable RabbitMQ Management Plugins
RUN /usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
RUN chmod a+r /usr/lib/rabbitmq/lib/rabbitmq_server-3.7.4/plugins/prometheus*.ez /usr/lib/rabbitmq/lib/rabbitmq_server-3.7.4/plugins/accept*.ez \
    && rabbitmq-plugins enable --offline prometheus accept prometheus_rabbitmq_exporter prometheus_process_collector prometheus_httpd prometheus_cowboy \
    && chmod -R 777 /etc/rabbitmq

# Copy the configuration file from Linux host to container
ADD bin/run-rabbitmq-server.sh /ugbu-server/config/rabbitmq/
ADD bin/rabbitmq.conf /etc/rabbitmq/

# Set permissions
RUN chown -R 1001:0 /etc/rabbitmq && chown -R 1001:0 /var/lib/rabbitmq  && chown -R 1001:0 /var/log/rabbitmq && \
    chmod -R ug+rw /etc/rabbitmq && chmod -R ug+rw /var/lib/rabbitmq && find /etc/rabbitmq -type d -exec chmod g+x {} + && \
    find /var/lib/rabbitmq -type d -exec chmod g+x {} +

# Create soft links
RUN ln -s /etc/rabbitmq/rabbitmq.conf /ugbu-server/config/rabbitmq/ && \
    ln -s /usr/lib/rabbitmq/bin/rabbitmq-plugins /ugbu-server/service/dataraker/bin/ && \
    ln -s /var/lib/rabbitmq/mnesia /ugbu-server/service/dataraker/

# Set  workdir
WORKDIR /var/lib/rabbitmq

#
# Expose RabbitMQ Ports
#
# 5672 rabbitmq-server - amqp port
# 15672 rabbitmq-server - for management plugin
# 4369 epmd - for clustering
# 25672 rabbitmq-server - for clustering
EXPOSE 4369 5672 15672 25672

# Set permissions for scripts directory
RUN chown -R 1001:0 /ugbu-server/config/rabbitmq && chmod -R ug+rwx /ugbu-server/config/rabbitmq && \
    find /ugbu-server/config/rabbitmq -type d -exec chmod g+x {} +

USER 1001
#
# entrypoint/cmd for container
CMD ["/ugbu-server/config/rabbitmq/run-rabbitmq-server.sh"]

# End
