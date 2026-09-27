"""Seed a realistic Along demo: 18 log-in-able test users (4+ per journey type)
across real Michigan corridors, with conversations in every state and
completed, rated trips so reputations show up.

    jac run scripts/seed_test_users.jac            # create users + conversations
    jac run scripts/seed_test_users.jac greet      # test users message YOUR matches

Feature coverage (each has at least one live example):
  - Find a ride (riders) / Find a buddy (drivers) / Rent together / Share a cab
  - weekday commutes, one-time trips, round trips, rentals needing moving help
  - chats: anonymous, waiting on a reveal, revealed with contact details,
    declined/closed, completed and rated by both sides
  - reputation: rated travelers with reviews, plus brand-new ones (no ratings)
  - a 2-ride relay: zoe (Grand Blanc -> Novi) via priya, then noah
  - the demo network (services/demo_network.jac): ~270 sample journeys

`greet`: post a journey from your own account first, then run this — each test
user whose route fits yours opens a conversation with you and says hello.

Env: ALONG_API (default http://localhost:8001), SEED_PASSWORD (default below).
Everything goes through the normal endpoints, so it lands in whichever
database the server is using (SQLite, or MongoDB when MONGODB_URI is set).
Re-running is safe: existing accounts, journeys, messages and ratings are kept.
"""

import os;
import sys;
import json;
import datetime;
import from urllib.request { Request, urlopen }
import from urllib.error { HTTPError }

glob API: str = os.environ.get("ALONG_API", "http://localhost:8001").rstrip("/"),
     PASSWORD: str = os.environ.get("SEED_PASSWORD", "AlongTest123!"),
     # One-time trips happen next Saturday so they always look upcoming.
     NEXT_SAT: str = (datetime.date.today() + datetime.timedelta(days=((5 - datetime.date.today().weekday()) % 7) or 7)).isoformat(),
     SEED_NOTE: str = "Along test user";

def person(key: str, name: str, area: str, phone: str, trip: dict) -> dict {
    return {"key": key, "name": name, "email": key + ".test@example.com", "area": area, "phone": phone, "trip": trip};
}

def ride(role: str, frm: str, dest: str, pref: str, time: str, seats: int = 0, recurring: bool = True, round_trip: bool = False) -> dict {
    return {"mode": "ride", "role": role, "from": frm, "to": dest, "pref": pref, "time": time,
            "recurring": recurring, "seats": seats, "round_trip": round_trip};
}

def peer(mode: str, frm: str, dest: str, pref: str, time: str, people: int = 1, vehicle: str = "", moving: bool = False, round_trip: bool = False) -> dict {
    return {"mode": mode, "role": "PEER", "from": frm, "to": dest, "pref": pref, "time": time, "recurring": False,
            "seats": 0, "people": people, "vehicle": vehicle, "moving": moving, "round_trip": round_trip};
}

# Everyone has an age and gender (required at signup; used only for matching).
glob BASICS: dict[str, list] = {
    "priya": [29, "woman"], "dana": [41, "woman"], "omar": [35, "man"], "grace": [27, "woman"],
    "noah": [38, "man"], "marcus": [24, "man"], "aisha": [31, "woman"], "ben": [22, "man"],
    "lena": [45, "woman"], "zoe": [26, "woman"], "riley": [33, "non-binary"], "kevin": [28, "man"],
    "sofia": [36, "woman"], "tom": [52, "man"], "jordan": [30, "non-binary"], "sam": [25, "man"],
    "mia": [34, "woman"], "ethan": [47, "man"]
};

