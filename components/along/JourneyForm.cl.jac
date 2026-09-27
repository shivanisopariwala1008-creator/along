"""JourneyForm — step 1 for all four journey types. Up front: pickup, dropoff
(picked from a Google Places dropdown when a Maps key is configured) and
round trip. Timing, vehicle and match preferences sit under "More options"
with sensible defaults. Submitting posts a Trip and opens the results."""

import from "@jac/runtime" { useNavigate, useParams, Navigate }
import from "@vis.gl/react-google-maps" { APIProvider }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from .PlaceInput { PlaceInput }
import from ...lib.along { flow_info, mode_of, role_of, today_iso }
sv import from ...services.along { create_journey, get_maps_config, MapsConfigView }

glob VEHICLES: list[list[str]] = [
    ["Compact", "4 people · light luggage"], ["Sedan", "5 people · medium luggage"],
    ["SUV", "5–7 people · extra cargo"], ["Minivan", "7 people · roomy cargo"],
    ["Pickup", "2–5 people · standard or full-size"], ["Moving van", "2–3 people · large cargo"],
];

glob DISTANCES: list[str] = ["Up to 2 miles", "Up to 5 miles", "Up to 10 miles"];

# Route wrapper: keying on the journey type resets the form when switching types.
def:pub JourneyRoute() -> JsxElement {
    params = useParams();
    kind: str = (params["kind"] or "") as str;
    if kind not in ["ride", "buddy", "rental", "cab"] {
        return <Navigate to="/journey/ride" replace={True} />;
    }
    return <JourneyForm key={kind} kind={kind} />;
}

