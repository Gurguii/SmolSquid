#!/bin/bash

exec_command()
{
  command="$1"
  # Execute the command
  $1 &>/dev/null
  # Check the status code
  if [ $? -eq 0 ]; then
    # Success
    printf "%s [SUCCESS]\n" "$command"
  else
    # Failure
    printf "Command '%s' exited with status code: %i\n" "$command" "$?" 
    exit 1
  fi
}

# Import vars file if existing
varspath="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/.setup.vars"

if [ -e "$varspath" ]; then
  source "$varspath"
else
  printf "Cannot find vars file: $varspath\n" && exit 1
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

# Check that local mountpoints do exist
for i in ${mountpoints[@]}; do
  if [[ ! -e "$i" || ! -d "$i" ]]; then
    exec_command "mkdir -p "$i""
  fi
done

# Check that squid.conf file exists
if [[ ! -e "$config_file" || ! -f "$config_file" ]]; then
  printf "Cannot locate config file @ %s\n" "$config_file"
  exit 1
fi

# Build the image if user asked for it
if (( $build_project )); then
  printf "== Building image ==\n"
	docker buildx build -t "$image_name" .
fi

# Create the docker if user asked for it
if (( $create_docker )); then
  # Set listening port from the `.setup.vars` file in the configuration file
  sed -i "s/^http_port [0-9]\+$/http_port $squid_listen_port/" "$config_file"
  printf "== Creating Docker ==\n"
  docker_id="$(docker run --name "$container_name" -p $squid_listen_port:$squid_listen_port -itd \
		-v "$cache_dir":/var/cache/squid \
		-v "$log_dir":/var/log/squid \
    -v "$config_file":/etc/squid/squid.conf \
    "$image_name")"
    if [ $? -eq 0 ]; then
      printf "Image name: %s\nDocker name: %s\nListen port: %s\nContainer ID: %s\nDate: %s\n====================\n" "$image_name" "$container_name" "$squid_listen_port" "$docker_id" $(date '+%d-%m-%Y') | tee -a .setup.logs
    fi
fi