# The first six keep the accounts/journeys earlier versions of this script made.
glob PEOPLE: list[dict] = [
    # --- Find a buddy: drivers offering seats ---
    person("priya", "Priya Shah", "Flint, MI", "(810) 555-0142", ride("DRIVER", "Flint, MI", "Ann Arbor, MI", "depart_at", "07:40", seats=3)),
    person("dana", "Dana Brooks", "Fenton, MI", "(810) 555-0177", ride("DRIVER", "Fenton, MI", "Ann Arbor, MI", "depart_at", "08:00", seats=2)),
    person("omar", "Omar Haddad", "Lansing, MI", "(517) 555-0131", ride("DRIVER", "Lansing, MI", "Detroit, MI", "depart_at", "07:15", seats=3)),
    person("grace", "Grace Okafor", "Howell, MI", "(517) 555-0156", ride("DRIVER", "Howell, MI", "Ann Arbor, MI", "depart_at", "07:50", seats=2, recurring=False)),
    # Relay example: no one drives Grand Blanc -> Novi, but Priya (Flint -> Ann Arbor,
    # via Brighton) + Noah (Brighton -> Detroit, via Novi) make a 2-ride route for Zoe.
    person("noah", "Noah Williams", "Brighton, MI", "(810) 555-0133", ride("DRIVER", "Brighton, MI", "Detroit, MI", "depart_at", "08:40", seats=3)),
    # --- Find a ride: riders ---
    person("marcus", "Marcus Lee", "Grand Blanc, MI", "(810) 555-0199", ride("RIDER", "Grand Blanc, MI", "Ann Arbor, MI", "arrive_by", "09:00")),
    person("aisha", "Aisha Rahman", "Holly, MI", "(248) 555-0112", ride("RIDER", "Holly, MI", "Ann Arbor, MI", "arrive_by", "09:15", round_trip=True)),
    person("ben", "Ben Carter", "East Lansing, MI", "(517) 555-0190", ride("RIDER", "East Lansing, MI", "Detroit, MI", "arrive_by", "09:00")),
    person("lena", "Lena Fischer", "Brighton, MI", "(810) 555-0168", ride("RIDER", "Brighton, MI", "Ann Arbor, MI", "arrive_by", "08:45", recurring=False)),
    person("zoe", "Zoe Adams", "Grand Blanc, MI", "(810) 555-0121", ride("RIDER", "Grand Blanc, MI", "Novi, MI", "arrive_by", "09:20")),
    # --- Rent together ---
    person("riley", "Riley Chen", "Novi, MI", "(248) 555-0164", peer("rental", "Novi, MI", "Detroit, MI", "arrive_by", "10:00", people=2, vehicle="Pickup truck", moving=True)),
    person("kevin", "Kevin Nguyen", "Novi, MI", "(248) 555-0107", peer("rental", "Novi, MI", "Detroit, MI", "depart_at", "09:30", vehicle="SUV", round_trip=True)),
    person("sofia", "Sofia Martinez", "Livonia, MI", "(734) 555-0145", peer("rental", "Livonia, MI", "Detroit, MI", "arrive_by", "11:00", people=2, vehicle="Minivan", moving=True)),
    person("tom", "Tom Becker", "Ann Arbor, MI", "(734) 555-0183", peer("rental", "Ann Arbor, MI", "Detroit, MI", "depart_at", "08:30", people=3, vehicle="Box truck", moving=True)),
    # --- Share a cab ---
    person("jordan", "Jordan Kim", "Detroit, MI", "(313) 555-0123", peer("cab", "Detroit Metro Airport", "Downtown Detroit", "depart_at", "18:30")),
    person("sam", "Sam Rivera", "Detroit, MI", "(313) 555-0188", peer("cab", "Detroit Metro Airport", "Midtown Detroit", "depart_at", "18:15")),
    person("mia", "Mia Thompson", "Dearborn, MI", "(313) 555-0150", peer("cab", "Detroit Metro Airport", "Downtown Detroit", "depart_at", "18:45", people=2, round_trip=True)),
    person("ethan", "Ethan Park", "Romulus, MI", "(734) 555-0172", peer("cab", "Romulus, MI", "Downtown Detroit", "depart_at", "18:20")),
];

