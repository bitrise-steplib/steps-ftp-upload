steps-ftp-upload
================

Bitrise step to upload a single file or a folder to an FTP server

# Input Environment Variables
- **FTP_HOSTNAME**

    the host of the target FTP
- **FTP_USERNAME**

	the username of the target FTP
- **FTP_PASSWORD**

	the password for the user of the target FTP
- **FTP_UPLOAD_SOURCE_PATH**

	the source path for the FTP upload; if path is a directory, and ends with "/", contents of the directory will be uploaded to the target path; otherwise, the directory will be uploaded to the target path
- **FTP_UPLOAD_TARGET_PATH**

	the target path for the FTP upload; if source path is a file, target path is assumed to be target directory or target file, whether it does or does not end with "/"

# How to test/run locally?

- clone this repository
- cd into the repository folder
- run: FTP_HOSTNAME=[your-hostname] FTP_USERNAME=[your-username] FTP_PASSWORD=[your-password] FTP_UPLOAD_SOURCE_PATH=[your-source-path] FTP_UPLOAD_TARGET_PATH=[your-target-path] bash step.sh