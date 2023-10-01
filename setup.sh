#!/bin/bash

# Sudo privileges required
if (( $EUID != 0 )); then
  printf "[!] Sudo privileges required\n"
  exit 1
fi

# Required files
script_path="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
config_file="$script_path/.config"
template_squid_config="$script_path/template.squid.conf"
logs_dir="$script_path/logs"
stderr_logs="$logs_dir/error.log"
stdout_logs="$logs_dir/setup.log"
installation_logs="$logs_dir/installation.log"

# FUNCTIONS 
exec_command()
{
  command="$1"
  # Execute the command and save output to log files
  $1 1>>"$stdout_logs" 2>>"$stderr_logs" 

  # Check the status code
  if [ $? -eq 0 ]; then
    # Success
    printf "[SUCCESS] %s\n" "$command"
  else
    # Failure
    printf "[FAIL] %s - status code: '%i'\n" "$command" "$?" 
    exit 0
  fi
}

remove_containers_using_image()
{
  container_ids=$(docker ps -aq)
  for $id in $container_ids; do
    if docker inspect "$id" | grep "$image_name" &>/dev/null ; then
      printf "[?] Docker with id '%s' is using image '%s'" "$id" "$image_name"
      read -rp "remove container? [Y/N] " ans
      if [[ ${ans,,} == "y" || ${ans,,} == "yes" ]]; then
        docker rm "$id"
      else
        printf "[!] All containers must be deleted in order to build a new image\n"
        exit 0
      fi
    fi
  done
}

# ~ .config 
if [[ ! -e "$config_file" || ! -f "$config_file" ]]; then
  printf "[!] Cannot find configuration file: $config_file\n" && exit 1
fi
# ~ import config file
source "$config_file"

# ~ template.squid.conf
if [[ ! -e "$template_squid_config" || ! -f "$template_squid_config" ]]; then
  printf "[!] Cannot locate squid template file @ %s\n" "$template_squid_config"
  exit 1
fi

# ~ create log files
if [[ ! -e "$logs_dir" || ! -d "$logs_dir" ]]; then
  exec_command "mkdir -p "$logs_dir""
  exec_command "touch "$stderr_logs""
  exec_command "touch "$stdout_logs""
fi

# ~ track user desires
build_project=0
create_docker=0

# ~ check <action> param // ./setup.sh <action>
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

# ~ check that 'docker' service is running
if ! sudo systemctl status docker &>/dev/null; then
  read -rp "[?] Service 'docker' is not running, start? [Y/N] " ans
  if [[ ${ans,,} == "y" || ${ans,,} == "yes" ]]; then
    systemctl start docker
  fi
fi

# ~ build the image if user asked for it
if (( $build_project )); then
  if docker image ls -q | grep -q "$image_name" &>/dev/null; then
    printf "[?] Docker image '%s' already exists," "$image_name"
    read -rp "remove? [Y/N] " ans
    if [[ ${ans,,} == "y" || ${ans,,} == "yes" ]]; then
      # ~ check if there are containers running such image
      remove_containers_using_image "$image_name"
      # ~ remove the image
      docker image rm "$image_name"
    else
      exit 0
    fi
  fi
  printf "== Building image ==\n"
  # ~ build command
  command=""
  # ~ check if buildx is available
  docker buildx &>/dev/null
  if [ $? -ne 0 ]; then
    printf "[!] WARNING - Plugin 'buildx' not found, proceeding building the image with deprecated 'docker build'...\n"
    command="docker build -t "$image_name" ."
  else
    command="docker buildx build -t "$image_name" ."
  fi
  # The idea is to make the user able to add parameters to the build command (some)
  $command 1>>$stdout_logs 2>>$stderr_logs
fi

# Create the docker if user asked for it
if (( $create_docker )); then
  # Check if container with the same name exists
	if docker inspect "$container_name" &>/dev/null; then
	  read -rp "[?] Docker container $container_name already exists, remove? [Y/N] " ans
	  if [[ ${ans,,} == "y" || ${ans,,} == "yes" ]]; then
		  printf "== Stopping docker container %s ==" "$container_name"
	  	docker ps -f name="$container_name" &>/dev/null && docker stop "$container_name" &>/dev/null
		  docker rm "$container_name" 
	  else
		  exit 1
	  fi
	fi
  
  # Set cache/log directories' paths
	if [ "$base_dir" ]; then
	  cache_dir="$base_dir"/"cache"
	  log_dir="$base_dir"/"logs"
	fi
  
	printf "== Creating Docker ==\n"

	# Check that local mountpoints do exist
	for i in "$cache_dir" "$log_dir" ; do
	  exec_command "mkdir -p "$i""
	  # 31 is the uuid of the squid user/group 
	  exec_command "chown --recursive 31:31 "$i""
	done
	
  # Set listening port from the `.config` file in the configuration file and save it to proper path 
	sed "s/^http_port [0-9]\+$/http_port $squid_listen_port/" "$template_squid_config" > "$squid_config_file"

	docker_id="$(docker run --name "$container_name" -p $squid_listen_port:$squid_listen_port -itd \
		-v "$cache_dir":/var/cache/squid \
		-v "$log_dir":/var/log/squid \
	  -v "$squid_config_file":/etc/squid/squid.conf \
	  "$image_name")"
	if [ $? -eq 0 ]; then
	  customdate=$(date '+%d-%m-%Y at %H:%M')
	  cat << EOF | tee -a "$installation_logs"
====================
[ General ]
Image name: "$image_name"
Docker name: "$container_name"
Listen port: "$squid_listen_port"
Container ID: "$docker_id"
Container ID short: "${docker_id:0:13}"
[ Mountpoints ]
cache directory: "$cache_dir"
log directory: "$log_dir"
squid configuration file: "$squid_config_file"
[ Extra ]
Date: "$customdate"
====================
EOF
	fi
fi
