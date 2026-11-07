import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const C = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandPrint.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), C);

const printer = (state, stateReason, jobs) => ({ state, stateReason, jobs });

test("nothing printing, nothing shown", () => {
    assert.equal(C.current(undefined), null);
    assert.equal(C.current({ "a": printer("idle", "none", []) }), null);
    assert.equal(C.current({ "a": printer("idle", "none", [{ "id": 1, "state": "pending" }]) }), null);
    assert.equal(C.current({ "a": printer("stopped", "paused", [{ "id": 1, "state": "pending" }]) }), null);
});

test("the job printing, with its page when it has one", () => {
    const s = C.current({ "a": printer("processing", "none", [{ "id": 4, "name": "doc", "state": "processing", "pages": 12, "pagesDone": 3 }]) });
    assert.deepEqual({ ...s }, { "printer": "a", "jobId": 4, "name": "doc", "page": 3, "pages": 12, "error": "" });
    assert.equal(C.pageText(s), "3/12");
    assert.equal(C.progress(s), 0.25);
    const bare = C.current({ "a": printer("processing", "none", [{ "id": 4, "state": "processing" }]) });
    assert.equal(C.pageText(bare), "");
    assert.equal(C.progress(bare), -1);
    assert.equal(C.pageText({ "page": 120, "pages": 1200 }), "120");
});

test("an error wins and keys apart from printing", () => {
    const printers = {
        "a": printer("processing", "none", [{ "id": 1, "state": "processing" }]),
        "b": printer("stopped", "media-empty-error", [{ "id": 2, "state": "pending" }])
    };
    const s = C.current(printers);
    assert.equal(s.printer, "b");
    assert.equal(s.error, "media-empty-error");
    assert.notEqual(C.key(s), C.key(C.current({ "a": printers.a })));
    assert.equal(C.current({ "a": printer("processing", "", [{ "id": 3, "state": "processing-stopped" }]) }).error, "stopped");
    assert.equal(C.current({ "a": printer("processing", "toner-low-report", [{ "id": 3, "state": "processing" }]) }).error, "");
    assert.equal(C.key(null), "");
});