def:pub JourneyForm(kind: str) -> JsxElement {
    info = flow_info(kind);

    has origin_name: str = "",
        destination_name: str = "",
        origin_lat: float = 0.0,
        origin_lng: float = 0.0,
        destination_lat: float = 0.0,
        destination_lng: float = 0.0,
        round_trip: bool = False,
        show_more: bool = False,
        places_down: bool = False,
        maps_key: str = "",
        recurring: bool = kind == "ride" or kind == "buddy",
        travel_date: str = today_iso(),
        time_preference: str = "depart_at" if kind == "buddy" or kind == "cab" else "arrive_by",
        time: str = "18:30" if kind == "cab" else ("07:40" if kind == "buddy" else "09:00"),
        distance: str = "Up to 5 miles",
        count: int = 3 if kind == "buddy" else 1,
        vehicle: str = "SUV",
        moving_help: bool = kind == "rental",
        age_pref: str = "No preference",
        gender_pref: str = "No preference",
        submitting: bool = False,
        error: str = "";

    nav = useNavigate();

    async can with entry {
        cfg: MapsConfigView | None = await get_maps_config();
        if cfg {
            maps_key = cfg.api_key;
        }
    }

    def swap(e: MouseEvent) {
        a = origin_name;
        a_lat = origin_lat;
        a_lng = origin_lng;
        origin_name = destination_name;
        origin_lat = destination_lat;
        origin_lng = destination_lng;
        destination_name = a;
        destination_lat = a_lat;
        destination_lng = a_lng;
    }

    # Typing after a pick invalidates it until another suggestion is chosen.
    def type_origin(v: str) {
        origin_name = v;
        origin_lat = 0.0;
        origin_lng = 0.0;
    }
    def type_destination(v: str) {
        destination_name = v;
        destination_lat = 0.0;
        destination_lng = 0.0;
    }
    def pick_origin(name: str, lat: float, lng: float) {
        origin_name = name;
        origin_lat = lat;
        origin_lng = lng;
    }
    def pick_destination(name: str, lat: float, lng: float) {
        destination_name = name;
        destination_lat = lat;
        destination_lng = lng;
    }

    async def handle_submit(e: FormEvent) {
        e.preventDefault();
        if not origin_name.strip() or not destination_name.strip() {
            error = "Please select a pickup and a dropoff location.";
            return;
        }
        # Require a dropdown pick while Google place search works; if it's down,
        # accept typed names and let the server geocode them.
        if maps_key and not places_down and (not origin_lat or not destination_lat) {
            error = "Please choose the pickup and dropoff from the suggestions list.";
            return;
        }
        if not recurring and not travel_date {
            error = "Please pick a date for a one-time journey.";
            return;
        }
        if not time {
            error = "Please choose a time.";
            return;
        }
        submitting = True;
        error = "";
        # Local names match the server parameters one-to-one.
        mode = mode_of(kind);
        role = role_of(kind);
        detour_by_distance = {"Up to 2 miles": 5, "Up to 5 miles": 10, "Up to 10 miles": 20};
        flexible_minutes = 20;
        seats_available = count if kind == "buddy" else 0;
        people = 1 if kind == "buddy" else count;
        max_detour_minutes = detour_by_distance[distance] if kind == "buddy" else 0;
        pickup_distance = "" if kind == "cab" else distance;
        notes = "";
        try {
            trip_id = await create_journey(
                mode, role, origin_name, destination_name, travel_date, time_preference, time,
                recurring, flexible_minutes, seats_available, people, max_detour_minutes,
                pickup_distance, vehicle, moving_help, age_pref, gender_pref, notes,
                origin_lat, origin_lng, destination_lat, destination_lng, round_trip
            );
            nav("/results?tripId=" + trip_id);
        } except Exception as ex {
            error = "We couldn’t post your journey. Please try again.";
            submitting = False;
        }
    }

    step_prefs = "4" if kind == "rental" else "3";
    distance_label = "Maximum detour" if kind == "buddy" else ("Acceptable pickup distance" if kind == "rental" else "Maximum pickup distance");
    count_options = [1, 2, 3, 4];

    return <div className="app-shell">
        <AppHeader progress={True} />
        <main className="form-page">
            <div className="form-header">
                <button className="back-link" onClick={lambda (e: MouseEvent) { nav("/"); }}><Icon name="back" /> Back</button>
                <div className={"flow-badge " + info["accent"]}><Icon name={info["icon"]} /></div>
                <span className="step-kicker">{"Step 1 of 2 · " + info["eyebrow"]}</span>
                <h1>{info["heading"]}</h1>
                <p>{info["description"]}</p>
            </div>
            <form className="journey-form" onSubmit={handle_submit}>
                <section className="form-card">
                    <div className="form-card-title">
                        <span>1</span>
                        <div>
                            <h2>{"Rental route" if kind == "rental" else "Journey"}</h2>
                            <p>We only show approximate areas to potential matches.</p>
                        </div>
                    </div>
                    <div className="route-fields">
                        <span className="route-rail"><i /><i /></span>
                        {if maps_key {
                            <APIProvider key="places" apiKey={maps_key}>
                                <PlaceInput
                                    label="Pickup" placeholder="Select a pickup location"
                                    value={origin_name} picked={origin_lat != 0.0}
                                    onType={type_origin} onPick={pick_origin}
                                    onUnavailable={lambda { places_down = True; }}
                                />
                                <button type="button" className="swap-btn" aria-label="Swap locations" onClick={swap}><Icon name="swap" /></button>
                                <PlaceInput
                                    label="Dropoff" placeholder="Select a dropoff location"
                                    value={destination_name} picked={destination_lat != 0.0}
                                    onType={type_destination} onPick={pick_destination}
                                    onUnavailable={lambda { places_down = True; }}
                                />
                            </APIProvider>
                        } else {
                            <TextField
                                key="from" label="Pickup" placeholder="Select a pickup location"
                                value={origin_name} icon="pin" onValue={type_origin}
                            />
                            <button key="swap" type="button" className="swap-btn" aria-label="Swap locations" onClick={swap}><Icon name="swap" /></button>
                            <TextField
                                key="to" label="Dropoff" placeholder="Select a dropoff location"
                                value={destination_name} icon="pin" onValue={type_destination}
                            />
                        }}
                    </div>
                    <label className="moving-toggle round-trip-toggle">
                        <input type="checkbox" checked={round_trip} onChange={lambda (e: ChangeEvent) { round_trip = not round_trip; }} />
                        <span><Icon name="swap" /></span>
                        <div><strong>Round trip</strong><small>I’m also coming back the same way</small></div>
                        <i />
                    </label>
                </section>

                <button type="button" className="more-options" onClick={lambda (e: MouseEvent) { show_more = not show_more; }} aria-expanded={show_more}>
                    <Icon name="tune" />
                    <span><strong>More options</strong><small>{("Timing, vehicle and" if kind == "rental" else "Timing and") + " match preferences — optional"}</small></span>
                    <Icon name="chevron" className={"more-chevron" + (" open" if show_more else "")} />
                </button>
                {if show_more {
                    <section key="timing" className="form-card">
                        <div className="form-card-title">
                            <span>2</span>
                            <div><h2>Timing &amp; flexibility</h2><p>Tell us what works, and we’ll find the best overlap.</p></div>
                        </div>
                        <div className="field-grid">
                            <SelectField
                                label="Journey type" value={"Recurring" if recurring else "One time"}
                                options={["One time", "Recurring"]}
                                onValue={lambda (v: str) { recurring = v == "Recurring"; }}
                            />
                            {if recurring {
                                <TextField key="days" label="Days" value="Weekdays (Mon–Fri)" icon="calendar" readOnly={True} onValue={lambda (v: str) { }} />
                            } else {
                                <TextField
                                    key="date" label={"Pickup date" if kind == "rental" else "Date"} value={travel_date}
                                    icon="calendar" inputType="date" onValue={lambda (v: str) { travel_date = v; }}
                                />
                            }}
                            <SelectField
                                label="Time preference"
                                value={"Arrive by" if time_preference == "arrive_by" else "Preferred departure"}
                                options={["Preferred departure", "Arrive by"]}
                                onValue={lambda (v: str) { time_preference = "arrive_by" if v == "Arrive by" else "depart_at"; }}
                            />
                            <TextField label="Time" value={time} icon="clock" inputType="time" onValue={lambda (v: str) { time = v; }} />
                            {if kind != "cab" {
                                <SelectField key="distance" label={distance_label} value={distance} options={DISTANCES} onValue={lambda (v: str) { distance = v; }} />
                            }}
                            <SelectField
                                label={"Available seats" if kind == "buddy" else "Number of people"}
                                value={_count_label(kind, count)}
                                options={[_count_label(kind, n) for n in count_options]}
                                onValue={lambda (v: str) { count = int(v.split(" ")[0]); }}
                            />
                        </div>
                    </section>

                    if kind == "rental" {
                        <section key="vehicle" className="form-card">
                            <div className="form-card-title">
                                <span>3</span>
                                <div><h2>Choose a vehicle type</h2><p>Capacity is a guide. You’ll confirm the vehicle together.</p></div>
                            </div>
                            <label className="moving-toggle">
                                <input type="checkbox" checked={moving_help} onChange={lambda (e: ChangeEvent) { moving_help = not moving_help; }} />
                                <span><Icon name="key" /></span>
                                <div><strong>I need help with moving</strong><small>Prioritize vehicles with more cargo space</small></div>
                                <i />
                            </label>
                            <div className="vehicle-grid">
                                {for v in VEHICLES {
                                    <button
                                        type="button" key={v[0]}
                                        className={"vehicle-card selected" if vehicle == v[0] else "vehicle-card"}
                                        onClick={lambda (e: MouseEvent) { vehicle = v[0]; }}
                                    >
                                        <span className={"vehicle-shape vehicle-" + v[0].lower().replace(" ", "-")}><Icon name="car" size={30} /></span>
                                        <strong>{v[0]}</strong>
                                        <small>{v[1]}</small>
                                        {vehicle == v[0] and <b><Icon name="check" size={14} /></b>}
                                    </button>
                                }}
                            </div>
                        </section>
                    }

                    <section key="prefs" className="form-card">
                        <div className="form-card-title">
                            <span>{step_prefs}</span>
                            <div><h2>Match preferences</h2><p>Every option includes “No preference.”</p></div>
                        </div>
                        <div className="field-grid">
                            <SelectField
                                label="Age preference" value={age_pref}
                                options={["No preference", "18–25", "26–40", "41–60", "60+"]}
                                onValue={lambda (v: str) { age_pref = v; }}
                            />
                            <SelectField
                                label="Gender preference" value={gender_pref}
                                options={["No preference", "Women", "Men", "Non-binary"]}
                                onValue={lambda (v: str) { gender_pref = v; }}
                            />
                        </div>
                        <div className="privacy-note">
                            <Icon name="shield" />
                            <span><strong>Your privacy comes first</strong><small>Exact addresses and identity stay private until both people agree.</small></span>
                        </div>
                    </section>
                }}
                {error and <p className="form-error" role="alert">{error}</p>}

                <div className="form-footer">
                    <span><Icon name="check" /> You can edit these details later</span>
                    <button type="submit" className="btn btn-primary" disabled={submitting}>
                        {"Posting your journey…" if submitting else info["submit"]}
                        <Icon name="arrow" />
                    </button>
                </div>
            </form>
        </main>
    </div>;
}

def _count_label(kind: str, n: int) -> str {
    if kind == "buddy" {
        return str(n) + (" seat" if n == 1 else " seats");
    }
    return str(n) + (" person" if n == 1 else " people");
}

def:pub TextField(
    label: str, value: str, onValue: Callable[[str], None], icon: str = "",
    inputType: str = "text", placeholder: str = "", readOnly: bool = False
) -> JsxElement {
    def handle(e: ChangeEvent) { onValue(e.target.value); }
    return <label className="field">
        <span>{label}</span>
        <div>
            {icon and <Icon name={icon} />}
            <input type={inputType} value={value} onChange={handle} placeholder={placeholder} readOnly={readOnly} />
        </div>
    </label>;
}

def:pub SelectField(label: str, value: str, options: list[str], onValue: Callable[[str], None]) -> JsxElement {
    def handle(e: ChangeEvent) { onValue(e.target.value); }
    return <label className="field">
        <span>{label}</span>
        <div>
            <select value={value} onChange={handle}>
                {for opt in options {
                    <option key={opt} value={opt}>{opt}</option>
                }}
            </select>
            <Icon name="chevron" />
        </div>
    </label>;
}
