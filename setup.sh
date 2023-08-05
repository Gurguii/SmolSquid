#!/bin/bash

# Required files
script_path="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
config_file="$script_path/.config"
template_squid_config="$script_path/template.squid.conf"
logs_dir="$script_path/logs"

# FUNCTIONS 
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
    printf "Command '%s' failed with status code: '%i'\n" "$command" "$?" 
  fi
}

# REQUIRED FILES CHECKING
# ~ .config 
if [ ! -e "$config_file" ]; then
  printf "Cannot find configuration file: $config_file\n" && exit 1
fi
source "$config_file"

# ~ template.squid.conf
if [[ ! -e "$template_squid_config" || ! -f "$template_squid_config" ]]; then
  printf "Cannot locate squid template file @ %s\n" "$template_squid_config"
  exit 1
fi

# ~ logs(d) info.log(f) error.log(f)
if [[ ! -e "$logs_dir" || ! -d "$logs_dir" ]]; then
  exec_command "mkdir -p "$logs_dir""
  exec_command "touch "$stderr_logs""
  exec_command "touch "$stdout_logs""
fi

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
  "rb" | "rebuild")
    rebuild_project=1
    ;;
  *)
    printf "Usage: %s <b|c|f|build|create|full>\n" "$0"
    exit 1
    ;;
esac

# Build the image if user asked for it
if (( $build_project )); then
  printf "== Building image ==\n"
  # Build command
  local command=""
  # Check if buildx is available
  docker buildx &>/dev/null
  if [ $? -ne 0 ]; then
    printf "WARNING - Plugin 'buildx' not found, proceeding building the image with deprecated 'docker build'...\n"
    command="docker build -t "$image_name" ."
  else
    command="docker buildx build -t "$image_name" ."
  fi
  # The idea is to make the user able to add parameters to the build command (some)
  $command
fi

# Create the docker if user asked for it
if (( $create_docker )); then
  # Set listening port from the `.config` file in the configuration file
  sed "s/^http_port [0-9]\+$/http_port $squid_listen_port/" "$template_squid_config"
  printf "== Creating Docker ==\n"

  # Check that local mountpoints do exist
  for i in ${mountpoints[@]}; do
    if [[ ! -e "$i" || ! -d "$i" ]]; then
      exec_command "mkdir -p "$i""
      exec_command "chown -R gurgui:docker "$i""
      # THIS IS SUPER INSECURE
      exec_command "chmod -R 777 "$i""
    fi
  done
  
  docker_id="$(docker run --name "$container_name" -p $squid_listen_port:$squid_listen_port -itd \
		-v "$cache_dir":/var/cache/squid \
		-v "$log_dir":/var/log/squid \
    -v "$config_file":/etc/squid/squid.conf \
    "$image_name")"
    if [ $? -eq 0 ]; then
      customdate=$(date '+%d-%m-%Y at %H:%M')
      printf "Image name: %s\nDocker name: %s\nListen port: %s\nContainer ID: %s\nDate: %s\n====================\n" "$image_name" "$container_name" "$squid_listen_port" "$docker_id" "$customdate" | tee -a .setup.logs
    fi
fi
