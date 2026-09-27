"""JourneyForm — step 1 for all four journey types. Up front: pickup, dropoff
(picked from a Google Places dropdown when a Maps key is configured) and
round trip. Timing, vehicle and match preferences sit under "More options"
with sensible defaults. Submitting posts a Trip and opens the results."""

import from "@jac/runtime" { useNavigate, useParams, Navigate }
import from "@vis.gl/react-google-maps" { APIProvider }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from .PlaceInput { PlaceInput }
import from .TripAssistant { take_trip_draft }
import from ...lib.along { flow_info, mode_of, role_of, today_iso }
sv import from ...services.along { create_journey, get_maps_config, get_rental_spots, MapsConfigView, RentalSpotView }

# Rental vehicles, described by the cargo space they give you.
glob VEHICLES: list[list[str]] = [
    ["Compact car", "A few bags"], ["Sedan", "Suitcases, trunk space"],
    ["SUV", "Boxes + a small dresser"], ["Minivan", "Seats fold for bulky items"],
    ["Pickup truck", "Open bed for furniture"], ["Cargo van", "About a studio's worth"],
    ["Box truck", "A 1–2 bedroom move"],
];

glob SPACE_OPTIONS: list[str] = ["A few boxes", "Boxes + small furniture", "One room", "Studio / 1-bedroom", "2+ bedrooms"];

glob RIDE_TYPES: list[list[str]] = [
    ["ride", "car", "With a driver", "Someone already driving your way"],
    ["cab", "cab", "Split a cab", "Share a taxi or Uber fare"]
];

glob DISTANCES: list[str] = ["Up to 2 miles", "Up to 5 miles", "Up to 10 miles"],
     GENDERS: list[list[str]] = [["woman", "Women"], ["man", "Men"], ["non-binary", "Non-binary"]];

# Route wrapper: keying on the journey type resets the form when switching types.
def:pub JourneyRoute() -> JsxElement {
    params = useParams();
    kind: str = (params["kind"] or "") as str;
    if kind not in ["ride", "buddy", "rental", "cab"] {
        return <Navigate to="/journey/ride" replace={True} />;
    }
    return <JourneyForm key={"ride" if kind == "cab" else kind} route_kind={kind} />;
}

