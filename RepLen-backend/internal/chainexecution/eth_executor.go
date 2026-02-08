package chainexecution
import (	"log"
	"github.com/Tanya0816/RepLen/RepLen-backend/internal/intent"
)

type EthExecutor struct {}

func (e *EthExecutor) ExecuteIntent(i intent.LenIntent) error {
	log.Printf("Calling contract for LP =%s Pool=%s Amount=%f", i.Address, i.PoolID, i.Amount)
	return nil
}