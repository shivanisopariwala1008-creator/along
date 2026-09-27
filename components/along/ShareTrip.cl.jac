"""Share my trip — create a read-only link for a friend, and the public page
they open (no account needed). The link holds a snapshot: route, the
driver's anonymous name + rating, times, and the stop for 2-ride trips."""

import from "@jac/runtime" { useParams, Link }
import from .Icon { Icon }
sv import from ...services.along { create_share_link, get_shared_trip, SharedTripView }

# Makes the link, then uses the phone's share sheet or copies it.
# Returns a short message to show the user.
async def:pub share_trip(match_id: str) -> str {
    token: str = await create_share_link(match_id);
    if not token {
        return "Couldn’t create a share link right now.";
    }
    url: str = window.location.origin + "/share/" + token;
    try {
        if navigator.share {  # jac:ignore[E1030]
            await navigator.share({"title": "My Along trip", "text": "Here's my trip so you can follow along:", "url": url});  # jac:ignore[E1030]
            return "Trip shared.";
        }
    } except Exception as e {
        print("share sheet dismissed");
    }
    try {
        await navigator.clipboard.writeText(url);  # jac:ignore[E1030]
        return "Link copied — send it to someone you trust.";
    } except Exception as e {
        return "Share this link: " + url;
    }
}

def:pub SharedTripPage() -> JsxElement {
    params = useParams();
    token: str = (params["token"] or "") as str;

    has trip: SharedTripView | None = None,
        loading: bool = True;

    async can with entry {
        if token {
            trip = await get_shared_trip(token);
        }
        loading = False;
    }

    return <div className="app-shell auth-page">
        <Link to="/" className="brand auth-brand" aria-label="Along home">
            <span className="brand-mark"><span /></span>
            <span>Along</span>
        </Link>
        <div className="auth-card share-card">
            {if loading {
                <div key="l" className="loading-state"><span className="spinner" /></div>
            } elif trip is None {
                <div key="none">
                    <h1>Link not found</h1>
                    <p>This trip link doesn’t exist or was turned off.</p>
                </div>
            } else {
                <span key="k" className="step-kicker">{trip.traveler + " shared a trip with you"}</span>
                <h1 key="h">{trip.route_from.split(",")[0] + " → " + trip.route_to.split(",")[0]}</h1>
                <p key="p">{trip.kind + " · " + trip.when + (" · arrives around " + trip.arrive if trip.arrive else "")}</p>
                <ol key="legs" className="relay-legs">
                    <li>
                        <span className="avatar avatar-small">1</span>
                        <div><strong>{("First driver: " if trip.second_driver else "Driver: ") + trip.driver}</strong><small>{trip.driver_rating}</small></div>
                    </li>
                    {if trip.handoff {
                        <li key="stop" className="relay-handoff">
                            <span className="handoff-dot"><Icon name="pin" size={16} /></span>
                            <div><strong>{"Stop: " + trip.handoff + " · " + trip.handoff_time}</strong><small>They switch to a second driver here</small></div>
                        </li>
                        <li key="second">
                            <span className="avatar avatar-small">2</span>
                            <div><strong>{"Second driver: " + trip.second_driver}</strong><small>{trip.second_rating}</small></div>
                        </li>
                    }}
                </ol>
                <div key="note" className="auth-note"><Icon name="shield" size={16} /> Drivers appear by their anonymous Along names. Exact addresses are never shared.</div>
            }}
        </div>
    </div>;
}
