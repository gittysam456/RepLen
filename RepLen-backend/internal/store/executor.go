package store
import (
"log"
//"sync"
"time"
//"github.com/Tanya0816/RepLen/RepLen-backend/internal/intent"
)

func(s *IntentStore) StartExecutor() {   // This function starts a background goroutine and has ticker for checking every 3 seconds.
	if s.executorRunning {
		return
	}
	s.executorRunning = true
	ticker := time.NewTicker(s.tickInterval)
	go func() {
		for range ticker.C {
			s.executeReadyIntents()
		}
	}()
}
//scan filter and execute
func (s *IntentStore) executeReadyIntents() {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	readyCount := 0
	for id, intent := range s.intents {
		if intent.Status != "PENDING" {
			continue
		}
		if intent.ExecuteAt.Before(now) || intent.ExecuteAt.Equal(now) {
			readyCount++
        if s.chainExecutor != nil {
			err := s.chainExecutor.ExecuteIntent(intent)
			if err != nil {
				log.Printf("[EXECUTOR] Error executing intent ID=%s: %v", intent.ID, err)
				continue
			}
			log.Printf(
				"[EXECUTOR] Executing intent ID=%s Action=%s Amount=%f",
				intent.ID,
				intent.Action,
				intent.Amount,
			)

			executedTime := time.Now()
			intent.Status = "EXECUTED"
			intent.ExecutedAt = &executedTime
			s.lastCheckedAt = time.Now()
			s.intents[id] = intent
	
		}
	}
	if readyCount > 0 {
		log.Printf("[EXECUTOR] %d intent(s) executed in this cycle", readyCount)
	}
}
}