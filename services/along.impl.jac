"""Deterministic matching engine + demo seeding for ALONG.

Every score below is computed from coordinates, times and preferences —
never guessed by the LLM. f"explain_match" is the ONLY place an LLM runs,
and it only narrates numbers this file already produced.
"""

import math;

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
# Shared-root helpers — this is a no-auth demo, so every seat lives under f"root"
# ---------------------------------------------------------------------------

def _find_user(handle: str) -> User | None {
    for u in [root-->][?:User] {
        if u.anonymous_handle == handle {
            return u;
        }
    }
    return None;
}

def _get_or_create_user(handle: str, display_name: str, verified: bool, home_region: str) -> User {
    existing = _find_user(handle);
    if existing != None {
        return existing as User;
    }
    user = User(
        anonymous_handle=handle, display_name=display_name, verified=verified,
        home_region=home_region, completed_connections=3, rating=4.8, trust_score=88
    );
    root ++> user;
    return user;
}

def _make_trip(
    owner: User, role: str, origin_name: str, olat: float, olng: float,
    destination_name: str, dlat: float, dlng: float, departure_time: str,
    arrival_deadline: str, recurring: bool, recurrence_days: str,
    flexible_minutes: int, seats_available: int, max_detour_minutes: int,
    smoking: bool, quiet_ride: bool, pets: bool, conversation_level: str, notes: str,
    cost_share: float
) -> Trip {
    trip = Trip(
        trip_type="commute", role=role, origin_name=origin_name, origin_lat=olat, origin_lng=olng,
        destination_name=destination_name, destination_lat=dlat, destination_lng=dlng,
        departure_time=departure_time, arrival_deadline=arrival_deadline, recurring=recurring,
        recurrence_days=recurrence_days, seats_available=seats_available, flexible_minutes=flexible_minutes,
        max_detour_minutes=max_detour_minutes, suggested_cost_share=cost_share, active=True,
        luggage="light", notes=notes, owner_handle=owner.anonymous_handle
    );
    owner +>:Posts:+> trip;
    root ++> trip;  # also index under root so matching/impact can find every trip
    origin_loc = trip +>:StartsAt:+> Location(name=origin_name, latitude=olat, longitude=olng, city=origin_name);
    dest_loc = trip +>:EndsAt:+> Location(name=destination_name, latitude=dlat, longitude=dlng, city=destination_name);
    trip +>:HasPreference:+> Preference(
        smoking=smoking, conversation_level=conversation_level, pets=pets,
        accessibility=False, quiet_ride=quiet_ride, luggage="light"
    );
    return trip;
}

# ---------------------------------------------------------------------------
# Demo seeding — Rider 184 / Driver 072 star match + weaker candidates
# ---------------------------------------------------------------------------

impl seed_demo_network() -> str {
    if _find_user("Rider 184") != None {
        return "Demo network already loaded.";
    }

    rider = _get_or_create_user("Rider 184", "Priya", False, "Grand Blanc, MI");
    driver = _get_or_create_user("Driver 072", "Marcus", True, "Flint, MI");

