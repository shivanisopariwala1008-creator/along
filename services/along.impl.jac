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
     "to": "Detroit, MI", "dep": "09:00", "arr": "", "seats": 0, "people": 2, "vehicle": "Pickup truck",
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
    round_trip: bool = False, return_date: str = "", space_needed: str = ""
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
    trip.round_trip = round_trip if clean_mode != "rental" else False;
    trip.return_date = return_date.strip()[:10] if clean_mode == "rental" else "";
    trip.space_needed = space_needed.strip()[:40] if clean_mode == "rental" and moving_help else "";
    me +>:Posts:+> trip;

    # Make sure there is always someone to match with in the demo.
    seed_demo_network();
    # Tell everyone already travelling this way that a new match just appeared.
    root.shared spawn Matchmaker(trip_id=jid(trip));
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
        owner_rating=rating[0], owner_reviews=rating[1], round_trip=t.round_trip,
        return_date=t.return_date, space_needed=t.space_needed
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

glob AGENT_ORDER: list[str] = ["Route Scout", "Schedule Agent", "Trust Agent", "Cost Agent", "Coordinator"];

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
        has_conversation=_find_conversation(m) is not None,
        agent_notes=[
            AgentNoteView(agent=name, note=m.agent_notes[name])
            for name in AGENT_ORDER if name in m.agent_notes
        ]
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

# ---------------------------------------------------------------------------
# The matching agents (walkers declared in along.jac)
# ---------------------------------------------------------------------------

# Rides pair a rider with a driver; rentals/cabs pair peers, and the searcher
# sits on the "rider" side of the Match.
def _pair(me: Trip, other: Trip) -> tuple[Trip, Trip] {
    if me.role == "RIDER" or me.role == "PEER" {
        return (me, other);
    }
    return (other, me);
}

def _candidate_index(cands: list[Candidate]) -> dict[str, Candidate] {
    return {c.trip_id: c for c in cands};
}

def _origin_trip(origin_id: str) -> Trip {
    return _load_trip(origin_id) as Trip;
}

impl RouteScout.start {
    visit [here-->][?:Trip];
}

impl RouteScout.inspect {
    self.scanned += 1;
    o = _origin_trip(self.origin_id);
    wanted = "PEER" if o.role == "PEER" else ("DRIVER" if o.role == "RIDER" else "RIDER");
    if not here.active or here.role != wanted or here.mode != o.mode
        or jid(here) == self.origin_id or here.owner_root == self.my_root {
        skip;
    }
    pair = _pair(o, here);
    route = _route_overlap(pair[0], pair[1]);
    c = Candidate(
        trip_id=jid(here), handle=here.owner_handle, owner_root=here.owner_root,
        route_score=route["overlap"] as int, detour=route["detour"] as int,
        origin_gap_km=route["origin_gap"] as float, dest_gap_km=route["dest_gap"] as float
    );
    gap_mi: float = (route["origin_gap"] as float) * 0.621371;
    c.notes["Route Scout"] = f"{c.route_score}% corridor overlap · starts {gap_mi:.1f} mi from you";
    self.candidates.append(c);
}

impl ScheduleAgent.start {
    visit [jobj(c.trip_id) for c in self.candidates];
}

impl ScheduleAgent.inspect {
    c = _candidate_index(self.candidates).get(jid(here));
    if c is None {
        skip;
    }
    pair = _pair(_origin_trip(self.origin_id), here);
    c.time_score = _time_compat(pair[0], pair[1]);
    c.time_gap_min = abs(_minutes_of_day(pair[0].departure_time) - _minutes_of_day(pair[1].departure_time));
    c.notes["Schedule Agent"] = f"{c.time_score}% schedule fit · departures {c.time_gap_min} min apart";
}

impl TrustAgent.start {
    visit [jobj(c.trip_id) for c in self.candidates];
}

impl TrustAgent.inspect {
    c = _candidate_index(self.candidates).get(jid(here));
    if c is None {
        skip;
    }
    pair = _pair(_origin_trip(self.origin_id), here);
    c.preference_score = _preference_compat(_preference_of(pair[0]), _preference_of(pair[1]));
    rep = _rating_summary(_ratee_key(here.owner_root, here.owner_handle), here.demo_rating, here.demo_reviews);
    c.rating = rep[0] as float;
    c.reviews = rep[1] as int;
    # Reputation nudges the ranking a little; it never overrides a bad route.
    if c.reviews >= 3 and c.rating >= 4.7 {
        c.trust_bonus = 3;
    } elif c.reviews >= 1 and c.rating >= 4.5 {
        c.trust_bonus = 2;
    } elif c.reviews >= 1 and c.rating < 3.5 {
        c.trust_bonus = -6;
    }
    rep_text = f"★ {c.rating:.1f} from {c.reviews} review{'s' if c.reviews != 1 else ''}" if c.reviews else "New traveler, no reviews yet";
    pref_text = "preferences compatible" if c.preference_score >= 90 else "some preference differences";
    c.notes["Trust Agent"] = rep_text + " · " + pref_text;
}

impl CostAgent.start {
    visit [jobj(c.trip_id) for c in self.candidates];
}

