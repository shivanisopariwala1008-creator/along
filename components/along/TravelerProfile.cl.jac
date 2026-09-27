"""TravelerProfile — another traveler's profile, opened through a match you
share: reputation, compliments and anonymous reviews, their journeys, and a
clear "new to Along" state. Real name, area and verification show only after
you've both agreed to reveal identities.

/people/:matchId
"""

import from "@jac/runtime" { useNavigate, useParams }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from ...lib.along { initials }
sv import from ...services.along { get_traveler_profile, TravelerProfileView, ReviewView }

def:pub TravelerProfileRoute() -> JsxElement {
    params = useParams();
    match_id: str = (params["matchId"] or "") as str;
    return <TravelerProfile key={match_id} match_id={match_id} />;
}

def:pub TravelerProfile(match_id: str) -> JsxElement {
    has profile: TravelerProfileView | None = None,
        loading: bool = True;

    nav = useNavigate();

    async can with entry {
        if match_id {
            profile = await get_traveler_profile(match_id);
        }
        loading = False;
    }

    if loading {
        return <div className="app-shell"><AppHeader /><main className="profile-page page-width"><div className="loading-state"><span className="spinner" /></div></main></div>;
    }
    if profile is None {
        return <div className="app-shell">
            <AppHeader />
            <main className="profile-page page-width">
                <div className="empty-state">
                    <span><Icon name="lock" size={30} /></span>
                    <h3>Profile unavailable</h3>
                    <p>You can only view travelers you've matched with.</p>
                    <button className="btn btn-primary" onClick={lambda (e: MouseEvent) { nav("/matches"); }}>Back to matches</button>
                </div>
            </main>
        </div>;
    }

    p = profile as TravelerProfileView;
    title = p.display_name if (p.revealed and p.display_name) else p.handle;

    return <div className="app-shell">
        <AppHeader />
        <main className="profile-page page-width traveler-page">
            <button className="back-link" onClick={lambda (e: MouseEvent) { nav(-1); }}><Icon name="back" /> Back</button>
            <div className="profile-layout">
                <section className="account-card">
                    <div className="traveler-hero">
                        <span className="avatar profile-avatar">{initials(title)}</span>
                        <div>
                            <span className="step-kicker">{"Revealed traveler" if p.revealed else "Anonymous traveler"}</span>
                            <h1>{title}</h1>
                            {p.revealed and p.display_name and <p className="handle-note">{"Along handle: " + p.handle}</p>}
                            <div className="traveler-badges">
                                {if p.is_new {
                                    <span key="new" className="badge-new"><Icon name="star" size={14} /> New to Along</span>
                                } else {
                                    <span key="rate" className="badge-rating">
                                        <Stars value={p.rating} /> <strong>{f"{p.rating:.1f}"}</strong>
                                        <small>{"· " + str(p.review_count) + (" review" if p.review_count == 1 else " reviews")}</small>
                                    </span>
                                }}
                                {p.revealed and p.verified and <span className="verified-pill"><Icon name="check" /> Identity verified</span>}
                            </div>
                            {if p.revealed and (p.home_region or p.member_since) {
                                <p key="where" className="traveler-where">
                                    {(p.home_region or "Michigan") + (" · Member since " + p.member_since if p.member_since else "")}
                                </p>
                            } elif not p.revealed {
                                <p key="hidden" className="traveler-where"><Icon name="lock" size={13} /> Name and area stay hidden until you both agree to reveal.</p>
                            }}
                        </div>
                    </div>

                    <div className="traveler-stats">
                        <div><strong>{"—" if p.is_new else f"{p.rating:.1f}"}</strong><small>Rating</small></div>
                        <div><strong>{str(p.review_count)}</strong><small>Reviews</small></div>
                        <div><strong>{str(p.journeys_posted)}</strong><small>Journeys posted</small></div>
                        <div><strong>{_types_text(p.journey_types)}</strong><small>Travels as</small></div>
                    </div>

                    {if len(p.top_tags) > 0 {
                        <div key="tags" className="traveler-section">
                            <h3>What people say</h3>
                            <div className="preference-chips compliment-chips">
                                {for t in p.top_tags {
                                    <span key={t}><Icon name="check" size={13} /> {t}</span>
                                }}
                            </div>
                        </div>
                    }}

                    <div className="traveler-section">
                        <h3>{"Reviews" if not p.is_new else "No reviews yet"}</h3>
                        {if p.is_new {
                            <div key="new" className="new-traveler-note">
                                <Icon name="star" />
                                <div>
                                    <strong>{p.handle + " is new to Along"}</strong>
                                    <p>New travelers haven't been rated yet. Chat first, meet at a public spot, and leave a review after your trip to help the community.</p>
                                </div>
                            </div>
                        } else {
                            <div key="list" className="review-list">
                                {for (i, r) in enumerate(p.reviews) {
                                    <ReviewItem key={str(i)} review={r} />
                                }}
                                {if len(p.reviews) < p.review_count {
                                    <p key="more" className="review-more">{"Showing " + str(len(p.reviews)) + " of " + str(p.review_count) + " reviews"}</p>
                                }}
                            </div>
                        }}
                    </div>
                </section>

                <aside className="trust-card traveler-actions">
                    <Icon name="shield" size={32} />
                    <h2>{"Connect with " + title}</h2>
                    <p>Reviews are anonymous: nobody sees who wrote them, only the stars and words.</p>
                    <button className="btn btn-primary full-button" onClick={lambda (e: MouseEvent) { nav("/chat/" + match_id); }}>
                        Message <Icon name="chat" />
                    </button>
                    <button className="btn btn-secondary full-button" onClick={lambda (e: MouseEvent) { nav("/matches/" + match_id); }}>
                        View match details
                    </button>
                    {if p.can_review and not p.already_reviewed {
                        <button key="review" className="btn btn-secondary full-button review-cta" onClick={lambda (e: MouseEvent) { nav("/rate/" + match_id); }}>
                            <Icon name="star" /> Leave a review
                        </button>
                    } elif p.already_reviewed {
                        <p key="done" className="reviewed-note"><Icon name="check" size={14} /> You reviewed this trip</p>
                    }}
                    <div className="safe-note">
                        <Icon name="lock" />
                        <span>Exact addresses and contact details are never shown without mutual permission.</span>
                    </div>
                </aside>
            </div>
        </main>
    </div>;
}

def _types_text(types: list[str]) -> str {
    if len(types) == 0 {
        return "—";
    }
    out = types[0];
    for t in types[1:] {
        out = out + " · " + t;
    }
    return out;
}

def:pub Stars(value: float, size: int = 14) -> JsxElement {
    return <span className="stars" aria-label={f"{value:.1f} out of 5 stars"}>
        {for n in [1, 2, 3, 4, 5] {
            <span key={str(n)} className={"star-slot" + (" on" if value >= n - 0.25 else (" half" if value >= n - 0.75 else ""))}>
                <Icon name="star" size={size} />
            </span>
        }}
    </span>;
}

def:pub ReviewItem(review: ReviewView) -> JsxElement {
    kind = "Rental" if review.mode == "rental" else ("Cab share" if review.mode == "cab" else "Ride");
    return <article className="review-item">
        <div className="review-top">
            <Stars value={float(review.stars)} size={13} />
            <small>{(review.rated_on or "Recently") + " · " + kind}</small>
        </div>
        {review.comment and <p>{"“" + review.comment + "”"}</p>}
        {if len(review.tags) > 0 {
            <div key="tags" className="review-tags">
                {for t in review.tags {
                    <span key={t}>{t}</span>
                }}
            </div>
        }}
    </article>;
}
