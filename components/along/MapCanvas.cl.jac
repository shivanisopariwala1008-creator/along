"""MapCanvas — the Figma results map. Markers and the route are placed from
real trip coordinates (projected into a box fitted around the journey); the
road texture and traffic colours stay illustrative, as labelled."""

import from .Icon { Icon }
import from ...lib.along { flow_info, map_bounds, project, pos_style, towns_in, fmt_time, when_text }
sv import from ...services.along { TripView, MatchCardView }

def:pub MapCanvas(
    my_trip: TripView | None, cards: list[MatchCardView], selected: int,
    onSelect: Callable[[int], None], kind: str = "ride"
) -> JsxElement {
    has zoom: float = 1.0;

    info = flow_info(kind);
    points: list[list[float]] = [];
    if my_trip is not None {
        points = points + [[my_trip.origin_lat, my_trip.origin_lng], [my_trip.destination_lat, my_trip.destination_lng]];
    }
    for c in cards {
        if c.other_trip is not None {
            points = points + [[c.other_trip.origin_lat, c.other_trip.origin_lng]];
        }
    }
    b = map_bounds(points);
    route = _route_points(b, my_trip);
    segments = _segments(route);

    def zoom_in(e: MouseEvent) { zoom = min(zoom + 0.25, 2.0); }
    def zoom_out(e: MouseEvent) { zoom = max(zoom - 0.25, 1.0); }
    def recenter(e: MouseEvent) { zoom = 1.0; }

    return <div className="map-canvas">
        <div className="map-layer" style={{"transform": "scale(" + str(zoom) + ")"}}>
            <svg className="roads" viewBox="0 0 800 650" preserveAspectRatio="none" aria-hidden="true">
                <path d="M-40 95C110 50 190 170 340 120s320-20 510 20M-40 475c160-80 270 60 430 0s260-120 450-25M130-30c30 140 0 250 90 360s80 190 55 350M610-30c-70 110-45 230-115 320s-80 220-30 390" />
                <path d="M-20 290c190 20 265-50 420 35s230 40 420 20M390-20c30 160-90 220-45 350s140 165 110 350" />
            </svg>
            {if len(route) > 0 {
                <svg key="route" className="route-overlay" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
                    <polyline className="route-shadow" points={_poly(route)} vectorEffect="non-scaling-stroke" />
                    {for (i, seg) in enumerate(segments) {
                        <polyline key={str(i)} className={"traffic " + seg[0]} points={seg[1]} vectorEffect="non-scaling-stroke" />
                    }}
                </svg>
            }}
            {for t in towns_in(b) {
                <span key={t[0]} className="map-label" style={pos_style(project(b, t[1] as float, t[2] as float))}>{t[0]}</span>
            }}
            {if my_trip is not None {
                <span key="start" className="trip-end start" style={pos_style(project(b, my_trip.origin_lat, my_trip.origin_lng))} title="Your start">A</span>
                <span key="end" className="trip-end" style={pos_style(project(b, my_trip.destination_lat, my_trip.destination_lng))} title="Your destination">B</span>
            }}
            {for (i, c) in enumerate(cards) {
                if c.other_trip is not None {
                    <button
                        key={c.id}
                        className={"result-marker " + info["accent"] + (" active" if selected == i else "")}
                        style={pos_style(project(b, c.other_trip.origin_lat, c.other_trip.origin_lng))}
                        onClick={lambda (e: MouseEvent) { onSelect(i); }}
                        aria-label={"Show " + c.other_handle}
                    >
                        <span>{info["marker"]}</span>
                        {selected == i and <b>{when_text(c)}</b>}
                    </button>
                }
            }}
        </div>
        <div className="map-controls">
            <button aria-label="Zoom in" onClick={zoom_in}>+</button>
            <button aria-label="Zoom out" onClick={zoom_out}>−</button>
            <button aria-label="Center map" onClick={recenter}><Icon name="pin" /></button>
        </div>
        <div className="traffic-legend">
            <strong>Illustrative traffic</strong>
            <span><i className="legend-green" /> Clear</span>
            <span><i className="legend-amber" /> Moderate</span>
            <span><i className="legend-red" /> Busy</span>
        </div>
        <div className="type-legend">
            <span className={"tiny-marker " + info["accent"]}>{info["marker"]}</span>{info["marker_label"]}
            {my_trip is not None and <span className="type-legend-you"><span className="tiny-end">A</span>Your route</span>}
        </div>
    </div>;
}

# A gently curved route from A to B, sampled along a quadratic bezier.
def _route_points(b: dict, t: TripView | None) -> list[list[float]] {
    if t is None {
        return [];
    }
    p0 = project(b, t.origin_lat, t.origin_lng);
    p2 = project(b, t.destination_lat, t.destination_lng);
    dx = p2[0] - p0[0];
    dy = p2[1] - p0[1];
    ctrl = [(p0[0] + p2[0]) / 2 - dy * 0.18, (p0[1] + p2[1]) / 2 + dx * 0.18];
    pts: list[list[float]] = [];
    steps = 12;
    i = 0;
    while i <= steps {
        s = i / steps;
        x = (1 - s) * (1 - s) * p0[0] + 2 * (1 - s) * s * ctrl[0] + s * s * p2[0];
        y = (1 - s) * (1 - s) * p0[1] + 2 * (1 - s) * s * ctrl[1] + s * s * p2[1];
        pts = pts + [[x, y]];
        i = i + 1;
    }
    return pts;
}

# SVG "x1,y1 x2,y2 ..." (built by hand: str.join is not available client-side).
def _poly(pts: list[list[float]]) -> str {
    out = "";
    for p in pts {
        out = out + (" " if out else "") + f"{p[0]:.2f},{p[1]:.2f}";
    }
    return out;
}

# Split the route into illustrative traffic bands: clear, moderate, busy, clear.
def _segments(pts: list[list[float]]) -> list[list[str]] {
    if len(pts) < 13 {
        return [];
    }
    return [
        ["green-line", _poly(pts[0:5])], ["amber-line", _poly(pts[4:7])],
        ["red-line", _poly(pts[6:9])], ["green-line", _poly(pts[8:13])],
    ];
}
