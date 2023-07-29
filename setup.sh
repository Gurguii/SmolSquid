#!/bin/bash

# Import .vars file if existing
if [ -e ".vars" ]; then
  source ".vars"
else
  printf "Cannot find vars file: $(pwd)/.vars\n" && exit 1
fi

# Gurgui - setup alpine squid proxy docker
build_project=0
create_docker=0

case "${1,,}" in
  "b" | "build")
    build_project=1
    ;;
  "c" | "create")
    create_docker=1
    ;;
  "f" | "full")
    build_project=1
    create_docker=1
    ;;
  *)
    printf "Usage: %s <b|c|f|build|create|full>\n" "$0"
    exit 1
    ;;
esac

# Build the image 
if (( $build_project )); then
  # Set variables in squid.conf
  sed -i "s/^http_port [0-9]\+$/http_port $squid_listen_port/" squid.conf
	docker buildx build --build-arg LPORT=$squid_listen_port -t "$image_name" .
fi

# Create the docker
if (( $create_docker )); then
	docker run --name "$container_name" -p $squid_listen_port:$squid_listen_port -itd \
		-v "$cache_dir":/var/cache/squid \
		-v "$log_dir":/var/log/squid \
		"$image_name"
fi
