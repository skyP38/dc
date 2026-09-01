package main

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"

	"t/lua"
)

const (
	packagesDir  = "./packages"
	downloadsDir = "./downloads"
	srcDir       = "./src"
)

// TODO
type Task struct {
	urlStr       string
	hashStr      string
	downloadPath string
	status       bool
}

type Runnable interface {
	Run(ch chan Task)
	run()
}

type runnable struct {
	callBackFunc func()
}

type Downloader struct {
	runnable
}

type Unpacker struct {
	runnable
}

func (r runnable) Run(ch chan Task) {
	r.run()
}

func (r runnable) run() {
	r.callBackFunc()
}

func (d Downloader) Run(ch chan Task) {
	//TODO
	//
	task := <-ch
	urlStr := task.urlStr
	hashStr := task.hashStr
	downloadPath := task.downloadPath

	// скачивание источников
	if err := os.MkdirAll(downloadsDir, 0755); err != nil {
		log.Fatalf("Failed to create downloads dir: %v", err)
	}

	log.Printf(downloadPath)

	if _, err := os.Stat(downloadPath); err != nil {

		log.Printf("Downloading %s ...", urlStr)

		err = downloadFile(urlStr, hashStr, downloadPath)
		if err != nil {
			log.Fatalf("%v", err)
		}

		log.Println("Done.")
	}
	task.status = true
	ch <- task

}

func NewDownloader() Runnable {
	var d Downloader
	// d.callBackFunc = d.Run()
	return d
}

func (u Unpacker) Run(ch chan Task) {
	//TODO
	//
	//

	task := <-ch
	fileName := task.urlStr
	versStr := task.hashStr
	downloadPath := task.downloadPath

	// распаковка в каталог src
	if err := os.MkdirAll(srcDir, 0755); err != nil {
		log.Fatalf("Failed to create src dir: %v", err)
	}

	md5String, err := getFileMD5(downloadPath)
	if err != nil {
		log.Fatalf("Error: %v\n", err)
		return
	}
	fileName = strings.Join([]string{md5String, fileName, versStr}, "-")
	srcPath := filepath.Join(srcDir, fileName)
	log.Printf(srcPath)

	err = ExtractFileTarGz(downloadPath, srcPath)
	if err != nil {
		log.Printf("Extraction failed: %v\n", err)
		return
	}
	log.Printf("extraction file done")

	task.status = true
	ch <- task

}

func NewUnpacker() Unpacker {
	var u Unpacker
	// u.callBackFunc = u.Run()
	return u
}

func main() {
	if len(os.Args) < 2 {
		log.Fatalf("Usage: %s <package-name>", os.Args[0])
	}
	// имя пакета
	pkgName := os.Args[1]

	// конфигурация Teal
	L := lua.NewState()
	defer L.Close()

	L.OpenLibs()

	if err := L.DoString(fmt.Sprintf(`package.path = package.path .. ";%s/?.lua"`, packagesDir)); err != nil {
		log.Fatalf("Failed to set package.path: %v", err)
	}

	if err := L.DoString(`tl = require("tl")`); err != nil {
		log.Fatalf("Failed to require tl: %v", err)
	}
	if err := L.DoString(`tl.loader()`); err != nil {
		log.Fatalf("Failed to activate Teal loader: %v", err)
	}

	// проверка на существование пакета
	if err := L.DoString(fmt.Sprintf(`recipe = require("%s")`, pkgName)); err != nil {
		log.Fatalf("Failed to require package %s: %v", pkgName, err)
	}

	// определение источников
	if err := L.DoString(`source_url = recipe.source.url`); err != nil {
		log.Fatalf("Failed to get source.url: %v", err)
	}
	if err := L.DoString(`source_hash = recipe.source.hash`); err != nil {
		log.Fatalf("Failed to get source.hash: %v", err)
	}

	urlVal, err := L.GetGlobal("source_url")
	if err != nil {
		log.Fatalf("Failed to get source_url: %v", err)
	}
	urlStr, ok := urlVal.(string)
	if !ok || urlStr == "" {
		log.Fatalf("source.url is not a valid string")
	}

	hashVal, err := L.GetGlobal("source_hash")
	if err != nil {
		log.Fatalf("Failed to get source_hash: %v", err)
	}
	hashStr, ok := hashVal.(string)
	if !ok || hashStr == "" {
		log.Fatalf("source.hash is not a valid string")
	}

	// определение зависимостей
	var deps []string
	L.SetGlobal("add_dep", func(args []interface{}) ([]interface{}, error) {
		if len(args) > 0 {
			if s, ok := args[0].(string); ok {
				deps = append(deps, s)
			}
		}
		return nil, nil
	})

	if err := L.DoString(`
		if recipe.dependencies then
			for _, dep in ipairs(recipe.dependencies) do
				add_dep(dep)
		end
		end
		`); err != nil {
		log.Fatalf("Failed to iterate dependencies: %v", err)
	}

	// log.Printf("Package: %s", pkgName)
	// log.Printf("Source URL: %s", urlStr)
	// log.Printf("Expected hash: %s", hashStr)
	// if len(deps) > 0 {
	// log.Printf("Dependencies: %v", deps)
	// } else {
	// log.Println("No dependencies")
	// }

	if err := L.DoString(`pkg_version = recipe.version`); err != nil {
		log.Fatalf("Failed to get recipe.version: %v", err)
	}
	versVal, err := L.GetGlobal("pkg_version")
	if err != nil {
		log.Fatalf("Failed to get pkg_version: %v", err)
	}
	versStr, ok := versVal.(string)
	if !ok || versStr == "" {
		log.Fatalf("version is not a valid string")
	}

	fileName := filepath.Base(urlStr)
	if fileName == "" || fileName == "." || fileName == "/" {
		fileName = pkgName + ".tar.gz"
	}
	downloadPath := filepath.Join(downloadsDir, fileName)

	d := NewDownloader()
	u := NewUnpacker()

	chd := make(chan Task)
	chu := make(chan Task)

	go d.Run(chd)
	go u.Run(chu)

	chd <- Task{urlStr, hashStr, downloadPath, false}

	chu <- Task{fileName, versStr, downloadPath, false}

	<-chd
	<-chu

}

func getFileMD5(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := md5.New()

	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}

	hashInBytes := hash.Sum(nil)
	return hex.EncodeToString(hashInBytes), nil
}
