"""PlaceInput — location field backed by Google Places autocomplete. Typing
shows a dropdown of real places (biased to Michigan); choosing one reports its
name and exact coordinates. Must render inside an <APIProvider>."""

import from "@vis.gl/react-google-maps" { useMapsLibrary }
import from react { useEffect }
import from .Icon { Icon }

glob MICHIGAN_BIAS: dict = {"center": {"lat": 43.0, "lng": -84.2}, "radius": 50000.0};

def:pub PlaceInput(
    label: str, value: str, picked: bool, onType: Callable[[str], None],
    onPick: Callable[[str, float, float], None], placeholder: str = "Search for a place",
    onUnavailable: Callable[[], None] | None = None
) -> JsxElement {
    has suggestions: list[dict] = [],
        menu_open: bool = False,
        active: int = -1,
        error: str = "",
        session: Ref[any] = Ref(None),
        latest: Ref[str] = Ref("");

    places: any = useMapsLibrary("places");

    async def load(query: str) -> None {
        try {
            if not session.current {
                session.current = new(places.AutocompleteSessionToken);  # jac:ignore[E1001,E1053]
            }
            result: any = await places.AutocompleteSuggestion.fetchAutocompleteSuggestions({
                "input": query, "sessionToken": session.current,
                "includedRegionCodes": ["us"], "locationBias": MICHIGAN_BIAS
            });
            if latest.current != query {
                return;   # a newer keystroke already superseded this request
            }
            found: list[dict] = [];
            for s in result.suggestions {
                p: any = s.placePrediction;
                if p {
                    found = found + [{
                        "text": p.text.text,
                        "main": p.mainText.text if p.mainText else p.text.text,
                        "secondary": p.secondaryText.text if p.secondaryText else "",
                        "prediction": p
                    }];
                }
            }
            suggestions = found;
            menu_open = len(found) > 0;
            active = -1;
            error = "";
        } except Exception as e {
            suggestions = [];
            error = "Place suggestions are unavailable right now — type the place name instead.";
            if onUnavailable {
                onUnavailable();
            }
        }
    }

    # Debounced lookup while typing; nothing to do once a place is chosen.
    useEffect(lambda {
        query = value.strip();
        latest.current = query;
        if not places or picked or len(query) < 2 {
            suggestions = [];
            menu_open = False;
            return lambda { };
        }
        timer = setTimeout(lambda { load(query); }, 250);  # jac:ignore[W2001]
        return lambda { clearTimeout(timer); };  # jac:ignore[W2001]
    }, [places, value, picked]);

    async def choose(i: int) -> None {
        if i < 0 or i >= len(suggestions) {
            return;
        }
        item = suggestions[i];
        menu_open = False;
        try {
            place: any = item["prediction"].toPlace();
            await place.fetchFields({"fields": ["location", "formattedAddress"]});
            session.current = None;   # a pick ends the billing session
            name: str = item["text"] as str;
            lat: float = place.location.lat() as float;
            lng: float = place.location.lng() as float;
            onPick(name, lat, lng);
        } except Exception as e {
            error = "Couldn't load that place. Please try another.";
        }
    }

    def handle_key(e: KeyboardEvent) {
        if not menu_open or len(suggestions) == 0 {
            return;
        }
        if e.key == "ArrowDown" {
            e.preventDefault();
            active = min(active + 1, len(suggestions) - 1);
        } elif e.key == "ArrowUp" {
            e.preventDefault();
            active = max(active - 1, 0);
        } elif e.key == "Enter" {
            e.preventDefault();
            choose(active if active >= 0 else 0);
        } elif e.key == "Escape" {
            menu_open = False;
        }
    }

    return <div className="field place-field">
        <span>{label}</span>
        <div className={"place-box" + (" picked" if picked else "")}>
            <Icon name="pin" />
            <input
                value={value} placeholder={placeholder} autoComplete="off" aria-label={label}
                onChange={lambda (e: ChangeEvent) { onType(e.target.value); }}
                onFocus={lambda (e: FocusEvent) { menu_open = len(suggestions) > 0 and not picked; }}
                onBlur={lambda (e: FocusEvent) { menu_open = False; }}
                onKeyDown={handle_key}
            />
            {picked and <Icon name="check" className="picked-check" />}
        </div>
        {if menu_open {
            <ul key="menu" className="place-menu" role="listbox">
                {for (i, s) in enumerate(suggestions) {
                    <li
                        key={s["text"]} role="option" aria-selected={i == active}
                        className={"active" if i == active else ""}
                        onMouseDown={lambda (e: MouseEvent) { e.preventDefault(); choose(i); }}
                    >
                        <Icon name="pin" size={16} />
                        <span><strong>{s["main"]}</strong><small>{s["secondary"]}</small></span>
                    </li>
                }}
                <li key="attr" className="place-attribution" aria-hidden="true">powered by Google</li>
            </ul>
        }}
        {error and <small className="place-error">{error}</small>}
    </div>;
}
