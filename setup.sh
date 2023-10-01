#!/bin/bash

# Sudo privileges required
if (( $EUID != 0 )); then
  printf "[!] Sudo privileges required\n"
  exit 1
fi

# Capture execution time
start=$(date +%s)

# Required files
script_path="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
config_file="$script_path/.config"
template_squid_config="$script_path/template.squid.conf"
logs_dir="$script_path/logs"
stderr_logs="$logs_dir/error.log"
stdout_logs="$logs_dir/setup.log"

# Log files 
if [[ ! -e "$logs_dir" || ! -d "$logs_dir" ]]; then
  exec_command "mkdir -p "$logs_dir""
  exec_command "touch "$stderr_logs""
  exec_command "chmod +r "$stderr_logs""
  exec_command "touch "$stdout_logs""
  exec_command "chmod +r "$stdout_logs""
fi

# Write start of installation to logs/installation.log

# FUNCTIONS 
function printgreen()
{
  printf "\e[92m$@\e[0m"
}

function printcyan()
{
  printf "\e[36m$@\e[0m"
}

function printyellow()
{
  printf "\e[93m$@\e[0m"
}

function printmagenta()
{
  printf "\e[35m$@\e[0m"
}

function cleanup()
{
  exitcode=$1
  end=$(date +%s)
  customdate=$(date '+%d-%m-%Y at %H:%M')
  printyellow "\n[END] smollsquid setup - $customdate execution time - $(( end - start ))s\n" | tee -a "$stdout_logs"
  exit $exitcode
}

function exec_command()
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
    cleanup 0
  fi
}

function remove_containers_using_image_name()
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
        cleanup 0
      fi
    fi
  done
}

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

# check that docker is installed
if ! command -v docker &>/dev/null; then 
  printf "[!] Please install docker to continue\n"
  exit 1
fi

# ~ check that 'docker' service is running
if ! sudo systemctl status docker &>/dev/null; then
  read -rp "[?] Service 'docker' is not running, start? [Y/N] " ans
  if [[ ${ans,,} == "y" || ${ans,,} == "yes" ]]; then
    systemctl start docker
  fi
fi

printyellow "[START] smolsquid setup - $(date '+%d-%m-%Y at %H:%M')\n" | tee -a "$stdout_logs"

# ~ build the image if user asked for it
if (( $build_project )); then
  # ~ check already existing images with same
  if docker image ls -q | grep -q "$image_name" &>/dev/null; then
    printf "[?] Docker image '%s' already exists," "$image_name"
    read -rp "remove? [Y/N] " ans
    if [[ ${ans,,} == "y" || ${ans,,} == "yes" ]]; then
      # ~ check if there are containers running such image
      remove_containers_using_image_name "$image_name"
      # ~ remove the image
      docker image rm "$image_name"
    else
      cleanup 0
    fi
  fi
  printgreen "[?] Building image\n"
  # ~ build command
  command=""
  # ~ check if buildx is available
  docker buildx &>/dev/null
  if [ $? -ne 0 ]; then
    printf "[!] WARNING - Plugin 'buildx' not installed, proceeding building the image with deprecated 'docker build'...\n"
    command="docker build -t "$image_name" ."
  else
    command="docker buildx build -t "$image_name" ."
  fi
  # The idea is to make the user able to add parameters to the build command (some)
  $command
fi

# Create the docker if user asked for it
if (( $create_docker )); then
  # Check if container with the same name exists
	if docker inspect "$container_name" &>/dev/null; then
	  read -rp "[?] Docker container $container_name already exists, remove? [Y/N] " ans
	  if [[ ${ans,,} == "y" || ${ans,,} == "yes" ]]; then
		  printf "[?] Stopping container '%s'\n" "$container_name"
	  	docker stop "$container_name" &>/dev/null
		  docker rm "$container_name" &>/dev/null
	  else
		  cleanup 1
	  fi
	fi
  
  # Set cache/log directories' paths
	if [ "$base_dir" ]; then
	  cache_dir="$base_dir"/"cache"
	  log_dir="$base_dir"/"logs"
	  squid_config_file="$base_dir/squid.conf"
	fi
  
	printgreen "[?] Creating Docker\n"

	# Check that local mountpoints do exist
	for i in "$cache_dir" "$log_dir" ; do
	  exec_command "mkdir -p "$i""
	  # 31 is the uuid of the squid user/group 
	  exec_command "chown --recursive 31:root "$i""
	done
  
  # TODO: add getopts after sourcing .config file to overrid any param if use requested
  # @note add it right after sourcing, not now that there might be some variables already used

  # Mold template squid.conf file and save it to local mountpoint path
  
  # Set listening port from the `.config` file in the configuration file and save it to proper path 
	sed "s/^http_port [0-9]\+$/http_port $squid_listen_port/" "$template_squid_config" \
	| sed "s/GURGUI_DEFAULT_BLOCKED_DOMAINS/$blocked_domains/" > "$squid_config_file"

	docker_id="$(docker run --name "$container_name" -p $squid_listen_port:$squid_listen_port -itd \
		-v "$cache_dir":/var/cache/squid \
		-v "$log_dir":/var/log/squid \
	  -v "$squid_config_file":/etc/squid/squid.conf \
	  "$image_name")"
	if [ $? -eq 0 ]; then
	  customdate=$(date '+%d-%m-%Y at %H:%M')
	  printmagenta "========== Installation summary ==========\n"
    printgreen "[ General ]\n"
    printcyan "Image name: $image_name\n"
    printcyan "Docker name: $container_name\n"
    printcyan "Listen port: $squid_listen_port\n"
    printcyan "Container ID: $docker_id\n"
    printcyan "Container ID short: ${docker_id:0:13}\n"
    printgreen "[ Mountpoints ]\n"
    printcyan "cache directory: $cache_dir\n"
    printcyan "log directory: $log_dir\n"
    printcyan "squid configuration file: $squid_config_file\n"
    printgreen "[ Extra ]\n"
    printcyan "Date: $customdate\n"
    printmagenta "==========================================\n"
	fi
fi
cleanup 1
