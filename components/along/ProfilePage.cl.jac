"""ProfilePage — Figma "Profile & trust": your account, what you share, and
what other travelers see. You never see your own score or who rated you."""

import from "@jac/runtime" { useNavigate, jacLogout }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from .SafetyActions { SafetyDialog }
import from ...lib.along { parse_age, initials, plural, flow_info, flow_of_trip, short_place, trip_timing }
sv import from ...services.along {
    get_my_profile, update_profile_details, get_my_trips, get_blocked, unblock_user, get_my_relay_plans,
    get_my_ratings, close_match, remove_journey,
    ProfileView, TripView, BlockedView, RelayPlanView, GivenRatingView
}

def:pub ProfilePage() -> JsxElement {
    has profile: ProfileView | None = None,
        trips: list[TripView] = [],
        blocked: list[BlockedView] = [],
        plans: list[RelayPlanView] = [],
        rated: list[GivenRatingView] = [],
        blocking: GivenRatingView | None = None,
        confirm_remove: str = "",
        confirm_trip: str = "",
        editing: bool = False,
        name_draft: str = "",
        region_draft: str = "",
        phone_draft: str = "",
        age_draft: str = "",
        gender_draft: str = "",
        saving: bool = False,
        error: str = "";

    nav = useNavigate();

    async can with entry {
        profile = await get_my_profile();
        trips = await get_my_trips();
        blocked = await get_blocked();
        plans = await get_my_relay_plans();
        rated = await get_my_ratings();
    }

    async def remove_match(match_id: str) -> None {
        _ = await close_match(match_id);
        rated = [r for r in rated if r.match_id != match_id];
        confirm_remove = "";
    }

    async def drop_journey(trip_id: str) -> None {
        _ = await remove_journey(trip_id);
        trips = [t for t in trips if t.id != trip_id];
        confirm_trip = "";
    }

    async def after_block -> None {
        blocking = None;
        rated = await get_my_ratings();
        blocked = await get_blocked();
    }

    async def unblock(key: str) -> None {
        _ = await unblock_user(key);
        blocked = [b for b in blocked if b.key != key];
    }

    def start_edit(e: MouseEvent) {
        if profile is not None {
            name_draft = profile.display_name;
            region_draft = profile.home_region;
            phone_draft = profile.phone;
            age_draft = str(profile.age) if profile.age else "";
            gender_draft = profile.gender;
        }
        error = "";
        editing = True;
    }

    async def save -> None {
        if not name_draft.strip() {
            error = "Please enter your name.";
            return;
        }
        if not (13 <= parse_age(age_draft) <= 120) {
            error = "Please enter your age (13 or older).";
            return;
        }
        if not gender_draft {
            error = "Please choose your gender.";
            return;
        }
        saving = True;
        # Local names match the server parameters.
        display_name = name_draft;
        home_region = region_draft;
        phone = phone_draft;
        age: int = parse_age(age_draft);
        gender = gender_draft;
        profile = await update_profile_details(display_name, home_region, phone, age, gender);
        saving = False;
        editing = False;
    }

    def logout(e: MouseEvent) {
        jacLogout();
        nav("/");
    }

    p = profile;
    name = (p.display_name or p.rider_handle) if p is not None else "";
    region = (p.home_region or "Michigan") if p is not None else "";
    since = ("Member since " + p.member_since) if (p is not None and p.member_since) else "Along member";

    return <div className="app-shell">
        <AppHeader />
        <main className="profile-page page-width">
            <div className="profile-header">
                <div>
                    <span className="step-kicker">Your account</span>
                    <h1>Profile &amp; trust</h1>
                    <p>Control what you share and see how Along protects your journey.</p>
                </div>
                <div className="profile-header-actions">
                    <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { nav("/matches"); }}>My matches</button>
                    <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { nav("/"); }}>Back home</button>
                </div>
            </div>
            {if p is None {
                <div key="loading" className="loading-state"><span className="spinner" /></div>
                skip;
            }}
            <div className="profile-layout">
                <section className="account-card">
                    <div className="account-top">
                        <span className="avatar profile-avatar">{initials(name)}</span>
                        <div>
                            <h2>{name}</h2>
                            <p>{region + " · " + since}</p>
                        </div>
                        {not editing and <button className="btn btn-secondary" onClick={start_edit}>Edit profile</button>}
                    </div>
                    {if editing {
                        <div key="edit" className="edit-profile">
                            <label className="field">
                                <span>Name</span>
                                <div><input value={name_draft} onChange={lambda (e: ChangeEvent) { name_draft = e.target.value; }} autoComplete="name" /></div>
                            </label>
                            <label className="field">
                                <span>Home area</span>
                                <div><input value={region_draft} onChange={lambda (e: ChangeEvent) { region_draft = e.target.value; }} placeholder="Grand Blanc, Michigan" /></div>
                            </label>
                            <label className="field">
                                <span>Phone (hidden until you both reveal)</span>
                                <div><input type="tel" value={phone_draft} onChange={lambda (e: ChangeEvent) { phone_draft = e.target.value; }} placeholder="(810) 555-0148" autoComplete="tel" /></div>
                            </label>
                            <label className="field">
                                <span>Age</span>
                                <div><input type="number" min="1" max="120" value={age_draft} onChange={lambda (e: ChangeEvent) { age_draft = e.target.value; }} placeholder="e.g. 28" /></div>
                            </label>
                            <label className="field">
                                <span>Gender</span>
                                <div>
                                    <select value={gender_draft} onChange={lambda (e: ChangeEvent) { gender_draft = e.target.value; }}>
                                        <option value="" disabled>Choose…</option>
                                        <option value="woman">Woman</option>
                                        <option value="man">Man</option>
                                        <option value="non-binary">Non-binary</option>
                                    </select>
                                    <Icon name="chevron" />
                                </div>
                            </label>
                            <p className="edit-hint">Age and gender are only used for matching preferences. They’re never shown on your profile.</p>
                            {error and <p className="form-error">{error}</p>}
                            <div className="edit-actions">
                                <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { editing = False; }}>Cancel</button>
                                <button className="btn btn-primary" onClick={save} disabled={saving}>{"Saving…" if saving else "Save changes"}</button>
                            </div>
                        </div>
                    }}
                    <div className="visibility-note">
                        <Icon name="user" />
                        <div>
                            <strong>Your view</strong>
                            <p>You will never see your own aggregate rating or who rated you. Other people see a rating only after you receive one.</p>
                        </div>
                    </div>
                    <h3>Your journeys</h3>
                    {if len(trips) == 0 {
                        <p key="none" className="journeys-empty">
                            Nothing posted yet. <button className="link-button" onClick={lambda (e: MouseEvent) { nav("/journey/ride"); }}>Post a journey</button>
                        </p>
                    }}
                    <div className="journey-list">
                        {for pl in plans {
                            <button key={pl.id} className="journey-row" onClick={lambda (e: MouseEvent) { nav("/plans/" + pl.id); }}>
                                <span className="flow-badge small green"><Icon name="pin" size={16} /></span>
                                <span>
                                    <strong>{pl.route_from.split(",")[0] + " → " + pl.route_to.split(",")[0]}</strong>
                                    <small>{"2-ride trip · stop at " + pl.handoff_name + (" · needs your attention" if pl.needs_attention else "")}</small>
                                </span>
                                <em>View trip <Icon name="chevron" size={14} /></em>
                            </button>
                        }}
                        {for t in trips {
                            <div key={t.id} className="journey-row-wrap">
                                <button className="journey-row" onClick={lambda (e: MouseEvent) { nav("/results?tripId=" + t.id); }}>
                                    <span className={"flow-badge small " + flow_info(flow_of_trip(t))["accent"]}>
                                        <Icon name={flow_info(flow_of_trip(t))["icon"]} size={16} />
                                    </span>
                                    <span>
                                        <strong>{short_place(t.origin_name) + " → " + short_place(t.destination_name)}</strong>
                                        <small>{flow_info(flow_of_trip(t))["title"] + " · " + trip_timing(t)}</small>
                                    </span>
                                    <em>View matches <Icon name="chevron" size={14} /></em>
                                </button>
                                {if confirm_trip == t.id {
                                    <span key="confirm" className="row-confirm">
                                        Remove this journey?
                                        <button className="btn btn-danger" onClick={lambda (e: MouseEvent) { drop_journey(t.id); }}>Remove</button>
                                        <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { confirm_trip = ""; }}>Keep</button>
                                    </span>
                                } else {
                                    <button key="x" className="row-remove" aria-label="Remove journey" title="Remove journey" onClick={lambda (e: MouseEvent) { confirm_trip = t.id; }}><Icon name="x" size={15} /></button>
                                }}
                            </div>
                        }}
                    </div>
                    {if len(rated) > 0 {
                        <div key="rated" className="rated-list">
                            <h3>People you’ve rated</h3>
                            <p className="section-note">Only you can see this. You can change a rating any time — they never see who rated them.</p>
                            {for r in rated {
                                <div key={r.match_id} className="rated-row">
                                    <span className="avatar avatar-small">{initials(r.handle)}</span>
                                    <span className="rated-main">
                                        <strong>{r.handle}</strong>
                                        <span className="rated-stars" aria-label={str(r.stars) + " stars"}>
                                            {for n in [1, 2, 3, 4, 5] {
                                                <i key={str(n)} className={"on" if n <= r.stars else ""}>★</i>
                                            }}
                                            <small>{(r.route + " · " if r.route else "") + r.rated_on}</small>
                                        </span>
                                        {r.comment and <small className="rated-comment">{"“" + r.comment + "”"}</small>}
                                    </span>
                                    {if confirm_remove == r.match_id {
                                        <span key="confirm" className="row-confirm">
                                            Remove this match?
                                            <button className="btn btn-danger" onClick={lambda (e: MouseEvent) { remove_match(r.match_id); }}>Remove</button>
                                            <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { confirm_remove = ""; }}>Keep</button>
                                        </span>
                                    } else {
                                        <span key="actions" className="rated-actions">
                                            <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { nav("/rate/" + r.match_id); }}>Edit rating</button>
                                            <button className="link-button" onClick={lambda (e: MouseEvent) { blocking = r; }}>Block</button>
                                            <button className="link-button" onClick={lambda (e: MouseEvent) { confirm_remove = r.match_id; }}>Remove</button>
                                        </span>
                                    }}
                                </div>
                            }}
                        </div>
                    }}
                    {if blocking is not None {
                        <SafetyDialog
                            key="block" match_id={(blocking as GivenRatingView).match_id}
                            handle={(blocking as GivenRatingView).handle} mode="block"
                            onClose={lambda { after_block(); }}
                        />
                    }}
                    <h3>Trust &amp; verification</h3>
                    <div className="settings-list">
                        <div>
                            <span className="setting-icon"><Icon name="shield" /></span>
                            <span>
                                <strong>Email verification</strong>
                                <small>Confirm your email to add a badge to your profile</small>
                            </span>
                            <span className="soon-pill">Coming soon</span>
                        </div>
                        <div>
                            <span className="setting-icon"><Icon name="user" /></span>
                            <span>
                                <strong>Identity verification</strong>
                                <small>Verify your ID so others know you’re you</small>
                            </span>
                            <span className="soon-pill">Coming soon</span>
                        </div>
                        <div>
                            <span className="setting-icon"><Icon name="user" /></span>
                            <span>
                                <strong>Contact details</strong>
                                <small>{"Phone number added · Hidden by default" if p is not None and p.phone else "No phone number yet · Add one to share after a reveal"}</small>
                            </span>
                            <button className="icon-button" onClick={start_edit} aria-label="Edit contact details"><Icon name="chevron" /></button>
                        </div>
                        <div>
                            <span className="setting-icon"><Icon name="lock" /></span>
                            <span><strong>Privacy preferences</strong><small>Approximate location sharing enabled</small></span>
                            <Icon name="check" />
                        </div>
                        <div>
                            <span className="setting-icon"><Icon name="star" /></span>
                            <span>
                                <strong>Trips done</strong>
                                <small>{plural(p.completed_connections if p is not None else 0, "trip", "trips") + " completed with Along"}</small>
                            </span>
                        </div>
                    </div>
                    {if len(blocked) > 0 {
                        <div key="blocked" className="blocked-list">
                            <h3>Blocked travelers</h3>
                            {for bl in blocked {
                                <div key={bl.key} className="blocked-row">
                                    <span className="avatar avatar-small muted">{initials(bl.handle)}</span>
                                    <span><strong>{bl.handle}</strong><small>{"Blocked " + bl.since}</small></span>
                                    <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { unblock(bl.key); }}>Unblock</button>
                                </div>
                            }}
                        </div>
                    }}
                    <button className="btn btn-ghost logout-button" onClick={logout}><Icon name="logout" /> Log out</button>
                </section>
                <aside className="trust-card">
                    <Icon name="shield" size={32} />
                    <h2>Built for trust</h2>
                    <p>Along is designed so connection comes before disclosure.</p>
                    <ul>
                        <li><Icon name="check" /> Anonymous handles by default</li>
                        <li><Icon name="check" /> Mutual identity approval</li>
                        <li><Icon name="check" /> Approximate pickup areas</li>
                        <li><Icon name="check" /> Private, anonymous ratings</li>
                    </ul>
                    <div className="others-view">
                        <small>WHAT OTHERS SEE</small>
                        <div>
                            <span className="avatar">{initials(p.rider_handle if p is not None else "")}</span>
                            <span>
                                <strong>{p.rider_handle if p is not None else ""}</strong>
                                <em>{"Rated by the community" if p is not None and p.has_ratings else "New to Along"}</em>
                            </span>
                        </div>
                        <p>Your real name stays hidden until you both agree. No rating appears until you receive feedback.</p>
                    </div>
                </aside>
            </div>
        </main>
    </div>;
}
