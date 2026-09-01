package main

import (
	"archive/tar"
	"compress/gzip"
	"crypto/md5"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-git/go-git/v5"

	"t/lua"
)

const (
	packagesDir  = "./packages"
	downloadsDir = "./downloads"
	srcDir       = "./src"
)

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

	log.Printf("Package: %s", pkgName)
	log.Printf("Source URL: %s", urlStr)
	log.Printf("Expected hash: %s", hashStr)
	if len(deps) > 0 {
		log.Printf("Dependencies: %v", deps)
	} else {
		log.Println("No dependencies")
	}

	// скачивание источников
	if err := os.MkdirAll(downloadsDir, 0755); err != nil {
		log.Fatalf("Failed to create downloads dir: %v", err)
	}

	fileName := filepath.Base(urlStr)
	if fileName == "" || fileName == "." || fileName == "/" {
		fileName = pkgName + ".tar.gz"
	}
	downloadPath := filepath.Join(downloadsDir, fileName)

	log.Printf(downloadPath)

	if _, err := os.Stat(downloadPath); err != nil {

		log.Printf("Downloading %s ...", urlStr)

		err = downloadFile(urlStr, hashStr, downloadPath)
		if err != nil {
			log.Fatalf("%v", err)
		}

		log.Println("Done.")
	}

	// распаковка в каталог src
	if err := os.MkdirAll(srcDir, 0755); err != nil {
		log.Fatalf("Failed to create src dir: %v", err)
	}

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
		fmt.Printf("Extraction failed: %v\n", err)
		return
	}
	log.Printf("extraction file done")
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
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

func ExtractFileTarGz(srcFile, destDir string) error {
	f, err := os.Open(srcFile)
	if err != nil {
		return fmt.Errorf("failed to open source file: %w", err)
	}
	defer f.Close()

	gzReader, err := gzip.NewReader(f)
	if err != nil {
		return fmt.Errorf("failed to create gzip reader: %w", err)
	}
	defer gzReader.Close()

	tarReader := tar.NewReader(gzReader)

	oldHeader, err := tarReader.Next()
	lenOldHeader := len(oldHeader.Name)

	for {
		header, err := tarReader.Next()
		if err == io.EOF {
			break // End of archive
		}
		if err != nil {
			return fmt.Errorf("failed to read tar header: %w", err)
		}

		targetPath := filepath.Join(destDir, header.Name[lenOldHeader:])

		if !strings.HasPrefix(targetPath, filepath.Clean(destDir)+string(os.PathSeparator)) {
			return fmt.Errorf("illegal file path path in tar: %s", header.Name)
		}

		switch header.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(targetPath, 0755); err != nil {
				return fmt.Errorf("failed to create directory: %w", err)
			}

		case tar.TypeReg:
			if err := os.MkdirAll(filepath.Dir(targetPath), 0755); err != nil {
				return fmt.Errorf("failed to create parent directory: %w", err)
			}

			outFile, err := os.OpenFile(targetPath, os.O_CREATE|os.O_RDWR|os.O_TRUNC, header.FileInfo().Mode())
			if err != nil {
				return fmt.Errorf("failed to create file: %w", err)
			}

			if _, err := io.Copy(outFile, tarReader); err != nil {
				outFile.Close()
				return fmt.Errorf("failed to copy file contents: %w", err)
			}
			outFile.Close()
		}
	}

	return nil
}

func downloadFile(url, hash, downloadPath string) error {
	if url[:5] == "https" {
		return downloadFileHTTPS(url, hash, downloadPath)
	} else {
		return downloadFileGit(url)
	}

}

func downloadFileHTTPS(url, hash, downloadPath string) error {

	tmpFile, err := os.CreateTemp("", "download-*")
	if err != nil {
		log.Fatalf("Failed to create temp file: %v", err)
	}
	defer os.Remove(tmpFile.Name())

	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("Failed to download: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP error: %s", resp.Status)
	}

	// проверка целостности
	hasher := sha256.New()
	multiWriter := io.MultiWriter(tmpFile, hasher)

	if _, err := io.Copy(multiWriter, resp.Body); err != nil {
		return fmt.Errorf("Failed to write to temp file: %v", err)
	}

	calculatedHash := hex.EncodeToString(hasher.Sum(nil))
	expectedHash := strings.TrimPrefix(hash, "sha256:")
	expectedHash = strings.TrimPrefix(expectedHash, "SHA256:")
	expectedHash = strings.TrimSpace(expectedHash)

	if calculatedHash != expectedHash {
		return fmt.Errorf("Hash mismatch: expected %s, got %s", expectedHash, calculatedHash)
	}
	log.Println("Hash verified successfully")

	if err := os.Rename(tmpFile.Name(), downloadPath); err != nil {
		if err := copyFile(tmpFile.Name(), downloadPath); err != nil {
			log.Fatalf("Failed to move file: %v", err)
		}
	}
	log.Printf("Downloaded and saved to %s", downloadPath)

	return nil
}

func downloadFileGit(url string) error {
	parts := strings.Split(url, "/")
	repoName := strings.TrimSuffix(parts[len(parts)-1], ".git")
	destDir := filepath.Join(".", repoName)

	// sshAuth, err := ssh.NewPublicKeysFromFile("git", os.ExpandEnv("$HOME/.ssh/id_rsa"), "")
	// if err != nil {
	// 	fmt.Printf("Ошибка загрузки SSH ключа: %v\n", err)
	// 	os.Exit(1)
	// }

	// Опции для клонирования
	cloneOptions := &git.CloneOptions{
		URL: url,
		// Auth:              sshAuth,
		Progress:          os.Stdout,
		Depth:             1, // Только последний коммит
		RecurseSubmodules: git.DefaultSubmoduleRecursionDepth,
	}

	_, err := git.PlainClone(destDir, false, cloneOptions)
	if err != nil {
		return fmt.Errorf("Error cloning repository: %v\n", err)
	}

	return nil
}
