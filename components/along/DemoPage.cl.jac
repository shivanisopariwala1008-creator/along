"""DemoPage — a narrated, self-playing product demo at /demo ("View demo").

Plays like a screen recording: a white title card ("Not Uber. Not U-Haul.
Better."), the Along logo and tagline, then the full journey on real screens
with a cursor that moves, types and clicks — log in, describe a trip, pick
preferences, meet the AI agents, matches, details, chat, reveal, safety,
posting, notifications, rentals and ratings — then a closing card.

The voiceover uses the browser's built-in speech (no audio files); each step
waits for its narration and its cursor actions before moving on. Pausing
stops both; playing again replays the current step.
"""

import from "@jac/runtime" { useNavigate }
import from react { useEffect }
import from .Icon { Icon }
import from "@jac-client/assets/demo/01-home.jpg" { default as img_01 }
import from "@jac-client/assets/demo/02-login.jpg" { default as img_02 }
import from "@jac-client/assets/demo/03-home-in.jpg" { default as img_03 }
import from "@jac-client/assets/demo/04-form.jpg" { default as img_04 }
import from "@jac-client/assets/demo/05-prefs.jpg" { default as img_05 }
import from "@jac-client/assets/demo/06-timing.jpg" { default as img_06 }
import from "@jac-client/assets/demo/07-searching.jpg" { default as img_07 }
import from "@jac-client/assets/demo/08-results.jpg" { default as img_08 }
import from "@jac-client/assets/demo/09-details.jpg" { default as img_09 }
import from "@jac-client/assets/demo/10-chat.jpg" { default as img_10 }
import from "@jac-client/assets/demo/11-reveal.jpg" { default as img_11 }
import from "@jac-client/assets/demo/12-safety.jpg" { default as img_12 }
import from "@jac-client/assets/demo/13-post.jpg" { default as img_13 }
import from "@jac-client/assets/demo/14-posted.jpg" { default as img_14 }
import from "@jac-client/assets/demo/15-bell.jpg" { default as img_15 }
import from "@jac-client/assets/demo/16-rental.jpg" { default as img_16 }
import from "@jac-client/assets/demo/17-driver.jpg" { default as img_17 }
import from "@jac-client/assets/demo/18-profile.jpg" { default as img_18 }
import from "@jac-client/assets/demo/19-rating.jpg" { default as img_19 }
import from "@jac-client/assets/demo/20-offer-home.jpg" { default as img_20 }
import from "@jac-client/assets/demo/21-offer-form.jpg" { default as img_21 }
import from "@jac-client/assets/demo/22-offer-seats.jpg" { default as img_22 }
import from "@jac-client/assets/demo/23-offer-riders.jpg" { default as img_23 }
import from "@jac-client/assets/demo/24-rental-home.jpg" { default as img_24 }
import from "@jac-client/assets/demo/25-rental-form.jpg" { default as img_25 }
import from "@jac-client/assets/demo/26-rental-vehicle.jpg" { default as img_26 }
import from "@jac-client/assets/demo/27-rental-results.jpg" { default as img_27 }

glob TAGLINE: str = "Michigan, moving together.",
     IMG: dict[str, str] = {"01-home": img_01, "02-login": img_02, "03-home-in": img_03, "04-form": img_04, "05-prefs": img_05, "06-timing": img_06, "07-searching": img_07, "08-results": img_08, "09-details": img_09, "10-chat": img_10, "11-reveal": img_11, "12-safety": img_12, "13-post": img_13, "14-posted": img_14, "15-bell": img_15, "16-rental": img_16, "17-driver": img_17, "18-profile": img_18, "19-rating": img_19, "20-offer-home": img_20, "21-offer-form": img_21, "22-offer-seats": img_22, "23-offer-riders": img_23, "24-rental-home": img_24, "25-rental-form": img_25, "26-rental-vehicle": img_26, "27-rental-results": img_27};

