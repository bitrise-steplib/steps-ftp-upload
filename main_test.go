package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/bitrise-io/go-utils/fileutil"
	"github.com/bitrise-io/go-utils/log"
	"github.com/bitrise-io/go-utils/pathutil"
	"github.com/bitrise-io/go-utils/sliceutil"
	"github.com/bitrise-tools/goftp"
	"github.com/stretchr/testify/require"
)

var filesMustBeUploaded = []string{
	"/htdocs/test0/inner1/inner2/file1.txt",
	"/htdocs/test0/inner1/inner2/inner3/test-file.txt",
	"/htdocs/test0/inner1/inner2file",
	"/htdocs/test1/file1.txt",
	"/htdocs/test1/file2.txt",
	"/htdocs/test1/file3.txt",
	"/htdocs/test1/inner/file1.txt",
	"/htdocs/test1/inner/inner2/file1.txt",
	"/htdocs/test1/inner/inner2/inner3/file1.txt",
	"/htdocs/test1/inner/inner2/inner3/inner4/file1.txt",
	"/htdocs/test2/[{temp_dir_name}]/file1.txt",
	"/htdocs/test2/[{temp_dir_name}]/file2.txt",
	"/htdocs/test2/[{temp_dir_name}]/file3.txt",
	"/htdocs/test2/[{temp_dir_name}]/inner/file1.txt",
	"/htdocs/test2/[{temp_dir_name}]/inner/inner2/file1.txt",
	"/htdocs/test2/[{temp_dir_name}]/inner/inner2/inner3/file1.txt",
	"/htdocs/test2/[{temp_dir_name}]/inner/inner2/inner3/inner4/file1.txt",
	"/htdocs/test3/test1/test2/test3/file1.txt",
	"/htdocs/test3/test1/test2/test3/file2.txt",
	"/htdocs/test3/test1/test2/test3/file3.txt",
	"/htdocs/test3/test1/test2/test3/inner/file1.txt",
	"/htdocs/test3/test1/test2/test3/inner/inner2/file1.txt",
	"/htdocs/test3/test1/test2/test3/inner/inner2/inner3/file1.txt",
	"/htdocs/test3/test1/test2/test3/inner/inner2/inner3/inner4/file1.txt",
}

func Test_sync(t *testing.T) {
	configs := createConfigsModelFromEnvs()
	configs.cleanHostName()
	origHostName := configs.HostName

	configs.HostName = "ftp.myhost.com"
	configs.cleanHostName()
	require.Equal(t, "ftp.myhost.com:21", configs.HostName)

	configs.HostName = "ftp://ftp.myhost.com"
	configs.cleanHostName()
	require.Equal(t, "ftp.myhost.com:21", configs.HostName)

	configs.HostName = "ftp://ftp.myhost.com:21"
	configs.cleanHostName()
	require.Equal(t, "ftp.myhost.com:21", configs.HostName)

	configs.HostName = "ftp.myhost.com:21"
	configs.cleanHostName()
	require.Equal(t, "ftp.myhost.com:21", configs.HostName)

	configs.HostName = origHostName

	tmpPath, err := pathutil.NormalizedOSTempDirPath("_ftp_test_")
	require.NoError(t, err)

	tmpPathSplit := strings.Split(tmpPath, "/")
	tmpPathName := tmpPathSplit[len(tmpPathSplit)-1]

	pth := filepath.Join(tmpPath, "file1.txt")
	require.NoError(t, pathutil.EnsureDirExist(filepath.Dir(pth)))
	require.NoError(t, fileutil.WriteStringToFile(pth, "content"))

	pth = filepath.Join(tmpPath, "file2.txt")
	require.NoError(t, pathutil.EnsureDirExist(filepath.Dir(pth)))
	require.NoError(t, fileutil.WriteStringToFile(pth, "content"))

	pth = filepath.Join(tmpPath, "file3.txt")
	require.NoError(t, pathutil.EnsureDirExist(filepath.Dir(pth)))
	require.NoError(t, fileutil.WriteStringToFile(pth, "content"))

	pth = filepath.Join(tmpPath, "inner", "file1.txt")
	require.NoError(t, pathutil.EnsureDirExist(filepath.Dir(pth)))
	require.NoError(t, fileutil.WriteStringToFile(pth, "content"))

	pth = filepath.Join(tmpPath, "inner", "inner2", "file1.txt")
	require.NoError(t, pathutil.EnsureDirExist(filepath.Dir(pth)))
	require.NoError(t, fileutil.WriteStringToFile(pth, "content"))

	pth = filepath.Join(tmpPath, "inner", "inner2", "emptydir")
	require.NoError(t, pathutil.EnsureDirExist(pth))

	pth = filepath.Join(tmpPath, "inner", "inner2", "inner3", "file1.txt")
	require.NoError(t, pathutil.EnsureDirExist(filepath.Dir(pth)))
	require.NoError(t, fileutil.WriteStringToFile(pth, "content"))

	pth = filepath.Join(tmpPath, "inner", "inner2", "inner3", "inner4", "file1.txt")
	require.NoError(t, pathutil.EnsureDirExist(filepath.Dir(pth)))
	require.NoError(t, fileutil.WriteStringToFile(pth, "content"))

	ftp, err := goftp.ConnectDbg(configs.HostName)
	require.NoError(t, err)

	defer func() {
		require.NoError(t, ftp.Close())
	}()

	err = ftp.Login(configs.Username, configs.Password)
	require.NoError(t, err)

	//use last pth for files testing
	err = configs.sync(ftp, pth, "/htdocs/test0/inner1/inner2/inner3/test-file.txt")
	require.NoError(t, err)

	err = configs.sync(ftp, pth, "/htdocs/test0/inner1/inner2/")
	require.NoError(t, err)

	err = configs.sync(ftp, pth, "/htdocs/test0/inner1/inner2file")
	require.NoError(t, err)

	err = configs.sync(ftp, tmpPath, "/htdocs/test1")
	require.NoError(t, err)

	err = configs.sync(ftp, tmpPath, "/htdocs/test2/")
	require.NoError(t, err)

	err = configs.sync(ftp, tmpPath, "/htdocs/test3/test1/test2/test3")
	require.NoError(t, err)

	filesUploaded := []string{}
	require.NoError(t, ftp.Walk("/", func(path string, info os.FileMode, err error) error {
		filesUploaded = append(filesUploaded, path)
		return nil
	}))

	log.Infof("%+v", filesUploaded)

	for _, file := range filesMustBeUploaded {
		expandedPath := strings.Replace(file, "[{temp_dir_name}]", tmpPathName, -1)
		if !sliceutil.IsStringInSlice(expandedPath, filesUploaded) {
			require.FailNow(t, "File is not uploaded: "+expandedPath)
		}
	}
}
