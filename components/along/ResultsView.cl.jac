"""ResultsView — Figma step 2: ranked matches beside the map.

/results?tripId=<id>  runs the graph matcher for that journey (loading state
                      while the walkers work, empty state if nobody fits).
/matches              lists every match you already have, across journeys.
"""

import from "@jac/runtime" { useNavigate, useLocation }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from .MapCanvas { MapCanvas }
import from ...lib.along {
    flow_info, flow_of_trip, short_place, initials, rating_text, has_rating,
    when_text, meta_text, trip_timing
}
sv import from ...services.along { run_matching, get_match_results, get_my_trip, TripView, MatchCardView }

# Keyed on the URL so /results?tripId=… and /matches never share stale state.
def:pub ResultsRoute() -> JsxElement {
    location: any = useLocation();
    url: str = ((location.pathname or "") as str) + ((location.search or "") as str);
    return <ResultsView key={url} />;
}

def:pub ResultsView() -> JsxElement {
    location = useLocation();
    params: any = new(URLSearchParams, location.search);  # jac:ignore[E1032,E1053]
    trip_id: str = (params.get("tripId") or "") as str;

    has cards: list[MatchCardView] = [],
        my_trip: TripView | None = None,
        status: str = "loading",
        selected: int = 0,
        view: str = "list",
        sort_by: str = "fit",
        min_score: int = 0,
        filters_open: bool = False;

    nav = useNavigate();

    async can with entry {
        # Declared up front: branch-local names don't survive the if/else in JS.
        found: list[MatchCardView] = [];
        try {
            if trip_id {
                my_trip = await get_my_trip(trip_id);
                found = await run_matching(trip_id);
            } else {
                found = await get_match_results();
            }
            cards = found;
            status = "ready" if len(found) > 0 else "empty";
        } except Exception as e {
            status = "error";
        }
    }

    shown = _sorted(cards, sort_by);
    shown = [c for c in shown if c.overall_score >= min_score];
    sel = selected if selected < len(shown) else 0;
    focus = shown[sel] if len(shown) > 0 else None;
    route_trip = my_trip if my_trip is not None else (focus.my_trip if focus is not None else None);
    kind = flow_of_trip(route_trip);
    info = flow_info(kind);
    title = info["result_title"] if trip_id else "Your matches";

    def open_details(match_id: str) { nav("/matches/" + match_id); }
    def open_chat(match_id: str) { nav("/chat/" + match_id); }
    def pick(i: int) { selected = i; }
    def set_filter(score: int) {
        min_score = score;
        selected = 0;
        filters_open = False;
    }

    subtitle = "";
    if status == "loading" {
        subtitle = "Finding the best route overlaps…";
    } elif status == "error" {
        subtitle = "Something went wrong while matching.";
    } elif len(shown) == 0 {
        subtitle = "Try expanding your distance or timing.";
    } else {
        subtitle = (str(len(shown)) + (" promising match" if len(shown) == 1 else " promising matches"))
            + " · Sorted by " + ("route fit" if sort_by == "fit" else "time");
    }

    return <div className="app-shell">
        <AppHeader progress={True} />
        <main className="results-page">
            <div className="results-toolbar">
                <button className="back-link" onClick={lambda (e: MouseEvent) { nav("/journey/" + kind); }}>
                    <Icon name="back" /> {"Change journey" if trip_id else "New journey"}
                </button>
                {if route_trip is not None {
                    <div key="summary" className="route-summary">
                        <span><i /><i /></span>
                        <div>
                            <small>{info["eyebrow"] if trip_id else "Selected match"}</small>
                            <strong>{short_place(route_trip.origin_name)} <Icon name="arrow" size={15} /> {short_place(route_trip.destination_name)}</strong>
                            <em>{trip_timing(route_trip)}</em>
                        </div>
                    </div>
                }}
                <div className="toolbar-buttons">
                    <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { filters_open = not filters_open; }}>
                        Filters {min_score > 0 and <b>1</b>}
                        <Icon name="tune" />
                    </button>
                    {if filters_open {
                        <div key="menu" className="filter-menu" role="menu">
                            <small>Minimum match</small>
                            <button className={"active" if min_score == 0 else ""} onClick={lambda (e: MouseEvent) { set_filter(0); }}>All matches</button>
                            <button className={"active" if min_score == 70 else ""} onClick={lambda (e: MouseEvent) { set_filter(70); }}>Good fit or better</button>
                            <button className={"active" if min_score == 85 else ""} onClick={lambda (e: MouseEvent) { set_filter(85); }}>Excellent fit only</button>
                        </div>
                    }}
                </div>
            </div>
            <div className="mobile-view-toggle">
                <button className={"active" if view == "list" else ""} onClick={lambda (e: MouseEvent) { view = "list"; }}><Icon name="list" /> List</button>
                <button className={"active" if view == "map" else ""} onClick={lambda (e: MouseEvent) { view = "map"; }}><Icon name="map" /> Map</button>
            </div>
            <div className="split-view">
                <section className={"results-list" + (" mobile-hidden" if view == "map" else "")}>
                    <div className="list-header">
                        <div>
                            <span className="step-kicker">{"Step 2 of 2" if trip_id else "All journeys"}</span>
                            <h1>{title}</h1>
                            <p>{subtitle}</p>
                        </div>
                        <button className="sort-button" onClick={lambda (e: MouseEvent) { sort_by = "time" if sort_by == "fit" else "fit"; selected = 0; }}>
                            {"Best fit" if sort_by == "fit" else "Earliest"} <Icon name="chevron" />
                        </button>
                    </div>
                    {if status == "loading" {
                        <div key="loading" className="loading-state">
                            <span className="spinner" />
                            <h3>Looking along your route</h3>
                            <p>Comparing timing, pickup distance, and preferences.</p>
                            <div className="skeleton" />
                            <div className="skeleton short" />
                        </div>
                    } elif len(shown) == 0 {
                        <div key="empty" className="empty-state">
                            <span><Icon name="map" size={30} /></span>
                            <h3>{"Couldn’t load matches" if status == "error" else "No close matches yet"}</h3>
                            <p>{"Please try again in a moment." if status == "error" else "Widen your pickup distance or adjust timing to see more people."}</p>
                            {if min_score > 0 {
                                <button key="clear" className="btn btn-primary" onClick={lambda (e: MouseEvent) { set_filter(0); }}>Show all matches</button>
                            } else {
                                <button key="edit" className="btn btn-primary" onClick={lambda (e: MouseEvent) { nav("/journey/" + kind); }}>Expand search</button>
                            }}
                        </div>
                    } else {
                        <div key="cards" className="cards">
                            {for (i, c) in enumerate(shown) {
                                <ResultCard
                                    key={c.id} card={c} selected={sel == i}
                                    onSelect={lambda { pick(i); }}
                                    onDetails={open_details} onMessage={open_chat}
                                />
                            }}
                        </div>
                    }}
                </section>
                <section className={"map-panel" + (" mobile-hidden-map" if view == "list" else "")}>
                    <MapCanvas my_trip={route_trip} cards={shown} selected={sel} onSelect={pick} kind={kind} />
                </section>
            </div>
        </main>
    </div>;
}