glob AGENTS: list[list[str]] = [
    ["spark", "Trip Assistant", "Gemini turns your sentence into a journey"],
    ["map", "Route Scout", "Walks the journey graph for shared routes"],
    ["clock", "Schedule Agent", "Lines up times — closest first"],
    ["shield", "Trust Agent", "Checks ratings, reviews and preferences"],
    ["star", "Cost Agent", "Estimates what you save"],
    ["graph", "Coordinator", "Ranks every match and learns from real choices"],
    ["swap", "Relay Agent", "Builds 2-ride trips; Gemini picks a safe handoff"],
    ["bell", "Matchmaker", "Notifies you when someone new fits"]
];

glob AGENTS_VOICE: str = "Meet the agents. The Trip Assistant reads your request. Route Scout walks the journey graph for shared routes. The Schedule Agent lines up times. The Trust Agent checks ratings and preferences. The Cost Agent estimates your savings. The Coordinator ranks every match, and learns from the matches people actually choose. When no one goes the whole way, the Relay Agent builds a two-ride trip, with Gemini picking a safe handoff spot. And the Matchmaker notifies you when someone new fits.";

def _scenes() -> list[dict] {
    return [
        {"kind": "intro", "voice": "Not Uber. Not U-Haul. Better."},
        {"kind": "logo", "voice": "Meet Along. " + TAGLINE},
        {"kind": "screen", "img": IMG["01-home"], "kicker": "Start", "title": "Welcome to Along", "caption": "Rides, cab shares and rentals with people already heading your way.", "voice": "Along connects you with people already heading your way, for rides, cab shares and rentals. Let's log in.", "click": [86.3, 4.93], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["02-login"], "kicker": "Step 1", "title": "Log in", "caption": "Other travelers only ever see an anonymous handle.", "voice": "Log in. Other travelers only ever see an anonymous handle, never your real name.", "click": [50, 73.72], "hover": False, "type": [{"x": 38.59, "y": 48.72, "w": 24.38, "text": "marcus.test@example.com"}, {"x": 38.59, "y": 61.15, "w": 24.38, "text": "••••••••••••"}]},
        {"kind": "screen", "img": IMG["03-home-in"], "kicker": "Step 2", "title": "Say where you're going", "caption": "The AI trip assistant understands places, times and preferences.", "voice": "Now just say where you're going, in plain English. Along's trip assistant, powered by Gemini, understands places, times and preferences.", "click": [37.98, 68.06], "hover": False, "type": [{"x": 8.33, "y": 68.06, "w": 24.95, "text": "Grand Blanc to Ann Arbor by 9 every weekday"}]},
        {"kind": "screen", "img": IMG["04-form"], "kicker": "Step 3", "title": "The form fills itself", "caption": "Ride with a driver, or split a cab — same trip, one tap.", "voice": "The form fills itself. Ride with a driver, or split a cab. Same trip, one tap.", "click": [61.13, 52.57], "hover": True, "type": []},
        {"kind": "screen", "img": IMG["05-prefs"], "kicker": "Step 4", "title": "Who you travel with", "caption": "Age range and gender preferences, matched both ways.", "voice": "Choose who you'd like to travel with. Age and gender preferences are matched both ways, and never shown on profiles.", "click": [23.52, 31.99], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["06-timing"], "kicker": "Step 5", "title": "Set your timing", "caption": "Arrive by or leave at — then show matching rides.", "voice": "Set your timing, then show matching rides.", "click": [73.28, 84.19], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["07-searching"], "kicker": "Step 6", "title": "The agents get to work", "caption": "A team of AI agents searches the journey graph.", "voice": "Behind the scenes, a team of AI agents gets to work.", "click": [], "hover": False, "type": []},
        {"kind": "agents", "voice": AGENTS_VOICE},
        {"kind": "screen", "img": IMG["08-results"], "kicker": "Step 7", "title": "Matches on your route", "caption": "Real road routes, best match first, and why it fits.", "voice": "Here are your matches, on real road routes. The best match comes first, with a plain reason, including whether the timing works.", "click": [26.02, 94.57], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["09-details"], "kicker": "Step 8", "title": "See the details", "caption": "Detour, timing, savings and reviews.", "voice": "Check the detour, timing, savings and reviews. Then say hello.", "click": [82.81, 82.92], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["10-chat"], "kicker": "Step 9", "title": "Chat anonymously", "caption": "Agree on a pickup spot — no numbers shared.", "voice": "Chat stays anonymous. Agree on a pickup spot without sharing your number.", "click": [76.17, 90.83], "hover": False, "type": [{"x": 23.28, "y": 90.83, "w": 50.94, "text": "Could we meet at the Grand Blanc library lot?"}]},
        {"kind": "screen", "img": IMG["11-reveal"], "kicker": "Step 10", "title": "Reveal when you're ready", "caption": "Names are shared only when you both agree.", "voice": "Names are revealed only when you both agree.", "click": [76.25, 4.72], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["12-safety"], "kicker": "Step 11", "title": "Safety built in", "caption": "Share your trip, report, remove a match, or block.", "voice": "Safety is built in. Share your trip with a friend, report, remove a match, or block, anytime.", "click": [70.94, 11.49], "hover": True, "type": []},
        {"kind": "screen", "img": IMG["13-post"], "kicker": "Step 12", "title": "No match yet? Post it", "caption": "Future travelers heading your way can find you.", "voice": "No match yet? Post your request, so future travelers heading your way can find you.", "click": [15.66, 60.95], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["14-posted"], "kicker": "Step 13", "title": "Along keeps looking", "caption": "The Matchmaker agent tells you when someone fits.", "voice": "Along keeps looking. The Matchmaker agent tells you the moment someone fits.", "click": [80.74, 4.93], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["15-bell"], "kicker": "Step 14", "title": "Get notified", "caption": "New matches land in your notifications.", "voice": "New matches land right in your notifications.", "click": [68.79, 26.14], "hover": True, "type": []},
        {"kind": "screen", "img": IMG["20-offer-home"], "kicker": "Offer a ride", "title": "Driving? Share your seats", "caption": "Say where you're driving and how many seats are free.", "voice": "Driving somewhere anyway? Offer your empty seats. Just say where you're driving, and how many seats are free.", "click": [37.98, 68.06], "hover": False, "type": [{"x": 8.33, "y": 68.06, "w": 24.95, "text": "Driving Lansing to Detroit, 7:30, 2 seats"}]},
        {"kind": "screen", "img": IMG["21-offer-form"], "kicker": "Offer a ride", "title": "Your route, ready to post", "caption": "The assistant sets you up as the driver.", "voice": "The assistant sets you up as the driver, with your route, date and time.", "click": [50, 55], "hover": True, "type": []},
        {"kind": "screen", "img": IMG["22-offer-seats"], "kicker": "Offer a ride", "title": "Seats, detour and timing", "caption": "Choose seats and how far you'll detour, then post.", "voice": "Choose your available seats and how far you'll detour. Then post your route and find riders.", "click": [72.7, 84.2], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["23-offer-riders"], "kicker": "Offer a ride", "title": "Riders along your route", "caption": "Ranked by detour, and whether you'll get them there on time.", "voice": "Along shows riders along your route, ranked by how little detour they add, and whether you'll get them there on time. Message a rider to set up the pickup.", "click": [34.47, 87.68], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["24-rental-home"], "kicker": "Share a rental", "title": "Share a rental car", "caption": "Road trip or moving day — split the car and the cost.", "voice": "Planning a road trip, or a move? Share a rental car, and split the cost.", "click": [37.98, 68.06], "hover": False, "type": [{"x": 8.33, "y": 68.06, "w": 24.95, "text": "SUV from Detroit to Traverse City, 2 of us"}]},
        {"kind": "screen", "img": IMG["25-rental-form"], "kicker": "Share a rental", "title": "Pick up near you", "caption": "Real rental counters near your pickup, from Google Maps.", "voice": "Along finds real rental counters near your pickup, from Google Maps. Tap one to use it.", "click": [73.38, 33.37], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["16-rental"], "kicker": "Share a rental", "title": "Return it where you finish", "caption": "Counters near your drop-off, too.", "voice": "And counters near your drop-off, so you can return the car where your trip ends.", "click": [73.24, 23.65], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["26-rental-vehicle"], "kicker": "Share a rental", "title": "Choose by space", "caption": "From a compact car to a box truck for moving day.", "voice": "Pick a vehicle by the space you need, from a compact car, to a box truck for moving day.", "click": [30.21, 49.96], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["17-driver"], "kicker": "Share a rental", "title": "Don't drive? No problem", "caption": "Ask for a partner who can drive.", "voice": "Don't drive? Ask for a partner who can. Two non-drivers are never matched.", "click": [76.64, 50.02], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["27-rental-results"], "kicker": "Share a rental", "title": "Potential rental partners", "caption": "People heading the same way — message to split the car.", "voice": "Then meet rental partners heading the same way, and message them to split the car.", "click": [34.47, 87.68], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["18-profile"], "kicker": "Step 15", "title": "People you've rated", "caption": "Your journeys and ratings in one place.", "voice": "After the trip, rate your partner anonymously. Everyone you've rated lives on your profile.", "click": [53.2, 47.08], "hover": False, "type": []},
        {"kind": "screen", "img": IMG["19-rating"], "kicker": "Step 16", "title": "Rate your trip", "caption": "Stars and compliments — edit them anytime.", "voice": "Stars and quick compliments build a trusted community, and you can edit them anytime.", "click": [53.36, 43.61], "hover": False, "type": []},
        {"kind": "outro", "voice": "Along. " + TAGLINE + " Get started today."}
    ];
}

