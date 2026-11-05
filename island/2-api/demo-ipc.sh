#!/bin/sh
# Demo of the island activities API over IPC (PR "island: activities API and scripts over IPC"): a script shows an
# activity on the island, updates it, ends it. Same calls on a real session: DMS=dms (the default); on the bench the
# media scripts set DMS to the bench's ctl.sh.
# usage: demo-ipc.sh live | alert
DMS=${DMS:-dms}
STEP=${STEP:-0.4}

case "$1" in
  live)
    # A live activity: a compact bubble with a progress ring, until the script ends it.
    tok=$($DMS ipc call island activity backup live '{"title":"Backup","icon":"backup","text":"Copying","progress":0}')
    echo "token: $tok"
    for p in 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1; do
      sleep "$STEP"
      $DMS ipc call island activityUpdate "$tok" '{"title":"Backup","icon":"backup","text":"Copying","progress":'$p'}' >/dev/null
    done
    $DMS ipc call island activityUpdate "$tok" '{"title":"Backup done","icon":"check_circle","accent":"success"}'
    sleep 1.5
    $DMS ipc call island activityEnd "$tok"
    ;;
  alert)
    # An alert opens its sheet at once, with up to three buttons; the picked one is readable with activityStatus.
    tok=$($DMS ipc call island activity build alert '{"title":"Build failed","icon":"error","accent":"error","text":"2 tests failed","actions":[{"id":"log","label":"Open log"},{"id":"retry","label":"Retry"},{"id":"dismiss","label":"Dismiss"}]}')
    echo "token: $tok"
    sleep 3
    $DMS ipc call island activityStatus "$tok"
    $DMS ipc call island activityEnd "$tok"
    ;;
  *)
    echo "usage: $0 live|alert" >&2
    exit 2
    ;;
esac
