#!/bin/bash

formatted_output_file_path="${BITRISE_STEP_FORMATTED_OUTPUT_FILE_PATH}"

function echo_string_to_formatted_output {
  echo "$1" >> $formatted_output_file_path
  # debug
  echo "$1"
}

function write_section_to_formatted_output {
  echo '' >> $formatted_output_file_path
  echo "$1" >> $formatted_output_file_path
  echo '' >> $formatted_output_file_path

  # debug
  echo ''
  echo "$1"
  echo ''
}

function do_failed_cleanup {
  write_section_to_formatted_output "# FTP upload failed!"
  write_section_to_formatted_output "Check the Logs for details."
}

if [ ! -n "${hostname}" ]; then
  echo ' [!] Input hostname is missing'
  write_section_to_formatted_output "# Error!"
  write_section_to_formatted_output "Reason: FTP hostname is missing."
  exit 1
fi

if [ ! -n "${username}" ]; then
  echo ' [!] Input username is missing'
  write_section_to_formatted_output "# Error!"
  write_section_to_formatted_output "Reason: FTP username is missing."
  exit 1
fi

if [ ! -n "${upload_source_path}" ]; then
  echo ' [!] Input upload_source_path is missing'
  write_section_to_formatted_output "# Error!"
  write_section_to_formatted_output "Reason: FTP upload source path is missing."
  exit 1
fi

if [ ! -n "${password}" ]; then
  echo ' [!] Input password is missing'
  write_section_to_formatted_output "# Error!"
  write_section_to_formatted_output "Reason: FTP user password is missing."
  exit 1
fi


# -------------
# --- Main

(
  set -e
  brew install lftp

  write_section_to_formatted_output "# Uploading:"
  echo_string_to_formatted_output "* from: \`${upload_source_path}\`"
  echo_string_to_formatted_output "* to: \`${upload_target_path}\`"

  echo " (i) Uploading: ${upload_source_path} -> ${upload_target_path}"

  let targets_last_index=${#upload_target_path}-1
  if [[ -d "${upload_source_path}" ]] ; then
    # source: dir | target: dir
    if [ "${upload_target_path:$targets_last_index:1}" = "/" ]; then
      lftp -u "${username},${password}" "${hostname}" -e "mirror -R ${upload_source_path} ${upload_target_path%?}; bye"
    else
      lftp -u "${username},${password}" "${hostname}" -e "mirror -R ${upload_source_path} ${upload_target_path}; bye"
    fi
  elif [[ -f "${upload_source_path}" ]] ; then
    if [ "${upload_target_path:$targets_last_index:1}" = "/" ]; then
      # source: file | target: dir
      if [ "$upload_source_path" = "" ] ; then
        # target: rootdir
        lftp -u "${username},${password}" "${hostname}" -e "put -O '/' ${upload_source_path}; bye"
      else
        set +e
        lftp -u "${username},${password}" "${hostname}" -e "mkdir -p ${upload_target_path}; bye"
        set -e
        lftp -u "${username},${password}" "${hostname}" -e "put -O ${upload_target_path} ${upload_source_path}; bye"
      fi
    else
      # source: file | target: file
      target_directory="$(dirname ${upload_target_path})"
      target_filename="$(basename ${upload_target_path})"
      if [ "$target_directory" = "" ] ; then
        # target-dir: rootdir
        lftp -u "${username},${password}" "${hostname}" -e "put -O '/' ${upload_source_path} -o ${target_filename}; bye"
      else
        set +e
        lftp -u "${username},${password}" "${hostname}" -e "mkdir -p ${target_directory}; bye"
        set -e
        lftp -u "${username},${password}" "${hostname}" -e "put -O ${target_directory} ${upload_source_path} -o ${target_filename}; bye"
      fi
    fi
  else
    echo "source is invalid"
    exit 1
  fi
)
if [ $? -ne 0 ] ; then
  do_failed_cleanup
  echo " [!] Failed!"
  exit 1
fi

write_section_to_formatted_output "# FTP upload successful!"