# Speak with a clear English voice, one sentence at a time (Chrome cuts off
# long utterances); calls done() after the last sentence.
def _speak(text: str, done: Callable[[], None]) -> None {
    synth: any = window.speechSynthesis;  # jac:ignore[E1030]
    if not synth or not text {
        done();
        return;
    }
    synth.cancel();
    voices: any = synth.getVoices();
    picked: any = None;
    for name in ["Samantha", "Google US English", "Aria", "Jenny", "Karen", "Daniel"] {
        if picked is None {
            for v in voices {
                if picked is None and name in v.name {
                    picked = v;
                }
            }
        }
    }
    parts: list[str] = [x.strip() + "." for x in text.split(". ") if x.strip()];
    def say(i: int) {
        if i >= len(parts) {
            done();
            return;
        }
        u: any = new(SpeechSynthesisUtterance, parts[i].replace("..", "."));  # jac:ignore[E1032,E1053]
        if picked is not None {
            u.voice = picked;
        }
        u.lang = "en-US";
        u.rate = 1.0;
        u.onend = lambda (e: any) { say(i + 1); };
        u.onerror = lambda (e: any) { done(); };
        synth.speak(u);
    }
    say(0);
}

def _hush() -> None {
    synth: any = window.speechSynthesis;  # jac:ignore[E1030]
    if synth {
        synth.cancel();
    }
}

