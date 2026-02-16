package chainexecution
import(
	"github.com/Tanya0816/RepLen/RepLen-backend/internal/intent"
)
type ChainExecutor interface {
	ExecuteIntent(intent *intent.LenIntent) error
}