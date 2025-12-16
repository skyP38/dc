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

	// Возвращаем базовую конфигурацию
	config := map[string]interface{}{
		"docker": map[string]interface{}{
			"host": "unix:///var/run/docker.sock",
			"execution": map[string]interface{}{
				"mode": "session",
				"container": map[string]interface{}{
					"image": "alpine:latest",
				},
			},
		},
	}
	// config := map[string]interface{}{
	// 	"docker": map[string]interface{}{
	// 		"host": "unix:///var/run/docker.sock",
	// 		"execution": map[string]interface{}{
	// 			"mode": "session",
	// 			"session": map[string]interface{}{
	// 				"mode": "passive",
	// 			},
	// 			"container": map[string]interface{}{
	// 				"image":      "alpine:latest",
	// 				"workingDir": "/config",
	// 				"disableAgent": false,
	// 			},
	// 		},
	// 		"timeouts": map[string]interface{}{
	// 			"container": map[string]interface{}{
	// 				"start": "60s",
	// 				"stop":  "60s",
	// 			},
	// 			"signal":   "30s",
	// 			"upload":   "30s",
	// 			"download": "30s",
	// 		},
	// 	},
	// }

	response := ConfigResponse{Config: config}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)

	log.Printf("Config request: user=%s", req.Username)
}

func main() {
	http.HandleFunc("/config", configHandler)

	log.Println("Config server starting on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}
