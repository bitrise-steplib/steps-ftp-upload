#!/bin/bash

set -e

#=======================================
# Functions
#=======================================

RESTORE='\033[0m'
RED='\033[00;31m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
GREEN='\033[00;32m'

function color_echo {
	color=$1
	msg=$2
	echo -e "${color}${msg}${RESTORE}"
}

function echo_fail {
	msg=$1
	echo
	color_echo "${RED}" "${msg}"
	exit 1
}

function echo_warn {
	msg=$1
	color_echo "${YELLOW}" "${msg}"
}

function echo_info {
	msg=$1
	echo
	color_echo "${BLUE}" "${msg}"
}

function echo_details {
	msg=$1
	echo "  ${msg}"
}

function echo_done {
	msg=$1
	color_echo "${GREEN}" "  ${msg}"
}

function validate_required_input {
	key=$1
	value=$2
	if [ -z "${value}" ] ; then
		echo_fail "[!] Missing required input: ${key}"
	fi
}

#=======================================
# Main
#=======================================

# Validate parameters
echo_info "Configs:"
echo_details "* hostname: $hostname"
echo_details "* username: $username"
echo_details "* password: $password"
echo_details "* upload_source_path: $upload_source_path"
echo_details "* upload_target_path: $upload_target_path"

validate_required_input "hostname" $hostname
validate_required_input "username" $username
validate_required_input "password" $password
validate_required_input "upload_source_path" $upload_source_path
validate_required_input "upload_target_path" $upload_target_path

os=$(uname -s)

if [[ "$os" == "Darwin" ]] ; then
  echo_info "Installing lftp on Darwin"
  echo_details "$ brew install lftp"

  brew install lftp
elif [[ "$os" == "Linux" ]] ; then
  echo_info "Installing lftp on Linux"
  echo_details "$ sudo apt-get install lftp"

  sudo apt-get install lftp
else
  echo_fail "unkown os: $os, supported: [Darwin, Linux]"
fi

echo_info "Uploading ${upload_source_path} -> ${upload_target_path}"

(
  let targets_last_index=${#upload_target_path}-1
  if [[ -d "${upload_source_path}" ]] ; then
    # source: dir | target: dir
    if [ "${upload_target_path:$targets_last_index:1}" = "/" ]; then
      lftp -u "${username},${password}" "${hostname}" -e "set ftp:ssl-allow no; mirror -R ${upload_source_path} ${upload_target_path%?}; bye"
    else
      lftp -u "${username},${password}" "${hostname}" -e "set ftp:ssl-allow no; mirror -R ${upload_source_path} ${upload_target_path}; bye"
    fi
  elif [[ -f "${upload_source_path}" ]] ; then
    if [ "${upload_target_path:$targets_last_index:1}" = "/" ]; then
      # source: file | target: dir
      if [ "$upload_source_path" = "" ] ; then
        # target: rootdir
        lftp -u "${username},${password}" "${hostname}" -e "set ftp:ssl-allow no; put -O '/' ${upload_source_path}; bye"
      else
        set +e
        lftp -u "${username},${password}" "${hostname}" -e "set ftp:ssl-allow no; mkdir -p ${upload_target_path}; bye"
        set -e
        lftp -u "${username},${password}" "${hostname}" -e "set ftp:ssl-allow no; put -O ${upload_target_path} ${upload_source_path}; bye"
      fi
    else
      # source: file | target: file
      target_directory="$(dirname ${upload_target_path})"
      target_filename="$(basename ${upload_target_path})"
      if [ "$target_directory" = "" ] ; then
        # target-dir: rootdir
        lftp -u "${username},${password}" "${hostname}" -e "set ftp:ssl-allow no; put -O '/' ${upload_source_path} -o ${target_filename}; bye"
      else
        set +e
        lftp -u "${username},${password}" "${hostname}" -e "set ftp:ssl-allow no; mkdir -p ${target_directory}; bye"
        set -e
        lftp -u "${username},${password}" "${hostname}" -e "set ftp:ssl-allow no; put -O ${target_directory} ${upload_source_path} -o ${target_filename}; bye"
      fi
    fi
  else
    echo "source is invalid"
    exit 1
  fi
)
if [ $? -ne 0 ] ; then
  echo_fail "Upload failed"
fi

echo_done "Upload succed"
