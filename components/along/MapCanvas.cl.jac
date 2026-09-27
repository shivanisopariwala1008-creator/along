"""MapCanvas — the results map. With a Google Maps key configured it renders
real Google Maps (road routes + live traffic, see GoogleMapView); without one
it falls back to a simple drawn map: your route and numbered match pins
projected from real trip coordinates, nothing decorative."""

import from .Icon { Icon }
import from .GoogleMapView { GoogleMapView }
import from ...lib.along { flow_info, map_bounds, project, pos_style, towns_in, fmt_time, when_text }
sv import from ...services.along { get_maps_config, get_trip_route, TripView, MatchCardView, RouteView, MapsConfigView, RelayView }

def:pub MapCanvas(
    my_trip: TripView | None, cards: list[MatchCardView], selected: int,
    onSelect: Callable[[int], None], kind: str = "ride", phase: str = "ready",
    relay: RelayView | None = None
) -> JsxElement {
    has config: MapsConfigView | None = None,
        my_route: RouteView | None = None,
        other_route: RouteView | None = None;

    my_trip_id = my_trip.id if my_trip is not None else "";
    focus = cards[selected] if selected < len(cards) else None;
    other_trip_id = focus.other_trip.id if (focus is not None and focus.other_trip is not None) else "";

    async can with entry {
        config = await get_maps_config();
    }

    async can with [my_trip_id] entry {
        if my_trip_id {
            my_route = await get_trip_route(my_trip_id);
        }
    }

    async can with [other_trip_id] entry {
        other_route = None;
        if other_trip_id {
            other_route = await get_trip_route(other_trip_id);
        }
    }

    # Don't flash the drawn map while we find out whether Google Maps is on.
    if config is None {
        return <div className="map-canvas map-pending" aria-busy="true" />;
    }
    if config.api_key {
        return <div className="map-canvas google">
            <GoogleMapView
                api_key={config.api_key} map_id={config.map_id} my_trip={my_trip}
                my_route={my_route} other_route={other_route} cards={cards}
                selected={selected} onSelect={onSelect} kind={kind} phase={phase} relay={relay}
            />
        </div>;
    }
    return <DrawnMap my_trip={my_trip} cards={cards} selected={selected} onSelect={onSelect} kind={kind} phase={phase} relay={relay} />;
}

# The Figma map drawn in SVG — used when no Google Maps key is configured.
def:pub DrawnMap(
    my_trip: TripView | None, cards: list[MatchCardView], selected: int,
    onSelect: Callable[[int], None], kind: str = "ride", phase: str = "ready",
    relay: RelayView | None = None
) -> JsxElement {
    has zoom: float = 1.0;

    info = flow_info(kind);
    points: list[list[float]] = [];
    if my_trip is not None {
        points = points + [[my_trip.origin_lat, my_trip.origin_lng], [my_trip.destination_lat, my_trip.destination_lng]];
    }
    for c in cards {
        if c.other_trip is not None and relay is None {
            points = points + [[c.other_trip.origin_lat, c.other_trip.origin_lng]];
        }
    }
    if relay is not None {
        points = points + relay.leg1_points + relay.leg2_points;
    }
    b = map_bounds(points);
    route = _route_points(b, my_trip);
    start_xy = project(b, my_trip.origin_lat, my_trip.origin_lng) if my_trip is not None else [50.0, 50.0];

    def zoom_in(e: MouseEvent) { zoom = min(zoom + 0.25, 2.0); }
    def zoom_out(e: MouseEvent) { zoom = max(zoom - 0.25, 1.0); }
    def recenter(e: MouseEvent) { zoom = 1.0; }

    return <div className="map-canvas">
        <div className="map-layer" style={{"transform": "scale(" + str(zoom) + ")"}}>
            {if len(route) > 0 {
                <svg key="route" className="route-overlay" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
                    <polyline className="route-shadow" points={_poly(route)} vectorEffect="non-scaling-stroke" />
                    <polyline className="route-line" points={_poly(route)} vectorEffect="non-scaling-stroke" />
                    {if relay is not None {
                        <polyline key="leg1" className="leg-line" points={_poly([project(b, p[0], p[1]) for p in relay.leg1_points])} vectorEffect="non-scaling-stroke" />
                        <polyline key="leg2" className="leg-line blue" points={_poly([project(b, p[0], p[1]) for p in relay.leg2_points])} vectorEffect="non-scaling-stroke" />
                    }}
                </svg>
            }}
            {if my_trip is not None {
                <svg key="graph" className={"graph-overlay " + phase} viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
                    {if phase == "searching" and len(route) > 0 {
                        <polyline key="tracer" className="tracer" points={_poly(route)} pathLength="100" vectorEffect="non-scaling-stroke" />
                    }}
                </svg>
            }}
            {if phase == "searching" and my_trip is not None {
                <span key="radar" className="radar" style={pos_style(start_xy)}><i /><i /></span>
            }}
            {for t in towns_in(b) {
                <span key={t[0]} className="map-label" style={pos_style(project(b, t[1] as float, t[2] as float))}>{t[0]}</span>
            }}
            {if my_trip is not None {
                <span key="start" className="trip-end start" style={pos_style(project(b, my_trip.origin_lat, my_trip.origin_lng))} title="Your start">A</span>
                <span key="end" className="trip-end" style={pos_style(project(b, my_trip.destination_lat, my_trip.destination_lng))} title="Your destination">B</span>
            }}
            {if relay is not None and relay.handoff is not None {
                <span key="handoff" className="handoff-pin drawn" style={pos_style(project(b, relay.handoff.lat, relay.handoff.lng))}>
                    <Icon name="pin" size={14} /><b>{relay.handoff.name or "Handoff"}</b>
                </span>
            }}
            {for (i, c) in enumerate(cards) {
                if c.other_trip is not None and relay is None {
                    <button
                        key={c.id}
                        className={"result-marker " + info["accent"] + (" active" if selected == i else "") + (" pop" if phase == "revealing" else "")}
                        style={{**pos_style(project(b, c.other_trip.origin_lat, c.other_trip.origin_lng)), "animationDelay": str(min(i, 6) * 0.42 + 0.3) + "s"}}
                        onClick={lambda (e: MouseEvent) { onSelect(i); }}
                        aria-label={"Show " + c.other_handle}
                    >
                        <span>{str(i + 1)}</span>
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
        <div className="type-legend">
            <span className={"tiny-marker " + info["accent"]}>1</span>Matches, best first
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

