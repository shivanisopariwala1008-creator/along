"""Along client helpers — journey-type copy, display formatting and the map
projection shared by every screen in components/along/.

A journey "kind" is one of the four Figma entry points:
  ride   -> mode "ride",   role RIDER   (I need a ride)
  buddy  -> mode "ride",   role DRIVER  (I'm offering a ride)
  rental -> mode "rental", role PEER    (share a car rental)
  cab    -> mode "cab",    role PEER    (split a cab)
"""

sv import from ..services.along { TripView, MatchCardView }

glob FLOW_KEYS: list[str] = ["ride", "buddy", "rental", "cab"];

def:pub flow_keys() -> list[str] {
    return FLOW_KEYS;
}

def:pub flow_info(kind: str) -> dict[str, str] {
    if kind == "buddy" {
        return {
            "title": "Find a buddy", "eyebrow": "I’m offering a ride", "icon": "users",
            "description": "Post your route and find people nearby who need a ride.",
            "detail": "I’m offering a ride and want to find someone going my way.",
            "heading": "Where are you driving?", "origin": "Flint, MI", "destination": "Ann Arbor, MI",
            "result_title": "Riders along your route", "marker": "R", "marker_label": "Ride request",
            "accent": "blue", "submit": "Post route & find riders"
        };
    }
    if kind == "rental" {
        return {
            "title": "Rent together", "eyebrow": "Share a car rental", "icon": "key",
            "description": "Choose a vehicle and connect with compatible rental partners.",
            "detail": "I want to share a car rental with someone.",
            "heading": "Plan your shared rental", "origin": "Novi, MI", "destination": "Detroit, MI",
            "result_title": "Potential rental partners", "marker": "P", "marker_label": "Rental partner",
            "accent": "purple", "submit": "Find rental partners"
        };
    }
    if kind == "cab" {
        return {
            "title": "Share a cab", "eyebrow": "Split a similar journey", "icon": "cab",
            "description": "Find people traveling from a similar point A to point B.",
            "detail": "I want to split a cab with people traveling a similar route.",
            "heading": "Where are you headed?", "origin": "Detroit Metro Airport",
            "destination": "Downtown Detroit", "result_title": "People with similar journeys",
            "marker": "C", "marker_label": "Cab share", "accent": "amber", "submit": "Find cab partners"
        };
    }
    return {
        "title": "Find a ride", "eyebrow": "I need a ride", "icon": "car",
        "description": "Connect with a trusted driver already heading your way.",
        "detail": "I need a ride from someone driving.",
        "heading": "Tell us about your journey", "origin": "Grand Blanc, MI",
        "destination": "Ann Arbor, MI", "result_title": "Drivers heading your way", "marker": "D",
        "marker_label": "Ride offer", "accent": "green", "submit": "Show matching rides"
    };
}

def:pub flow_of(mode: str, role: str) -> str {
    if mode == "rental" or mode == "cab" {
        return mode;
    }
    return "buddy" if role == "DRIVER" else "ride";
}

def:pub mode_of(kind: str) -> str {
    return kind if kind == "rental" or kind == "cab" else "ride";
}

def:pub role_of(kind: str) -> str {
    if kind == "buddy" {
        return "DRIVER";
    }
    return "RIDER" if kind == "ride" else "PEER";
}

def:pub flow_of_trip(t: TripView | None) -> str {
    if t is None {
        return "ride";
    }
    return flow_of(t.mode, t.role);
}

# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

# "07:40" -> "7:40 AM"
def:pub fmt_time(hhmm: str) -> str {
    if not hhmm or ":" not in hhmm {
        return hhmm or "";
    }
    parts = hhmm.split(":");
    hours = int(parts[0]);
    suffix = "PM" if hours >= 12 else "AM";
    h12 = hours % 12;
    if h12 == 0 {
        h12 = 12;
    }
    return str(h12) + ":" + parts[1][:2] + " " + suffix;
}

# "2026-05-24" -> "Sun, May 24"; anything else is returned unchanged.
def:pub fmt_date(iso: str) -> str {
    if not iso or len(iso) != 10 or iso[4] != "-" {
        return iso or "";
    }
    d = new(Date, iso + "T12:00:00");
    label: str = d.toLocaleDateString("en-US", {"weekday": "short", "month": "short", "day": "numeric"});
    return label;
}

def:pub today_iso() -> str {
    d = new(Date);
    offset_ms: float = d.getTimezoneOffset() * 60000;
    local = new(Date, d.getTime() - offset_ms);
    iso: str = local.toISOString();
    return iso[:10];
}

def:pub short_place(name: str) -> str {
    return (name or "").split(",")[0];
}

def:pub plural(n: int, one: str, many: str) -> str {
    return str(n) + " " + (one if n == 1 else many);
}

# "MapleDriver" -> "MD", "Rider 184" -> "R1", "Alex Kim" -> "AK"
def:pub initials(name: str) -> str {
    clean = (name or "").strip();
    if not clean {
        return "?";
    }
    words = clean.split(" ");
    if len(words) >= 2 and words[1] {
        return (words[0][:1] + words[1][:1]).upper();
    }
    i = 1;
    while i < len(clean) {
        ch = clean[i];
        if ch != ch.lower() {
            return (clean[:1] + ch).upper();
        }
        i = i + 1;
    }
    return clean[:2].upper();
}

