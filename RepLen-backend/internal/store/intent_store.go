package store

import (
	"log"
	"sync"
	"time"

	"github.com/Tanya0816/RepLen/RepLen-backend/internal/chainexecution"
	"github.com/Tanya0816/RepLen/RepLen-backend/internal/intent"
)

type IntentStore struct {
	mu            sync.Mutex
	intents       map[string]intent.LenIntent
	chainExecutor chainexecution.ChainExecutor
}

func NewIntentStore() *IntentStore {
	return &IntentStore{
		intents: make(map[string]intent.LenIntent),
	}
}

func (s *IntentStore) SetChainExecutor(exec chainexecution.ChainExecutor) {
	s.chainExecutor = exec
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

func (s *IntentStore) ExecuteReadyIntents() {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()

	for id, i := range s.intents {

		// Skip if already executed
		if i.Executed {
			continue
		}

		// Execute if time reached
		if now.After(i.ExecutedAt) {

			if s.chainExecutor != nil {
				err := s.chainExecutor.ExecuteIntent(&i)
				if err != nil {
					log.Printf("execution failed: %v", err)
					continue
				}
			}

			i.Executed = true
			s.intents[id] = i

			log.Printf("Intent %s executed", id)
		}
	}
}
