"""TripAssistant — "Tell Along where you're going" box. Sends one sentence to
the server's plan_trip (Gemini, with a rules fallback), then opens the normal
journey form pre-filled so the traveler can check it before posting."""

import from "@jac/runtime" { useNavigate, jacIsLoggedIn }
import from .Icon { Icon }
sv import from ...services.along { plan_trip, TripDraftView }

glob EXAMPLES: list[str] = [
    "Flint to Ann Arbor by 9 every weekday, back at 5",
    "Driving Lansing to Detroit tomorrow at 7:30, 2 seats free",
    "Split a cab from DTW to downtown Detroit Friday 6pm",
];

glob DRAFT_KEY: str = "along_trip_draft";

def:pub TripAssistant() -> JsxElement {
    has text: str = "",
        busy: bool = False,
        hint: str = "";

    nav = useNavigate();

    async def plan -> None {
        sentence = text.strip();
        if len(sentence) < 4 {
            hint = "Try something like “Flint to Ann Arbor by 9 every weekday”.";
            return;
        }
        if not jacIsLoggedIn() {
            nav("/login?next=%2F");
            return;
        }
        busy = True;
        hint = "";
        try {
            draft: TripDraftView = await plan_trip(sentence);
            if not draft.ok or not draft.origin_name or not draft.destination_name {
                hint = "I couldn’t tell where you’re starting and going. Try “Novi to Detroit on Saturday”.";
                busy = False;
                return;
            }
            try {
                sessionStorage.setItem(DRAFT_KEY, JSON.stringify({**draft, "sentence": sentence}));  # jac:ignore[E1030,E1032]
            } except Exception as err {
                hint = "Couldn't save the draft in this browser.";
            }
            nav("/journey/" + draft.kind + "?draft=1");
        } except Exception as e {
            hint = "The assistant is unavailable right now — you can still pick a journey type below.";
        }
        busy = False;
    }

    def handle_submit(e: FormEvent) {
        e.preventDefault();
        plan();
    }

    return <form className="trip-assistant" onSubmit={handle_submit}>
        <label htmlFor="assistant-input" className="visually-hidden">Describe your trip</label>
        <div className="assistant-box">
            <input
                id="assistant-input" value={text} placeholder="e.g. Flint to Ann Arbor by 9 every weekday, back at 5"
                onChange={lambda (e: ChangeEvent) { text = e.target.value; }} disabled={busy} autoComplete="off"
            />
            <button type="submit" className="btn btn-primary" disabled={busy}>
                {"Planning…" if busy else "Plan it"} <Icon name="arrow" />
            </button>
        </div>
        {if hint {
            <p key="hint" className="assistant-hint">{hint}</p>
        } else {
            <div key="ex" className="assistant-examples">
                {for ex in EXAMPLES {
                    <button key={ex} type="button" onClick={lambda (e: MouseEvent) { text = ex; }}>{ex}</button>
                }}
            </div>
        }}
    </form>;
}

# Read (once) the draft the assistant left for the journey form.
def:pub take_trip_draft() -> any {
    try {
        raw: any = sessionStorage.getItem(DRAFT_KEY);  # jac:ignore[E1030,E1032]
        if not raw {
            return None;
        }
        sessionStorage.removeItem(DRAFT_KEY);  # jac:ignore[E1030,E1032]
        parsed: any = JSON.parse(raw as str);  # jac:ignore[E1030,E1032,E1001,E1053]
        return parsed;
    } except Exception as e {
        return None;
    }
}
