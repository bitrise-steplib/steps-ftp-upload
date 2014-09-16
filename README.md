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

	the source file or directory for the FTP upload

	format: default (e. g. "./" or "$HOME/temp" or "$HOME/temp/")
- **FTP_UPLOAD_TARGET_PATH**

	the target path for the FTP upload; if source is file, target is directory if ends with "/", file otherwise

	format: e. g. root directory: ""; directory "temp" in root directory: "temp/"; directory "backup" in directory "temp" in root directory: "temp/backup/"; file "example.dat" in directory "temp" in root directory: "temp/example.dat"

# How to test/run locally?

- clone this repository
- cd into the repository folder
- run: FTP_HOSTNAME=[your-hostname] FTP_USERNAME=[your-username] FTP_PASSWORD=[your-password] FTP_UPLOAD_SOURCE_PATH=[your-source-path] FTP_UPLOAD_TARGET_PATH=[your-target-path] bash step.sh