# Conversations. `end`: anonymous | pending (initiator approved the reveal) |
# revealed | closed (declined) | completed. `stars`: [initiator's rating of the
# other, other's rating of initiator] for completed trips.
# New travelers with no ratings on purpose: lena, grace, tom, ethan.
glob CONVERSATIONS: list[dict] = [
    {"from": "marcus", "to": "priya", "end": "pending", "messages": [
        "Hi! Looks like your Flint route passes right by Grand Blanc. Any room on weekday mornings?",
        "Hi! Yes, I have 3 seats. I leave Flint around 7:40.",
        "Perfect, I need to be in Ann Arbor by 9. Could we meet near the Grand Blanc library?",
        "The library lot works. Want to try this Monday?"
    ]},
    {"from": "marcus", "to": "dana", "end": "anonymous", "messages": [
        "Hey! Do you ever pass through Grand Blanc on your way from Fenton?",
        "Not usually, but it's only a small detour. What time do you need to arrive?"
    ]},
    {"from": "jordan", "to": "sam", "end": "revealed", "messages": [
        "Landing at DTW around 6:15 on Friday — want to split a cab downtown?",
        "Yes! I'm on the 6:05 arrival, McNamara terminal. Meet at baggage claim 7?",
        "Deal. I'll message when I land."
    ]},
    {"from": "aisha", "to": "priya", "end": "completed", "stars": [5, 5], "messages": [
        "Hi! I'm in Holly and need Ann Arbor by 9:15 — and back in the evening. Is that on your way?",
        "Holly is a quick hop off US-23 for me. Evenings I leave around 5:30, does that work?",
        "That's perfect for the return trip too. Thank you!",
        "See you Monday at the Holly Park & Ride."
    ], "comments": ["Right on time both ways, super friendly.", "Easy pickup and great company."], "tags": [["On time", "Friendly"], ["Easy pickup", "Respectful"]]},
    {"from": "aisha", "to": "dana", "end": "completed", "stars": [5, 4], "messages": [
        "Hi Dana! Priya's car is full on Thursday — could I ride with you that day?",
        "Sure, I pass Holly around 7:55. I'll message when I'm close."
    ], "comments": ["Saved my Thursday, thanks!", "Nice ride, a couple minutes late to the pickup."], "tags": [["Flexible", "Friendly"], ["Great communication"]]},
    {"from": "ben", "to": "omar", "end": "completed", "stars": [5, 4], "messages": [
        "Hi! I'm in East Lansing heading to Detroit for work. Could you pick up near MSU?",
        "Yes — I take I-96 anyway. Grand River & Harrison at 7:25?",
        "Works great. I'll chip in for gas.",
        "Appreciated. See you then."
    ], "comments": ["Smooth drive, left exactly on time.", "Great passenger, very punctual."], "tags": [["On time", "Safe driving"], ["On time", "Respectful"]]},
    {"from": "riley", "to": "kevin", "end": "completed", "stars": [4, 5], "messages": [
        "Hey! I'm renting a truck Novi -> Detroit Saturday to move a few boxes. Want to split it?",
        "I was about to rent an SUV for the same run — a truck works better. Half each?",
        "Half each. I'll book it for 9."
    ], "comments": ["Helpful with loading, thanks!", "Riley organized everything, easy split."], "tags": [["Flexible"], ["Great communication", "Friendly"]]},
    {"from": "sofia", "to": "riley", "end": "anonymous", "messages": [
        "Hi! I'm also moving to Detroit next week and need a minivan. Could we coordinate a rental?",
        "Possibly! How much stuff do you have? I've got about 10 boxes and a desk."
    ]},
    {"from": "kevin", "to": "sofia", "end": "closed", "messages": [
        "Hi, want to share an SUV from Novi to Detroit?",
        "Thanks, but I need something bigger for my move. Good luck!"
    ]},
    {"from": "mia", "to": "jordan", "end": "completed", "stars": [5, 5], "messages": [
        "Hi Jordan! Also at DTW around 6:30, heading downtown. Split an Uber?",
        "Absolutely — meet at the rideshare pickup, level 4?"
    ], "comments": ["Made the airport ride so much cheaper!", "Friendly and easy to find."], "tags": [["Easy pickup", "Friendly"], ["Easy pickup"]]},
    {"from": "sam", "to": "mia", "end": "completed", "stars": [4, 5], "messages": [
        "Hey Mia, I'm going to Midtown at about 6:15 — sharing a cab works if you don't mind a short stop.",
        "No problem, Midtown is on the way for me."
    ], "comments": ["Good company, a bit of a wait at pickup.", "Sam was great, would share again."], "tags": [["Friendly"], ["Respectful", "Great communication"]]},
    {"from": "lena", "to": "grace", "end": "pending", "messages": [
        "Hi Grace! I'm in Brighton heading to Ann Arbor on Saturday morning — any room?",
        "Hi Lena! I leave Howell at 7:50 and could pick you up in Brighton around 8:05."
    ]},
    {"from": "tom", "to": "sofia", "end": "revealed", "messages": [
        "Hey! I'm renting a moving van Ann Arbor -> Detroit. Want to share it and the cost?",
        "Yes please — a van is exactly what I need. Can you swing by Livonia?",
        "Livonia is on the way. Sharing my number so we can plan the loading."
    ]},
];

