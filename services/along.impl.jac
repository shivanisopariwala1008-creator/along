"""Deterministic matching engine + demo seeding for ALONG.

Every score below is computed from coordinates, times and preferences —
never guessed by the LLM. f"explain_match" is the ONLY place an LLM runs,
and it only narrates numbers this file already produced.
"""

import math;
import random;
import datetime;
import os;
import json;
import from urllib.request { Request, urlopen }
import from urllib.parse { urlencode }
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
    # Only two recurring commutes can disagree on their weekly schedule.
    if rider.recurring and driver.recurring
        and rider.recurrence_days.strip().lower() != driver.recurrence_days.strip().lower() {
        score -= 15.0;
    }
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
    user = User(
        handle_number=random.randint(100, 999), completed_connections=0, trust_score=80,
        member_since=datetime.datetime.now().strftime("%B %Y")
    );
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
        verified=me.verified, phone=me.phone, member_since=me.member_since,
        # Only whether feedback exists — never your own score (Figma: "Your view").
        has_ratings=_rating_summary(_my_root_id())[1] > 0,
        completed_connections=me.completed_connections
    );
}

impl get_my_profile() -> ProfileView {
    return _profile_view(_me());
}

impl update_profile_details(display_name: str, home_region: str, phone: str) -> ProfileView {
    me = _me();
    me.display_name = display_name.strip()[:60];
    me.home_region = home_region.strip()[:60];
    me.phone = phone.strip()[:30];
    return _profile_view(me);
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

# Demo people for each Figma flow. Seeded per handle, so re-running only fills gaps.
glob DEMO_PEOPLE: list[dict] = [
    # Drivers heading toward Ann Arbor ("Find a ride")
    {"handle": "MapleDriver", "name": "Marcus", "role": "DRIVER", "mode": "ride", "from": "Flint, MI",
     "to": "Ann Arbor, MI", "dep": "07:40", "arr": "09:05", "seats": 2, "rating": 4.9, "reviews": 28,
     "note": "Drive this route every weekday, happy to pick up on the way."},
    {"handle": "NorthStar22", "name": "Nadia", "role": "DRIVER", "mode": "ride", "from": "Fenton, MI",
     "to": "Ann Arbor, MI", "dep": "08:05", "arr": "09:00", "seats": 3, "rating": 4.8, "reviews": 16,
     "note": "Leaving from Fenton Rd, quiet ride preferred."},
    {"handle": "MorningMiles", "name": "Theo", "role": "DRIVER", "mode": "ride", "from": "Holly, MI",
     "to": "Ann Arbor, MI", "dep": "08:20", "arr": "09:15", "seats": 1, "rating": 0.0, "reviews": 0,
     "note": "New to Along, flexible by 20 minutes."},
    # Riders looking for a lift ("Find a buddy")
    {"handle": "GardenRider", "name": "Priya", "role": "RIDER", "mode": "ride", "from": "Grand Blanc, MI",
     "to": "Ann Arbor, MI", "dep": "07:35", "arr": "09:15", "seats": 0, "rating": 4.9, "reviews": 11,
     "note": "Need to be at the office by 9:15."},
    {"handle": "CampusBound", "name": "Devon", "role": "RIDER", "mode": "ride", "from": "Fenton, MI",
     "to": "Ann Arbor, MI", "dep": "07:20", "arr": "08:30", "seats": 0, "rating": 4.7, "reviews": 8,
     "note": "Heading to campus, two of us."},
    {"handle": "EarlyRobin", "name": "Sam", "role": "RIDER", "mode": "ride", "from": "Holly, MI",
     "to": "Ann Arbor, MI", "dep": "07:50", "arr": "09:00", "seats": 0, "rating": 0.0, "reviews": 0,
     "note": "Flexible by 20 minutes."},
    {"handle": "LakeLooper", "name": "Jordan", "role": "RIDER", "mode": "ride", "from": "Howell, MI",
     "to": "Ann Arbor, MI", "dep": "07:15", "arr": "08:50", "seats": 0, "rating": 4.6, "reviews": 5,
     "note": "Looking for a regular carpool."},
    {"handle": "YpsiCommuter", "name": "Casey", "role": "RIDER", "mode": "ride", "from": "Ypsilanti, MI",
     "to": "Detroit, MI", "dep": "07:45", "arr": "09:00", "seats": 0, "rating": 4.8, "reviews": 9,
     "note": "Looking for a regular carpool."},
    # Rental partners ("Rent together")
    {"handle": "MovingNorth", "name": "Alexis", "role": "PEER", "mode": "rental", "from": "Novi, MI",
     "to": "Detroit, MI", "dep": "09:00", "arr": "", "seats": 0, "people": 2, "vehicle": "Pickup",
     "moving": True, "rating": 4.8, "reviews": 6, "note": "Also moving and needs cargo room."},
    {"handle": "WeekendWay", "name": "Riley", "role": "PEER", "mode": "rental", "from": "Farmington Hills, MI",
     "to": "Detroit, MI", "dep": "10:00", "arr": "", "seats": 0, "people": 1, "vehicle": "SUV",
     "moving": False, "rating": 4.9, "reviews": 14, "note": "Weekend trip, flexible dates."},
    {"handle": "LakeTrip", "name": "Morgan", "role": "PEER", "mode": "rental", "from": "Livonia, MI",
     "to": "Detroit, MI", "dep": "13:00", "arr": "", "seats": 0, "people": 2, "vehicle": "Minivan",
     "moving": False, "rating": 0.0, "reviews": 0, "note": "Flexible timing."},
    # Cab sharers ("Share a cab")
    {"handle": "WindowSeat", "name": "Jamie", "role": "PEER", "mode": "cab", "from": "Detroit Metro Airport",
     "to": "Downtown Detroit", "dep": "18:10", "arr": "", "seats": 0, "people": 1, "rating": 4.9,
     "reviews": 21, "note": "Landing at McNamara Terminal."},
    {"handle": "CityLight", "name": "Avery", "role": "PEER", "mode": "cab", "from": "Detroit Metro Airport",
     "to": "Midtown Detroit", "dep": "18:30", "arr": "", "seats": 0, "people": 2, "rating": 4.7,
     "reviews": 9, "note": "Evans Terminal pickup."},
    {"handle": "CarryOnOnly", "name": "Quinn", "role": "PEER", "mode": "cab", "from": "Romulus, MI",
     "to": "Downtown Detroit", "dep": "18:15", "arr": "", "seats": 0, "people": 1, "rating": 0.0,
     "reviews": 0, "note": "Airport hotel, carry-on only."},
];

impl seed_demo_network() -> str {
    present = set([t.owner_handle for t in _public_trips() if t.is_demo]);
    added = 0;
    for p in DEMO_PEOPLE {
        handle = p["handle"] as str;
        if handle in present {
            continue;
        }
        mode = p["mode"] as str;
        origin = _town_coords(p["from"] as str);
        dest = _town_coords(p["to"] as str);
        trip = _make_trip(
            handle, "demo", p["role"] as str, p["from"] as str, origin[0], origin[1],
            p["to"] as str, dest[0], dest[1], p["dep"] as str, p["arr"] as str,
            mode == "ride", "Mon-Fri" if mode == "ride" else "", 20, p["seats"] as int,
            10 if p["role"] == "DRIVER" else 0, False, False, True, "moderate",
            p["note"] as str, 20.0 if p["role"] == "RIDER" else 10.0, True, p["name"] as str
        );
        trip.mode = mode;
        trip.people = (p["people"] as int) if "people" in p else 1;
        trip.vehicle = (p["vehicle"] as str) if "vehicle" in p else "";
        trip.moving_help = (p["moving"] as bool) if "moving" in p else False;
        trip.demo_rating = p["rating"] as float;
        trip.demo_reviews = p["reviews"] as int;
        added += 1;
    }
    if added == 0 {
        return "Demo network already loaded.";
    }
    return f"Michigan demo network loaded: {added} travelers across rides, rentals and cab shares.";
}

glob TOWNS: dict[str, list[float]] = {
    "grand blanc": [42.9269, -83.6410], "flint": [43.0125, -83.6875],
    "ann arbor": [42.2808, -83.7430], "fenton": [42.7970, -83.7052],
    "howell": [42.6072, -83.9294], "novi": [42.4806, -83.4755],
    "brighton": [42.5284, -83.7796], "ypsilanti": [42.2411, -83.6130],
    "canton": [42.3086, -83.4820], "detroit": [42.3314, -83.0458],
    "holly": [42.7917, -83.6277], "livonia": [42.3684, -83.3527],
    "farmington hills": [42.4990, -83.3677], "romulus": [42.2223, -83.3966],
    "detroit metro airport": [42.2162, -83.3554], "dtw": [42.2162, -83.3554],
    "airport": [42.2162, -83.3554], "downtown detroit": [42.3314, -83.0458],
    "midtown detroit": [42.3569, -83.0663], "dearborn": [42.3223, -83.1763],
    "troy": [42.6064, -83.1498], "royal oak": [42.4895, -83.1446],
    "southfield": [42.4734, -83.2219], "pontiac": [42.6389, -83.2910],
    "auburn hills": [42.6875, -83.2341], "clarkston": [42.7359, -83.4189],
    "lansing": [42.7325, -84.5555], "east lansing": [42.7370, -84.4839],
    "grand rapids": [42.9634, -85.6681], "kalamazoo": [42.2917, -85.5872],
    "saginaw": [43.4195, -83.9508],
};

def _town_key_length(k: str) -> int {
    return len(k);
}

# Longest known place name contained in the input wins, so "Detroit Metro
# Airport" resolves to the airport rather than downtown Detroit.
def _town_coords(name: str) -> list[float] {
    lowered = name.strip().lower();
    for key in sorted(TOWNS.keys(), key=_town_key_length, reverse=True) {
        if key in lowered {
            return TOWNS[key];
        }
    }
    found = _geocode(name);
    if found is not None {
        return found;
    }
    return [42.7325, -84.5555];   # Michigan centroid fallback for unrecognized towns
}

# ---------------------------------------------------------------------------
# Google Maps — geocoding unknown places and real road routes. Everything
# degrades to the built-in town table / straight lines when no key is set.
# ---------------------------------------------------------------------------

glob _GEOCODE_CACHE: dict[str, list[float]] = {},
     _ROUTE_CACHE: dict[str, RouteView] = {};

def _maps_key() -> str {
    return os.environ.get("GOOGLE_MAPS_API_KEY", "").strip();
}

def _http_json(url: str, body: dict | None, headers: dict[str, str]) -> dict | None {
    data = json.dumps(body).encode("utf-8") if body is not None else None;
    req = Request(url, data=data, headers=headers, method="POST" if body is not None else "GET");
    try {
        with urlopen(req, timeout=8) as resp {
            return json.loads(resp.read().decode("utf-8"));
        }
    } except Exception as e {
        print(f"[maps] request failed: {e}");
        return None;
    }
}

# Place name -> [lat, lng], biased to Michigan. None when unavailable.
def _geocode(name: str) -> list[float] | None {
    key = _maps_key();
    clean = name.strip();
    if not key or not clean {
        return None;
    }
    if clean.lower() in _GEOCODE_CACHE {
        return _GEOCODE_CACHE[clean.lower()];
    }
    query = urlencode({
        "address": clean, "components": "administrative_area:MI|country:US", "key": key
    });
    result = _http_json("https://maps.googleapis.com/maps/api/geocode/json?" + query, None, {});
    if result is None or result.get("status") != "OK" or not result.get("results") {
        return None;
    }
    loc = result["results"][0]["geometry"]["location"];
    coords: list[float] = [float(loc["lat"]), float(loc["lng"])];
    _GEOCODE_CACHE[clean.lower()] = coords;
    return coords;
}

def _straight_route(t: Trip) -> RouteView {
    km = _haversine_km(t.origin_lat, t.origin_lng, t.destination_lat, t.destination_lng);
    return RouteView(
        points=[[t.origin_lat, t.origin_lng], [t.destination_lat, t.destination_lng]],
        distance_km=float(f"{km:.1f}"), duration_min=int(km * 0.9) + 10, source="straight"
    );
}

# Driving route from the Routes API, thinned to at most ~250 points.
def _google_route(t: Trip) -> RouteView | None {
    key = _maps_key();
    if not key {
        return None;
    }
    body = {
        "origin": {"location": {"latLng": {"latitude": t.origin_lat, "longitude": t.origin_lng}}},
        "destination": {"location": {"latLng": {"latitude": t.destination_lat, "longitude": t.destination_lng}}},
        "travelMode": "DRIVE",
        "polylineEncoding": "GEO_JSON_LINESTRING"
    };
    headers = {
        "Content-Type": "application/json", "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": "routes.duration,routes.distanceMeters,routes.polyline.geoJsonLinestring"
    };
    result = _http_json("https://routes.googleapis.com/directions/v2:computeRoutes", body, headers);
    if result is None or not result.get("routes") {
        return None;
    }
    route = result["routes"][0];
    coords = route["polyline"]["geoJsonLinestring"]["coordinates"];
    step = max(1, len(coords) // 250);
    points: list[list[float]] = [[float(c[1]), float(c[0])] for c in coords[::step]];
    last = coords[-1];
    if points[-1] != [float(last[1]), float(last[0])] {
        points.append([float(last[1]), float(last[0])]);
    }
    seconds = int(str(route.get("duration", "0s")).rstrip("s") or "0");
    return RouteView(
        points=points, distance_km=float(f"{route.get('distanceMeters', 0) / 1000:.1f}"),
        duration_min=seconds // 60, source="google"
    );
}

impl get_maps_config() -> MapsConfigView {
    browser_key = os.environ.get("GOOGLE_MAPS_BROWSER_KEY", "").strip() or _maps_key();
    return MapsConfigView(
        api_key=browser_key,
        map_id=os.environ.get("GOOGLE_MAPS_MAP_ID", "").strip() or "DEMO_MAP_ID"
    );
}

impl get_trip_route(trip_id: str) -> RouteView {
    loaded = _load_trip(trip_id);
    if loaded is None {
        return RouteView();
    }
    t = loaded as Trip;
    cache_key = f"{t.origin_lat:.4f},{t.origin_lng:.4f}>{t.destination_lat:.4f},{t.destination_lng:.4f}";
    if cache_key in _ROUTE_CACHE {
        return _ROUTE_CACHE[cache_key];
    }
    if t.route_json {
        try {
            saved = json.loads(t.route_json);
            view = RouteView(
                points=saved["points"] as list[list[float]],
                distance_km=saved["distance_km"] as float,
                duration_min=saved["duration_min"] as int, source="google"
            );
            _ROUTE_CACHE[cache_key] = view;
            return view;
        } except Exception {
            print("[maps] ignoring unreadable cached route");
        }
    }
    fetched = _google_route(t);
    if fetched is None {
        return _straight_route(t);   # not cached, so a key added later takes effect
    }
    route = fetched as RouteView;
    _ROUTE_CACHE[cache_key] = route;
    if t.owner_root == _my_root_id() {
        # Only the owner may write the trip; others just use the in-process cache.
        t.route_json = json.dumps({
            "points": route.points, "distance_km": route.distance_km, "duration_min": route.duration_min
        });
    }
    return route;
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

def _hhmm_shift(hhmm: str, minutes: int) -> str {
    total = (_minutes_of_day(hhmm) + minutes) % (24 * 60);
    return f"{total // 60:02d}:{total % 60:02d}";
}

impl create_journey(
    mode: str, role: str, origin_name: str, destination_name: str, travel_date: str,
    time_preference: str, time: str, recurring: bool, flexible_minutes: int,
    seats_available: int, people: int, max_detour_minutes: int, pickup_distance: str,
    vehicle: str, moving_help: bool, age_pref: str, gender_pref: str, notes: str,
    origin_lat: float = 0.0, origin_lng: float = 0.0,
    destination_lat: float = 0.0, destination_lng: float = 0.0,
    round_trip: bool = False
) -> str {
    me = _me();
    clean_mode = mode if mode in ["ride", "rental", "cab"] else "ride";
    clean_role = ("DRIVER" if role == "DRIVER" else "RIDER") if clean_mode == "ride" else "PEER";
    origin_coords = [origin_lat, origin_lng] if (origin_lat and origin_lng) else _town_coords(origin_name);
    dest_coords = [destination_lat, destination_lng] if (destination_lat and destination_lng) else _town_coords(destination_name);

    # Scoring compares departures, so derive one from an arrive-by time.
    km = _haversine_km(origin_coords[0], origin_coords[1], dest_coords[0], dest_coords[1]);
    drive_minutes = int(km * 0.9) + 10;
    arrive_by = time_preference == "arrive_by";
    departure = _hhmm_shift(time, -drive_minutes) if arrive_by else time;
    deadline = time if arrive_by else _hhmm_shift(time, drive_minutes);

    handle = _handle_for(me, clean_role if clean_role != "PEER" else "RIDER");
    trip = _make_trip(
        handle, _my_root_id(), clean_role,
        origin_name.strip()[:80], origin_coords[0], origin_coords[1],
        destination_name.strip()[:80], dest_coords[0], dest_coords[1],
        departure, deadline, recurring, "Mon-Fri" if recurring else travel_date.strip()[:40],
        flexible_minutes, seats_available if clean_role == "DRIVER" else 0,
        max_detour_minutes if clean_role == "DRIVER" else 0,
        False, False, True, "moderate", notes.strip()[:500],
        20.0 if clean_role == "RIDER" else 8.0, False, ""
    );
    trip.mode = clean_mode;
    trip.travel_date = travel_date.strip()[:40];
    trip.time_preference = "arrive_by" if arrive_by else "depart_at";
    trip.people = people if people > 0 else 1;
    trip.vehicle = vehicle.strip()[:30] if clean_mode == "rental" else "";
    trip.moving_help = moving_help if clean_mode == "rental" else False;
    trip.pickup_distance = pickup_distance.strip()[:30];
    trip.age_pref = age_pref.strip()[:30] or "No preference";
    trip.gender_pref = gender_pref.strip()[:30] or "No preference";
    trip.round_trip = round_trip;
    me +>:Posts:+> trip;

    # Make sure there is always someone to match with in the demo.
    seed_demo_network();
    return jid(trip);
}

impl get_my_trips() -> list[TripView] {
    return [_trip_view(t) for t in [_me() ->:Posts:->][?:Trip] if t.active];
}

impl get_my_trip(trip_id: str) -> TripView | None {
    t = _load_trip(trip_id);
    if t is None or (t as Trip).owner_root != _my_root_id() {
        return None;
    }
    return _trip_view(t as Trip);
}

# ---------------------------------------------------------------------------
# Matching — candidates come from root.shared; each Match is opened to both sides
# ---------------------------------------------------------------------------

# Ratings are keyed by root id; demo users (who share the "demo" root) by handle.
def _ratee_key(owner_root: str, owner_handle: str) -> str {
    return "demo:" + owner_handle if owner_root == "demo" else owner_root;
}

# (average, count) across seeded reputation plus real anonymous ratings.
def _rating_summary(key: str, base_rating: float = 0.0, base_reviews: int = 0) -> tuple[float, int] {
    total = base_rating * base_reviews;
    count = base_reviews;
    for r in [root.shared-->][?:Rating] {
        if r.ratee_key == key {
            total += r.stars;
            count += 1;
        }
    }
    if count == 0 {
        return (0.0, 0);
    }
    return (round(total / count, 1), count);
}

def _trip_view(t: Trip) -> TripView {
    rating = _rating_summary(_ratee_key(t.owner_root, t.owner_handle), t.demo_rating, t.demo_reviews);
    return TripView(
        id=jid(t), role=t.role, origin_name=t.origin_name, destination_name=t.destination_name,
        departure_time=t.departure_time, arrival_deadline=t.arrival_deadline,
        recurrence_days=t.recurrence_days, seats_available=t.seats_available,
        max_detour_minutes=t.max_detour_minutes, flexible_minutes=t.flexible_minutes,
        suggested_cost_share=t.suggested_cost_share, notes=t.notes, owner_handle=t.owner_handle,
        mode=t.mode, travel_date=t.travel_date, time_preference=t.time_preference,
        people=t.people, vehicle=t.vehicle, moving_help=t.moving_help,
        pickup_distance=t.pickup_distance, age_pref=t.age_pref, gender_pref=t.gender_pref,
        recurring=t.recurring, smoking=_preference_of(t).smoking,
        origin_lat=t.origin_lat, origin_lng=t.origin_lng,
        destination_lat=t.destination_lat, destination_lng=t.destination_lng,
        owner_rating=rating[0], owner_reviews=rating[1], round_trip=t.round_trip
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

def _fit_label(m: Match) -> str {
    if m.mode == "cab" {
        return f"{m.route_score}% journey overlap";
    }
    if m.overall_score >= 85 {
        return "Excellent route fit" if m.mode == "ride" else "Great timing match";
    }
    if m.overall_score >= 70 {
        return "Good route fit" if m.mode == "ride" else "Good area match";
    }
    return "Possible match";
}

# One deterministic sentence for the "Why it matches" box — no LLM involved.
def _why_text(m: Match, mine: Trip | None, other: Trip | None) -> str {
    if mine is None or other is None {
        return f"{m.route_score}% route overlap with a {m.detour_minutes}-minute detour.";
    }
    me_t = mine as Trip;
    ot = other as Trip;
    gap = m.pickup_gap_miles;
    near = "close to" if gap >= 0 and gap < 4 else ("a short hop from" if gap >= 0 and gap < 12 else "within reach of");
    if m.mode == "ride" and ot.role == "DRIVER" {
        return f"Their {ot.origin_name.split(',')[0]} → {ot.destination_name.split(',')[0]} route passes {near} {me_t.origin_name.split(',')[0]}, adding about {m.detour_minutes} min.";
    }
    if m.mode == "ride" {
        return f"Their pickup area in {ot.origin_name.split(',')[0]} is {near} your route, about a {m.detour_minutes}-minute detour.";
    }
    if m.mode == "rental" {
        extra = " and needs cargo room" if ot.moving_help else "";
        vehicle = f" ({ot.vehicle})" if ot.vehicle else "";
        return f"Also heading from {ot.origin_name.split(',')[0]} toward {ot.destination_name.split(',')[0]}{vehicle}{extra}.";
    }
    return f"Similar timing and a destination near {ot.destination_name.split(',')[0]}; their start is {near} yours.";
}

def _match_to_card(m: Match) -> MatchCardView {
    rider_trip = _load_trip(m.rider_trip_id);
    driver_trip = _load_trip(m.driver_trip_id);
    i_am_rider = m.rider_root == _my_root_id();
    mine = rider_trip if i_am_rider else driver_trip;
    other = driver_trip if i_am_rider else rider_trip;
    return MatchCardView(
        id=jid(m), overall_score=m.overall_score, route_score=m.route_score, time_score=m.time_score,
        detour_minutes=m.detour_minutes, preference_score=m.preference_score,
        cost_benefit_score=m.cost_benefit_score, estimated_rider_savings=m.estimated_rider_savings,
        status=m.status,
        driver_trip=_trip_view(driver_trip) if driver_trip is not None else None,
        rider_trip=_trip_view(rider_trip) if rider_trip is not None else None,
        my_trip=_trip_view(mine) if mine is not None else None,
        other_trip=_trip_view(other) if other is not None else None,
        mode=m.mode, fit_label=_fit_label(m), why=_why_text(m, mine, other),
        other_handle=m.driver_handle if i_am_rider else m.rider_handle,
        has_conversation=_find_conversation(m) is not None
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
    # Rides pair opposite roles; rentals and cabs pair peers of the same mode.
    is_peer = o.role == "PEER";
    wanted_role = "PEER" if is_peer else ("DRIVER" if o.role == "RIDER" else "RIDER");

    existing: dict[str, Match] = {};
    for m in _my_matches() {
        existing[m.rider_trip_id + ":" + m.driver_trip_id] = m;
    }

    # A. CandidateDiscovery: active, opposite-role trips from other users.
    candidates = [
        t for t in _public_trips()
        if t.active and t.role == wanted_role and t.mode == o.mode
        and jid(t) != trip_id and t.owner_root != me
    ];

    results: list[MatchCardView] = [];
    for c in candidates {
        # For peers the searcher sits on the "rider" side of the Match.
        rider_trip = o if (o.role == "RIDER" or is_peer) else c;
        driver_trip = c if (o.role == "RIDER" or is_peer) else o;
        key = jid(rider_trip) + ":" + jid(driver_trip);
        if key in existing {
            if existing[key].status != "closed" {
                results.append(_match_to_card(existing[key]));
            }
            continue;
        }

        # B-E. Route overlap, time, preference and cost scoring
        route = _route_overlap(rider_trip, driver_trip);
        time_score = _time_compat(rider_trip, driver_trip);
        pref_score = _preference_compat(_preference_of(rider_trip), _preference_of(driver_trip));
        cost = _cost_benefit(rider_trip, driver_trip, route["origin_gap"] as float, route["dest_gap"] as float);
        # G. MatchScoring
        overall = _score_match(route["overlap"] as int, route["detour"] as int, time_score, pref_score, cost["score"] as int);

        gap_miles: float = (route["origin_gap"] as float) * 0.621371;
        m = Match(
            overall_score=overall, route_score=route["overlap"] as int, time_score=time_score,
            detour_minutes=route["detour"] as int, preference_score=pref_score,
            cost_benefit_score=cost["score"] as int, estimated_rider_savings=cost["rider_savings"] as float,
            estimated_driver_contribution=cost["driver_contribution"] as float, status="suggested",
            rider_handle=rider_trip.owner_handle, driver_handle=driver_trip.owner_handle,
            rider_trip_id=jid(rider_trip), driver_trip_id=jid(driver_trip),
            rider_root=rider_trip.owner_root, driver_root=driver_trip.owner_root,
            created_at=_now(), mode=o.mode,
            pickup_gap_miles=float(f"{gap_miles:.1f}")
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
    return _sort_cards([_match_to_card(m) for m in _my_matches() if m.status != "closed"]);
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
    # The LLM stack (byllm/litellm) costs ~150 MB of RAM, so it is only
    # imported when a key is configured; otherwise use the template below.
    has_key = bool(os.environ.get("OPENAI_API_KEY", "").strip());
    try {
        if not has_key {
            raise RuntimeError("no LLM key configured");
        }
        import from services.narrate { narrate_match }
        text = narrate_match(
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
        messages=views, other_display_name=identity[0], other_verified=identity[1],
        other_phone=_other_phone(m, convo), match_status=m.status, mode=m.mode,
        i_rated=m.rider_rated if role == "RIDER" else m.driver_rated
    );
}

# Contact details the other person saved — only after a mutual reveal.
def _other_phone(m: Match, convo: Conversation) -> str {
    if not convo.identity_revealed or _is_demo_match(m) {
        return "";
    }
    other_profile_id = convo.driver_profile_id if _my_role(m) == "RIDER" else convo.rider_profile_id;
    try {
        prof = jobj(other_profile_id);
    } except Exception {
        return "";
    }
    return (prof as User).phone if isinstance(prof, User) else "";
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

# ---------------------------------------------------------------------------
# Figma flows — conversations inbox, decline, complete, anonymous rating
# ---------------------------------------------------------------------------

def _summary_time(s: ConversationSummaryView) -> str {
    return s.last_time;
}

impl get_my_conversations() -> list[ConversationSummaryView] {
    out: list[ConversationSummaryView] = [];
    for m in _my_matches() {
        convo = _find_conversation(m);
        if convo is None {
            continue;
        }
        c = convo as Conversation;
        view = _convo_view(m, c);
        last = c.messages[-1] if len(c.messages) > 0 else {"body": "", "ts": c.created_at};
        out.append(ConversationSummaryView(
            match_id=jid(m), other_handle=view.other_handle,
            other_display_name=view.other_display_name,
            last_message=last["body"] or "Conversation started",
            last_time=last["ts"], status=c.status, match_status=m.status, mode=m.mode
        ));
    }
    return sorted(out, key=_summary_time, reverse=True);
}

impl close_match(match_id: str) -> bool {
    m = _find_match(match_id);
    if m is None {
        return False;
    }
    (m as Match).status = "closed";
    return True;
}

impl complete_match(match_id: str) -> bool {
    m = _find_match(match_id);
    if m is None {
        return False;
    }
    mt = m as Match;
    if mt.status != "completed" {
        mt.status = "completed";
        me = _me();
        me.completed_connections += 1;
        rec = _impact_record();
        rec.connections_created += 1;
    }
    return True;
}

impl rate_match(match_id: str, stars: int, comment: str, tags: list[str] = []) -> bool {
    m = _find_match(match_id);
    if m is None or stars < 1 or stars > 5 {
        return False;
    }
    mt = m as Match;
    role = _my_role(mt);
    already = mt.rider_rated if role == "RIDER" else mt.driver_rated;
    if already {
        return False;
    }
    other_handle = mt.driver_handle if role == "RIDER" else mt.rider_handle;
    clean_tags = [t for t in tags if t in REVIEW_TAGS][:6];
    rating = Rating(
        ratee_key=_ratee_key(_other_root(mt), other_handle), stars=stars,
        comment=comment.strip()[:1000], created_at=_now(), tags=clean_tags,
        rated_on=datetime.datetime.now().strftime("%b %Y"), mode=mt.mode
    );
    root.shared ++> rating;
    grant(rating, level=ReadPerm);
    if role == "RIDER" {
        mt.rider_rated = True;
    } else {
        mt.driver_rated = True;
    }
    return True;
}

# ---------------------------------------------------------------------------
# Traveler profiles + reviews
# ---------------------------------------------------------------------------

glob REVIEW_TAGS: list[str] = [
    "On time", "Friendly", "Safe driving", "Clean car", "Great communication",
    "Flexible", "Respectful", "Easy pickup"
];

# Demo travelers' seeded reputation comes with a few sample reviews to show.
glob DEMO_REVIEWS: dict[str, list[dict]] = {
    "MapleDriver": [
        {"stars": 5, "comment": "Always right on time at the Grand Blanc lot.", "tags": ["On time", "Easy pickup"], "rated_on": "Aug 2026", "mode": "ride"},
        {"stars": 5, "comment": "Calm, careful driver — my favorite commute.", "tags": ["Safe driving", "Friendly"], "rated_on": "Jul 2026", "mode": "ride"},
        {"stars": 4, "comment": "", "tags": ["Clean car"], "rated_on": "Jul 2026", "mode": "ride"},
    ],
    "NorthStar22": [
        {"stars": 5, "comment": "Quiet ride, exactly what I wanted before work.", "tags": ["Respectful", "On time"], "rated_on": "Aug 2026", "mode": "ride"},
        {"stars": 4, "comment": "Great driver, a few minutes late once.", "tags": ["Safe driving"], "rated_on": "Jun 2026", "mode": "ride"},
    ],
    "GardenRider": [
        {"stars": 5, "comment": "Ready at the pickup spot every morning.", "tags": ["On time", "Great communication"], "rated_on": "Aug 2026", "mode": "ride"},
    ],
    "CampusBound": [
        {"stars": 5, "comment": "", "tags": ["Friendly", "Respectful"], "rated_on": "Aug 2026", "mode": "ride"},
    ],
    "LakeLooper": [{"stars": 4, "comment": "Nice company on the drive.", "tags": ["Friendly"], "rated_on": "Jul 2026", "mode": "ride"}],
    "YpsiCommuter": [{"stars": 5, "comment": "Super easy to coordinate with.", "tags": ["Great communication"], "rated_on": "Aug 2026", "mode": "ride"}],
    "MovingNorth": [{"stars": 5, "comment": "Helped load the truck, split was fair.", "tags": ["Flexible", "Friendly"], "rated_on": "Aug 2026", "mode": "rental"}],
    "WeekendWay": [
        {"stars": 5, "comment": "Returned the SUV spotless and on time.", "tags": ["On time", "Respectful"], "rated_on": "Aug 2026", "mode": "rental"},
        {"stars": 5, "comment": "", "tags": ["Great communication"], "rated_on": "Jun 2026", "mode": "rental"},
    ],
    "WindowSeat": [
        {"stars": 5, "comment": "Found each other at baggage claim in minutes.", "tags": ["Easy pickup", "Great communication"], "rated_on": "Aug 2026", "mode": "cab"},
        {"stars": 5, "comment": "", "tags": ["Friendly"], "rated_on": "Jul 2026", "mode": "cab"},
    ],
    "CityLight": [{"stars": 4, "comment": "Good cab share, small wait at the curb.", "tags": ["Flexible"], "rated_on": "Jul 2026", "mode": "cab"}],
};

def _tag_count(pair: list) -> int {
    return pair[1] as int;
}

def _mode_label(mode: str, role: str) -> str {
    if mode == "rental" {
        return "Rent together";
    }
    if mode == "cab" {
        return "Share a cab";
    }
    return "Offers rides" if role == "DRIVER" else "Needs rides";
}

impl get_traveler_profile(match_id: str) -> TravelerProfileView | None {
    m = _find_match(match_id);
    if m is None {
        return None;
    }
    mt = m as Match;
    role = _my_role(mt);
    other_root = _other_root(mt);
    handle = mt.driver_handle if role == "RIDER" else mt.rider_handle;
    other_trip_id = mt.driver_trip_id if role == "RIDER" else mt.rider_trip_id;
    loaded = _load_trip(other_trip_id);
    is_demo = other_root == "demo";
    key = _ratee_key(other_root, handle);

    # Reviews: real anonymous ratings, plus seeded samples for demo travelers.
    reviews: list[ReviewView] = [];
    total = 0.0;
    count = 0;
    for r in [root.shared-->][?:Rating] {
        if r.ratee_key == key {
            reviews.append(ReviewView(stars=r.stars, comment=r.comment, tags=r.tags, rated_on=r.rated_on, mode=r.mode));
            total += r.stars;
            count += 1;
        }
    }
    if is_demo and loaded is not None {
        t = loaded as Trip;
        for d in DEMO_REVIEWS.get(t.owner_handle, []) {
            reviews.append(ReviewView(
                stars=d["stars"] as int, comment=d["comment"] as str, tags=d["tags"] as list[str],
                rated_on=d["rated_on"] as str, mode=d["mode"] as str
            ));
        }
        total += t.demo_rating * t.demo_reviews;
        count += t.demo_reviews;
    }
    tag_counts: dict[str, int] = {};
    for rv in reviews {
        for tg in rv.tags {
            tag_counts[tg] = tag_counts.get(tg, 0) + 1;
        }
    }
    top: list[str] = [p[0] as str for p in sorted([[k, v] for (k, v) in tag_counts.items()], key=_tag_count, reverse=True)][:4];

    # Their public journeys (trips are visible to every logged-in user anyway).
    theirs = [t for t in _public_trips() if t.owner_root == other_root and t.active and (not is_demo or t.owner_handle == handle)];
    kinds = sorted(list(set([_mode_label(t.mode, t.role) for t in theirs])));

    convo = _find_conversation(mt);
    revealed = convo is not None and (convo as Conversation).identity_revealed;
    view = TravelerProfileView(
        match_id=jid(mt), handle=handle, revealed=revealed,
        rating=float(f"{(total / count) if count else 0.0:.1f}"), review_count=count,
        is_new=count == 0, top_tags=top, reviews=reviews[::-1][:12] if not is_demo else reviews[:12],
        journeys_posted=len(theirs), journey_types=kinds, is_demo=is_demo,
        can_review=mt.status == "completed",
        already_reviewed=mt.rider_rated if role == "RIDER" else mt.driver_rated
    );
    if revealed {
        c = convo as Conversation;
        name_verified = _other_identity(mt, c);
        view.display_name = name_verified[0] as str;
        view.verified = name_verified[1] as bool;
        if not is_demo {
            other_profile_id = c.driver_profile_id if role == "RIDER" else c.rider_profile_id;
            try {
                prof = jobj(other_profile_id);
                if isinstance(prof, User) {
                    view.home_region = (prof as User).home_region;
                    view.member_since = (prof as User).member_since;
                }
            } except Exception {
                print("[profile] other traveler's profile not shared yet");
            }
        }
    }
    return view;
}
