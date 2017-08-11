package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/bitrise-io/go-utils/log"
	"github.com/bitrise-tools/go-steputils/input"
	"github.com/dutchcoders/goftp"
)

// ConfigsModel ...
type ConfigsModel struct {
	HostName   string
	Username   string
	Password   string
	SourcePath string
	TargetPath string
	DebugMode  bool
}

func createConfigsModelFromEnvs() *ConfigsModel {
	return &ConfigsModel{
		HostName:   os.Getenv("hostname"),
		Username:   os.Getenv("username"),
		Password:   os.Getenv("password"),
		SourcePath: os.Getenv("upload_source_path"),
		TargetPath: os.Getenv("upload_target_path"),
		DebugMode:  os.Getenv("debug_mode") == "true",
	}
}

func (configs ConfigsModel) print() {
	log.Infof("Configs:")
	log.Printf("- HostName: %s", configs.HostName)
	log.Printf("- Username: %s", input.SecureInput(configs.Username))
	log.Printf("- Password: %s", input.SecureInput(configs.Password))
	log.Printf("- SourcePath: %s", configs.SourcePath)
	log.Printf("- TargetPath: %s", configs.TargetPath)
}

func failf(format string, v ...interface{}) {
	log.Errorf(format, v...)
	os.Exit(1)
}

func (configs ConfigsModel) validate() error {
	if err := input.ValidateIfNotEmpty(configs.HostName); err != nil {
		return errors.New("no HostName parameter specified")
	}

	if err := input.ValidateIfNotEmpty(configs.Username); err != nil {
		return errors.New("no Username parameter specified")
	}

	if err := input.ValidateIfNotEmpty(configs.Password); err != nil {
		return errors.New("no Password parameter specified")
	}

	if err := input.ValidateIfNotEmpty(configs.SourcePath); err != nil {
		return errors.New("no SourcePath parameter specified")
	}

	if err := input.ValidateIfPathExists(configs.SourcePath); err != nil {
		return fmt.Errorf("SourcePath's path(%s) doesn't exists", configs.SourcePath)
	}

	if err := input.ValidateIfNotEmpty(configs.TargetPath); err != nil {
		return errors.New("no TargetPath parameter specified")
	}

	return nil
}

func (configs *ConfigsModel) cleanHostName() {
	//clean hostname, removes ftp:// prefix and if no port given sets the default :21
	configs.HostName = strings.TrimPrefix(configs.HostName, "ftp://")
	if !strings.Contains(configs.HostName, ":") {
		configs.HostName += ":21"
	}
}

func main() {
	configs := createConfigsModelFromEnvs()

	fmt.Println()
	configs.print()

	if err := configs.validate(); err != nil {
		failf("Issue with input: %s", err)
	}

	fmt.Println()
	log.Infof("Connecting to server...")

	var ftp *goftp.FTP
	var err error

	configs.cleanHostName()

	if !configs.DebugMode {
		ftp, err = goftp.Connect(configs.HostName)
	} else {
		ftp, err = goftp.ConnectDbg(configs.HostName)
	}
	if err != nil {
		failf("Failed to connect to the ftp server, error: %+v", err)
	}

	defer func() {
		err := ftp.Close()
		if err != nil {
			failf("Failed to close ftp connection, error: %+v", err)
		}
	}()

	log.Donef("Connected")

	fmt.Println()
	log.Infof("Authenticating user...")

	if err = ftp.Login(configs.Username, configs.Password); err != nil {
		failf("Failed to login to the ftp server, error: %+v", err)
	}

	log.Donef("Successful")

	fmt.Println()
	log.Infof("Uploading...")

	err = configs.sync(ftp, configs.SourcePath, configs.TargetPath)
	if err != nil {
		failf("Failed to upload files, error: %+v", err)
	}
	log.Donef("Done")
}

func (configs ConfigsModel) sync(ftp *goftp.FTP, localPath, remotePath string) error {
	fullPath, err := filepath.Abs(localPath)
	if err != nil {
		return err
	}

	localFileInfo, err := os.Stat(localPath)
	if err != nil {
		return err
	}

	if localFileInfo.IsDir() {
		if !strings.HasSuffix(remotePath, "/") {
			remotePath += "/"
		}
		splitPath := strings.Split(remotePath, "/")
		mkdirPath := "/"
		for _, pItem := range splitPath {
			mkdirPath = filepath.Join(mkdirPath, pItem)
			if err := ftp.Mkd(mkdirPath); err != nil {
				if configs.DebugMode {
					log.Warnf("Warning: %+v", err)
				}
			}
		}
	} else {
		splitPath := strings.Split(remotePath, "/")
		mkdirPath := "/"
		for _, pItem := range strings.Split(remotePath, "/")[:len(splitPath)-1] {
			mkdirPath = filepath.Join(mkdirPath, pItem)
			if err := ftp.Mkd(mkdirPath); err != nil {
				if configs.DebugMode {
					log.Warnf("Warning: %+v", err)
				}
			}
		}
	}

	walkFunc := func(path string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		relPath, err := filepath.Rel(fullPath, path)
		if err != nil {
			return err
		}
		switch {
		case fi.IsDir():
			if path == fullPath {
				return nil
			}
			rPath := filepath.Join(remotePath, relPath)
			if err = ftp.Mkd(rPath); err != nil {
				if configs.DebugMode {
					log.Warnf("Warning: %+v", err)
				}
			}
		case fi.Mode()&os.ModeSymlink == os.ModeSymlink:
			fInfo, err := os.Stat(path)
			if err != nil {
				return err
			}
			if fInfo.IsDir() {
				err = ftp.Mkd(relPath)
				return err
			} else if fInfo.Mode()&os.ModeType != 0 {
				return nil
			}
			fallthrough
		case fi.Mode()&os.ModeType == 0:
			rPath := filepath.Join(remotePath, relPath)

			if strings.HasSuffix(remotePath, "/") && !localFileInfo.IsDir() {
				rPath = filepath.Join(rPath, fi.Name())
			}

			if err = copyFile(ftp, path, rPath); err != nil {
				return err
			}
		}
		return nil
	}
	return filepath.Walk(fullPath, walkFunc)
}

func copyFile(ftp *goftp.FTP, localPath, serverPath string) (err error) {
	var file *os.File
	if file, err = os.Open(localPath); err != nil {
		return err
	}
	defer func() {
		err := file.Close()
		if err != nil {
			failf("Failed to close file, error: %+v", err)
		}
	}()

	if err := ftp.Stor(serverPath, file); err != nil {
		return err
	}
	return nil
}
