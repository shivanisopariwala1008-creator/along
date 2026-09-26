"""Seed fake Along users for testing chat end to end.

Creates real (log-in-able) test accounts through the running server's API,
posts a journey for each, and opens a few anonymous conversations between
them with some messages — so you can log in as either side and chat.

    jac run scripts/seed_test_users.jac            # create users + conversations
    jac run scripts/seed_test_users.jac greet      # test users message YOUR matches

`greet`: post a journey from your own account first, then run this — each test
user whose route fits yours opens a conversation with you and says hello.

Env: ALONG_API (default http://localhost:8001), SEED_PASSWORD (default below).
Everything goes through the normal endpoints, so it lands in whichever
database the server is using (SQLite, or MongoDB when MONGODB_URI is set).
"""

import os;
import sys;
import json;
import from urllib.request { Request, urlopen }
import from urllib.error { HTTPError }

glob API: str = os.environ.get("ALONG_API", "http://localhost:8001").rstrip("/"),
     PASSWORD: str = os.environ.get("SEED_PASSWORD", "AlongTest123!");

# key, name, email, home area, phone, journey
glob PEOPLE: list[dict] = [
    {"key": "priya", "name": "Priya Shah", "email": "priya.test@example.com", "area": "Flint, MI",
     "phone": "(810) 555-0142", "trip": {"mode": "ride", "role": "DRIVER", "from": "Flint, MI",
     "to": "Ann Arbor, MI", "pref": "depart_at", "time": "07:40", "recurring": True, "seats": 3}},
    {"key": "dana", "name": "Dana Brooks", "email": "dana.test@example.com", "area": "Fenton, MI",
     "phone": "(810) 555-0177", "trip": {"mode": "ride", "role": "DRIVER", "from": "Fenton, MI",
     "to": "Ann Arbor, MI", "pref": "depart_at", "time": "08:00", "recurring": True, "seats": 2}},
    {"key": "marcus", "name": "Marcus Lee", "email": "marcus.test@example.com", "area": "Grand Blanc, MI",
     "phone": "(810) 555-0199", "trip": {"mode": "ride", "role": "RIDER", "from": "Grand Blanc, MI",
     "to": "Ann Arbor, MI", "pref": "arrive_by", "time": "09:00", "recurring": True, "seats": 0}},
    {"key": "jordan", "name": "Jordan Kim", "email": "jordan.test@example.com", "area": "Detroit, MI",
     "phone": "(313) 555-0123", "trip": {"mode": "cab", "role": "PEER", "from": "Detroit Metro Airport",
     "to": "Downtown Detroit", "pref": "depart_at", "time": "18:30", "recurring": False, "seats": 0}},
    {"key": "sam", "name": "Sam Rivera", "email": "sam.test@example.com", "area": "Detroit, MI",
     "phone": "(313) 555-0188", "trip": {"mode": "cab", "role": "PEER", "from": "Detroit Metro Airport",
     "to": "Midtown Detroit", "pref": "depart_at", "time": "18:15", "recurring": False, "seats": 0}},
    {"key": "riley", "name": "Riley Chen", "email": "riley.test@example.com", "area": "Novi, MI",
     "phone": "(248) 555-0164", "trip": {"mode": "rental", "role": "PEER", "from": "Novi, MI",
     "to": "Detroit, MI", "pref": "arrive_by", "time": "10:00", "recurring": False, "seats": 0,
     "vehicle": "Pickup", "moving": True}},
];

# initiator, other side, alternating messages (initiator first), does each side approve the reveal
glob CONVERSATIONS: list[dict] = [
    {"from": "marcus", "to": "priya", "reveal": [True, False], "messages": [
        "Hi! Looks like your Flint route passes right by Grand Blanc. Any room on weekday mornings?",
        "Hi! Yes, I have 3 seats. I leave Flint around 7:40.",
        "Perfect, I need to be in Ann Arbor by 9. Could we meet near the Grand Blanc library?",
        "The library lot works. Want to try this Monday?"
    ]},
    {"from": "marcus", "to": "dana", "reveal": [False, False], "messages": [
        "Hey! Do you ever pass through Grand Blanc on your way from Fenton?",
        "Not usually, but it's only a small detour. What time do you need to arrive?"
    ]},
    {"from": "jordan", "to": "sam", "reveal": [True, True], "messages": [
        "Landing at DTW around 6:15 on Friday — want to split a cab downtown?",
        "Yes! I'm on the 6:05 arrival, McNamara terminal. Meet at baggage claim 7?",
        "Deal. I'll message when I land."
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

def ensure_trip(p: dict, token: str) -> dict {
    trips = fn("get_my_trips", token, {});
    if trips {
        return trips[0] as dict;
    }
    t = p["trip"];
    trip_id = fn("create_journey", token, {
        "mode": t["mode"], "role": t["role"], "origin_name": t["from"], "destination_name": t["to"],
        "travel_date": "", "time_preference": t["pref"], "time": t["time"], "recurring": t["recurring"],
        "flexible_minutes": 20, "seats_available": t["seats"], "people": 1,
        "max_detour_minutes": 15 if t["role"] == "DRIVER" else 0, "pickup_distance": "Up to 10 miles",
        "vehicle": t.get("vehicle", ""), "moving_help": t.get("moving", False),
        "age_pref": "No preference", "gender_pref": "No preference", "notes": "Along test user"
    });
    return fn("get_my_trip", token, {"trip_id": trip_id}) as dict;
}

def setup_people() -> dict {
    people: dict = {};
    for p in PEOPLE {
        (token, created) = ensure_account(p);
        fn("update_profile_details", token, {"display_name": p["name"], "home_region": p["area"], "phone": p["phone"]});
        profile = fn("get_my_profile", token, {});
        trip = ensure_trip(p, token);
        people[p["key"]] = {**p, "token": token, "trip": trip, "profile": profile};
        print(f"  {'created ' if created else 'exists  '} {p['email']:<26} {trip['owner_handle']:<11} {trip['origin_name']} -> {trip['destination_name']}");
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
        if c["reveal"][0] {
            fn("approve_identity_reveal", a["token"], {"match_id": match_id});
        }
        if c["reveal"][1] {
            fn("approve_identity_reveal", b["token"], {"match_id": match_id});
        }
        state = fn("get_conversation", a["token"], {"match_id": match_id});
        print(f"  {a['name']} <-> {b['name']}: {len(state['messages'] as list)} messages, status {state['status']}");
    }
}

# Test users say hello to every real (non-test, non-demo) person they match.
def greet(people: dict) -> None {
    test_handles = set([p["trip"]["owner_handle"] for p in people.values()]);
    sent = 0;
    for p in people.values() {
        for m in fn("run_matching", p["token"], {"trip_id": p["trip"]["id"]}) {
            other = m["other_handle"];
            is_real = other.startswith("Rider ") or other.startswith("Driver ");
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
    if mode == "greet" {
        print("Greeting your matches:");
        greet(people);
    } else {
        print("Conversations:");
        seed_conversations(people);
    }
    print(f"\nAll test accounts use the password: {PASSWORD}");
}