glob GREETING: str = "Hi! Along matched our journeys — I'm heading the same way. Want to coordinate?";

def call(path: str, body: dict, token: any = "") -> dict {
    headers = {"content-type": "application/json"};
    if token {
        headers["authorization"] = "Bearer " + str(token);
    }
    req = Request(API + path, data=json.dumps(body).encode("utf-8"), headers=headers, method="POST");
    try {
        resp: any = urlopen(req, timeout=60);
        raw: str = resp.read().decode("utf-8") as str;
        return json.loads(raw) as dict;
    } except HTTPError as e {
        return {"ok": False, "status": e.code, "error": e.read().decode("utf-8")[:300]};
    }
}

# Calls a server function and unwraps the response envelope.
def fn(name: str, token: any, args: dict) -> any {
    r = call("/function/" + name, args, token);
    if not r.get("ok", True) and "data" not in r {
        raise Exception(f"{name} failed: {r}");
    }
    data = r.get("data", r);
    return data.get("result", data) if isinstance(data, dict) else data;
}

# Registers the account if needed, logs in. Returns (token, created_now).
def ensure_account(p: dict) -> tuple[str, bool] {
    reg = call("/user/register", {
        "identities": [{"type": "email", "value": p["email"]}],
        "credential": {"type": "password", "password": PASSWORD}
    });
    created = reg.get("ok", False) is True;
    login = call("/user/login", {
        "identity": {"type": "email", "value": p["email"]},
        "credential": {"type": "password", "password": PASSWORD}
    });
    token = (login.get("data") or {}).get("token", "");
    if not token {
        raise Exception(f"Could not log in as {p['email']}: {login}. Was it created with a different SEED_PASSWORD?");
    }
    return (token, created);
}

# Reuse the journey this script posted earlier (tagged with SEED_NOTE) so
# re-runs never duplicate matches or conversations.
def ensure_trip(p: dict, token: str) -> dict {
    for existing in fn("get_my_trips", token, {}) {
        if existing["notes"] == SEED_NOTE {
            return existing as dict;
        }
    }
    t = p["trip"];
    trip_id = fn("create_journey", token, {
        "mode": t["mode"], "role": t["role"], "origin_name": t["from"], "destination_name": t["to"],
        "travel_date": "" if t["recurring"] else NEXT_SAT, "time_preference": t["pref"], "time": t["time"],
        "recurring": t["recurring"], "flexible_minutes": 20, "seats_available": t["seats"],
        "people": t.get("people", 1), "max_detour_minutes": 15 if t["role"] == "DRIVER" else 0,
        "pickup_distance": "Up to 10 miles", "vehicle": t.get("vehicle", ""),
        "moving_help": t.get("moving", False), "age_pref": "No preference",
        "gender_pref": "No preference", "notes": SEED_NOTE,
        "origin_lat": 0.0, "origin_lng": 0.0, "destination_lat": 0.0, "destination_lng": 0.0,
        "round_trip": t.get("round_trip", False), "return_date": "", "space_needed": "",
        "age_min": 1, "age_max": 100, "gender_prefs": []
    });
    return fn("get_my_trip", token, {"trip_id": trip_id}) as dict;
}