impl CostAgent.inspect {
    c = _candidate_index(self.candidates).get(jid(here));
    if c is None {
        skip;
    }
    o = _origin_trip(self.origin_id);
    pair = _pair(o, here);
    cost = _cost_benefit(pair[0], pair[1], c.origin_gap_km, c.dest_gap_km);
    c.cost_score = cost["score"] as int;
    c.rider_savings = cost["rider_savings"] as float;
    c.driver_contribution = cost["driver_contribution"] as float;
    period = "a week" if pair[0].recurring else "per trip";
    c.notes["Cost Agent"] = f"Saves about ${c.rider_savings:.0f} {period} vs. a private rideshare";
}

def _cand_overall(c: Candidate) -> int {
    return c.overall;
}

impl Coordinator.decide {
    o = _origin_trip(self.origin_id);
    existing: dict[str, Match] = {};
    for m in _my_matches() {
        existing[m.rider_trip_id + ":" + m.driver_trip_id] = m;
    }
    for c in self.candidates {
        base = _score_match(c.route_score, c.detour, c.time_score, c.preference_score, c.cost_score);
        c.overall = max(1, min(99, base + c.trust_bonus));
    }
    ranked = sorted(self.candidates, key=_cand_overall, reverse=True);
    for (i, c) in enumerate(ranked) {
        c.notes["Coordinator"] = f"Ranked #{i + 1} of {len(ranked)} · {c.overall}% overall";
        other = _load_trip(c.trip_id);
        if other is None {
            continue;
        }
        pair = _pair(o, other as Trip);
        rider_trip = pair[0];
        driver_trip = pair[1];
        key = jid(rider_trip) + ":" + jid(driver_trip);
        gap_miles: float = c.origin_gap_km * 0.621371;
        if key in existing {
            m = existing[key];
            if m.status == "closed" {
                continue;   # declined matches stay out of the results
            }
            # Fresh evaluation: refresh the stored scores and notes.
            m.overall_score = c.overall;
            m.route_score = c.route_score;
            m.time_score = c.time_score;
            m.detour_minutes = c.detour;
            m.preference_score = c.preference_score;
            m.cost_benefit_score = c.cost_score;
            m.estimated_rider_savings = c.rider_savings;
            m.estimated_driver_contribution = c.driver_contribution;
            m.pickup_gap_miles = float(f"{gap_miles:.1f}");
            m.agent_notes = c.notes;
            self.cards.append(_match_to_card(m));
            continue;
        }
        m = Match(
            overall_score=c.overall, route_score=c.route_score, time_score=c.time_score,
            detour_minutes=c.detour, preference_score=c.preference_score,
            cost_benefit_score=c.cost_score, estimated_rider_savings=c.rider_savings,
            estimated_driver_contribution=c.driver_contribution, status="suggested",
            rider_handle=rider_trip.owner_handle, driver_handle=driver_trip.owner_handle,
            rider_trip_id=jid(rider_trip), driver_trip_id=jid(driver_trip),
            rider_root=rider_trip.owner_root, driver_root=driver_trip.owner_root,
            created_at=_now(), mode=o.mode, pickup_gap_miles=float(f"{gap_miles:.1f}"),
            agent_notes=c.notes
        );
        root.shared ++> m;
        _share_with(m, c.owner_root, WritePerm);
        rec = _impact_record();
        rec.trips_matched += 1;
        rec.estimated_savings += m.estimated_rider_savings;
        rec.estimated_shared_miles += 38.5;
        self.cards.append(_match_to_card(m));
    }
}

impl run_agents(trip_id: str) -> AgentRunView {
    return _run_agents(trip_id, True);
}

# with_relays: also look for 2-ride routes (slower: needs road routes + places).
def _run_agents(trip_id: str, with_relays: bool) -> AgentRunView {
    origin = _load_trip(trip_id);
    me = _my_root_id();
    if origin is None or (origin as Trip).owner_root != me {
        return AgentRunView();   # you can only run matching for your own trip
    }
    shared = root.shared;

    scout = RouteScout(origin_id=trip_id, my_root=me);
    shared spawn scout;
    found = scout.candidates;
    schedule = ScheduleAgent(origin_id=trip_id, candidates=found);
    shared spawn schedule;
    trust = TrustAgent(origin_id=trip_id, candidates=found);
    shared spawn trust;
    cost = CostAgent(origin_id=trip_id, candidates=found);
    shared spawn cost;
    coordinator = Coordinator(origin_id=trip_id, my_root=me, candidates=found);
    shared spawn coordinator;

    cards = _sort_cards(coordinator.cards);
    k = len(found);
    in_window = len([c for c in found if c.time_gap_min <= 20]);
    rated = len([c for c in found if c.reviews > 0]);
    best_saving: float = max([c.rider_savings for c in found]) if k else 0.0;
    steps = [
        AgentStepView(agent="Route Scout", role="Walks the journey graph for shared corridors",
            looked_at=scout.scanned, kept=k,
            summary=f"Walked {scout.scanned} journeys on the graph; {k} share your corridor"),
        AgentStepView(agent="Schedule Agent", role="Lines up departure times and detours",
            looked_at=k, kept=in_window,
            summary=f"Checked {k} schedules; {in_window} leave within 20 minutes of you"),
        AgentStepView(agent="Trust Agent", role="Weighs reviews and ride preferences",
            looked_at=k, kept=rated,
            summary=f"{rated} rated travelers, {k - rated} new to Along; preferences checked"),
        AgentStepView(agent="Cost Agent", role="Estimates what each match saves",
            looked_at=k, kept=k,
            summary=f"Best split saves about ${best_saving:.0f}" if k else "No costs to compare yet"),
        AgentStepView(agent="Coordinator", role="Combines every agent's score and ranks",
            looked_at=k, kept=len(cards),
            summary=(f"Ranked {len(cards)} matches; the best is {cards[0].overall_score}%") if len(cards) else "No matches to rank yet"),
    ];
    relays: list[RelayView] = [];
    o = origin as Trip;
    if with_relays and o.mode == "ride" and o.role == "RIDER" {
        relays = _find_relays(o, cards);
        steps = steps + [AgentStepView(
            agent="Relay Agent", role="Pairs two drivers with a safe handoff when no one goes the whole way",
            looked_at=len([c for c in cards if c.other_trip is not None]), kept=len(relays),
            summary=(f"Found {len(relays)} 2-ride route{'s' if len(relays) != 1 else ''}; handoff picked by " + (relays[0].handoff.source if relays[0].handoff is not None else "rules"))
                if len(relays) else "No 2-ride route beats waiting for a direct ride"
        )];
    }
    return AgentRunView(cards=cards, steps=steps, relays=relays);
}

