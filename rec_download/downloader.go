package main

import (
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
)

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
