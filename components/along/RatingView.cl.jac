"""RatingView — Figma "How was your journey?". Ratings are stored without the
rater's identity; the other person only ever sees their aggregate."""

import from "@jac/runtime" { useNavigate, useParams }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from ...lib.along { initials, fmt_date }
sv import from ...services.along { get_match_details, get_conversation, rate_match, MatchDetailView, ConversationView }

glob STAR_LABELS: list[str] = ["Tap a star to rate", "Not great", "Could be better", "Good", "Great", "Excellent"];

def:pub RatingView() -> JsxElement {
    params = useParams();
    match_id: str = (params["matchId"] or "") as str;

    has detail: MatchDetailView | None = None,
        convo: ConversationView | None = None,
        stars: int = 0,
        comment: str = "",
        loading: bool = True,
        submitting: bool = False,
        error: str = "";

    nav = useNavigate();

    async can with entry {
        if match_id {
            detail = await get_match_details(match_id);
            convo = await get_conversation(match_id);
        }
        loading = False;
    }

    async def submit -> None {
        if stars == 0 {
            error = "Choose a star rating first, or skip for now.";
            return;
        }
        submitting = True;
        error = "";
        ok = await rate_match(match_id, stars, comment);
        submitting = False;
        if ok {
            nav("/profile");
        } else {
            error = "This journey was already rated.";
        }
    }

    card = detail.card if detail is not None else None;
    other_name = "";
    if convo is not None and convo.identity_revealed and convo.other_display_name {
        other_name = convo.other_display_name;
    } elif card is not None {
        other_name = card.other_handle;
    }
    when = "";
    if card is not None and card.my_trip is not None {
        when = "Weekday commute" if card.my_trip.recurring else fmt_date(card.my_trip.travel_date);
    }
    already = convo is not None and convo.i_rated;

    return <div className="app-shell">
        <AppHeader progress={True} />
        <main className="rating-page">
            <div className="rating-card">
                {if loading {
                    <div key="loading" className="loading-state"><span className="spinner" /></div>
                } elif card is None {
                    <div key="missing" className="empty-state">
                        <h3>Journey not found</h3>
                        <button className="btn btn-primary" onClick={lambda (e: MouseEvent) { nav("/matches"); }}>Back to matches</button>
                    </div>
                } else {
                    <span key="icon" className="success-icon"><Icon name="check" size={28} /></span>
                    <span key="kicker" className="step-kicker">Journey complete</span>
                    <h1 key="h">{"Thanks for your feedback" if already else "How was your journey?"}</h1>
                    <p key="p">Your anonymous feedback helps the Along community travel with confidence.</p>
                    <div key="person" className="rate-person">
                        <span className="avatar avatar-large">{initials(other_name)}</span>
                        <div><strong>{other_name}</strong><small>{"Your match" + ((" · " + when) if when else "")}</small></div>
                    </div>
                    if already {
                        <button key="done" className="btn btn-primary full-button rating-done" onClick={lambda (e: MouseEvent) { nav("/profile"); }}>Go to your profile <Icon name="arrow" /></button>
                    } else {
                        <div key="stars" className="star-picker" aria-label="Choose a rating">
                            {for n in [1, 2, 3, 4, 5] {
                                <button key={str(n)} className={"active" if n <= stars else ""} onClick={lambda (e: MouseEvent) { stars = n; }} aria-label={str(n) + " stars"}>
                                    <Icon name="star" size={32} />
                                </button>
                            }}
                        </div>
                        <small key="label" className="rating-label">{STAR_LABELS[stars]}</small>
                        <label key="comment" className="comment-field">
                            <span>Anything else? <em>Optional</em></span>
                            <textarea value={comment} onChange={lambda (e: ChangeEvent) { comment = e.target.value; }} placeholder="Share helpful, respectful feedback…" />
                        </label>
                        <div key="anon" className="anonymous-note">
                            <Icon name="lock" />
                            <span><strong>Your rating is anonymous</strong><small>They won’t see your rating, comment, or identity as a rater. Only their aggregate rating is visible to other users.</small></span>
                        </div>
                        if error {
                            <p key="err" className="form-error">{error}</p>
                        }
                        <button key="submit" className="btn btn-primary full-button" onClick={submit} disabled={submitting}>
                            {"Submitting…" if submitting else "Submit feedback"} <Icon name="arrow" />
                        </button>
                        <button key="skip" className="skip-link" onClick={lambda (e: MouseEvent) { nav("/profile"); }}>Skip for now</button>
                    }
                }}
            </div>
        </main>
    </div>;
}
