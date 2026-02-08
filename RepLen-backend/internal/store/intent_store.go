package store

import (
	"sync"
	"time"
	"github.com/Tanya0816/RepLen/RepLen-backend/internal/intent"
	"github.com/Tanya0816/RepLen/RepLen-backend/internal/chainexecution"
)

type IntentStore struct {
	mu      sync.Mutex
	intents map[string]intent.LenIntent
	executorRunning bool
	lastCheckedAt time.Time
	tickInterval    time.Duration
	chainExecutor  chainexecution.ChainExecutor

}

func NewIntentStore() *IntentStore {
	return &IntentStore{
		intents:         make(map[string]intent.LenIntent),
		executorRunning: false,
		tickInterval:    5 * time.Second,
	}
}


func (s *IntentStore) Add(i intent.LenIntent) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.intents[i.ID] = i
}

func (s *IntentStore) GetAll() []intent.LenIntent {
	s.mu.Lock()
	defer s.mu.Unlock()

	result := make([]intent.LenIntent, 0, len(s.intents))
	for _, v := range s.intents {
		result = append(result, v)
	}
	return result
}

func (s *IntentStore) ExecutorStatus() map[string]interface{} {
	s.mu.Lock()
	defer s.mu.Unlock()

	pending := 0
	executed := 0

	for _, i := range s.intents {
		if i.Status == "PENDING" && (i.ExecuteAt.Before(time.Now()) || i.ExecuteAt.Equal(time.Now())) {
			pending++
		}
		if i.Status == "EXECUTED" {
			executed++
		}
	}

	return map[string]interface{}{
		"running":                 s.executorRunning,
		"tick_interval_seconds":   int(s.tickInterval.Seconds()),
		"pending_intents":         pending,
		"executed_intents":        executed,
		"last_checked_at":         s.lastCheckedAt,
	}
}

func (s *IntentStore) GetReadyIntents() []intent.LenIntent {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	ready := []intent.LenIntent{}

	for _, i := range s.intents {
		if i.Status == "PENDING" &&
			(i.ExecutedAt.Before(now) || i.ExecutedAt.Equal(now)) {
			ready = append(ready, i)
		}
	}

	return ready
}
func (s *IntentStore) SetChainExecutor(exec chainexecution.ChainExecutor) {
	s.chainExecutor = exec
}
