"""DemoPage — a self-playing product demo at /demo ("View demo" on home).

Plays like a video: a white title card ("Not Uber. Not U-Haul. Better."),
the Along logo and tagline, then every feature in order on real screens —
log in, describe a trip, matches, details, chat, reveal, safety, posting,
notifications, rentals, rating and your profile — then a closing card.
Space pauses, arrow keys step, and the progress bar is clickable.
"""

import from "@jac/runtime" { useNavigate }
import from react { useEffect }
import from .Icon { Icon }
import from "@jac-client/assets/demo/01-home.jpg" { default as s01 }
import from "@jac-client/assets/demo/02-login.jpg" { default as s02 }
import from "@jac-client/assets/demo/03-assistant.jpg" { default as s03 }
import from "@jac-client/assets/demo/04-form.jpg" { default as s04 }
import from "@jac-client/assets/demo/05-prefs.jpg" { default as s05 }
import from "@jac-client/assets/demo/06-searching.jpg" { default as s06 }
import from "@jac-client/assets/demo/07-results.jpg" { default as s07 }
import from "@jac-client/assets/demo/08-details.jpg" { default as s08 }
import from "@jac-client/assets/demo/09-chat.jpg" { default as s09 }
import from "@jac-client/assets/demo/10-reveal.jpg" { default as s10 }
import from "@jac-client/assets/demo/11-safety.jpg" { default as s11 }
import from "@jac-client/assets/demo/12-post.jpg" { default as s12 }
import from "@jac-client/assets/demo/13-posted.jpg" { default as s13 }
import from "@jac-client/assets/demo/14-bell.jpg" { default as s14 }
import from "@jac-client/assets/demo/15-rental.jpg" { default as s15 }
import from "@jac-client/assets/demo/16-rental-driver.jpg" { default as s16 }
import from "@jac-client/assets/demo/17-rating.jpg" { default as s17 }
import from "@jac-client/assets/demo/18-profile.jpg" { default as s18 }

glob TAGLINE: str = "Michigan, moving together.";

# [image, kicker, title, caption, zoom focus "x% y%"]
def _steps() -> list[list[str]] {
    return [
        [s01, "Start", "Welcome to Along", "Rides, cab shares and rentals with people already heading your way.", "30% 40%"],
        [s02, "Step 1", "Log in", "Your real name stays private — others only see an anonymous handle.", "50% 45%"],
        [s03, "Step 2", "Just say where you're going", "Type it in plain English. Along's AI assistant understands places, times and preferences.", "30% 55%"],
        [s04, "Step 3", "The form fills itself", "Ride with a driver or split a cab — the assistant picked the details, you check them.", "50% 60%"],
        [s05, "Step 4", "Choose who you travel with", "Age range and gender preferences, matched both ways — and never shown on profiles.", "50% 40%"],
        [s06, "Step 5", "Five AI agents get to work", "Route, schedule, trust and cost agents search the journey graph; a coordinator ranks them.", "25% 45%"],
        [s07, "Step 6", "Matches on your route", "Real road routes on the map, the best match first, and why it fits — including timing.", "35% 50%"],
        [s08, "Step 7", "See the details", "Detour, timing, savings and the other traveler's reviews before you commit.", "40% 45%"],
        [s09, "Step 8", "Chat anonymously", "Say hello and agree on a pickup spot — no names or numbers shared yet.", "55% 55%"],
        [s10, "Step 9", "Reveal when you're both ready", "Identities are shared only after both people agree.", "50% 20%"],
        [s11, "Step 10", "Safety built in", "Share your trip with a friend, report, remove a match, or block — anytime.", "72% 25%"],
        [s12, "Step 11", "No match yet? Post it", "Post your request so future travelers heading your way can find you.", "20% 45%"],
        [s13, "Step 12", "Along keeps looking", "Your request is live — we'll tell you when someone fits.", "20% 45%"],
        [s14, "Step 13", "Get notified", "The bell lights up the moment a matching journey is posted.", "70% 30%"],
        [s15, "Step 14", "Share a rental", "Rental counters near your pickup and your dropoff, from Google Maps.", "50% 45%"],
        [s16, "Step 15", "Moving? Don't drive?", "Pick a vehicle by the space you need, and ask for a partner who can drive.", "50% 55%"],
        [s17, "Step 16", "Rate your trip", "Anonymous stars and quick compliments — and you can change them later.", "50% 45%"],
        [s18, "Step 17", "Your profile", "Your journeys, people you've rated, and every safety control in one place.", "40% 55%"]
    ];
}

glob INTRO_MS: int = 3600,
     LOGO_MS: int = 3200,
     STEP_MS: int = 4800,
     OUTRO_MS: int = 6000;