impl run_matching(trip_id: str) -> list[MatchCardView] {
    return _run_agents(trip_id, False).cards;
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
        _notify(
            _other_root(mt), "message", "New message from " + handle,
            clean[:90] + ("…" if len(clean) > 90 else ""), jid(mt), "", True
        );
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

# ---------------------------------------------------------------------------
# Matchmaker + notifications
# ---------------------------------------------------------------------------

glob NOTIFY_MIN_SCORE: int = 60,     # don't ping people about weak matches
     NOTIFY_MAX_PER_POST: int = 8;

def _iso_now() -> str {
    return datetime.datetime.now(datetime.timezone.utc).isoformat();
}

# Create (or refresh) a notification for another user. `coalesce` folds a
# burst of chat messages into one unread notification per conversation.
def _notify(recipient: str, kind: str, title: str, body: str, match_id: str, trip_id: str, coalesce: bool = False) -> None {
    if not recipient or recipient == "demo" or recipient == _my_root_id() {
        return;
    }
    if coalesce {
        for n in [root.shared-->][?:Notification] {
            if n.recipient_root == recipient and n.kind == kind and n.match_id == match_id and not n.read {
                n.title = title;
                n.body = body;
                n.created_at = _iso_now();
                return;
            }
        }
    }
    n = Notification(
        recipient_root=recipient, kind=kind, title=title, body=body,
        match_id=match_id, trip_id=trip_id, created_at=_iso_now()
    );
    root.shared ++> n;
    _share_with(n, recipient, WritePerm);   # the recipient can mark it read
}

impl Matchmaker.watch {
    posted = _load_trip(self.trip_id);
    if posted is None {
        skip;
    }
    p = posted as Trip;
    run = _run_agents(self.trip_id, False);
    route = p.origin_name.split(",")[0] + " → " + p.destination_name.split(",")[0];
    for card in run.cards[:NOTIFY_MAX_PER_POST] {
        other = card.other_trip;
        if other is None or card.overall_score < NOTIFY_MIN_SCORE {
            continue;
        }
        other_trip = _load_trip(other.id);
        if other_trip is None {
            continue;
        }
        theirs = other_trip as Trip;
        their_route = theirs.origin_name.split(",")[0] + " → " + theirs.destination_name.split(",")[0];
        who = "driver" if p.role == "DRIVER" else ("rider" if p.role == "RIDER" else "traveler");
        _notify(
            theirs.owner_root, "match",
            f"New {card.overall_score}% match for your {their_route} journey",
            f"A {who} just posted {route} ({card.fit_label.lower()}). Along's agents think you'd travel well together.",
            card.id, jid(theirs)
        );
        self.notified += 1;
    }
}

def _notification_time(n: NotificationView) -> str {
    return n.created_at;
}

impl get_my_notifications() -> list[NotificationView] {
    me = _my_root_id();
    mine = [
        NotificationView(
            id=jid(n), kind=n.kind, title=n.title, body=n.body, match_id=n.match_id,
            trip_id=n.trip_id, created_at=n.created_at, read=n.read
        )
        for n in [root.shared-->][?:Notification] if n.recipient_root == me
    ];
    return sorted(mine, key=_notification_time, reverse=True)[:30];
}

# Marks the given notifications read (all of mine when ids is empty).
impl mark_notifications_read(ids: list[str]) -> int {
    me = _my_root_id();
    changed = 0;
    for n in [root.shared-->][?:Notification] {
        if n.recipient_root == me and not n.read and (len(ids) == 0 or jid(n) in ids) {
            n.read = True;
            changed += 1;
        }
    }
    return changed;
}

# ---------------------------------------------------------------------------
# Trip assistant — plain English -> journey draft
#
# Gemini is called directly over REST (no byllm/litellm), which keeps the
# server small enough for Render's free plan. With no key, or if Gemini
# fails, a rule-based reader handles common phrasings, so it never breaks.
# ---------------------------------------------------------------------------

import re;

glob VEHICLE_CHOICES: list[str] = ["Compact car", "Sedan", "SUV", "Minivan", "Pickup truck", "Cargo van", "Box truck"],
     WEEKDAYS: list[str] = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

def _gemini_key() -> str {
    return os.environ.get("GEMINI_API_KEY", "").strip();
}

def _draft_schema() -> dict {
    return {
        "type": "OBJECT",
        "properties": {
            "journey_type": {"type": "STRING", "enum": ["ride", "buddy", "rental", "cab"],
                "description": "ride = needs a ride from a driver; buddy = is driving and offering seats; rental = wants to share a car rental; cab = wants to split a cab/taxi/rideshare"},
            "pickup": {"type": "STRING", "description": "Start place as the user wrote it, e.g. 'Grand Blanc, MI' or 'Detroit Metro Airport'. Empty if not given."},
            "dropoff": {"type": "STRING", "description": "Destination place. Empty if not given."},
            "time": {"type": "STRING", "description": "24h HH:MM, or empty if no time was given"},
            "time_preference": {"type": "STRING", "enum": ["arrive_by", "depart_at"],
                "description": "arrive_by for 'by 9', 'need to be there at'; depart_at for 'leaving at', 'around 7'"},
            "recurring": {"type": "BOOLEAN", "description": "true for commutes: every weekday, daily, Mon-Fri, every morning"},
            "date": {"type": "STRING", "description": "YYYY-MM-DD for a one-time trip (resolve 'tomorrow', 'Saturday' from today's date), else empty"},
            "round_trip": {"type": "BOOLEAN", "description": "true if they also come back (and back, return, round trip, back at 5)"},
            "seats": {"type": "INTEGER", "description": "seats offered when journey_type is buddy, else 0"},
            "people": {"type": "INTEGER", "description": "people travelling (default 1)"},
            # Gemini rejects "" in an enum, so "none" stands for no vehicle.
            "vehicle": {"type": "STRING", "enum": ["none", "Compact car", "Sedan", "SUV", "Minivan", "Pickup truck", "Cargo van", "Box truck"]},
            "moving_help": {"type": "BOOLEAN", "description": "true if they mention moving, boxes, furniture"},
            "summary": {"type": "STRING", "description": "One short friendly sentence restating the plan"}
        },
        "required": ["journey_type", "pickup", "dropoff", "time", "time_preference", "recurring", "date",
                     "round_trip", "seats", "people", "vehicle", "moving_help", "summary"]
    };
}

def _gemini_draft(text: str) -> dict | None {
    key = _gemini_key();
    if not key {
        return None;
    }
    model = os.environ.get("GEMINI_MODEL", "").strip() or "gemini-flash-lite-latest";
    today = datetime.date.today();
    instruction = (
        "You turn one sentence from a traveler in Michigan into a structured journey for the Along "
        "ride-sharing app. Today is " + today.strftime("%A, %Y-%m-%d") + ". Only use what the sentence "
        "says; leave fields empty/false/0 when unsure. Places are in Michigan unless stated. "
        "Never invent a pickup or dropoff."
    );
    body = {
        "systemInstruction": {"parts": [{"text": instruction}]},
        "contents": [{"role": "user", "parts": [{"text": text[:500]}]}],
        "generationConfig": {
            "temperature": 0, "responseMimeType": "application/json", "responseSchema": _draft_schema()
        }
    };
    url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent";
    result = _http_json(url, body, {"Content-Type": "application/json", "x-goog-api-key": key});
    if result is None or not result.get("candidates") {
        return None;
    }
    try {
        raw: str = result["candidates"][0]["content"]["parts"][0]["text"];
        return json.loads(raw);
    } except Exception as e {
        print(f"[assistant] could not read Gemini reply: {e}");
        return None;
    }
}

def _to_hhmm(hour: int, minute: int, meridiem: str) -> str {
    h = hour;
    if meridiem.startswith("p") and h < 12 {
        h += 12;
    }
    if meridiem.startswith("a") and h == 12 {
        h = 0;
    }
    if not meridiem and h < 6 {
        h += 12;    # "by 5" with no am/pm almost always means 5 PM
    }
    return f"{h % 24:02d}:{minute:02d}";
}

# Strip filler the regex can't tell apart from a place: leading verbs
# ("driving Lansing") and trailing day words ("Detroit Friday").
def _clean_place(raw: str) -> str {
    place = raw.strip(" .,");
    place = re.sub(r"^(?:i'?m |i am |i )?(?:driving|going|heading|leaving|travell?ing|commuting|flying)(?: from)?\s+", "", place, flags=re.I);
    place = re.sub(r"\s+(?:on\s+)?(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|today|tonight|this \w+|next \w+)$", "", place, flags=re.I);
    return place.strip(" .,");
}

# Handles the common phrasings when Gemini isn't available.
def _rules_draft(text: str) -> dict {
    t = text.lower();
    kind = "ride";
    if re.search(r"\b(rent|rental|truck|moving van|u-?haul)\b", t) {
        kind = "rental";
    } elif re.search(r"\b(cab|taxi|uber|lyft|split a ride|airport)\b", t) {
        kind = "cab";
    } elif re.search(r"\b(i'?m driving|i drive|offering|have (\d+ )?(empty )?seats?|giving a ride)\b", t) {
        kind = "buddy";
    }
    pickup = "";
    dropoff = "";
    m = re.search(r"from\s+(.+?)\s+to\s+(.+?)(?=\s+(?:by|at|around|every|on|tomorrow|today|this|next|and|leaving|arriving|,)\b|[.,!]|$)", text, re.I);
    if not m {
        m = re.search(r"^(?:i need (?:a ride )?|i'?m (?:going|heading|driving) )?(?:from\s+)?([a-z .'-]+?)\s+to\s+([a-z .'-]+?)(?=\s+(?:by|at|around|every|on|tomorrow|and|,)\b|[.,!]|$)", text, re.I);
    }
    if m {
        pickup = _clean_place(m.group(1));
        dropoff = _clean_place(m.group(2));
    }
    time_pref = "depart_at";
    tm = re.search(r"\b(by|before|arrive(?: by)?|at|around|leaving(?: at)?|leave(?: at)?)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?", t);
    hhmm = "";
    if tm {
        time_pref = "arrive_by" if tm.group(1).startswith(("by", "before", "arrive")) else "depart_at";
        hhmm = _to_hhmm(int(tm.group(2)), int(tm.group(3) or 0), (tm.group(4) or "").replace(".", ""));
    }
    recurring = bool(re.search(r"\b(every (week)?day|weekdays|daily|mon(day)?\s*-\s*fri(day)?|each morning|commute)\b", t));
    date = "";
    today = datetime.date.today();
    if "tomorrow" in t {
        date = (today + datetime.timedelta(days=1)).isoformat();
    } elif "today" in t or "tonight" in t {
        date = today.isoformat();
    } else {
        for (i, day) in enumerate(WEEKDAYS) {
            if day in t and not recurring {
                ahead = (i - today.weekday()) % 7 or 7;
                date = (today + datetime.timedelta(days=ahead)).isoformat();
                break;
            }
        }
    }
    seats = 0;
    sm = re.search(r"(\d+)\s+(?:empty\s+)?seats?", t);
    if sm and kind == "buddy" {
        seats = int(sm.group(1));
    }
    pm = re.search(r"(\d+)\s+(?:of us|people|persons|travelers)", t);
    people = int(pm.group(1)) if pm else 1;
    vehicle = "";
    for v in VEHICLE_CHOICES {
        if v.lower() in t {
            vehicle = v;
        }
    }
    return {
        "journey_type": kind, "pickup": pickup, "dropoff": dropoff, "time": hhmm,
        "time_preference": time_pref, "recurring": recurring, "date": date,
        "round_trip": bool(re.search(r"\b(round ?trip|and back|come back|coming back|return|back at)\b", t)),
        "seats": seats, "people": people, "vehicle": vehicle,
        "moving_help": bool(re.search(r"\b(moving|boxes|furniture|couch)\b", t)), "summary": ""
    };
}

impl plan_trip(text: str) -> TripDraftView {
    clean = text.strip();
    if len(clean) < 4 {
        return TripDraftView(ok=False, summary="Tell me where you're going, e.g. 'Flint to Ann Arbor by 9 every weekday'.");
    }
    data = _gemini_draft(clean);
    source = "gemini";
    if data is None {
        data = _rules_draft(clean);
        source = "rules";
    }
    d = data as dict;
    kind = str(d.get("journey_type") or "ride");
    if kind not in ["ride", "buddy", "rental", "cab"] {
        kind = "ride";
    }
    draft = TripDraftView(
        ok=True, source=source, kind=kind,
        origin_name=str(d.get("pickup") or "").strip()[:80],
        destination_name=str(d.get("dropoff") or "").strip()[:80],
        time=str(d.get("time") or "")[:5],
        time_preference="arrive_by" if d.get("time_preference") == "arrive_by" else "depart_at",
        recurring=bool(d.get("recurring")), travel_date=str(d.get("date") or "")[:10],
        round_trip=bool(d.get("round_trip")),
        seats=max(0, min(int(d.get("seats") or 0), 8)),
        people=max(1, min(int(d.get("people") or 1), 8)),
        vehicle=str(d.get("vehicle") or "") if str(d.get("vehicle") or "") in VEHICLE_CHOICES else "",
        moving_help=bool(d.get("moving_help")),
        summary=str(d.get("summary") or "")[:200]
    );
    if draft.kind == "buddy" and draft.seats == 0 {
        draft.seats = 3;
    }
    # Pin both places on the map (Michigan-biased), so the form arrives ready.
    if draft.origin_name {
        found = _geocode(draft.origin_name);
        if found is not None {
            draft.origin_lat = found[0];
            draft.origin_lng = found[1];
        }
    }
    if draft.destination_name {
        found = _geocode(draft.destination_name);
        if found is not None {
            draft.destination_lat = found[0];
            draft.destination_lng = found[1];
        }
    }
    missing: list[str] = [];
    if not draft.origin_name {
        missing.append("pickup");
    }
    if not draft.destination_name {
        missing.append("dropoff");
    }
    if not draft.time {
        missing.append("time");
    }
    draft.missing = missing;
    if not draft.summary {
        where = (draft.origin_name or "?") + " → " + (draft.destination_name or "?");
        draft.summary = "Got it: " + where + ".";
    }
    return draft;
}

# ---------------------------------------------------------------------------
# Relay Agent — 2-ride routes with an AI-picked handoff spot
#
# Driver A's road route passes your pickup; driver B's reaches your
# destination. Where their routes come closest is the handoff point; Google
# Places lists real public places there, and Gemini picks the best + safest
# one for all three people (rules if Gemini is unavailable).
# ---------------------------------------------------------------------------

glob RELAY_NEAR_KM: float = 9.0,        # pickup/dropoff this close to a driver's route (town centre to highway is often 5-8 km)
     RELAY_MEET_KM: float = 4.0,        # the two routes must pass this close to each other
     RELAY_MIN_WAIT: int = 3,
     RELAY_MAX_WAIT: int = 45,
     RELAY_MAX_RESULTS: int = 2;

glob HANDOFF_TYPES: list[str] = [
    "cafe", "coffee_shop", "library", "shopping_mall", "supermarket", "gas_station",
    "transit_station", "bus_station", "park_and_ride", "restaurant", "fast_food_restaurant"
];

def _thin(points: list[list[float]], n: int) -> list[list[float]] {
    if len(points) <= n {
        return points;
    }
    step = len(points) / n;
    out = [points[int(i * step)] for i in range(n)];
    return out + [points[-1]];
}

def _cum_km(points: list[list[float]]) -> list[float] {
    out: list[float] = [0.0];
    for i in range(1, len(points)) {
        out.append(out[-1] + _haversine_km(points[i - 1][0], points[i - 1][1], points[i][0], points[i][1]));
    }
    return out;
}

# (index of the closest route point, distance in km)
def _nearest_on(points: list[list[float]], lat: float, lng: float) -> tuple[int, float] {
    best = 0;
    best_km = 1e9;
    for (i, p) in enumerate(points) {
        d = _haversine_km(p[0], p[1], lat, lng);
        if d < best_km {
            best_km = d;
            best = i;
        }
    }
    return (best, best_km);
}

def _hhmm(minutes: float) -> str {
    total = int(round(minutes)) % (24 * 60);
    return f"{total // 60:02d}:{total % 60:02d}";
}

def _route_of(t: Trip) -> RouteView {
    return get_trip_route(jid(t));
}

def _find_relays(o: Trip, cards: list[MatchCardView]) -> list[RelayView] {
    drivers: list[tuple[Trip, str]] = [];
    for c in cards {
        if c.other_trip is not None and c.other_trip.role == "DRIVER" {
            t = _load_trip(c.other_trip.id);
            if t is not None {
                drivers.append((t as Trip, c.id));
            }
        }
    }
    if len(drivers) < 2 {
        return [];
    }
    routes: dict[str, list[list[float]]] = {};
    for (t, mid) in drivers {
        routes[jid(t)] = _thin(_route_of(t).points, 80);
    }
    # Leg 1 candidates pass your pickup; leg 2 candidates pass your destination.
    firsts: list[dict] = [];
    seconds: list[dict] = [];
    for (t, mid) in drivers {
        pts = routes[jid(t)];
        if len(pts) < 2 {
            continue;
        }
        pick = _nearest_on(pts, o.origin_lat, o.origin_lng);
        drop = _nearest_on(pts, o.destination_lat, o.destination_lng);
        if pick[1] <= RELAY_NEAR_KM and pick[0] < len(pts) - 1 {
            firsts.append({"trip": t, "match": mid, "pts": pts, "pick": pick[0], "gap": pick[1]});
        }
        if drop[1] <= RELAY_NEAR_KM and drop[0] > 0 {
            seconds.append({"trip": t, "match": mid, "pts": pts, "drop": drop[0], "gap": drop[1]});
        }
    }
    deadline = _minutes_of_day(o.arrival_deadline) + max(o.flexible_minutes, 10) if o.time_preference == "arrive_by" and o.arrival_deadline else 99999;
    found: list[RelayView] = [];
    for f in firsts {
        a = f["trip"] as Trip;
        a_pts = f["pts"] as list[list[float]];
        a_cum = _cum_km(a_pts);
        a_route = _route_of(a);
        for sec in seconds {
            b = sec["trip"] as Trip;
            if jid(a) == jid(b) {
                continue;   # one driver going the whole way is a direct match, not a relay
            }
            b_pts = sec["pts"] as list[list[float]];
            b_cum = _cum_km(b_pts);
            b_route = _route_of(b);
            # Closest approach: after A picks you up, before B drops you off.
            best = (0, 0, 1e9);
            for ia in range(f["pick"] as int, len(a_pts)) {
                for ib in range(0, (sec["drop"] as int) + 1) {
                    d = _haversine_km(a_pts[ia][0], a_pts[ia][1], b_pts[ib][0], b_pts[ib][1]);
                    if d < best[2] {
                        best = (ia, ib, d);
                    }
                }
            }
            if best[2] > RELAY_MEET_KM {
                continue;
            }
            ia = best[0];
            ib = best[1];
            a_share = a_cum[ia] / a_cum[-1] if a_cum[-1] > 0 else 0.0;
            a_pick_share = a_cum[f["pick"] as int] / a_cum[-1] if a_cum[-1] > 0 else 0.0;
            b_share = b_cum[ib] / b_cum[-1] if b_cum[-1] > 0 else 0.0;
            b_drop_share = b_cum[sec["drop"] as int] / b_cum[-1] if b_cum[-1] > 0 else 1.0;
            a_dep = _minutes_of_day(a.departure_time);
            b_dep = _minutes_of_day(b.departure_time);
            pickup_at = a_dep + a_route.duration_min * a_pick_share;
            at_handoff = a_dep + a_route.duration_min * a_share;
            b_at_handoff = b_dep + b_route.duration_min * b_share;
            wait_m = int(round(b_at_handoff - at_handoff));
            arrive = b_dep + b_route.duration_min * b_drop_share;
            if wait_m < RELAY_MIN_WAIT or wait_m > RELAY_MAX_WAIT or arrive > deadline {
                continue;
            }
            total = int(round(arrive - pickup_at));
            rep_a = _rating_summary(_ratee_key(a.owner_root, a.owner_handle), a.demo_rating, a.demo_reviews);
            rep_b = _rating_summary(_ratee_key(b.owner_root, b.owner_handle), b.demo_rating, b.demo_reviews);
            score = 96 - wait_m * 0.4 - (f["gap"] as float) * 2.5 - (sec["gap"] as float) * 2.0 - best[2] * 3.0;
            score += 2 if rep_a[1] > 0 and rep_a[0] >= 4.5 else 0;
            score += 2 if rep_b[1] > 0 and rep_b[0] >= 4.5 else 0;
            meet_lat = (a_pts[ia][0] + b_pts[ib][0]) / 2;
            meet_lng = (a_pts[ia][1] + b_pts[ib][1]) / 2;
            found.append(RelayView(
                id=jid(a) + ":" + jid(b), leg1_match_id=f["match"] as str, leg2_match_id=sec["match"] as str,
                leg1_handle=a.owner_handle, leg2_handle=b.owner_handle,
                leg1_rating=rep_a[0] as float, leg1_reviews=rep_a[1] as int,
                leg2_rating=rep_b[0] as float, leg2_reviews=rep_b[1] as int,
                pickup_time=_hhmm(pickup_at), handoff_time=_hhmm(at_handoff), wait_min=wait_m,
                leg2_depart=_hhmm(b_at_handoff), arrive_time=_hhmm(arrive), total_min=total,
                leg1_min=int(round(at_handoff - pickup_at)), leg2_min=int(round(arrive - b_at_handoff)),
                pickup_gap_mi=float(f"{(f['gap'] as float) * 0.621371:.1f}"),
                score=max(1, min(99, int(score))),
                handoff=HandoffView(lat=meet_lat, lng=meet_lng),
                leg1_points=a_pts[f["pick"] as int:ia + 1], leg2_points=b_pts[ib:(sec["drop"] as int) + 1]
            ));
        }
    }
    ranked = sorted(found, key=_relay_score, reverse=True)[:RELAY_MAX_RESULTS];
    # Judge opening hours for the day the trip actually happens.
    day = "a weekday (Monday to Friday)" if o.recurring else _weekday_of(o.travel_date);
    for r in ranked {
        h = r.handoff as HandoffView;
        r.handoff = _pick_handoff(h.lat, h.lng, r.handoff_time, r.wait_min, r.leg1_handle, r.leg2_handle, day);
        where = r.handoff.name if r.handoff is not None and r.handoff.name else "a public spot";
        r.why = f"{r.leg1_handle} passes your pickup and meets {r.leg2_handle}'s route near {where}; you wait about {r.wait_min} min.";
    }
    return ranked;
}

def _weekday_of(iso: str) -> str {
    try {
        return datetime.date.fromisoformat(iso).strftime("%A");
    } except Exception {
        return datetime.date.today().strftime("%A");
    }
}

def _relay_score(r: RelayView) -> int {
    return r.score;
}

# Real public places near the meeting point (Places API, New).
def _places_near(lat: float, lng: float) -> list[dict] {
    key = _maps_key();
    if not key {
        return [];
    }
    body = {
        "includedTypes": HANDOFF_TYPES, "maxResultCount": 10, "rankPreference": "DISTANCE",
        "locationRestriction": {"circle": {"center": {"latitude": lat, "longitude": lng}, "radius": 2500.0}}
    };
    headers = {
        "Content-Type": "application/json", "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": "places.displayName,places.formattedAddress,places.location,places.primaryType,places.rating,places.userRatingCount,places.businessStatus,places.regularOpeningHours.weekdayDescriptions,places.currentOpeningHours.openNow"
    };
    result = _http_json("https://places.googleapis.com/v1/places:searchNearby", body, headers);
    if result is None {
        return [];
    }
    out: list[dict] = [];
    for p in result.get("places", []) {
        if p.get("businessStatus", "OPERATIONAL") != "OPERATIONAL" {
            continue;
        }
        loc = p.get("location", {});
        out.append({
            "name": (p.get("displayName") or {}).get("text", ""), "address": p.get("formattedAddress", ""),
            "lat": loc.get("latitude", lat), "lng": loc.get("longitude", lng),
            "type": str(p.get("primaryType", "")).replace("_", " "),
            "rating": p.get("rating", 0.0), "reviews": p.get("userRatingCount", 0),
            "open_now": (p.get("currentOpeningHours") or {}).get("openNow"),
            "hours": ((p.get("regularOpeningHours") or {}).get("weekdayDescriptions") or [])[:7],
            "km_from_meeting_point": round(_haversine_km(lat, lng, loc.get("latitude", lat), loc.get("longitude", lng)), 2)
        });
    }
    return out;
}

# Gemini chooses the best + safest handoff for everyone; rules if it can't.
glob _HANDOFF_CACHE: dict[str, HandoffView] = {};

def _pick_handoff(lat: float, lng: float, when: str, wait_m: int, first: str, second: str, day: str) -> HandoffView {
    cache_key = f"{lat:.3f},{lng:.3f}|{day}|{when}";
    if cache_key in _HANDOFF_CACHE {
        return _HANDOFF_CACHE[cache_key];
    }
    picked = _choose_handoff(lat, lng, when, wait_m, first, second, day);
    if picked.source != "none" {
        _HANDOFF_CACHE[cache_key] = picked;
    }
    return picked;
}

def _choose_handoff(lat: float, lng: float, when: str, wait_m: int, first: str, second: str, day: str) -> HandoffView {
    places = _places_near(lat, lng);
    if len(places) == 0 {
        return HandoffView(lat=lat, lng=lng, name="Meeting point", reason="No listed public places nearby — agree on a well-lit public spot in chat.", source="none");
    }
    choice = _gemini_pick_handoff(places, when, wait_m, first, second, day);
    source = "gemini";
    if choice is None {
        choice = _rules_pick_handoff(places);
        source = "rules";
    }
    idx = max(0, min(int(choice[0]), len(places) - 1));
    p = places[idx];
    return HandoffView(
        name=p["name"], address=p["address"], lat=float(p["lat"]), lng=float(p["lng"]),
        kind=str(p["type"]).capitalize(), rating=float(p["rating"] or 0.0), reviews=int(p["reviews"] or 0),
        open_now="",   # "open right now" isn't meaningful for a future handoff
        reason=str(choice[1])[:220], source=source
    );
}

def _gemini_pick_handoff(places: list[dict], when: str, wait_m: int, first: str, second: str, day: str) -> tuple[int, str] | None {
    key = _gemini_key();
    if not key {
        return None;
    }
    model = os.environ.get("GEMINI_MODEL", "").strip() or "gemini-flash-lite-latest";
    brief = [
        {k: p[k] for k in ["name", "type", "rating", "reviews", "hours", "km_from_meeting_point"]}
        for p in places
    ];
    prompt = (
        f"A rider is switching between two ride-share drivers ({first} drops off, {second} picks up) "
        f"on {day} at about {when}, waiting roughly {wait_m} minutes. Use each place's opening hours "
        "for that day. "
        "Choose the single best and safest public handoff place from this list: busy, well-reviewed, "
        "open at that time, with somewhere comfortable to wait, and close to the meeting point so both "
        "drivers barely detour. Places:\n" + json.dumps(brief)
    );
    body = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0, "responseMimeType": "application/json",
            "responseSchema": {
                "type": "OBJECT",
                "properties": {
                    "index": {"type": "INTEGER", "description": "0-based index into the list"},
                    "reason": {"type": "STRING", "description": "One short sentence for the rider on why this spot is best and safe"}
                },
                "required": ["index", "reason"]
            }
        }
    };
    url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent";
    result = _http_json(url, body, {"Content-Type": "application/json", "x-goog-api-key": key});
    if result is None or not result.get("candidates") {
        return None;
    }
    try {
        picked = json.loads(result["candidates"][0]["content"]["parts"][0]["text"]);
        return (int(picked["index"]), str(picked["reason"]));
    } except Exception as e {
        print(f"[relay] could not read Gemini handoff pick: {e}");
        return None;
    }
}