    _make_trip(
        rider, "RIDER", "Grand Blanc, MI", 42.9269, -83.6410, "Ann Arbor, MI", 42.2808, -83.7430,
        "07:35", "09:00", True, "Mon-Fri", 20, 0, 0, False, False, True, "moderate",
        "Need to be at the office by 9am, flexible either way.", 40.0
    );
    _make_trip(
        driver, "DRIVER", "Flint, MI", 43.0125, -83.6875, "Ann Arbor, MI", 42.2808, -83.7430,
        "07:40", "09:10", True, "Mon-Fri", 10, 2, 10, False, False, True, "moderate",
        "Drive this route every weekday, happy to pick up on the way.", 10.0
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
        u = _get_or_create_user(w["handle"] as str, w["name"] as str, False, w["city"] as str);
        _make_trip(
            u, "RIDER", w["city"] as str, w["lat"] as float, w["lng"] as float,
            w["dest"] as str, w["dlat"] as float, w["dlng"] as float,
            w["dep"] as str, w["arr"] as str, True, "Mon-Fri", 15, 0, 0, False, False, True,
            "moderate", "Looking for a regular carpool.", 30.0
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

# ---------------------------------------------------------------------------
# create_trip — the user's own posted trip ("You")
# ---------------------------------------------------------------------------

impl create_trip(
    role: str, origin_name: str, destination_name: str, departure_time: str,
    arrival_deadline: str, recurring: bool, recurrence_days: str,
    flexible_minutes: int, seats_available: int, max_detour_minutes: int,
    smoking: bool, quiet_ride: bool, pets: bool, notes: str
) -> str {
    you = _get_or_create_user("You", "You", False, origin_name);

    origin_coords = _town_coords(origin_name);
    dest_coords = _town_coords(destination_name);
    olat = origin_coords[0];
    olng = origin_coords[1];
    dlat = dest_coords[0];
    dlng = dest_coords[1];

    trip = _make_trip(
        you, role, origin_name, olat, olng, destination_name, dlat, dlng,
        departure_time, arrival_deadline, recurring, recurrence_days, flexible_minutes,
        seats_available, max_detour_minutes, smoking, quiet_ride, pets, "moderate", notes,
        20.0 if role == "RIDER" else 8.0
    );
    return jid(trip);
}

# ---------------------------------------------------------------------------
# Matching walker — CandidateDiscovery + all scoring walkers, combined
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

def _match_to_card(m: Match) -> MatchCardView {
    trips = [m ->:Connects:->][?:Trip];
    driver_view: TripView | None = None;
    rider_view: TripView | None = None;
    for t in trips {
        if t.role == "DRIVER" {
            driver_view = _trip_view(t);
        } else {
            rider_view = _trip_view(t);
        }
    }
    return MatchCardView(
        id=jid(m), overall_score=m.overall_score, route_score=m.route_score, time_score=m.time_score,
        detour_minutes=m.detour_minutes, preference_score=m.preference_score,
        cost_benefit_score=m.cost_benefit_score, estimated_rider_savings=m.estimated_rider_savings,
        status=m.status, driver_trip=driver_view, rider_trip=rider_view
    );
}

impl run_matching(trip_id: str) -> list[MatchCardView] {
    try {
        target = jobj(trip_id);
    } except Exception {
        return [];
    }
    if not isinstance(target, Trip) {
        return [];
    }
    origin = target as Trip;
    opposite_role = "DRIVER" if origin.role == "RIDER" else "RIDER";

    # A. CandidateDiscoveryWalker step (simplified to a direct filter for reliability
    #    in a live demo): active, opposite-role trips are the shortlist.
    candidates = [t for t in [root-->][?:Trip] if t.active and t.role == opposite_role and jid(t) != trip_id];

    rider = origin if origin.role == "RIDER" else None;
    driver = origin if origin.role == "DRIVER" else None;

    results: list[MatchCardView] = [];
    for c in candidates {
        rider_trip = rider if rider != None else c;
        driver_trip = driver if driver != None else c;

        # B. RouteOverlapWalker
        route = _route_overlap(rider_trip, driver_trip);
        # C. TimeCompatibilityWalker
        time_score = _time_compat(rider_trip, driver_trip);
        # D. PreferenceCompatibilityWalker
        pref_score = _preference_compat(_preference_of(rider_trip), _preference_of(driver_trip));
        # E. CostImpactWalker
        cost = _cost_benefit(rider_trip, driver_trip, route["origin_gap"] as float, route["dest_gap"] as float);
        # G. MatchScoringWalker
        overall = _score_match(route["overlap"] as int, route["detour"] as int, time_score, pref_score, cost["score"] as int);

        origin +>:CandidateMatch:+> c;

        m = Match(
            overall_score=overall, route_score=route["overlap"] as int, time_score=time_score,
            detour_minutes=route["detour"] as int, preference_score=pref_score,
            cost_benefit_score=cost["score"] as int, estimated_rider_savings=cost["rider_savings"] as float,
            estimated_driver_contribution=cost["driver_contribution"] as float, status="suggested",
            rider_handle=rider_trip.owner_handle, driver_handle=driver_trip.owner_handle
        );
        root ++> m;
        m +>:Connects:+> rider_trip;
        m +>:Connects:+> driver_trip;

        results.append(_match_to_card(m));
    }

    return _sort_cards(results);
}

impl get_match_results() -> list[MatchCardView] {
    matches = [root-->][?:Match];
    return _sort_cards([_match_to_card(m) for m in matches]);
}

def _card_score(c: MatchCardView) -> int {
    return c.overall_score;
}

def _sort_cards(cards: list[MatchCardView]) -> list[MatchCardView] {
    return sorted(cards, key=_card_score, reverse=True);
}

def _find_match(match_id: str) -> Match | None {
    try {
        obj_ = jobj(match_id);
    } except Exception {
        return None;
    }
    if isinstance(obj_, Match) {
        return obj_ as Match;
    }
    return None;
}

impl get_match_details(match_id: str) -> MatchDetailView | None {
    m = _find_match(match_id);
    if m == None {
        return None;
    }
    card = _match_to_card(m as Match);
    return MatchDetailView(card=card, explanation=(m as Match).explanation);
}

impl explain_match(match_id: str) -> str {
    m = _find_match(match_id);
    if m == None {
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
    if m == None {
        return None;
    }
    mt = m as Match;
    trips = [mt ->:Connects:->][?:Trip];
    rider_trip: Trip | None = None;
    driver_trip: Trip | None = None;
    for t in trips {
        if t.role == "RIDER" { rider_trip = t; } else { driver_trip = t; }
    }
    if rider_trip == None or driver_trip == None {
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
# Safety / Privacy — anonymous connection + mutual identity reveal
# ---------------------------------------------------------------------------

def _seed_chat(convo: Conversation, rider_handle: str, driver_handle: str, detour: int) -> None {
    convo +>:Contains:+> Message(
        sender_anonymous_handle=driver_handle,
        body="Hi! I saw we have a similar route. I usually leave around " + "7:40 AM. Would arriving before 9 work for you?",
        timestamp="07:41"
    );
    convo +>:Contains:+> Message(
        sender_anonymous_handle=rider_handle,
        body="Yes, that works. I need to reach my destination by 9.",
        timestamp="07:42"
    );
    convo +>:Contains:+> Message(
        sender_anonymous_handle=driver_handle,
        body="I can make a small pickup detour. It should add about " + str(detour) + " minutes.",
        timestamp="07:43"
    );
    convo +>:Contains:+> Message(
        sender_anonymous_handle=rider_handle,
        body="That sounds good. How many seats do you usually have?",
        timestamp="07:44"
    );
    convo +>:Contains:+> Message(
        sender_anonymous_handle=driver_handle,
        body="Usually two.",
        timestamp="07:45"
    );
}

def _convo_view(match_id: str, convo: Conversation, rider_handle: str, driver_handle: str) -> ConversationView {
    msgs = [convo ->:Contains:->][?:Message];
    views = [MessageView(sender_anonymous_handle=x.sender_anonymous_handle, body=x.body, timestamp=x.timestamp) for x in msgs];
    driver_name = "";
    driver_verified = False;
    if convo.identity_revealed {
        driver_user = _find_user(driver_handle);
        if driver_user != None {
            driver_name = (driver_user as User).display_name;
            driver_verified = (driver_user as User).verified;
        }
    }
    return ConversationView(
        match_id=match_id, status=convo.status, identity_revealed=convo.identity_revealed,
        rider_approved=convo.rider_approved, driver_approved=convo.driver_approved, messages=views,
        driver_display_name=driver_name, driver_verified=driver_verified, rider_display_name=""
    );
}

def _find_conversation(match_id: str) -> Conversation | None {
    m = _find_match(match_id);
    if m == None {
        return None;
    }
    convos = [(m as Match) ->:Opens:->][?:Conversation];
    if len(convos) > 0 {
        return convos[0];
    }
    return None;
}

impl create_anonymous_connection(match_id: str) -> ConversationView | None {
    m = _find_match(match_id);
    if m == None {
        return None;
    }
    mt = m as Match;
    existing = _find_conversation(match_id);
    if existing != None {
        return _convo_view(match_id, existing as Conversation, mt.rider_handle, mt.driver_handle);
    }
    convo = Conversation(status="anonymous", identity_revealed=False, created_at="now");
    mt +>:Opens:+> convo;
    _seed_chat(convo, mt.rider_handle, mt.driver_handle, mt.detour_minutes);
    mt.status = "connected";
    return _convo_view(match_id, convo, mt.rider_handle, mt.driver_handle);
}

impl send_message(match_id: str, sender_anonymous_handle: str, body: str) -> ConversationView | None {
    convo = _find_conversation(match_id);
    m = _find_match(match_id);
    if convo == None or m == None {
        return None;
    }
    clean = body.strip();
    if clean {
        (convo as Conversation) +>:Contains:+> Message(sender_anonymous_handle=sender_anonymous_handle, body=clean, timestamp="now");
    }
    mt = m as Match;
    return _convo_view(match_id, convo as Conversation, mt.rider_handle, mt.driver_handle);
}

impl approve_identity_reveal(match_id: str, approver: str) -> ConversationView | None {
    convo = _find_conversation(match_id);
    m = _find_match(match_id);
    if convo == None or m == None {
        return None;
    }
    c = convo as Conversation;
    if approver == "rider" {
        c.rider_approved = True;
    } else {
        c.driver_approved = True;
    }
    if c.rider_approved and c.driver_approved {
        c.identity_revealed = True;
        c.status = "revealed";
    } else {
        c.status = "pending_reveal";
    }
    mt = m as Match;
    return _convo_view(match_id, c, mt.rider_handle, mt.driver_handle);
}

impl get_conversation(match_id: str) -> ConversationView | None {
    convo = _find_conversation(match_id);
    m = _find_match(match_id);
    if convo == None or m == None {
        return None;
    }
    mt = m as Match;
    return _convo_view(match_id, convo as Conversation, mt.rider_handle, mt.driver_handle);
}

# ---------------------------------------------------------------------------
# Local Impact dashboard
# ---------------------------------------------------------------------------

impl get_impact_metrics() -> ImpactView {
    matches = [root-->][?:Match];
    connected = [m for m in matches if m.status != "suggested"];
    total_savings: float = 0.0;
    for m in matches {
        total_savings += m.estimated_rider_savings;
    }
    seats = sum([t.seats_available for t in [root-->][?:Trip] if t.role == "DRIVER"]);
    cities = list(set([t.origin_name for t in [root-->][?:Trip]] + [t.destination_name for t in [root-->][?:Trip]]));
    shared_miles: float = len(matches) * 38.5;
    return ImpactView(
        journeys_matched=len(matches), estimated_rider_savings=float(f"{total_savings:.2f}"),
        empty_seats_activated=seats, shared_miles=float(f"{shared_miles:.1f}"),
        communities_connected=len(cities), cities=cities
    );
}
