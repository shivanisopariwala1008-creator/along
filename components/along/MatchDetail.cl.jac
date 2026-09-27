"""MatchDetail — Figma match details: map, journey timeline, why this works
(deterministic scores + the LLM narration), preferences, and the anonymous
profile card with the start-conversation / not-a-match actions."""

import from "@jac/runtime" { useNavigate, useParams, Link }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from .MapCanvas { MapCanvas }
import from ...lib.along {
    flow_info, flow_of_trip, initials, rating_text, has_rating, when_text, fmt_time, plural, fmt_date
}
sv import from ...services.along {
    get_match_details, close_match, MatchDetailView, MatchCardView, TripView
}

# Keyed on the match so moving between matches reloads cleanly.
def:pub MatchDetailRoute() -> JsxElement {
    params = useParams();
    match_id: str = (params["matchId"] or "") as str;
    return <MatchDetail key={match_id} match_id={match_id} />;
}

def:pub MatchDetail(match_id: str) -> JsxElement {

    has detail: MatchDetailView | None = None,
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
                        <h2>Why it’s a match</h2>
                        <p className="match-why">{card.why}</p>
                        <div className="stat-grid">
                            <div><Icon name="pin" /><span><small>Pickup</small><strong>{_pickup_text(card)}</strong></span></div>
                            <div><Icon name="clock" /><span><small>Timing</small><strong>{when_text(card)}</strong></span></div>
                            <div><Icon name="star" /><span><small>Rating</small><strong>{rating_text(other)}</strong></span></div>
                        </div>
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
                        {"Continue conversation" if card.has_conversation else "Message " + card.other_handle}
                        <Icon name="chat" />
                    </button>
                    <button className="btn btn-secondary full-button graph-link" onClick={lambda (e: MouseEvent) { nav("/people/" + match_id); }}>
                        <Icon name="user" /> View profile
                    </button>
                    {card.status == "completed" and <button className="btn btn-secondary full-button graph-link" onClick={lambda (e: MouseEvent) { nav("/rate/" + match_id); }}>
                        <Icon name="star" /> Leave a review
                    </button>}
                    <button className="decline-link" onClick={decline} disabled={declining}>{"Removing…" if declining else "Remove match"}</button>
                    <div className="safe-note">
                        <Icon name="lock" />
                        <span>Your full name, exact address, and contact details are never shared without permission.</span>
                    </div>
                </aside>
            </div>
            <div className="mobile-cta">
                <button className="btn btn-primary full-button" onClick={lambda (e: MouseEvent) { nav("/chat/" + match_id); }}>
                    {"Continue conversation" if card.has_conversation else "Message " + card.other_handle} <Icon name="chat" />
                </button>
            </div>
        </main>
    </div>;
}

def _pickup_text(card: MatchCardView) -> str {
    if card.pickup_gap_miles < 0 {
        return "Near your start";
    }
    if card.pickup_gap_miles < 1 {
        return "Under a mile away";
    }
    return f"{card.pickup_gap_miles:.1f} mi from your start";
}

def _preference_chips(t: TripView | None) -> list[str] {
    if t is None {
        return [];
    }
    ages = "Any age" if t.age_min <= 1 and t.age_max >= 100 else ("Ages " + str(t.age_min) + "–" + (str(t.age_max) if t.age_max < 100 else "100+"));
    genders = "Anyone" if len(t.gender_prefs) == 0 else _gender_list(t.gender_prefs);
    chips = [ages, "Travels with: " + genders];
    chips = chips + (["Smoking OK"] if t.smoking else ["Non-smoking"]);
    if t.mode == "rental" {
        chips = chips + ["Vehicle: " + (t.vehicle or "Flexible")];
        if t.needs_driver {
            chips = chips + ["Needs someone to drive"];
        }
        if t.moving_help {
            chips = chips + ["Moving: " + (t.space_needed or "needs cargo space")];
        }
        if t.return_date {
            chips = chips + ["Returns " + fmt_date(t.return_date)];
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

def _gender_list(prefs: list[str]) -> str {
    names = {"woman": "Women", "man": "Men", "non-binary": "Non-binary"};
    out = "";
    for g in prefs {
        out = out + (", " if out else "") + names.get(g, g);
    }
    return out;
}