def _handoff_rule_score(p: dict) -> float {
    kind_bonus = {"cafe": 3.0, "coffee shop": 3.0, "library": 3.0, "shopping mall": 2.5, "supermarket": 2.0,
                  "transit station": 2.0, "bus station": 1.5, "park and ride": 2.0, "gas station": 1.0};
    busy = math.log10(1 + float(p["reviews"] or 0));
    open_bonus = 1.5 if len(p["hours"]) > 0 else 0.0;   # has published hours
    return kind_bonus.get(str(p["type"]), 0.5) + float(p["rating"] or 0) * 0.6 + busy + open_bonus - float(p["km_from_meeting_point"]) * 1.5;
}

def _rules_pick_handoff(places: list[dict]) -> tuple[int, str] {
    best = 0;
    for i in range(len(places)) {
        if _handoff_rule_score(places[i]) > _handoff_rule_score(places[best]) {
            best = i;
        }
    }
    p = places[best];
    return (best, f"A busy, well-reviewed {p['type']} right by where both routes meet.");
}

# ---------------------------------------------------------------------------
# Rent together — car-rental counters near the pickup (Places API, New)
# ---------------------------------------------------------------------------

impl get_rental_spots(lat: float, lng: float) -> list[RentalSpotView] {
    key = _maps_key();
    if not key or not lat or not lng {
        return [];
    }
    body = {
        "includedTypes": ["car_rental"], "maxResultCount": 12, "rankPreference": "DISTANCE",
        "locationRestriction": {"circle": {"center": {"latitude": lat, "longitude": lng}, "radius": 20000.0}}
    };
    headers = {
        "Content-Type": "application/json", "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": "places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.businessStatus"
    };
    result = _http_json("https://places.googleapis.com/v1/places:searchNearby", body, headers);
    if result is None {
        return [];
    }
    spots: list[RentalSpotView] = [];
    places: list[dict] = (result as dict).get("places", []) as list[dict];
    for p in places {
        if p.get("businessStatus", "OPERATIONAL") != "OPERATIONAL" {
            continue;
        }
        loc: dict = p.get("location", {}) as dict;
        plat: float = loc.get("latitude", lat) as float;
        plng: float = loc.get("longitude", lng) as float;
        shown: dict = (p.get("displayName") or {}) as dict;
        name = str(shown.get("text", "Car rental"));
        spots.append(RentalSpotView(
            name=name, address=str(p.get("formattedAddress", "")), lat=plat, lng=plng,
            rating=p.get("rating", 0.0) as float, reviews=p.get("userRatingCount", 0) as int,
            km=float(f"{_haversine_km(lat, lng, plat, plng):.1f}"),
            maps_url="https://www.google.com/maps/search/?api=1&query=" + urlencode({"q": name})[2:] + "&query_place_id=" + str(p.get("id", ""))
        ));
    }
    return spots;
}
