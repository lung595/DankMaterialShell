package server

import (
	"github.com/duxlabs-dev/dux-go/ipc"
	"github.com/duxlabs-dev/dux-shell/core/internal/server/transfers"
)

// handleTransfers answers the transfers.* requests (the island's transfers bubble), kept out of router.go like the
// managers' own handlers.
func handleTransfers(conn *ipc.ConnWriter, req ipc.Request) {
	if transfersManager == nil {
		conn.RespondError(req.ID, "transfers manager not initialized")
		return
	}
	transfers.HandleRequest(conn, req, transfersManager)
}
