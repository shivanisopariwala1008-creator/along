"""Deterministic matching engine + demo seeding for ALONG.

Every score below is computed from coordinates, times and preferences —
never guessed by the LLM. f"explain_match" is the ONLY place an LLM runs,
and it only narrates numbers this file already produced.
"""

import math;
import random;
import datetime;
import from uuid { UUID }
import from jaclang { JacRuntime as Jac }

# ---------------------------------------------------------------------------
# Deterministic helpers — CandidateDiscovery / RouteOverlap / Time / Pref / Cost
# ---------------------------------------------------------------------------

def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float {
    r = 6371.0;
    p1 = math.radians(lat1);
    p2 = math.radians(lat2);
    dphi = math.radians(lat2 - lat1);
    dlambda = math.radians(lng2 - lng1);
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2;
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

def _minutes_of_day(hhmm: str) -> int {
    clean = hhmm.strip();
    if not clean or ":" not in clean {
        return 0;
    }
    parts = clean.split(":");
    try {
        return int(parts[0]) * 60 + int(parts[1]);
    } except ValueError {
        return 0;
    }
}

def _route_overlap(rider: Trip, driver: Trip) -> dict {
    origin_gap = _haversine_km(rider.origin_lat, rider.origin_lng, driver.origin_lat, driver.origin_lng);
    dest_gap = _haversine_km(rider.destination_lat, rider.destination_lng, driver.destination_lat, driver.destination_lng);
    overlap = 100.0 - (origin_gap * 1.6) - (dest_gap * 6.0);
    if overlap < 5.0 { overlap = 5.0; }
    if overlap > 99.0 { overlap = 99.0; }
    detour = int(round(origin_gap * 1.4)) + 2;
    if detour < 3 { detour = 3; }
    return {"overlap": int(round(overlap)), "detour": detour, "origin_gap": origin_gap, "dest_gap": dest_gap};
}

def _time_compat(rider: Trip, driver: Trip) -> int {
    rider_dep = _minutes_of_day(rider.departure_time);
    driver_dep = _minutes_of_day(driver.departure_time);
    diff = abs(rider_dep - driver_dep);
    window = rider.flexible_minutes + driver.flexible_minutes + 5;
    if window <= 0 { window = 20; }
    score = 100.0 - (float(diff) / float(window)) * 60.0;
    same_days = 1 if rider.recurrence_days.strip().lower() == driver.recurrence_days.strip().lower() else 0;
    if not same_days { score -= 15.0; }
    if score < 10.0 { score = 10.0; }
    if score > 100.0 { score = 100.0; }
    return int(round(score));
}

def _preference_compat(rider_pref: Preference, driver_pref: Preference) -> int {
    score = 100;
    if rider_pref.smoking != driver_pref.smoking { score -= 40; }
    if rider_pref.quiet_ride and driver_pref.conversation_level == "chatty" { score -= 15; }
    if rider_pref.accessibility and not driver_pref.accessibility { score -= 10; }
    if score < 0 { score = 0; }
    return score;
}

def _cost_benefit(rider: Trip, driver: Trip, origin_gap: float, dest_gap: float) -> dict {
    trip_km = _haversine_km(driver.origin_lat, driver.origin_lng, driver.destination_lat, driver.destination_lng) + origin_gap;
    trip_miles = trip_km * 0.621371;
    baseline_rideshare = 1.85 * trip_miles + 6.0;      # rough private-rideshare baseline, labeled estimate
    driver_contribution: float = round(trip_miles * 0.35 + 3.0, 2);
    rider_savings: float = round(baseline_rideshare - driver_contribution, 2);
    if rider_savings < 5.0 { rider_savings = 5.0; }
    recurrence_multiplier: float = 5.0 if rider.recurring else 1.0;
    weekly: float = round(rider_savings * recurrence_multiplier, 2);
    cost_score = 60;
    if weekly > 25 { cost_score = 80; }
    if weekly > 45 { cost_score = 95; }
    return {"rider_savings": weekly, "driver_contribution": driver_contribution, "score": cost_score};
}

def _score_match(route_overlap: int, detour: int, time_score: int, pref_score: int, cost_score: int) -> int {
    detour_score = 100 - (detour * 5);
    if detour_score < 0 { detour_score = 0; }
    overall = (route_overlap * 0.35) + (time_score * 0.25) + (detour_score * 0.15) + (pref_score * 0.15) + (cost_score * 0.10);
    if overall > 99 { overall = 99; }
    return int(round(overall));
}


# ---------------------------------------------------------------------------
# Identity + sharing helpers
# ---------------------------------------------------------------------------

def _my_root_id() -> str {
    return jid(root);
}

# The caller's profile node, created on first use.
def _me() -> User {
    for u in [root-->][?:User] {
        return u;
    }
    user = User(handle_number=random.randint(100, 999), completed_connections=0, trust_score=80);
    root ++> user;
    return user;
}

def _handle_for(me: User, role: str) -> str {
    return ("Driver " if role == "DRIVER" else "Rider ") + str(me.handle_number);
}

def _now() -> str {
    return datetime.datetime.now().strftime("%H:%M");
}

# Open one node to one other user. No-op for demo users and for yourself.
def _share_with(target: any, other_root: str, level: any) -> None {
    if other_root and other_root != "demo" and other_root != _my_root_id() {
        Jac.allow_root(target, UUID(other_root), level);  # jac:ignore[E1053]
    }
}

def _profile_view(me: User) -> ProfileView {
    return ProfileView(
        display_name=me.display_name, home_region=me.home_region,
        rider_handle=_handle_for(me, "RIDER"), driver_handle=_handle_for(me, "DRIVER"),
        verified=me.verified
    );
}

impl get_my_profile() -> ProfileView {
    return _profile_view(_me());
}

impl update_profile(display_name: str, home_region: str) -> ProfileView {
    me = _me();
    me.display_name = display_name.strip()[:60];
    me.home_region = home_region.strip()[:60];
    return _profile_view(me);
}

# ---------------------------------------------------------------------------
# Trips — posted into root.shared so every logged-in user's matching sees them
# ---------------------------------------------------------------------------

def _public_trips() -> list[Trip] {
    return [root.shared-->][?:Trip];
}

def _make_trip(
    owner_handle: str, owner_root: str, role: str, origin_name: str, olat: float, olng: float,
    destination_name: str, dlat: float, dlng: float, departure_time: str,
    arrival_deadline: str, recurring: bool, recurrence_days: str,
    flexible_minutes: int, seats_available: int, max_detour_minutes: int,
    smoking: bool, quiet_ride: bool, pets: bool, conversation_level: str, notes: str,
    cost_share: float, is_demo: bool, demo_name: str
) -> Trip {
    trip = Trip(
        trip_type="commute" if recurring else "one_time", role=role,
        origin_name=origin_name, origin_lat=olat, origin_lng=olng,
        destination_name=destination_name, destination_lat=dlat, destination_lng=dlng,
        departure_time=departure_time, arrival_deadline=arrival_deadline, recurring=recurring,
        recurrence_days=recurrence_days, seats_available=seats_available, flexible_minutes=flexible_minutes,
        max_detour_minutes=max_detour_minutes, suggested_cost_share=cost_share, active=True,
        luggage="light", notes=notes, owner_handle=owner_handle, owner_root=owner_root,
        is_demo=is_demo, demo_name=demo_name
    );
    root.shared ++> trip;
    grant(trip, level=ReadPerm);
    pref = Preference(
        smoking=smoking, conversation_level=conversation_level, pets=pets,
        accessibility=False, quiet_ride=quiet_ride, luggage="light"
    );
    trip +>:HasPreference:+> pref;
    grant(pref, level=ReadPerm);
    return trip;
}

impl seed_demo_network() -> str {
    for t in _public_trips() {
        if t.is_demo {
            return "Demo network already loaded.";
        }
    }

    _make_trip(
        "Rider 184", "demo", "RIDER", "Grand Blanc, MI", 42.9269, -83.6410, "Ann Arbor, MI", 42.2808, -83.7430,
        "07:35", "09:00", True, "Mon-Fri", 20, 0, 0, False, False, True, "moderate",
        "Need to be at the office by 9am, flexible either way.", 40.0, True, "Priya"
    );
    _make_trip(
        "Driver 072", "demo", "DRIVER", "Flint, MI", 43.0125, -83.6875, "Ann Arbor, MI", 42.2808, -83.7430,
        "07:40", "09:10", True, "Mon-Fri", 10, 2, 10, False, False, True, "moderate",
        "Drive this route every weekday, happy to pick up on the way.", 10.0, True, "Marcus"
    );

    weaker = [
        {"handle": "Rider 233", "name": "Devon", "city": "Fenton, MI", "lat": 42.7970, "lng": -83.7052,
         "dest": "Ann Arbor, MI", "dlat": 42.2808, "dlng": -83.7430, "dep": "07:20", "arr": "09:00"},
        {"handle": "Rider 067", "name": "Sam", "city": "Howell, MI", "lat": 42.6072, "lng": -83.9294,
         "dest": "Ann Arbor, MI", "dlat": 42.2808, "dlng": -83.7430, "dep": "07:15", "arr": "08:50"},
        {"handle": "Rider 145", "name": "Jordan", "city": "Novi, MI", "lat": 42.4806, "lng": -83.4755,
         "dest": "Ann Arbor, MI", "dlat": 42.2808, "dlng": -83.7430, "dep": "07:50", "arr": "08:45"},
        {"handle": "Rider 298", "name": "Alexis", "city": "Brighton, MI", "lat": 42.5284, "lng": -83.7796,
         "dest": "Detroit, MI", "dlat": 42.3314, "dlng": -83.0458, "dep": "07:10", "arr": "08:40"},
        {"handle": "Rider 312", "name": "Casey", "city": "Ypsilanti, MI", "lat": 42.2411, "lng": -83.6130,
         "dest": "Detroit, MI", "dlat": 42.3314, "dlng": -83.0458, "dep": "07:45", "arr": "09:00"},
        {"handle": "Rider 401", "name": "Riley", "city": "Canton, MI", "lat": 42.3086, "lng": -83.4820,
         "dest": "Ann Arbor, MI", "dlat": 42.2808, "dlng": -83.7430, "dep": "08:05", "arr": "08:55"},
    ];
    for w in weaker {
        _make_trip(
            w["handle"] as str, "demo", "RIDER", w["city"] as str, w["lat"] as float, w["lng"] as float,
            w["dest"] as str, w["dlat"] as float, w["dlng"] as float,
            w["dep"] as str, w["arr"] as str, True, "Mon-Fri", 15, 0, 0, False, False, True,
            "moderate", "Looking for a regular carpool.", 30.0, True, w["name"] as str
        );
    }

    return "Michigan demo network loaded: 8 riders/drivers across Grand Blanc, Flint, Fenton, Howell, Novi, Brighton, Ypsilanti and Canton.";
}

def _town_coords(name: str) -> list[float] {
    key = name.strip().lower().split(",")[0];
    table = {
        "grand blanc": [42.9269, -83.6410], "flint": [43.0125, -83.6875],
        "ann arbor": [42.2808, -83.7430], "fenton": [42.7970, -83.7052],
        "howell": [42.6072, -83.9294], "novi": [42.4806, -83.4755],
        "brighton": [42.5284, -83.7796], "ypsilanti": [42.2411, -83.6130],
        "canton": [42.3086, -83.4820], "detroit": [42.3314, -83.0458],
    };
    if key in table {
        return table[key];
    }
    return [42.7325, -84.5555];   # Michigan centroid fallback for unrecognized towns
}

impl create_trip(
    role: str, origin_name: str, destination_name: str, departure_time: str,
    arrival_deadline: str, recurring: bool, recurrence_days: str,
    flexible_minutes: int, seats_available: int, max_detour_minutes: int,
    smoking: bool, quiet_ride: bool, pets: bool, notes: str
) -> str {
    me = _me();
    clean_role = "DRIVER" if role == "DRIVER" else "RIDER";
    origin_coords = _town_coords(origin_name);
    dest_coords = _town_coords(destination_name);

    trip = _make_trip(
        _handle_for(me, clean_role), _my_root_id(), clean_role,
        origin_name, origin_coords[0], origin_coords[1],
        destination_name, dest_coords[0], dest_coords[1],
        departure_time, arrival_deadline, recurring, recurrence_days, flexible_minutes,
        seats_available, max_detour_minutes, smoking, quiet_ride, pets, "moderate", notes,
        20.0 if clean_role == "RIDER" else 8.0, False, ""
    );
    me +>:Posts:+> trip;
    return jid(trip);
}

# ---------------------------------------------------------------------------
# Matching — candidates come from root.shared; each Match is opened to both sides
# ---------------------------------------------------------------------------

def _trip_view(t: Trip) -> TripView {
    return TripView(
        id=jid(t), role=t.role, origin_name=t.origin_name, destination_name=t.destination_name,
        departure_time=t.departure_time, arrival_deadline=t.arrival_deadline,
        recurrence_days=t.recurrence_days, seats_available=t.seats_available,
        max_detour_minutes=t.max_detour_minutes, flexible_minutes=t.flexible_minutes,
        suggested_cost_share=t.suggested_cost_share, notes=t.notes, owner_handle=t.owner_handle
    );
}

def _preference_of(t: Trip) -> Preference {
    prefs = [t ->:HasPreference:->][?:Preference];
    if len(prefs) > 0 {
        return prefs[0];
    }
    return Preference();
}

def _load_trip(trip_id: str) -> Trip | None {
    if not trip_id {
        return None;
    }
    try {
        obj_ = jobj(trip_id);
    } except Exception {
        return None;
    }
    if isinstance(obj_, Trip) {
        return obj_ as Trip;
    }
    return None;
}

def _is_participant(m: Match) -> bool {
    me = _my_root_id();
    return m.rider_root == me or m.driver_root == me;
}

def _my_matches() -> list[Match] {
    return [m for m in [root.shared-->][?:Match] if _is_participant(m)];
}

# Resolve a match id — only if the caller is one of its two participants.
def _find_match(match_id: str) -> Match | None {
    try {
        obj_ = jobj(match_id);
    } except Exception {
        return None;
    }
    if isinstance(obj_, Match) and _is_participant(obj_ as Match) {
        return obj_ as Match;
    }
    return None;
}

def _match_to_card(m: Match) -> MatchCardView {
    rider_trip = _load_trip(m.rider_trip_id);
    driver_trip = _load_trip(m.driver_trip_id);
    return MatchCardView(
        id=jid(m), overall_score=m.overall_score, route_score=m.route_score, time_score=m.time_score,
        detour_minutes=m.detour_minutes, preference_score=m.preference_score,
        cost_benefit_score=m.cost_benefit_score, estimated_rider_savings=m.estimated_rider_savings,
        status=m.status,
        driver_trip=_trip_view(driver_trip) if driver_trip is not None else None,
        rider_trip=_trip_view(rider_trip) if rider_trip is not None else None
    );
}

def _card_score(c: MatchCardView) -> int {
    return c.overall_score;
}

def _sort_cards(cards: list[MatchCardView]) -> list[MatchCardView] {
    return sorted(cards, key=_card_score, reverse=True);
}

def _impact_record() -> ImpactRecord {
    for rec in [root.shared-->][?:ImpactRecord] {
        return rec;
    }
    rec = ImpactRecord();
    root.shared ++> rec;
    grant(rec, level=WritePerm);
    return rec;
}

impl run_matching(trip_id: str) -> list[MatchCardView] {
    origin = _load_trip(trip_id);
    me = _my_root_id();
    if origin is None or (origin as Trip).owner_root != me {
        return [];   # you can only run matching for your own trip
    }
    o = origin as Trip;
    opposite_role = "DRIVER" if o.role == "RIDER" else "RIDER";

    existing: dict[str, Match] = {};
    for m in _my_matches() {
        existing[m.rider_trip_id + ":" + m.driver_trip_id] = m;
    }

    # A. CandidateDiscovery: active, opposite-role trips from other users.
    candidates = [
        t for t in _public_trips()
        if t.active and t.role == opposite_role and jid(t) != trip_id and t.owner_root != me
    ];

    results: list[MatchCardView] = [];
    for c in candidates {
        rider_trip = o if o.role == "RIDER" else c;
        driver_trip = c if o.role == "RIDER" else o;
        key = jid(rider_trip) + ":" + jid(driver_trip);
        if key in existing {
            results.append(_match_to_card(existing[key]));
            continue;
        }

        # B-E. Route overlap, time, preference and cost scoring
        route = _route_overlap(rider_trip, driver_trip);
        time_score = _time_compat(rider_trip, driver_trip);
        pref_score = _preference_compat(_preference_of(rider_trip), _preference_of(driver_trip));
        cost = _cost_benefit(rider_trip, driver_trip, route["origin_gap"] as float, route["dest_gap"] as float);
        # G. MatchScoring
        overall = _score_match(route["overlap"] as int, route["detour"] as int, time_score, pref_score, cost["score"] as int);

        m = Match(
            overall_score=overall, route_score=route["overlap"] as int, time_score=time_score,
            detour_minutes=route["detour"] as int, preference_score=pref_score,
            cost_benefit_score=cost["score"] as int, estimated_rider_savings=cost["rider_savings"] as float,
            estimated_driver_contribution=cost["driver_contribution"] as float, status="suggested",
            rider_handle=rider_trip.owner_handle, driver_handle=driver_trip.owner_handle,
            rider_trip_id=jid(rider_trip), driver_trip_id=jid(driver_trip),
            rider_root=rider_trip.owner_root, driver_root=driver_trip.owner_root,
            created_at=_now()
        );
        root.shared ++> m;
        _share_with(m, c.owner_root, WritePerm);

        rec = _impact_record();
        rec.trips_matched += 1;
        rec.estimated_savings += m.estimated_rider_savings;
        rec.estimated_shared_miles += 38.5;

        results.append(_match_to_card(m));
    }

    return _sort_cards(results);
}

impl get_match_results() -> list[MatchCardView] {
    return _sort_cards([_match_to_card(m) for m in _my_matches()]);
}

impl get_match_details(match_id: str) -> MatchDetailView | None {
    m = _find_match(match_id);
    if m is None {
        return None;
    }
    mt = m as Match;
    return MatchDetailView(card=_match_to_card(mt), explanation=mt.explanation);
}

impl explain_match(match_id: str) -> str {
    m = _find_match(match_id);
    if m is None {
        return "Match not found.";
    }
    mt = m as Match;
    if mt.explanation.strip() {
        return mt.explanation;
    }
    try {
        text = _narrate_match(
            mt.route_score, mt.time_score, mt.detour_minutes, mt.preference_score,
            mt.cost_benefit_score, mt.overall_score, mt.rider_handle, mt.driver_handle,
            mt.estimated_rider_savings
        );
    } except Exception {
        # No LLM configured (e.g. OPENAI_API_KEY unset) — fall back to a template.
        return (
            f"{mt.rider_handle} and {mt.driver_handle} share {mt.route_score}% of their route "
            f"with a {mt.detour_minutes}-minute detour and {mt.time_score}% schedule fit, "
            f"saving {mt.rider_handle} about ${mt.estimated_rider_savings:.0f} a week."
        );
    }
    mt.explanation = text;
    return text;
}

def _narrate_match(
    route_score: int, time_score: int, detour_minutes: int, preference_score: int,
    cost_benefit_score: int, overall_score: int, rider_handle: str, driver_handle: str,
    estimated_weekly_savings: float
) -> str by explain_llm();
sem _narrate_match = "Write ONE short, warm, human-friendly paragraph (2-3 sentences) explaining why these two anonymous commuters are a good rideshare match. Use ONLY the numbers given — never invent a route detail, address, or statistic not passed in. Refer to them only by their anonymous handles, never assume real names.";
sem _narrate_match.route_score = "Percent overlap between the two commute routes (0-100).";
sem _narrate_match.time_score = "Schedule compatibility score (0-100).";
sem _narrate_match.detour_minutes = "Extra minutes the driver detours to pick up the rider.";
sem _narrate_match.preference_score = "Ride preference compatibility score (0-100).";
sem _narrate_match.cost_benefit_score = "Cost-benefit score (0-100).";
sem _narrate_match.overall_score = "Final weighted match score (0-100).";
sem _narrate_match.rider_handle = "The rider's anonymous handle.";
sem _narrate_match.driver_handle = "The driver's anonymous handle.";
sem _narrate_match.estimated_weekly_savings = "Estimated weekly savings for the rider in US dollars, already computed.";

impl get_match_graph(match_id: str) -> GraphView | None {
    m = _find_match(match_id);
    if m is None {
        return None;
    }
    mt = m as Match;
    rider_trip = _load_trip(mt.rider_trip_id);
    driver_trip = _load_trip(mt.driver_trip_id);
    if rider_trip is None or driver_trip is None {
        return None;
    }
    rt = rider_trip as Trip;
    dt = driver_trip as Trip;

    nodes = [
        GraphNodeView(id="rider", label=mt.rider_handle, kind="user"),
        GraphNodeView(id="rider_origin", label=rt.origin_name, kind="location"),
        GraphNodeView(id="corridor", label="Shared corridor", kind="route"),
        GraphNodeView(id="driver_origin", label=dt.origin_name, kind="location"),
        GraphNodeView(id="driver", label=mt.driver_handle, kind="user"),
        GraphNodeView(id="destination", label=rt.destination_name, kind="location"),
        GraphNodeView(id="schedule", label=rt.recurrence_days, kind="time"),
        GraphNodeView(id="time_node", label=dt.departure_time, kind="time"),
        GraphNodeView(id="match_node", label=str(mt.overall_score) + "% Match", kind="match"),
    ];
    edges = [
        GraphEdgeView(source="rider", target="rider_origin", label="NEEDS_RIDE"),
        GraphEdgeView(source="rider_origin", target="corridor", label="NEAR_CORRIDOR"),
        GraphEdgeView(source="driver_origin", target="corridor", label="SHARES_CORRIDOR"),
        GraphEdgeView(source="driver", target="driver_origin", label="DRIVES_FROM"),
        GraphEdgeView(source="corridor", target="destination", label="TRAVELS_TO"),
        GraphEdgeView(source="driver", target="schedule", label="COMPATIBLE_TIME"),
        GraphEdgeView(source="rider", target="time_node", label="COMPATIBLE_PREFERENCE"),
        GraphEdgeView(source="destination", target="match_node", label="MATCHED_WITH"),
    ];
    return GraphView(nodes=nodes, edges=edges);
}

# ---------------------------------------------------------------------------
# Safety / Privacy — anonymous chat between the two participants + mutual reveal
# ---------------------------------------------------------------------------

def _my_role(m: Match) -> str {
    return "RIDER" if m.rider_root == _my_root_id() else "DRIVER";
}

def _other_root(m: Match) -> str {
    return m.driver_root if _my_role(m) == "RIDER" else m.rider_root;
}

def _is_demo_match(m: Match) -> bool {
    return _other_root(m) == "demo";
}

def _add_message(convo: Conversation, handle: str, sender_root: str, body: str, ts: str) -> None {
    # Rebind (not append) so the field change is detected and persisted.
    convo.messages = convo.messages + [{"handle": handle, "root": sender_root, "body": body, "ts": ts}];
}

# Only demo matches get a scripted opening — real matches start empty.
def _seed_demo_chat(convo: Conversation, m: Match) -> None {
    me = _my_root_id();
    demo_handle = m.driver_handle if _my_role(m) == "RIDER" else m.rider_handle;
    my_handle = m.rider_handle if _my_role(m) == "RIDER" else m.driver_handle;
    _add_message(convo, demo_handle, "demo", "Hi! I saw we have a similar route. Would arriving before 9 work for you?", "07:41");
    _add_message(convo, my_handle, me, "Yes, that works. I need to reach my destination by 9.", "07:42");
    _add_message(convo, demo_handle, "demo", "I can make a small pickup detour. It should add about " + str(m.detour_minutes) + " minutes.", "07:43");
}

def _find_conversation(m: Match) -> Conversation | None {
    for c in [m ->:Opens:->][?:Conversation] {
        return c;
    }
    return None;
}

# Display name + verified flag of the other side — only once revealed.
def _other_identity(m: Match, convo: Conversation) -> tuple[str, bool] {
    if not convo.identity_revealed {
        return ("", False);
    }
    if _is_demo_match(m) {
        other_trip_id = m.driver_trip_id if _my_role(m) == "RIDER" else m.rider_trip_id;
        other_trip = _load_trip(other_trip_id);
        return ((other_trip as Trip).demo_name if other_trip is not None else "", False);
    }
    other_profile_id = convo.driver_profile_id if _my_role(m) == "RIDER" else convo.rider_profile_id;
    try {
        prof = jobj(other_profile_id);
    } except Exception {
        return ("", False);
    }
    if isinstance(prof, User) {
        return ((prof as User).display_name, (prof as User).verified);
    }
    return ("", False);
}

def _convo_view(m: Match, convo: Conversation) -> ConversationView {
    me = _my_root_id();
    role = _my_role(m);
    views = [
        MessageView(
            sender_anonymous_handle=x["handle"], body=x["body"],
            timestamp=x["ts"], mine=x["root"] == me
        ) for x in convo.messages
    ];
    identity = _other_identity(m, convo);
    return ConversationView(
        match_id=jid(m), status=convo.status, identity_revealed=convo.identity_revealed,
        my_role=role,
        my_handle=m.rider_handle if role == "RIDER" else m.driver_handle,
        other_handle=m.driver_handle if role == "RIDER" else m.rider_handle,
        me_approved=convo.rider_approved if role == "RIDER" else convo.driver_approved,
        other_approved=convo.driver_approved if role == "RIDER" else convo.rider_approved,
        messages=views, other_display_name=identity[0], other_verified=identity[1]
    );
}

impl create_anonymous_connection(match_id: str) -> ConversationView | None {
    m = _find_match(match_id);
    if m is None {
        return None;
    }
    mt = m as Match;
    existing = _find_conversation(mt);
    if existing is not None {
        return _convo_view(mt, existing as Conversation);
    }
    convo = Conversation(status="anonymous", identity_revealed=False, created_at=_now());
    mt +>:Opens:+> convo;
    _share_with(convo, _other_root(mt), WritePerm);
    if _is_demo_match(mt) {
        _seed_demo_chat(convo, mt);
    }
    mt.status = "connected";
    return _convo_view(mt, convo);
}

impl send_message(match_id: str, body: str) -> ConversationView | None {
    m = _find_match(match_id);
    if m is None {
        return None;
    }
    mt = m as Match;
    convo = _find_conversation(mt);
    if convo is None {
        return None;
    }
    clean = body.strip()[:1000];
    if clean {
        handle = mt.rider_handle if _my_role(mt) == "RIDER" else mt.driver_handle;
        _add_message(convo as Conversation, handle, _my_root_id(), clean, _now());
    }
    return _convo_view(mt, convo as Conversation);
}

impl approve_identity_reveal(match_id: str) -> ConversationView | None {
    m = _find_match(match_id);
    if m is None {
        return None;
    }
    mt = m as Match;
    convo = _find_conversation(mt);
    if convo is None {
        return None;
    }
    c = convo as Conversation;
    me = _me();
    # Approving is what shares YOUR profile with the other participant.
    _share_with(me, _other_root(mt), ReadPerm);
    if _my_role(mt) == "RIDER" {
        c.rider_approved = True;
        c.rider_profile_id = jid(me);
        if _is_demo_match(mt) { c.driver_approved = True; }
    } else {
        c.driver_approved = True;
        c.driver_profile_id = jid(me);
        if _is_demo_match(mt) { c.rider_approved = True; }
    }
    if c.rider_approved and c.driver_approved {
        c.identity_revealed = True;
        c.status = "revealed";
    } else {
        c.status = "pending_reveal";
    }
    return _convo_view(mt, c);
}

impl get_conversation(match_id: str) -> ConversationView | None {
    m = _find_match(match_id);
    if m is None {
        return None;
    }
    mt = m as Match;
    convo = _find_conversation(mt);
    if convo is None {
        return None;
    }
    return _convo_view(mt, convo as Conversation);
}

# ---------------------------------------------------------------------------
# Local Impact dashboard — public aggregate counters
# ---------------------------------------------------------------------------

impl get_impact_metrics() -> ImpactView {
    trips = _public_trips();
    matched = 0;
    savings: float = 0.0;
    miles: float = 0.0;
    for rec in [root.shared-->][?:ImpactRecord] {
        matched = rec.trips_matched;
        savings = rec.estimated_savings;
        miles = rec.estimated_shared_miles;
    }
    seats = sum([t.seats_available for t in trips if t.role == "DRIVER"]);
    cities = sorted(list(set([t.origin_name for t in trips] + [t.destination_name for t in trips])));
    return ImpactView(
        journeys_matched=matched, estimated_rider_savings=float(f"{savings:.2f}"),
        empty_seats_activated=seats, shared_miles=float(f"{miles:.1f}"),
        communities_connected=len(cities), cities=cities
    );
}