def setup_people() -> dict {
    people: dict = {};
    for p in PEOPLE {
        (token, created) = ensure_account(p);
        basics = BASICS[p["key"]];
        fn("update_profile_details", token, {
            "display_name": p["name"], "home_region": p["area"], "phone": p["phone"],
            "age": basics[0], "gender": basics[1]
        });
        profile = fn("get_my_profile", token, {});
        trip = ensure_trip(p, token);
        people[p["key"]] = {**p, "token": token, "trip": trip, "profile": profile};
        print(f"  {'created ' if created else 'exists  '} {p['email']:<26} {trip['owner_handle']:<11} {trip['mode']:<6} {trip['origin_name']} -> {trip['destination_name']}");
    }
    return people;
}

def seed_conversations(people: dict) -> None {
    for c in CONVERSATIONS {
        a = people[c["from"]];
        b = people[c["to"]];
        cards = fn("run_matching", a["token"], {"trip_id": a["trip"]["id"]});
        found = [m for m in cards if m["other_trip"] and m["other_trip"]["id"] == b["trip"]["id"]];
        if not found {
            print(f"  ! no match between {a['name']} and {b['name']} — skipped");
            continue;
        }
        match_id = found[0]["id"];
        convo = fn("create_anonymous_connection", a["token"], {"match_id": match_id});
        if len(convo["messages"] as list) == 0 {
            for (i, body) in enumerate(c["messages"] as list) {
                sender = a if i % 2 == 0 else b;
                fn("send_message", sender["token"], {"match_id": match_id, "body": body});
            }
        }
        end = c["end"];
        if end in ["pending", "revealed"] {
            fn("approve_identity_reveal", a["token"], {"match_id": match_id});
        }
        if end == "revealed" {
            fn("approve_identity_reveal", b["token"], {"match_id": match_id});
        }
        if end == "closed" {
            fn("close_match", b["token"], {"match_id": match_id});   # the other side declines
        }
        if end == "completed" {
            fn("complete_match", a["token"], {"match_id": match_id});
            stars = c["stars"];
            comments = c.get("comments", ["", ""]);
            # rate_match refuses a second rating, so re-runs don't stack reviews.
            tags = c.get("tags", [[], []]);
            fn("rate_match", a["token"], {"match_id": match_id, "stars": stars[0], "comment": comments[0], "tags": tags[0]});
            fn("rate_match", b["token"], {"match_id": match_id, "stars": stars[1], "comment": comments[1], "tags": tags[1]});
        }
        state = fn("get_conversation", a["token"], {"match_id": match_id});
        print(f"  {a['name']:<14} <-> {b['name']:<14} {c['end']:<10} {len(state['messages'] as list)} messages");
    }
}

# Test users say hello to every real (non-test, non-demo) person they match.
def greet(people: dict) -> None {
    test_handles = set([p["trip"]["owner_handle"] for p in people.values()]);
    sent = 0;
    for p in people.values() {
        for m in fn("run_matching", p["token"], {"trip_id": p["trip"]["id"]}) {
            other: str = m["other_handle"] as str;
            # Real travelers have two-word anonymous names; demo travelers are one word.
            is_real = " " in other;
            if not is_real or other in test_handles {
                continue;
            }
            convo = fn("create_anonymous_connection", p["token"], {"match_id": m["id"]});
            if len(convo["messages"] as list) == 0 {
                fn("send_message", p["token"], {"match_id": m["id"], "body": GREETING});
                print(f"  {p['name']} ({p['trip']['owner_handle']}) -> {other}");
                sent += 1;
            }
        }
    }
    if sent == 0 {
        print("  No new real matches to greet. Post a journey from your account that overlaps a test user, then re-run.");
    }
}

with entry:__main__ {
    mode = sys.argv[-1] if len(sys.argv) > 1 and sys.argv[-1] in ["greet"] else "seed";
    print(f"Along test users -> {API}");
    people = setup_people();
    # ~270 sample journeys (drivers, riders, rentals, cabs) so every search has matches.
    print("  " + str(fn("seed_demo_network", people["priya"]["token"], {})));
    if mode == "greet" {
        print("Greeting your matches:");
        greet(people);
    } else {
        print("Conversations:");
        seed_conversations(people);
    }
    print(f"\nAll test accounts use the password: {PASSWORD}");
}
