# Airán 'Gurgui' Gómez de Salazar Eugenio

# Use latest available alpine docker version
FROM alpine:latest

# Update the system repositories and add squid (proxy)
RUN apk upgrade && apk upgrade && \
    apk add squid

# Copy custom entry point script 
COPY entrypoint.sh /usr/sbin/entrypoint

# Make the entrypoint script executable
RUN chmod +x /usr/sbin/entrypoint

# Make user 'squid' the owner of necessary files

RUN chown --recursive squid:root  /usr/sbin/entrypoint /var/run/

# Drop privileges
USER squid

# Entrypoint
ENTRYPOINT ["entrypoint"]

# These are arguments for the entrypoint script
CMD [""]
