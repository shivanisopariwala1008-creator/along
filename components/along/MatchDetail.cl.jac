"""MatchDetail — Figma match details: map, journey timeline, why this works
(deterministic scores + the LLM narration), preferences, and the anonymous
profile card with the start-conversation / not-a-match actions."""

import from "@jac/runtime" { useNavigate, useParams, Link }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from .MapCanvas { MapCanvas }
import from ...lib.along {
    flow_info, flow_of_trip, initials, rating_text, has_rating, when_text, fmt_time, plural
}
sv import from ...services.along {
    get_match_details, explain_match, close_match, MatchDetailView, MatchCardView, TripView
}

# Keyed on the match so moving between matches reloads cleanly.
def:pub MatchDetailRoute() -> JsxElement {
    params = useParams();
    match_id: str = (params["matchId"] or "") as str;
    return <MatchDetail key={match_id} match_id={match_id} />;
}

def:pub MatchDetail(match_id: str) -> JsxElement {

    has detail: MatchDetailView | None = None,
        explanation: str = "",
        loading: bool = True,
        declining: bool = False;

    nav = useNavigate();

    async can with entry {
        # Read the fetched value from a local: `detail` stays stale inside this effect.
        found: MatchDetailView | None = None;
        if match_id {
            found = await get_match_details(match_id);
        }
        detail = found;
        loading = False;
        if found {
            text = await explain_match(match_id);
            explanation = text;
        }
    }

    async def decline -> None {
        declining = True;
        _ = await close_match(match_id);
        nav("/matches");
    }

    if loading {
        return <div className="app-shell">
            <AppHeader progress={True} />
            <main className="detail-page"><div className="page-width loading-state"><span className="spinner" /><h3>Loading match</h3></div></main>
        </div>;
    }

    if detail is None or detail.card is None {
        return <div className="app-shell">
            <AppHeader />
            <main className="detail-page">
                <div className="page-width empty-state">
                    <span><Icon name="map" size={30} /></span>
                    <h3>Match not found</h3>
                    <p>It may have been closed, or it belongs to someone else.</p>
                    <Link to="/matches" className="btn btn-primary">Back to matches</Link>
                </div>
            </main>
        </div>;
    }

    card = detail.card as MatchCardView;
    mine = card.my_trip;
    other = card.other_trip;
    kind = flow_of_trip(mine);
    info = flow_info(kind);
    capacity = "";
    if other is not None {
        if kind == "ride" {
            capacity = plural(other.seats_available, "seat", "seats");
        } else {
            capacity = plural(other.people, "person", "people");
        }
    }

    return <div className="app-shell">
        <AppHeader progress={True} />
        <main className="detail-page">
            <div className="page-width">
                <button className="back-link" onClick={lambda (e: MouseEvent) { nav(-1); }}><Icon name="back" /> Back to matches</button>
            </div>
            <div className="detail-layout page-width">
                <section className="detail-main">
                    <div className="detail-map">
                        <MapCanvas my_trip={mine} cards={[card]} selected={0} onSelect={lambda (i: int) { }} kind={kind} />
                    </div>
                    <div className="detail-section">
                        <span className="step-kicker">{info["marker_label"]}</span>
                        <h1>{"A strong match for your journey" if card.overall_score >= 70 else "A possible match for your journey"}</h1>
                        <div className="journey-timeline">
                            <span><i /><i /></span>
                            <div className="timeline-stops">
                                <div>
                                    <small>STARTS NEAR</small>
                                    <strong>{other.origin_name if other is not None else ""}</strong>
                                    <p>Approximate area only</p>
                                </div>
                                <div>
                                    <small>HEADING TO</small>
                                    <strong>{other.destination_name if other is not None else ""}</strong>
                                    <p>{when_text(card)}</p>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="detail-section">
                        <h2>Why this works</h2>
                        <div className="match-explanation">
                            <Icon name="check" />
                            <div>
                                <strong>{card.fit_label + " · " + str(card.overall_score) + "% overall"}</strong>
                                <p>{card.why}</p>
                                {if explanation {
                                    <p key="ai" className="ai-note">{explanation}</p>
                                } else {
                                    <p key="ai-loading" className="ai-note muted">Writing a plain-language summary…</p>
                                }}
                            </div>
                        </div>
                        <div className="stat-grid">
                            <div><Icon name="clock" /><span><small>Timing</small><strong>{when_text(card)}</strong></span></div>
                            <div><Icon name="users" /><span><small>{"Seats" if kind == "ride" else "Group"}</small><strong>{capacity}</strong></span></div>
                            <div><Icon name="pin" /><span><small>Detour</small><strong>{"+" + str(card.detour_minutes) + " min"}</strong></span></div>
                        </div>
                        <div className="score-bars">
                            <ScoreBar label="Route overlap" value={card.route_score} />
                            <ScoreBar label="Schedule fit" value={card.time_score} />
                            <ScoreBar label="Preferences" value={card.preference_score} />
                            <ScoreBar label="Cost benefit" value={card.cost_benefit_score} />
                        </div>
                        {if kind == "ride" or kind == "cab" {
                            <p key="savings" className="savings-note">
                                {"Estimated savings: about $" + str(int(card.estimated_rider_savings)) + (" a week" if mine is not None and mine.recurring else " for this trip") + " compared with a private rideshare."}
                            </p>
                        }}
                    </div>
                    <div className="detail-section">
                        <h2>Preferences</h2>
                        <div className="preference-chips">
                            {for chip in _preference_chips(other) {
                                <span key={chip}>{chip}</span>
                            }}
                        </div>
                    </div>
                </section>
                <aside className="profile-card">
                    <div className="profile-intro">
                        <span className="avatar avatar-large">{initials(card.other_handle)}</span>
                        <h2>{card.other_handle}</h2>
                        <span className={"rating" if has_rating(other) else "new-user"}>
                            {has_rating(other) and <Icon name="star" size={15} />} {rating_text(other)}
                        </span>
                        <p>Identity stays private until you both choose to reveal it.</p>
                    </div>
                    <div className="trust-list">
                        <div><Icon name="shield" /><span><strong>Anonymous handle</strong><small>Real name hidden until mutual approval</small></span></div>
                        <div><Icon name="pin" /><span><strong>Approximate area</strong><small>Exact addresses are never shown</small></span></div>
                        <div><Icon name="star" /><span><strong>{"Community rated" if has_rating(other) else "New traveler"}</strong><small>{"Ratings are anonymous" if has_rating(other) else "No ratings received yet"}</small></span></div>
                    </div>
                    <button className="btn btn-primary full-button" onClick={lambda (e: MouseEvent) { nav("/chat/" + match_id); }}>
                        {"Continue conversation" if card.has_conversation else "Start anonymous conversation"}
                        <Icon name="chat" />
                    </button>
                    <button className="btn btn-secondary full-button graph-link" onClick={lambda (e: MouseEvent) { nav("/graph/" + match_id); }}>
                        <Icon name="graph" /> How Along found this
                    </button>
                    <button className="decline-link" onClick={decline} disabled={declining}>{"Closing…" if declining else "Not a match"}</button>
                    <div className="safe-note">
                        <Icon name="lock" />
                        <span>Your full name, exact address, and contact details are never shared without permission.</span>
                    </div>
                </aside>
            </div>
        </main>
    </div>;
}

def _preference_chips(t: TripView | None) -> list[str] {
    if t is None {
        return [];
    }
    chips = ["Age: " + (t.age_pref or "No preference"), "Gender: " + (t.gender_pref or "No preference")];
    chips = chips + (["Smoking OK"] if t.smoking else ["Non-smoking"]);
    if t.mode == "rental" {
        chips = chips + ["Vehicle: " + (t.vehicle or "Flexible")];
        if t.moving_help {
            chips = chips + ["Needs moving help"];
        }
    }
    if t.recurring {
        chips = chips + ["Weekday commute"];
    }
    if t.round_trip {
        chips = chips + ["Round trip"];
    }
    if t.flexible_minutes > 0 {
        chips = chips + ["Flexible ±" + str(t.flexible_minutes) + " min"];
    }
    return chips;
}

def:pub ScoreBar(label: str, value: int) -> JsxElement {
    return <div className="score-bar">
        <span>{label}</span>
        <i><b style={{"width": str(value) + "%"}} /></i>
        <strong>{str(value) + "%"}</strong>
    </div>;
}
