package transfers

import (
	"fmt"

	"github.com/duxlabs-dev/dux-go/ipc"
	"github.com/duxlabs-dev/dux-go/ipc/params"
	"github.com/duxlabs-dev/dux-shell/core/internal/server/models"
)

func HandleRequest(conn *ipc.ConnWriter, req ipc.Request, manager *Manager) {
	var act func([]string) error
	switch req.Method {
	case "transfers.getState":
		conn.Respond(req.ID, manager.GetState())
		return
	case "transfers.pause":
		act = manager.Pause
	case "transfers.resume":
		act = manager.Resume
	case "transfers.cancel":
		act = manager.Cancel
	default:
		conn.RespondError(req.ID, fmt.Sprintf("unknown method: %s", req.Method))
		return
	}
	if err := act(params.StringSlice(req.Params, "ids")); err != nil {
		conn.RespondError(req.ID, err.Error())
		return
	}
	conn.Respond(req.ID, models.SuccessResult{Success: true, Message: req.Method})
}
