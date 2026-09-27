"""RelayPlanPage — the rider's booked 2-ride trip: both rides with their
status, the stop, and (if a driver can't make it) options to replace that
ride or go direct. Nothing is cancelled for the rider automatically.
Only the rider ever sees both drivers here.

/plans/:planId
"""

import from "@jac/runtime" { useNavigate, useParams, __jacClearCache }
import from react { useEffect }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from .ShareTrip { share_trip }
import from ...lib.along { initials, fmt_time, match_label }
sv import from ...services.along {
    get_relay_plan, replace_relay_leg, cancel_relay, RelayPlanView, RelayLegView, RelayView
}

glob STATUS_TEXT: dict[str, str] = {
    "pending": "Waiting for them to accept", "accepted": "Accepted",
    "declined": "Can’t make it", "replaced": "Replaced", "cancelled": "Cancelled"
};

def:pub RelayPlanRoute() -> JsxElement {
    params = useParams();
    plan_id: str = (params["planId"] or "") as str;
    return <RelayPlanPage key={plan_id} plan_id={plan_id} />;
}

def:pub RelayPlanPage(plan_id: str) -> JsxElement {
    has plan: RelayPlanView | None = None,
        loading: bool = True,
        busy: bool = False,
        note: str = "",
        confirm_cancel: bool = False;

    nav = useNavigate();

    async def load(fresh: bool) -> None {
        if fresh {
            __jacClearCache();
        }
        latest: RelayPlanView | None = await get_relay_plan(plan_id);
        plan = latest;
        loading = False;
    }

    useEffect(lambda {
        load(False);
        timer = setInterval(lambda { load(True); }, 15000);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }, [plan_id]);

    async def use_option(r: RelayView, leg: str) -> None {
        busy = True;
        h = r.handoff;
        new_match_id = r.leg1_match_id if leg == "first" else r.leg2_match_id;
        ok = await replace_relay_leg(
            plan_id, leg, new_match_id, h.name if h else "", h.address if h else "",
            h.lat if h else 0.0, h.lng if h else 0.0, r.handoff_time, r.arrive_time, r.wait_min
        );
        busy = False;
        note = "Asked " + (r.leg1_handle if leg == "first" else r.leg2_handle) + " to take that ride." if ok else "Couldn’t update the trip. Please try again.";
        load(True);
    }

    async def cancel_trip -> None {
        busy = True;
        _ = await cancel_relay(plan_id);
        busy = False;
        confirm_cancel = False;
        load(True);
    }

    async def share -> None {
        if plan is not None and len(plan.legs) > 0 {
            note = await share_trip(plan.legs[0].match_id);
        }
    }

    if loading {
        return <div className="app-shell"><AppHeader /><main className="profile-page page-width"><div className="loading-state"><span className="spinner" /></div></main></div>;
    }
    if plan is None {
        return <div className="app-shell"><AppHeader /><main className="profile-page page-width"><div className="empty-state"><h3>Trip not found</h3><button className="btn btn-primary" onClick={lambda (e: MouseEvent) { nav("/profile"); }}>Back to profile</button></div></main></div>;
    }

    p = plan as RelayPlanView;
    dropped = [l for l in p.legs if l.status == "declined"];
    dropped_leg = dropped[0].leg if len(dropped) > 0 else "";
    cancelled = p.status == "cancelled";

    return <div className="app-shell">
        <AppHeader />
        <main className="profile-page page-width plan-page">
            <button className="back-link" onClick={lambda (e: MouseEvent) { nav(-1); }}><Icon name="back" /> Back</button>
            <div className="plan-head">
                <span className="relay-badge">2-ride trip</span>
                <h1>{p.route_from.split(",")[0] + " → " + p.route_to.split(",")[0]}</h1>
                <p>{("Cancelled" if cancelled else "Arrive around " + p.arrive_time) + " · " + str(p.wait_min) + " min at the stop"}</p>
            </div>

            {if p.needs_attention and not cancelled {
                <div key="attention" className="plan-alert" role="status">
                    <Icon name="lock" />
                    <div>
                        <strong>{dropped[0].handle + " can’t make the " + dropped_leg + " ride"}</strong>
                        <p>Your other ride is still booked. Pick a replacement below, switch to a direct ride, or cancel the trip — it’s your call.</p>
                    </div>
                </div>
            }}
            {note and <p className="plan-note">{note}</p>}

            <ol className="relay-legs plan-legs">
                {for (i, l) in enumerate(p.legs) {
                    <li key={l.match_id}>
                        <span className="avatar avatar-small">{initials(l.handle)}</span>
                        <div>
                            <strong>{("Ride 1: " if l.leg == "first" else "Ride 2: ") + l.handle}</strong>
                            <small>{l.rating + " · " + ("leaves " + l.depart if l.depart else "") + " → " + l.arrive}</small>
                            <span className={"leg-status " + l.status}>{STATUS_TEXT.get(l.status, l.status)}</span>
                        </div>
                        {l.status in ["pending", "accepted"] and <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { nav("/chat/" + l.match_id); }}>Message</button>}
                    </li>
                    if i == 0 {
                        <li key="stop" className="relay-handoff">
                            <span className="handoff-dot"><Icon name="pin" size={16} /></span>
                            <div>
                                <strong>{"Stop: " + p.handoff_name + " · " + p.handoff_time}</strong>
                                <small>{p.handoff_address}</small>
                                <a href={"https://www.google.com/maps/search/?api=1&query=" + str(p.handoff_lat) + "," + str(p.handoff_lng)} target="_blank" rel="noreferrer">Open in Google Maps ↗</a>
                            </div>
                        </li>
                    }
                }}
            </ol>

            {if p.needs_attention and not cancelled {
                <section key="options" className="plan-options">
                    <h2>Options</h2>
                    {if len(p.alternatives) == 0 and len(p.direct_options) == 0 {
                        <p key="none" className="rental-empty">No replacements right now. Along will keep looking — you can also cancel.</p>
                    }}
                    {for r in p.alternatives {
                        <div key={r.id} className="option-row">
                            <div>
                                <strong>{"Replace with " + (r.leg1_handle if dropped_leg == "first" else r.leg2_handle)}</strong>
                                <small>{"Stop: " + (r.handoff.name if r.handoff else "meeting point") + " · arrive " + fmt_time(r.arrive_time) + " · " + str(r.wait_min) + " min wait"}</small>
                            </div>
                            <button className="btn btn-primary" disabled={busy} onClick={lambda (e: MouseEvent) { use_option(r, dropped_leg); }}>Use this</button>
                        </div>
                    }}
                    {for c in p.direct_options {
                        <div key={c.id} className="option-row">
                            <div>
                                <strong>{"Go direct with " + c.other_handle}</strong>
                                <small>{match_label(c.overall_score) + " · one ride, no stop"}</small>
                            </div>
                            <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { nav("/matches/" + c.id); }}>View</button>
                        </div>
                    }}
                </section>
            }}

            {if not cancelled {
                <div key="actions" className="plan-actions">
                    <button className="btn btn-secondary" onClick={share}><Icon name="share" /> Share my trip</button>
                    {if confirm_cancel {
                        <span key="confirm" className="confirm-row">
                            Cancel both rides?
                            <button className="btn btn-danger" onClick={cancel_trip} disabled={busy}>Yes, cancel</button>
                            <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { confirm_cancel = False; }}>Keep it</button>
                        </span>
                    } else {
                        <button key="cancel" className="decline-link" onClick={lambda (e: MouseEvent) { confirm_cancel = True; }}>Cancel trip</button>
                    }}
                </div>
            }}
        </main>
    </div>;
}