def:pub rating_text(t: TripView | None) -> str {
    if t is not None and t.owner_reviews > 0 {
        return f"{t.owner_rating:.1f} · " + plural(t.owner_reviews, "review", "reviews");
    }
    return "New to Along";
}

def:pub has_rating(t: TripView | None) -> bool {
    return t is not None and t.owner_reviews > 0;
}

# The headline time on a result card, phrased for what the other person posted.
def:pub when_text(card: MatchCardView) -> str {
    other = card.other_trip;
    if other is None {
        return "";
    }
    if card.mode == "rental" {
        return (fmt_date(other.travel_date) or "Flexible dates") + " · from " + fmt_time(other.departure_time);
    }
    if card.mode == "cab" {
        return "Ready around " + fmt_time(other.departure_time);
    }
    if other.role == "DRIVER" {
        return "Leaves " + fmt_time(other.departure_time);
    }
    return "Needs arrival by " + fmt_time(other.arrival_deadline);
}

def:pub meta_text(card: MatchCardView) -> str {
    other = card.other_trip;
    if other is None {
        return "";
    }
    if card.mode == "rental" {
        return plural(other.people, "person", "people") + " · " + (other.vehicle or "Any vehicle");
    }
    if card.mode == "ride" and other.role == "DRIVER" {
        return plural(other.seats_available, "seat", "seats") + " · near " + short_place(other.origin_name);
    }
    return plural(other.people, "person", "people") + " · " + short_place(other.origin_name);
}

# What the searcher asked for, for the results toolbar ("Sat, May 24 · Arrive by 9:00 AM").
def:pub trip_timing(t: TripView | None) -> str {
    if t is None {
        return "";
    }
    day = "Weekdays" if t.recurring else (fmt_date(t.travel_date) or "One time");
    if t.time_preference == "depart_at" {
        return day + " · Leave at " + fmt_time(t.departure_time);
    }
    return day + " · Arrive by " + fmt_time(t.arrival_deadline);
}

# ---------------------------------------------------------------------------
# Map projection — lat/lng onto a percentage box fitted around the journey
# ---------------------------------------------------------------------------

glob MAP_TOWNS: list[list[any]] = [
    ["Flint", 43.0125, -83.6875], ["Grand Blanc", 42.9269, -83.6410], ["Fenton", 42.7970, -83.7052],
    ["Holly", 42.7917, -83.6277], ["Howell", 42.6072, -83.9294], ["Brighton", 42.5284, -83.7796],
    ["Novi", 42.4806, -83.4755], ["Ann Arbor", 42.2808, -83.7430], ["Ypsilanti", 42.2411, -83.6130],
    ["Canton", 42.3086, -83.4820], ["Livonia", 42.3684, -83.3527], ["Detroit", 42.3314, -83.0458],
    ["DTW Airport", 42.2162, -83.3554], ["Dearborn", 42.3223, -83.1763], ["Troy", 42.6064, -83.1498],
    ["Pontiac", 42.6389, -83.2910], ["Lansing", 42.7325, -84.5555],
];

# points: [[lat, lng], ...]. Pads the box and keeps a sensible minimum span.
def:pub map_bounds(points: list[list[float]]) -> dict {
    if len(points) == 0 {
        return {"min_lat": 42.15, "max_lat": 43.1, "min_lng": -84.05, "max_lng": -82.95};
    }
    min_lat = points[0][0];
    max_lat = points[0][0];
    min_lng = points[0][1];
    max_lng = points[0][1];
    for p in points {
        min_lat = min(min_lat, p[0]);
        max_lat = max(max_lat, p[0]);
        min_lng = min(min_lng, p[1]);
        max_lng = max(max_lng, p[1]);
    }
    lat_span = max(max_lat - min_lat, 0.18);
    lng_span = max(max_lng - min_lng, 0.26);
    mid_lat = (min_lat + max_lat) / 2;
    mid_lng = (min_lng + max_lng) / 2;
    return {
        "min_lat": mid_lat - lat_span * 0.75, "max_lat": mid_lat + lat_span * 0.75,
        "min_lng": mid_lng - lng_span * 0.72, "max_lng": mid_lng + lng_span * 0.72
    };
}

# Returns [x, y] in 0-100 map units.
def:pub project(b: dict, lat: float, lng: float) -> list[float] {
    x = (lng - (b["min_lng"] as float)) / ((b["max_lng"] as float) - (b["min_lng"] as float)) * 100;
    y = ((b["max_lat"] as float) - lat) / ((b["max_lat"] as float) - (b["min_lat"] as float)) * 100;
    return [min(max(x, 4.0), 96.0), min(max(y, 5.0), 95.0)];
}

def:pub pos_style(xy: list[float]) -> dict {
    return {"left": str(xy[0]) + "%", "top": str(xy[1]) + "%"};
}

# Towns inside the box, for the faint map labels.
def:pub towns_in(b: dict) -> list[list[any]] {
    return [
        t for t in MAP_TOWNS
        if (t[1] as float) > (b["min_lat"] as float) and (t[1] as float) < (b["max_lat"] as float)
        and (t[2] as float) > (b["min_lng"] as float) and (t[2] as float) < (b["max_lng"] as float)
    ];
}
