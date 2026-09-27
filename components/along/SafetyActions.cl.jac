"""Safety actions — report and block another traveler. Used from the chat
header menu and from traveler profiles. Reports go to the Along team only;
blocking hides both people from each other everywhere."""

import from "@jac/runtime" { useNavigate }
import from .Icon { Icon }
sv import from ...services.along { block_user, report_user }

glob REPORT_REASONS: list[list[str]] = [
    ["unsafe", "Unsafe behavior or driving"],
    ["harassment", "Harassment or inappropriate messages"],
    ["spam", "Spam, scam, or asking for money"],
    ["no_show", "Didn’t show up"],
    ["other", "Something else"],
];

# mode: "report" | "block". onClose runs when the dialog is dismissed.
def:pub SafetyDialog(match_id: str, handle: str, mode: str, onClose: Callable[[], None]) -> JsxElement {
    has reason: str = "",
        details: str = "",
        also_block: bool = True,
        busy: bool = False,
        done: str = "",
        error: str = "";

    nav = useNavigate();

    async def submit_report -> None {
        if not reason {
            error = "Please choose what happened.";
            return;
        }
        busy = True;
        ok = await report_user(match_id, reason, details, also_block);
        busy = False;
        if ok {
            done = "Thanks for telling us. Our team will review this report." + (" You won’t see each other again." if also_block else "");
        } else {
            error = "Couldn’t send the report. Please try again.";
        }
    }

    async def confirm_block -> None {
        busy = True;
        ok = await block_user(match_id);
        busy = False;
        if ok {
            done = handle + " is blocked. You won’t see each other or be able to message.";
        } else {
            error = "Couldn’t block right now. Please try again.";
        }
    }

    def finish(e: MouseEvent) {
        onClose();
        if done and (mode == "block" or also_block) {
            nav("/matches");
        }
    }

    return <div className="dialog-backdrop" role="dialog" aria-modal="true" aria-label={"Report " + handle if mode == "report" else "Block " + handle}>
        <div className="dialog-card">
            {if done {
                <div key="done" className="dialog-done">
                    <span className="success-icon"><Icon name="check" size={26} /></span>
                    <p>{done}</p>
                    <button className="btn btn-primary full-button" onClick={finish}>Done</button>
                </div>
            } elif mode == "block" {
                <div key="block">
                    <h2>{"Block " + handle + "?"}</h2>
                    <p className="dialog-sub">You won’t see each other’s journeys or profiles, and neither of you can send messages. They aren’t told you blocked them.</p>
                    {error and <p className="form-error">{error}</p>}
                    <div className="dialog-actions">
                        <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { onClose(); }}>Cancel</button>
                        <button className="btn btn-danger" onClick={confirm_block} disabled={busy}>{"Blocking…" if busy else "Block"}</button>
                    </div>
                </div>
            } else {
                <div key="report">
                    <h2>{"Report " + handle}</h2>
                    <p className="dialog-sub">Reports are private: only the Along team sees them, never the person you report.</p>
                    <div className="reason-list" role="radiogroup" aria-label="What happened">
                        {for r in REPORT_REASONS {
                            <button
                                key={r[0]} type="button" role="radio" aria-checked={reason == r[0]}
                                className={"reason-option" + (" on" if reason == r[0] else "")}
                                onClick={lambda (e: MouseEvent) { reason = r[0]; error = ""; }}
                            >
                                <i />{r[1]}
                            </button>
                        }}
                    </div>
                    <label className="comment-field">
                        <span>Anything else? <em>Optional</em></span>
                        <textarea value={details} maxLength={2000} onChange={lambda (e: ChangeEvent) { details = e.target.value; }} placeholder="What happened, and when?" />
                    </label>
                    <label className="check-row">
                        <input type="checkbox" checked={also_block} onChange={lambda (e: ChangeEvent) { also_block = not also_block; }} />
                        {"Also block " + handle}
                    </label>
                    {error and <p className="form-error">{error}</p>}
                    <div className="dialog-actions">
                        <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { onClose(); }}>Cancel</button>
                        <button className="btn btn-danger" onClick={submit_report} disabled={busy}>{"Sending…" if busy else "Send report"}</button>
                    </div>
                </div>
            }}
        </div>
    </div>;
}