def _by_departure(c: MatchCardView) -> str {
    return c.other_trip.departure_time if c.other_trip is not None else "99:99";
}

def _by_score(c: MatchCardView) -> int {
    return c.overall_score;
}

def _sorted(cards: list[MatchCardView], sort_by: str) -> list[MatchCardView] {
    if sort_by == "time" {
        return sorted(cards, key=_by_departure);
    }
    return sorted(cards, key=_by_score, reverse=True);
}

def:pub ResultCard(
    card: MatchCardView, selected: bool, onSelect: Callable[[], None],
    onDetails: Callable[[str], None], onMessage: Callable[[str], None]
) -> JsxElement {
    other = card.other_trip;
    mine = card.my_trip;

    def select(e: MouseEvent) { onSelect(); }
    def details(e: MouseEvent) {
        e.stopPropagation();
        onDetails(card.id);
    }
    def message(e: MouseEvent) {
        e.stopPropagation();
        onMessage(card.id);
    }

    return <article className={"result-card" + (" selected" if selected else "")} onClick={select}>
        <div className="result-top">
            <span className="avatar">{initials(card.other_handle)}</span>
            <div>
                <h3>{card.other_handle}</h3>
                <span className={"rating" if has_rating(other) else "new-user"}>
                    {has_rating(other) and <Icon name="star" size={14} />}
                    {rating_text(other)}
                </span>
            </div>
            <span className="fit-badge">{card.fit_label}</span>
        </div>
        <div className="result-route">
            <span><i /><i /></span>
            <div>
                <b>{other.origin_name if other is not None else ""}</b>
                <small>{meta_text(card)}</small>
                <b>{other.destination_name if other is not None else ""}</b>
            </div>
        </div>
        <div className="result-time">
            <Icon name="clock" />
            <strong>{when_text(card)}</strong>
            <span className="score-pill">{str(card.overall_score) + "% match"}</span>
        </div>
        <p className="why"><strong>Why it matches</strong>{card.why}</p>
        <div className="card-actions">
            {card.status == "connected" and <span className="status-note"><Icon name="chat" size={14} /> In conversation</span>}
            <button className="btn btn-secondary" onClick={details}>View details</button>
            <button className="btn btn-primary" onClick={message}>Message <Icon name="chat" /></button>
        </div>
    </article>;
}
