package intent
import "time"
type ActionType string
type intentStatus string
const(
	AddLiquidity    ActionType = "ADD"
	RemoveLiquidity ActionType = "REMOVE"
	Rebalance       ActionType = "REBALANCE"
)
const(
	StatusPending   intentStatus = "PENDING"
	StatusExecuted  intentStatus = "EXECUTED"
	StatusFailed    intentStatus = "FAILED"
	StatusCancelled intentStatus = "CANCELLED"
)
type LenIntent struct {
	ID        string
	Action    ActionType
	Address   string
	PoolID    string
	Amount	float64
	CreatedAt time.Time      // when the intent was created
	ExecutedAt time.Time    //when the intent was executed
}