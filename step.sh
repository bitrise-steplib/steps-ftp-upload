#!/bin/bash

formatted_output_file_path="$BITRISE_STEP_FORMATTED_OUTPUT_FILE_PATH"

function echo_string_to_formatted_output {
  echo "$1" >> $formatted_output_file_path
}

function write_section_to_formatted_output {
  echo '' >> $formatted_output_file_path
  echo "$1" >> $formatted_output_file_path
  echo '' >> $formatted_output_file_path
}

function do_failed_cleanup {
  write_section_to_formatted_output "# FTP upload failed!"
  write_section_to_formatted_output "Check the Logs for details."
}

function print_command_cleanup_and_exit_on_error {
  if [ $? -ne 0 ]; then
    do_failed_cleanup
    echo " [!] Failed!"
    exit 1
  fi
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

brew install lftp
print_command_cleanup_and_exit_on_error

echo "FTP_UPLOAD_SOURCE_PATH: ${FTP_UPLOAD_SOURCE_PATH}"
echo "FTP_UPLOAD_TARGET_PATH: ${FTP_UPLOAD_TARGET_PATH}"

# strip beginning "./" from target directory
let sources_last_index=${#FTP_UPLOAD_SOURCE_PATH}-1
let targets_last_index=${#FTP_UPLOAD_TARGET_PATH}-1
target_directory="${FTP_UPLOAD_TARGET_PATH}"
if [ "${target_directory:0:2}" = "./" ] ; then
  target_directory="${target_directory:2:targets_last_index}"
fi

# if source path is a valid directory
if [[ -d "${FTP_UPLOAD_SOURCE_PATH}" ]] ; then
  # put source to target directory, specified in target path
  # if source is files in source path, put files to target path
  if [ "${FTP_UPLOAD_SOURCE_PATH:$sources_last_index:1}" = "/" ] ; then
    echo "source is files in directory"
    write_section_to_formatted_output "### Source is files in directory"
    if [ "$target_directory" != "" ] ; then
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mkdir ${target_directory}; bye"
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mput -O ${target_directory} ${FTP_UPLOAD_SOURCE_PATH}*; bye"
    else
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mput -O './' ${FTP_UPLOAD_SOURCE_PATH}*; bye"
    fi
  # if source is directory, put source directory to target path
  else
    echo "source is directory"
    write_section_to_formatted_output "### Source is directory"
    lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mirror -R ${FTP_UPLOAD_SOURCE_PATH} ${target_directory}; bye"
    print_command_cleanup_and_exit_on_error
  fi
  echo "target is directory"
  write_section_to_formatted_output "### Target is directory"
# else, if source path is a valid file
elif [[ -f "${FTP_UPLOAD_SOURCE_PATH}" ]] ; then
  echo "source is file"
  write_section_to_formatted_output "### Source is file"
  # if target path is a directory name by format
  if [ "${FTP_UPLOAD_TARGET_PATH:$targets_last_index:1}" = "/" ] ; then
    echo "target is directory"
    write_section_to_formatted_output "### Target is directory"
    # put source file to target directory
    if [ "$target_directory" != "" ] ; then
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mkdir ${target_directory}; bye"
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "put -O ${target_directory} ${FTP_UPLOAD_SOURCE_PATH}; bye"
    else
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "put -O './' ${FTP_UPLOAD_SOURCE_PATH}; bye"
    fi
    print_command_cleanup_and_exit_on_error
  # else, target path is a filename by format
  else
    echo "target is file"
    write_section_to_formatted_output "### Target is file"
    source_filename="$(basename ${FTP_UPLOAD_SOURCE_PATH})"
    target_directory="$(dirname ${target_directory})"
    target_filename="$(basename ${FTP_UPLOAD_TARGET_PATH})"
    if [ "$target_directory" != "." ] ; then
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "mkdir ${target_directory}; bye"
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "put -O ${target_directory} ${FTP_UPLOAD_SOURCE_PATH} -o ${target_filename}; bye"
    else
      lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" "${FTP_HOSTNAME}" -e "put -O './' ${FTP_UPLOAD_SOURCE_PATH} -o ${target_filename}; bye"
    fi
  fi
# else, source path is invalid
else
  echo "source is invalid"
  do_failed_cleanup
  echo " [!] Failed!"
  exit 1
fi

write_section_to_formatted_output "# FTP upload successful!"