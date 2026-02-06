package store

import (
	"sync"

	"RepLen-backend/internal/intent"
)

type IntentStore struct {
	mu      sync.Mutex
	intents map[string]intent.LenIntent
}

func NewIntentStore() *IntentStore {
	return &IntentStore{
		intents: make(map[string]intent.LenIntent),
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