def:pub DemoPage() -> JsxElement {
    has idx: int = 0,
        playing: bool = True;

    nav = useNavigate();
    steps = _steps();
    total = len(steps) + 3;          # intro, logo, steps..., outro

    def duration(i: int) -> int {
        if i == 0 {
            return INTRO_MS;
        }
        if i == 1 {
            return LOGO_MS;
        }
        return OUTRO_MS if i == total - 1 else STEP_MS;
    }

    def go(i: int) {
        idx = max(0, min(total - 1, i));
    }

    # Advance automatically while playing; stop on the closing card.
    useEffect(lambda {
        if not playing or idx >= total - 1 {
            return None;
        }
        timer = setTimeout(lambda { idx = idx + 1; }, duration(idx));  # jac:ignore[W2001]
        return lambda { clearTimeout(timer); };  # jac:ignore[W2001]
    }, [idx, playing]);

    useEffect(lambda {
        def on_key(e: KeyboardEvent) {
            if e.key == "ArrowRight" {
                idx = min(total - 1, idx + 1);
            } elif e.key == "ArrowLeft" {
                idx = max(0, idx - 1);
            } elif e.key == " " {
                e.preventDefault();
                playing = not playing;
            } elif e.key == "Escape" {
                nav("/");
            }
        }
        window.addEventListener("keydown", on_key);
        return lambda { window.removeEventListener("keydown", on_key); };
    }, [idx, playing]);

    scene: any = None;
    if idx == 0 {
        scene = <div key="intro" className="demo-intro">
            <h1>
                <span style={{"animationDelay": "0.2s"}}>Not Uber.</span>
                <span style={{"animationDelay": "1.0s"}}>Not U-Haul.</span>
                <span className="better" style={{"animationDelay": "1.9s"}}>Better.</span>
            </h1>
        </div>;
    } elif idx == 1 {
        scene = <div key="logo" className="demo-logo">
            <span className="brand-mark demo-mark"><span /></span>
            <h1>Along</h1>
            <p>{TAGLINE}</p>
        </div>;
    } elif idx == total - 1 {
        scene = <div key="outro" className="demo-logo demo-outro">
            <span className="brand-mark demo-mark"><span /></span>
            <h1>Your ride is already on the road.</h1>
            <p>{"Along — " + TAGLINE}</p>
            <div className="demo-cta">
                <button className="btn btn-primary" onClick={lambda (e: MouseEvent) { nav("/signup"); }}>Get started <Icon name="arrow" /></button>
                <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { go(0); playing = True; }}>Watch again</button>
            </div>
        </div>;
    } else {
        st = steps[idx - 2];
        scene = <div key={"step" + str(idx)} className="demo-step">
            <div className="demo-frame">
                <div className="demo-chrome"><i /><i /><i /><span>along · localhost</span></div>
                <div className="demo-shot">
                    <img src={st[0]} alt={st[2]} style={{"transformOrigin": st[4], "animationDuration": str(STEP_MS + 600) + "ms"}} />
                </div>
            </div>
            <div className="demo-caption">
                <span className="demo-kicker">{st[1]}</span>
                <h2>{st[2]}</h2>
                <p>{st[3]}</p>
            </div>
        </div>;
    }

    return <div className={"demo-page" + (" dark" if idx >= 2 and idx < total - 1 else "")}>
        <div className="demo-progress" role="tablist" aria-label="Demo progress">
            {for i in range(total) {
                <button
                    key={str(i)} aria-label={"Go to part " + str(i + 1)}
                    className={"dseg" + (" done" if i < idx else "") + (" now" if i == idx else "")}
                    onClick={lambda (e: MouseEvent) { go(i); }}
                >
                    <i style={{"animationDuration": str(duration(i)) + "ms", "animationPlayState": "running" if playing else "paused"}} />
                </button>
            }}
        </div>
        <div className="demo-stage">{scene}</div>
        <div className="demo-controls">
            <button aria-label="Close demo" onClick={lambda (e: MouseEvent) { nav("/"); }}><Icon name="x" size={18} /></button>
            <button aria-label="Previous" onClick={lambda (e: MouseEvent) { go(idx - 1); }}><Icon name="back" size={18} /></button>
            <button className="play" aria-label={"Pause" if playing else "Play"} onClick={lambda (e: MouseEvent) { playing = not playing; }}>
                {"❚❚" if playing else "▶"}
            </button>
            <button aria-label="Next" onClick={lambda (e: MouseEvent) { go(idx + 1); }}><Icon name="arrow" size={18} /></button>
            <span className="demo-count">{str(idx + 1) + " / " + str(total)}</span>
        </div>
    </div>;
}
