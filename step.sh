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

if [ ! -n "${FTP_HOSTNAME}" ]; then
  echo ' [!] Input FTP_HOSTNAME is missing'
  write_section_to_formatted_output "# Error!"
  write_section_to_formatted_output "Reason: FTP hostname is missing."
  exit 1
fi

if [ ! -n "${FTP_USERNAME}" ]; then
  echo ' [!] Input FTP_USERNAME is missing'
  write_section_to_formatted_output "# Error!"
  write_section_to_formatted_output "Reason: FTP username is missing."
  exit 1
fi

if [ ! -n "${FTP_UPLOAD_SOURCE_PATH}" ]; then
  echo ' [!] Input FTP_UPLOAD_SOURCE_PATH is missing'
  write_section_to_formatted_output "# Error!"
  write_section_to_formatted_output "Reason: FTP upload source path is missing."
  exit 1
fi

if [ ! -n "${FTP_PASSWORD}" ]; then
  echo ' [!] Input FTP_PASSWORD is missing'
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
  echo_string_to_formatted_output "* from: \`${FTP_UPLOAD_SOURCE_PATH}\`"
  echo_string_to_formatted_output "* to: \`${FTP_UPLOAD_TARGET_PATH}\`"

  echo " (i) Uploading: ${FTP_UPLOAD_SOURCE_PATH} -> ${FTP_UPLOAD_TARGET_PATH}"

  let targets_last_index=${#FTP_UPLOAD_TARGET_PATH}-1
  if [[ -d "${FTP_UPLOAD_SOURCE_PATH}" ]] ; then
    # source: dir | target: dir
    if [ "${FTP_UPLOAD_TARGET_PATH:$targets_last_index:1}" = "/" ]; then
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mirror -R ${FTP_UPLOAD_SOURCE_PATH} ${FTP_UPLOAD_TARGET_PATH%?}; bye"
    else
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mirror -R ${FTP_UPLOAD_SOURCE_PATH} ${FTP_UPLOAD_TARGET_PATH}; bye"
    fi
  elif [[ -f "${FTP_UPLOAD_SOURCE_PATH}" ]] ; then
    if [ "${FTP_UPLOAD_TARGET_PATH:$targets_last_index:1}" = "/" ]; then
      # source: file | target: dir
      if [ "$FTP_UPLOAD_SOURCE_PATH" = "" ] ; then
        # target: rootdir
        lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "put -O '/' ${FTP_UPLOAD_SOURCE_PATH}; bye"
      else
        set +e
        lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mkdir -p ${FTP_UPLOAD_TARGET_PATH}; bye"
        set -e
        lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "put -O ${FTP_UPLOAD_TARGET_PATH} ${FTP_UPLOAD_SOURCE_PATH}; bye"
      fi
    else
      # source: file | target: file
      target_directory="$(dirname ${FTP_UPLOAD_TARGET_PATH})"
      target_filename="$(basename ${FTP_UPLOAD_TARGET_PATH})"
      if [ "$target_directory" = "" ] ; then
        # target-dir: rootdir
        lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "put -O '/' ${FTP_UPLOAD_SOURCE_PATH} -o ${target_filename}; bye"
      else
        set +e
        lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mkdir -p ${target_directory}; bye"
        set -e
        lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "put -O ${target_directory} ${FTP_UPLOAD_SOURCE_PATH} -o ${target_filename}; bye"
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