def:pub JourneyForm(route_kind: str) -> JsxElement {
    has ride_type: str = route_kind,            # "ride" (with a driver) or "cab" (split a cab)
        origin_name: str = "",
        destination_name: str = "",
        origin_lat: float = 0.0,
        origin_lng: float = 0.0,
        destination_lat: float = 0.0,
        destination_lng: float = 0.0,
        round_trip: bool = False,
        show_more: bool = False,
        places_down: bool = False,
        return_date: str = "",
        space_needed: str = "Boxes + small furniture",
        rental_spots: list[RentalSpotView] = [],
        spots_loading: bool = False,
        drop_spots: list[RentalSpotView] = [],
        drop_loading: bool = False,
        needs_driver: bool = False,
        draft_note: str = "",
        draft_sentence: str = "",
        maps_key: str = "",
        recurring: bool = route_kind == "ride" or route_kind == "buddy",
        travel_date: str = today_iso(),
        time_preference: str = "depart_at" if route_kind == "buddy" or route_kind == "cab" else "arrive_by",
        time: str = "18:30" if route_kind == "cab" else ("07:40" if route_kind == "buddy" else "09:00"),
        distance: str = "Up to 5 miles",
        count: int = 3 if route_kind == "buddy" else 1,
        vehicle: str = "SUV",
        moving_help: bool = False,
        age_pref: str = "No preference",
        gender_pref: str = "No preference",
        age_min: int = 1,
        age_max: int = 100,
        gender_prefs: list[str] = [],
        submitting: bool = False,
        error: str = "";

    nav = useNavigate();
    # "Find a ride" covers both: riding with a driver and splitting a cab.
    kind: str = ride_type if route_kind == "ride" or route_kind == "cab" else route_kind;
    info = flow_info(kind);

    def choose_type(t: str) {
        ride_type = t;
        time_preference = "depart_at" if t == "cab" else time_preference;
        window.history.replaceState(None, "", "/journey/" + t);  # jac:ignore[E1030]
    }

    # Pre-fill from the trip assistant's draft, if it just sent us here.
    can with entry {
        d: any = take_trip_draft();
        if not d {
            return;
        }
        origin_name = (d["origin_name"] or "") as str;
        origin_lat = (d["origin_lat"] or 0.0) as float;
        origin_lng = (d["origin_lng"] or 0.0) as float;
        destination_name = (d["destination_name"] or "") as str;
        destination_lat = (d["destination_lat"] or 0.0) as float;
        destination_lng = (d["destination_lng"] or 0.0) as float;
        round_trip = bool(d["round_trip"]);
        recurring = bool(d["recurring"]);
        if d["travel_date"] {
            travel_date = d["travel_date"] as str;
        }
        if d["time"] {
            time = d["time"] as str;
            time_preference = (d["time_preference"] or time_preference) as str;
        }
        if kind == "buddy" and d["seats"] {
            count = d["seats"] as int;
        } elif kind != "buddy" and d["people"] {
            count = d["people"] as int;
        }
        if d["vehicle"] {
            vehicle = d["vehicle"] as str;
        }
        moving_help = bool(d["moving_help"]) or moving_help;
        needs_driver = bool(d["needs_driver"]) or needs_driver;
        if d["gender_prefs"] {
            gender_prefs = d["gender_prefs"] as list[str];
        }
        if d["age_min"] {
            age_min = d["age_min"] as int;
        }
        if d["age_max"] {
            age_max = d["age_max"] as int;
        }
        show_more = True;   # let them see the timing the assistant picked
        draft_note = (d["summary"] or "") as str;
        draft_sentence = (d["sentence"] or "") as str;
    }

    # Rent together: list car-rental counters around the chosen pickup.
    async can with (origin_lat, origin_lng) entry {
        if kind != "rental" or not origin_lat or not origin_lng {
            rental_spots = [];
            return;
        }
        spots_loading = True;
        lat = origin_lat;
        lng = origin_lng;
        found: list[RentalSpotView] = await get_rental_spots(lat, lng);
        rental_spots = found;
        spots_loading = False;
    }

    # ...and around the dropoff, for returning the car.
    async can with (destination_lat, destination_lng) entry {
        if kind != "rental" or not destination_lat or not destination_lng {
            drop_spots = [];
            return;
        }
        drop_loading = True;
        lat = destination_lat;
        lng = destination_lng;
        found: list[RentalSpotView] = await get_rental_spots(lat, lng);
        drop_spots = found;
        drop_loading = False;
    }

    def use_spot(sp: RentalSpotView) {
        origin_name = sp.name + (", " + sp.address if sp.address else "");
        origin_lat = sp.lat;
        origin_lng = sp.lng;
    }

    def use_drop_spot(sp: RentalSpotView) {
        destination_name = sp.name + (", " + sp.address if sp.address else "");
        destination_lat = sp.lat;
        destination_lng = sp.lng;
    }

    async can with entry {
        cfg: MapsConfigView | None = await get_maps_config();
        if cfg {
            maps_key = cfg.api_key;
        }
    }

    def toggle_gender(g: str) {
        gender_prefs = [x for x in gender_prefs if x != g] if g in gender_prefs else gender_prefs + [g];
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
        if kind == "rental" {
            recurring = False;
            if not travel_date {
                error = "Please pick the rental pickup date.";
                return;
            }
            if return_date and return_date < travel_date {
                error = "The return date can’t be before the pickup date.";
                return;
            }
        } elif not recurring and not travel_date {
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
        if kind == "rental" {
            time_preference = "depart_at";   # a rental starts at its pickup time
        }
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
                origin_lat, origin_lng, destination_lat, destination_lng,
                round_trip and kind != "rental", return_date, space_needed,
                age_min, age_max, gender_prefs, needs_driver and kind == "rental"
            );
            nav("/results?tripId=" + trip_id);
        } except Exception as ex {
            error = "We couldn’t post your journey. Please try again.";
            submitting = False;
        }
    }

    step_prefs = "4" if kind == "rental" else "2";
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
                {if kind == "ride" or kind == "cab" {
                    <div key="how" className="ride-type" role="radiogroup" aria-label="How do you want to go?">
                        {for opt in RIDE_TYPES {
                            <button
                                key={opt[0]} type="button" role="radio" aria-checked={kind == opt[0]}
                                className={"ride-type-option" + (" on" if kind == opt[0] else "")}
                                onClick={lambda (e: MouseEvent) { choose_type(opt[0]); }}
                            >
                                <Icon name={opt[1]} />
                                <span><strong>{opt[2]}</strong><small>{opt[3]}</small></span>
                            </button>
                        }}
                    </div>
                }}
            </div>
            {if draft_note or draft_sentence {
                <div key="draft" className="assistant-banner" role="status">
                    <Icon name="spark" />
                    <div>
                        <strong>Filled in by Along’s assistant — check it, then post</strong>
                        <p>{draft_note}</p>
                        {draft_sentence and <small>{"You said: “" + draft_sentence + "”"}</small>}
                    </div>
                </div>
            }}
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
                    {if kind != "rental" {
                        <label key="round" className="moving-toggle round-trip-toggle">
                            <input type="checkbox" checked={round_trip} onChange={lambda (e: ChangeEvent) { round_trip = not round_trip; }} />
                            <span><Icon name="swap" /></span>
                            <div><strong>Round trip</strong><small>I’m also coming back the same way</small></div>
                            <i />
                        </label>
                    } else {
                        <div key="spot-lists" className="rental-spot-lists">
                            {if origin_lat {
                                <RentalSpots
                                    key="pick" title="Rental counters near your pickup" spots={rental_spots}
                                    loading={spots_loading} action="Use as pickup" onUse={use_spot}
                                />
                            }}
                            {if destination_lat {
                                <RentalSpots
                                    key="drop" title="Return counters near your dropoff" spots={drop_spots}
                                    loading={drop_loading} action="Use as dropoff" onUse={use_drop_spot}
                                />
                            }}
                        </div>
                    }}
                </section>

                {if kind == "rental" {
                    <section key="dates" className="form-card">
                        <div className="form-card-title">
                            <span>2</span>
                            <div><h2>Rental dates</h2><p>When you’ll pick the car up and bring it back.</p></div>
                        </div>
                        <div className="field-grid">
                            <TextField label="Pickup date" value={travel_date} icon="calendar" inputType="date" onValue={lambda (v: str) { travel_date = v; }} />
                            <TextField label="Pickup time" value={time} icon="clock" inputType="time" onValue={lambda (v: str) { time = v; }} />
                            <TextField label="Return date" value={return_date} icon="calendar" inputType="date" onValue={lambda (v: str) { return_date = v; }} />
                            <SelectField
                                label="People sharing the rental" value={_count_label(kind, count)}
                                options={[_count_label(kind, n) for n in count_options]}
                                onValue={lambda (v: str) { count = int(v.split(" ")[0]); }}
                            />
                            <SelectField label="How far you’ll go to the counter" value={distance} options={DISTANCES} onValue={lambda (v: str) { distance = v; }} />
                        </div>
                    </section>
                    <section key="vehicle" className="form-card">
                        <div className="form-card-title">
                            <span>3</span>
                            <div><h2>Vehicle &amp; space</h2><p>Pick by how much you need to carry. You’ll confirm the exact car together.</p></div>
                        </div>
                        <label className="moving-toggle">
                            <input type="checkbox" checked={moving_help} onChange={lambda (e: ChangeEvent) { moving_help = not moving_help; }} />
                            <span><Icon name="key" /></span>
                            <div><strong>I’m moving things</strong><small>We’ll favor partners and vehicles with cargo space</small></div>
                            <i />
                        </label>
                        {if moving_help {
                            <div key="space" className="field-grid space-grid">
                                <SelectField label="Space you need" value={space_needed} options={SPACE_OPTIONS} onValue={lambda (v: str) { space_needed = v; }} />
                            </div>
                        }}
                        <label className="moving-toggle driver-toggle">
                            <input type="checkbox" checked={needs_driver} onChange={lambda (e: ChangeEvent) { needs_driver = not needs_driver; }} />
                            <span><Icon name="user" /></span>
                            <div><strong>I need someone to drive</strong><small>Don’t drive? We’ll only match you with partners who can.</small></div>
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
                }}

                <section className="form-card">
                    <div className="form-card-title">
                        <span>{step_prefs}</span>
                        <div><h2>Who you’d like to travel with</h2><p>Optional — leave these as they are to match with anyone.</p></div>
                    </div>
                    <AgeRange min_age={age_min} max_age={age_max} onChange={lambda (lo: int, hi: int) { age_min = lo; age_max = hi; }} />
                    <div className="pref-block">
                        <div className="pref-head"><span className="pref-label">Gender</span><strong>{"Anyone" if len(gender_prefs) == 0 else str(len(gender_prefs)) + " selected"}</strong></div>
                        <div className="chip-row">
                            {for g in GENDERS {
                                <button
                                    key={g[0]} type="button" aria-pressed={g[0] in gender_prefs}
                                    className={"tag-chip" + (" on" if g[0] in gender_prefs else "")}
                                    onClick={lambda (e: MouseEvent) { toggle_gender(g[0]); }}
                                >
                                    {g[0] in gender_prefs and <Icon name="check" size={13} />} {g[1]}
                                </button>
                            }}
                        </div>
                    </div>
                    <div className="privacy-note">
                        <Icon name="shield" />
                        <span><strong>Your privacy comes first</strong><small>Everyone’s age and gender are used only for matching — they’re never shown on profiles.</small></span>
                    </div>
                </section>

                {kind != "rental" and <button type="button" className="more-options" onClick={lambda (e: MouseEvent) { show_more = not show_more; }} aria-expanded={show_more}>
                    <Icon name="tune" />
                    <span><strong>More options</strong><small>Timing and number of people — optional</small></span>
                    <Icon name="chevron" className={"more-chevron" + (" open" if show_more else "")} />
                </button>}
                {if show_more {
                    if kind != "rental" {
                    <section key="timing" className="form-card">
                        <div className="form-card-title">
                            <span>3</span>
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

                    }


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
    if kind == "rental" {
        return "1 person (just me)" if n == 1 else str(n) + " people sharing";
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

# Two-handle age slider, 1 to 100+ ("Any age" when fully open).
def:pub AgeRange(min_age: int, max_age: int, onChange: Callable[[int, int], None]) -> JsxElement {
    def set_low(e: ChangeEvent) {
        v: int = int(e.target.value);
        onChange(min(v, max_age - 1), max_age);
    }
    def set_high(e: ChangeEvent) {
        v: int = int(e.target.value);
        onChange(min_age, max(v, min_age + 1));
    }
    left: float = (min_age - 1) / 99 * 100;
    right: float = (max_age - 1) / 99 * 100;
    label = "Any age" if min_age <= 1 and max_age >= 100 else (str(min_age) + " – " + (str(max_age) if max_age < 100 else "100+"));
    return <div className="pref-block">
        <div className="pref-head"><span className="pref-label">Age</span><strong>{label}</strong></div>
        <div className="age-range">
            <div className="age-track"><i style={{"left": str(left) + "%", "width": str(right - left) + "%"}} /></div>
            <input type="range" min="1" max="100" step="1" value={str(min_age)} onChange={set_low} aria-label="Youngest age" />
            <input type="range" min="1" max="100" step="1" value={str(max_age)} onChange={set_high} aria-label="Oldest age" />
        </div>
        <div className="age-scale"><span>1</span><span>100+</span></div>
    </div>;
}

# Car-rental counters around a point, with a button to use one.
def RentalSpots(
    title: str, spots: list[RentalSpotView], loading: bool, action: str,
    onUse: Callable[[RentalSpotView], None]
) -> JsxElement {
    return <div className="rental-spots">
        <div className="rental-spots-head">
            <Icon name="key" size={16} />
            <strong>{title}</strong>
            <small>{"Looking…" if loading else (str(len(spots)) + " within 20 km")}</small>
        </div>
        {if not loading and len(spots) == 0 {
            <p key="none" className="rental-empty">No rental counters found nearby — try a larger town or the airport.</p>
        }}
        <ul>
            {for sp in spots[:5] {
                <li key={sp.name + sp.address}>
                    <div>
                        <strong>{sp.name}</strong>
                        <small>{str(sp.km) + " km" + (f" · ★ {sp.rating:.1f} ({sp.reviews})" if sp.reviews else "") + (" · " + sp.address if sp.address else "")}</small>
                    </div>
                    <a href={sp.maps_url} target="_blank" rel="noreferrer">Map ↗</a>
                    <button type="button" className="btn btn-secondary" onClick={lambda (e: MouseEvent) { onUse(sp); }}>{action}</button>
                </li>
            }}
        </ul>
    </div>;
}
