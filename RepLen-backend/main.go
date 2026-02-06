package main

import (
"encoding/json"
"fmt"
"log"
"net/http"
"time"
"github.com/Tanya0816/RepLen/RepLen-backend/internal/store"
"github.com/Tanya0816/RepLen/RepLen-backend/internal/intent"
)
var intentStore *store.IntentStore
func main() {
	intentStore = store.NewIntentStore()
	http.HandleFunc("/health",healthHandler)
    http.HandleFunc("/intent", createIntentHandler)    // POST /intent
    http.HandleFunc("/intents", listIntentsHandler)  // GET /intents

	log.Println("Server is running on port 3000") 
	log.Fatal(http.ListenAndServe(":3000", nil))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, "OK")
}
func createIntentHandler(w http.ResponseWriter, r *http.Request) {    // post /intent
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		ID        string  `json:"id"`
		Address string  `json:"lp_address"`
		PoolID    string  `json:"pool_id"`
		Action    string  `json:"action"`
		Amount    float64 `json:"amount"`
		DelaySec  int     `json:"delay_sec"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}

	now := time.Now()

	i := intent.LenIntent{
		ID:        req.ID,
		Address:   req.Address,
		PoolID:    req.PoolID,
		Action:    intent.ActionType(req.Action),
		Amount:    req.Amount,
		CreatedAt: now,
		ExecutedAt: now.Add(time.Duration(req.DelaySec) * time.Second),
	}

	intentStore.Add(i)

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(i)
}
func listIntentsHandler(w http.ResponseWriter, r *http.Request) {   // GET /intents
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	intents := intentStore.GetAll()
	json.NewEncoder(w).Encode(intents)
}
