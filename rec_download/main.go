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

	"t/lua"
)

const (
	packagesDir  = "./packages"
	downloadsDir = "./downloads"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatalf("Usage: %s <package-name>", os.Args[0])
	}
	pkgName := os.Args[1]

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

	if err := L.DoString(fmt.Sprintf(`recipe = require("%s")`, pkgName)); err != nil {
		log.Fatalf("Failed to require package %s: %v", pkgName, err)
	}

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

		if err := os.MkdirAll(downloadsDir, 0755); err != nil {
			log.Fatalf("Failed to create downloads dir: %v", err)
		}

		fileName := filepath.Base(urlStr)
		if fileName == "" || fileName == "." || fileName == "/" {
			fileName = pkgName + ".tar.gz"
		}
		downloadPath := filepath.Join(downloadsDir, fileName)

		log.Printf("Downloading %s ...", urlStr)
		tmpFile, err := os.CreateTemp("", "download-*")
		if err != nil {
			log.Fatalf("Failed to create temp file: %v", err)
		}
		defer os.Remove(tmpFile.Name())

		resp, err := http.Get(urlStr)
		if err != nil {
			log.Fatalf("Failed to download: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			log.Fatalf("HTTP error: %s", resp.Status)
		}

		hasher := sha256.New()
		multiWriter := io.MultiWriter(tmpFile, hasher)

		if _, err := io.Copy(multiWriter, resp.Body); err != nil {
			log.Fatalf("Failed to write to temp file: %v", err)
		}

		calculatedHash := hex.EncodeToString(hasher.Sum(nil))
		expectedHash := strings.TrimPrefix(hashStr, "sha256:")
		expectedHash = strings.TrimPrefix(expectedHash, "SHA256:")
		expectedHash = strings.TrimSpace(expectedHash)

		if calculatedHash != expectedHash {
			log.Fatalf("Hash mismatch: expected %s, got %s", expectedHash, calculatedHash)
		}
		log.Println("Hash verified successfully")

		if err := os.Rename(tmpFile.Name(), downloadPath); err != nil {
			if err := copyFile(tmpFile.Name(), downloadPath); err != nil {
				log.Fatalf("Failed to move file: %v", err)
			}
		}
		log.Printf("Downloaded and saved to %s", downloadPath)

		log.Println("Done.")
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
