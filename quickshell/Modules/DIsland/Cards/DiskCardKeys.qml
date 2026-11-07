pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.DIsland.Kit
import "../../../Common/DiskChart.js" as DiskChart

// The disk card's keyboard (BubbleCardDisk), once it has it: arrows move the choice on the chart or the list, Enter
// goes in (or shows a listed item on the chart), Backspace / Escape go back then give the keyboard back, Del trashes.
QtObject {
    id: keys

    required property BubbleCardDisk card
    required property DiskLargestList listView
    required property DiskChartView chartView

    function press(event) {
        const k = event.key;
        const list = card.svc.mode === "list";
        // The cleanup covers the chart: Escape or Backspace folds it back, nothing else moves under it.
        if (card.cleanupOpen) {
            if (k === Qt.Key_Escape || k === Qt.Key_Backspace)
                card.cleanupOpen = false;
            event.accepted = true;
            return;
        }
        if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
            const dx = k === Qt.Key_Right ? 1 : k === Qt.Key_Left ? -1 : 0;
            const dy = k === Qt.Key_Down ? 1 : k === Qt.Key_Up ? -1 : 0;
            if (list) {
                const i = DiskChart.listStep(keys.listView.rows.length, keys.listView.chosenIndex, dy || dx);
                card.sel = keys.listView.rows[i] ?? null;
                if (card.sel)
                    keys.listView.positionViewAtIndex(i, ListView.Contain);
            } else if (card.svc.mode === "sun") {
                card.pick(DiskChart.ringStep(keys.chartView.items, card.chosenNode, dx || dy));
            } else {
                card.pick(DiskChart.step(keys.chartView.items, card.chosenNode, dx, dy));
            }
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (list)
                card.reveal(card.sel);
            else
                card.enter(card.chosenNode);
            event.accepted = true;
        } else if (k === Qt.Key_Backspace || k === Qt.Key_Escape) {
            if (list && card.oldOnly)
                card.oldOnly = false;
            else if (!card.up()) {
                if (card.sel)
                    card.sel = null;
                else if (k === Qt.Key_Escape) {
                    // At the top with nothing chosen: Escape gives the keyboard back.
                    card.keysTaken = false;
                    card.bubble?.keyboard?.(null);
                }
            }
            event.accepted = true;
        } else if (k === Qt.Key_Delete) {
            card.act.trashChosen();
            event.accepted = true;
        }
    }
}