def:pub DemoPage() -> JsxElement {
    has idx: int = 0,
        started: bool = False,
        playing: bool = False,
        voice_on: bool = True,
        cur_x: float = 50.0,
        cur_y: float = 60.0,
        clicks: int = 0,
        typed: list[str] = [];

    nav = useNavigate();
    scenes = _scenes();
    total = len(scenes);

    def go(i: int) {
        idx = max(0, min(total - 1, i));
    }

    # One step: narrate, move the cursor, type, click — then advance when
    # both the narration and the actions are finished.
    useEffect(lambda {
        timers: list[any] = [];
        flags: dict = {"acts": False, "voice": False, "moved": False};
        buf: list[str] = ["", "", ""];     # typed text, local to this step
        taps: list[int] = [clicks];        # click counter, local to this step
        if not started or not playing {
            _hush();
            return lambda { for t in timers { clearTimeout(t); } };  # jac:ignore[E1053]
        }
        sc = scenes[idx];
        last = idx >= total - 1;

        def maybe_next() {
            if flags["acts"] and flags["voice"] and not flags["moved"] and not last {
                flags["moved"] = True;
                timers.append(setTimeout(lambda { idx = idx + 1; }, 700));  # jac:ignore[W2001]
            }
        }
        def voice_done() {
            if not flags["voice"] {
                flags["voice"] = True;
                maybe_next();
            }
        }
        def acts_done() {
            flags["acts"] = True;
            maybe_next();
        }
        def later(ms: int, f: Callable[[], None]) {
            timers.append(setTimeout(f, ms));  # jac:ignore[W2001]
        }

        typed = [];
        if voice_on {
            line = sc["voice"] as str;
            later(250, lambda { _speak(line, voice_done); });
            # Safety net if speech never reports back (no audio device, etc.).
            later(900 + len(line.split(" ")) * 420, voice_done);
        } else {
            later(250, voice_done);
        }

        kind = sc["kind"] as str;
        if kind != "screen" {
            later(3600 if kind != "agents" else 9000, acts_done);
        } else {
            t: int = 500;
            fields: list[dict] = sc["type"] as list[dict];
            for (fi, f) in enumerate(fields) {
                fx: float = (f["x"] as float) + 1.5;
                fy: float = f["y"] as float;
                txt: str = f["text"] as str;
                later(t, lambda { cur_x = fx; cur_y = fy; });
                t += 950;
                later(t, lambda { taps[0] = taps[0] + 1; clicks = taps[0]; });
                t += 200;
                for n in range(1, len(txt) + 1) {
                    part = txt[:n];
                    slot = fi;
                    later(t + n * 38, lambda {
                        buf[slot] = part;
                        typed = [x for x in buf];
                    });
                }
                t += len(txt) * 38 + 350;
            }
            target: list[float] = sc["click"] as list[float];
            if len(target) == 2 {
                tx: float = target[0] as float;
                ty: float = target[1] as float;
                later(t, lambda { cur_x = tx; cur_y = ty; });
                t += 1000;
                if not sc["hover"] {
                    later(t, lambda { taps[0] = taps[0] + 1; clicks = taps[0]; });
                }
                t += 500;
            }
            later(max(t + 600, 4600), acts_done);
        }
        return lambda {
            for tm in timers {
                clearTimeout(tm);  # jac:ignore[E1053]
            }
            _hush();
        };
    }, [idx, playing, started, voice_on]);

    useEffect(lambda {
        def on_key(e: KeyboardEvent) {
            if e.key == "ArrowRight" {
                idx = min(total - 1, idx + 1);
            } elif e.key == "ArrowLeft" {
                idx = max(0, idx - 1);
            } elif e.key == " " and started {
                e.preventDefault();
                playing = not playing;
            } elif e.key == "Escape" {
                nav("/");
            }
        }
        window.addEventListener("keydown", on_key);
        return lambda { window.removeEventListener("keydown", on_key); _hush(); };
    }, [idx, playing, started]);

    def start(e: MouseEvent) {
        started = True;
        playing = True;
        idx = 0;
    }

    sc = scenes[idx];
    kind = sc["kind"] as str;
    scene: any = None;
    if not started {
        scene = <div key="start" className="demo-logo demo-start">
            <span className="brand-mark demo-mark"><span /></span>
            <h1>See Along in action</h1>
            <p>A narrated 4-minute tour of every feature.</p>
            <div className="demo-cta">
                <button className="btn btn-primary demo-go" onClick={start}><span className="demo-play">▶</span> Play demo</button>
                <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { voice_on = not voice_on; }}>{"Voiceover: on" if voice_on else "Voiceover: off"}</button>
            </div>
        </div>;
    } elif kind == "intro" {
        scene = <div key="intro" className="demo-intro">
            <h1>
                <span style={{"animationDelay": "0.2s"}}>Not Uber.</span>
                <span style={{"animationDelay": "1.0s"}}>Not U-Haul.</span>
                <span className="better" style={{"animationDelay": "1.9s"}}>Better.</span>
            </h1>
        </div>;
    } elif kind == "logo" {
        scene = <div key="logo" className="demo-logo">
            <span className="brand-mark demo-mark"><span /></span>
            <h1>Along</h1>
            <p>{TAGLINE}</p>
        </div>;
    } elif kind == "agents" {
        scene = <div key="agents" className="demo-agents">
            <span className="demo-kicker">Under the hood</span>
            <h2>Meet the agents</h2>
            <div className="agent-grid">
                {for (i, a) in enumerate(AGENTS) {
                    <div key={a[1]} className="agent-card" style={{"animationDelay": str(0.3 + i * 0.95) + "s"}}>
                        <span><Icon name={a[0]} size={20} /></span>
                        <strong>{a[1]}</strong>
                        <small>{a[2]}</small>
                    </div>
                }}
            </div>
        </div>;
    } elif kind == "outro" {
        scene = <div key="outro" className="demo-logo demo-outro">
            <span className="brand-mark demo-mark"><span /></span>
            <h1>Your ride is already on the road.</h1>
            <p>{"Along — " + TAGLINE}</p>
            <div className="demo-cta">
                <button className="btn btn-primary" onClick={lambda (e: MouseEvent) { nav("/signup"); }}>Get started <Icon name="arrow" /></button>
                <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { idx = 0; playing = True; }}>Watch again</button>
            </div>
        </div>;
    } else {
        fields: list[dict] = sc["type"] as list[dict];
        scene = <div key={"step" + str(idx)} className="demo-step">
            <div className="demo-frame">
                <div className="demo-chrome"><i /><i /><i /><span>along</span></div>
                <div className="demo-shot">
                    <img src={sc["img"]} alt={sc["title"]} />
                    {for (fi, f) in enumerate(fields) {
                        <span
                            key={"t" + str(fi)} className="demo-typed"
                            style={{"left": str(f["x"]) + "%", "top": str(f["y"]) + "%", "width": str(f["w"]) + "%"}}
                        >
                            {typed[fi] if fi < len(typed) else ""}<b className="caret" />
                        </span>
                    }}
                    <span className="demo-cursor" style={{"left": str(cur_x) + "%", "top": str(cur_y) + "%"}}>
                        <i key={"c" + str(clicks)} className="ripple" />
                        <svg viewBox="0 0 24 24" width="26" height="26"><path d="M4 2l15 11-6.6 1.2L16 21l-2.8 1.3-3.6-6.8L4 20z" fill="#111" stroke="white" strokeWidth="1.4" strokeLinejoin="round" /></svg>
                    </span>
                </div>
            </div>
            <div className="demo-caption">
                <span className="demo-kicker">{sc["kicker"]}</span>
                <h2>{sc["title"]}</h2>
                <p>{sc["caption"]}</p>
            </div>
        </div>;
    }

    dark = started and kind != "intro" and kind != "logo" and kind != "outro";
    return <div className={"demo-page" + (" dark" if dark else "")}>
        {started and <div className="demo-progress" role="tablist" aria-label="Demo progress">
            {for i in range(total) {
                <button key={str(i)} aria-label={"Go to part " + str(i + 1)} className={"dseg" + (" done" if i < idx else "") + (" now" if i == idx else "")} onClick={lambda (e: MouseEvent) { go(i); }}><i /></button>
            }}
        </div>}
        <div className="demo-stage">{scene}</div>
        {started and <div className="demo-controls">
            <button aria-label="Close demo" onClick={lambda (e: MouseEvent) { nav("/"); }}><Icon name="x" size={18} /></button>
            <button aria-label="Previous" onClick={lambda (e: MouseEvent) { go(idx - 1); }}><Icon name="back" size={18} /></button>
            <button className="play" aria-label={"Pause" if playing else "Play"} onClick={lambda (e: MouseEvent) { playing = not playing; }}>{"❚❚" if playing else "▶"}</button>
            <button aria-label="Next" onClick={lambda (e: MouseEvent) { go(idx + 1); }}><Icon name="arrow" size={18} /></button>
            <button aria-label={"Mute voiceover" if voice_on else "Turn voiceover on"} onClick={lambda (e: MouseEvent) { voice_on = not voice_on; }}>{"🔊" if voice_on else "🔇"}</button>
            <span className="demo-count">{str(idx + 1) + " / " + str(total)}</span>
        </div>}
    </div>;
}
