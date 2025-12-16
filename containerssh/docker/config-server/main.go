package main

import (
	"encoding/json"
	"log"
	"net/http"
)

type ConfigRequest struct {
	Username string `json:"username"`
}

type ConfigResponse struct {
	Config map[string]interface{} `json:"config"`
}

func configHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ConfigRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Конфигурация для ContainerSSH
	config := map[string]interface{}{
		"docker": map[string]interface{}{
			"connection": map[string]interface{}{
				"host": "unix:///var/run/docker.sock",
			},
			"execution": map[string]interface{}{
				"mode": "session",
				"container": map[string]interface{}{
					"image":      "alpine:latest",
					"workingDir": "/root",
					"network": map[string]interface{}{
						"enabled": false,
					},
				},
			},
		},
	}

	response := ConfigResponse{Config: config}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)

	log.Printf("Config request: user=%s, image=guest-image", req.Username)
}

func main() {
	http.HandleFunc("/config", configHandler)

	// health check endpoint
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	log.Println("Config server starting on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}
