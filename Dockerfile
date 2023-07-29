# Gurgui

# Use latest available alpine docker version
FROM alpine:latest

ARG LPORT=3128

# Update the system repositories and add squid (proxy)
RUN apk upgrade && apk upgrade && \
    apk add squid 

# Copy custom entry point script 
COPY entrypoint.sh /usr/sbin/entrypoint

# Make the entrypoint script executable
RUN chmod +x /usr/sbin/entrypoint

# Copy our default squid configuration file within the server
COPY squid.conf /etc/squid/squid.conf

# Port 3128 is the one expected to be exposed (default Squid port)
EXPOSE $LPORT

# Hints for docker of volumes that will be created
VOLUME ["/var/docker/alpinesquid/cache","/var/docker/alpinesquid/logs"]

# Entrypoint
ENTRYPOINT ["entrypoint"]

# These are arguments for the entrypoint script
CMD [""]
