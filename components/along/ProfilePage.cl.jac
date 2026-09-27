"""ProfilePage — Figma "Profile & trust": your account, what you share, and
what other travelers see. You never see your own score or who rated you."""

import from "@jac/runtime" { useNavigate, jacLogout }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from ...lib.along { initials, plural, flow_info, flow_of_trip, short_place, trip_timing }
sv import from ...services.along { get_my_profile, update_profile_details, get_my_trips, ProfileView, TripView }

def:pub ProfilePage() -> JsxElement {
    has profile: ProfileView | None = None,
        trips: list[TripView] = [],
        editing: bool = False,
        name_draft: str = "",
        region_draft: str = "",
        phone_draft: str = "",
        saving: bool = False,
        error: str = "";

    nav = useNavigate();

    async can with entry {
        profile = await get_my_profile();
        trips = await get_my_trips();
    }

    def start_edit(e: MouseEvent) {
        if profile is not None {
            name_draft = profile.display_name;
            region_draft = profile.home_region;
            phone_draft = profile.phone;
        }
        error = "";
        editing = True;
    }

    async def save -> None {
        if not name_draft.strip() {
            error = "Please enter your name.";
            return;
        }
        saving = True;
        # Local names match the server parameters.
        display_name = name_draft;
        home_region = region_draft;
        phone = phone_draft;
        profile = await update_profile_details(display_name, home_region, phone);
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
                            {if p is not None and p.verified {
                                <span key="v" className="verified-pill"><Icon name="check" /> Identity verified</span>
                            } else {
                                <span key="nv" className="verified-pill pending"><Icon name="shield" /> Verification not started</span>
                            }}
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
                        {for t in trips {
                            <button key={t.id} className="journey-row" onClick={lambda (e: MouseEvent) { nav("/results?tripId=" + t.id); }}>
                                <span className={"flow-badge small " + flow_info(flow_of_trip(t))["accent"]}>
                                    <Icon name={flow_info(flow_of_trip(t))["icon"]} size={16} />
                                </span>
                                <span>
                                    <strong>{short_place(t.origin_name) + " → " + short_place(t.destination_name)}</strong>
                                    <small>{flow_info(flow_of_trip(t))["title"] + " · " + trip_timing(t)}</small>
                                </span>
                                <em>View matches <Icon name="chevron" size={14} /></em>
                            </button>
                        }}
                    </div>
                    <h3>Trust &amp; verification</h3>
                    <div className="settings-list">
                        <div>
                            <span className="setting-icon"><Icon name="shield" /></span>
                            <span><strong>Identity verification</strong><small>Verified privately · Never shown without mutual consent</small></span>
                            <b>{"Complete" if p is not None and p.verified else "Coming soon"}</b>
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
