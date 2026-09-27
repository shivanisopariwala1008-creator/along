"""GoogleMapView — the results/details map on real Google Maps: your driving
route (from the Routes API via get_trip_route), the selected match's route
dashed on top, live traffic, and tappable match markers."""

import from "@vis.gl/react-google-maps" { APIProvider, Map as GoogleMap, AdvancedMarker, useMap }
import from react { useEffect }
import from .Icon { Icon }
import from ...lib.along { flow_info, when_text }
sv import from ...services.along { TripView, MatchCardView, RouteView, RelayView }

glob MICHIGAN_CENTER: dict[str, float] = {"lat": 42.6, "lng": -83.6};

def:pub GoogleMapView(
    api_key: str, map_id: str, my_trip: TripView | None, my_route: RouteView | None,
    other_route: RouteView | None, cards: list[MatchCardView], selected: int,
    onSelect: Callable[[int], None], kind: str = "ride", phase: str = "ready",
    relay: RelayView | None = None
) -> JsxElement {
    info = flow_info(kind);
    origin: list[float] = [my_trip.origin_lat, my_trip.origin_lng] if my_trip is not None else [];
    trace: list[list[float]] = my_route.points if my_route is not None and len(my_route.points) > 1 else (
        [origin, [my_trip.destination_lat, my_trip.destination_lng]] if my_trip is not None else []
    );
    targets: list[list[float]] = [
        [c.other_trip.origin_lat, c.other_trip.origin_lng] for c in cards if c.other_trip is not None
    ];
    lines: list[dict] = [];
    if my_route is not None and len(my_route.points) > 1 {
        # Dark ink so the route stands out against Google's green "clear" traffic.
        lines = lines + [{"points": my_route.points, "color": "#17211a", "dashed": False}];
    }
    if relay is not None {
        # A 2-ride route: leg 1 in green, leg 2 in blue, meeting at the handoff.
        lines = [
            {"points": relay.leg1_points, "color": "#176b45", "dashed": False},
            {"points": relay.leg2_points, "color": "#386fa4", "dashed": False},
        ];
    } elif other_route is not None and len(other_route.points) > 1 {
        lines = lines + [{"points": other_route.points, "color": _accent_hex(info["accent"]), "dashed": True}];
    }
    # Redraw only when the routes themselves change, not on every render.
    signature = _signature(my_route) + "|" + _signature(other_route) + "|" + (relay.id if relay is not None else "");

    return <APIProvider apiKey={api_key}>
        <GoogleMap
            className="gmap" mapId={map_id} defaultCenter={MICHIGAN_CENTER} defaultZoom={9}
            gestureHandling="greedy" disableDefaultUI={True} zoomControl={True}
        >
            <RouteLines lines={lines} signature={signature} />
            <SearchOverlay origin={origin} trace={trace} targets={targets} phase={phase} />
            {if my_trip is not None {
                <AdvancedMarker key="a" position={{"lat": my_trip.origin_lat, "lng": my_trip.origin_lng}} title="Your start">
                    <span className="trip-end start">A</span>
                </AdvancedMarker>
                <AdvancedMarker key="b" position={{"lat": my_trip.destination_lat, "lng": my_trip.destination_lng}} title="Your destination">
                    <span className="trip-end">B</span>
                </AdvancedMarker>
            }}
            {if relay is not None and relay.handoff is not None {
                <AdvancedMarker
                    key="handoff" zIndex={20} title={"Handoff: " + relay.handoff.name}
                    position={{"lat": relay.handoff.lat, "lng": relay.handoff.lng}}
                >
                    <span className="handoff-pin"><Icon name="pin" size={16} /><b>{relay.handoff.name or "Handoff"}</b></span>
                </AdvancedMarker>
            }}
            {for (i, c) in enumerate(cards) {
                if c.other_trip is not None and relay is None {
                    <AdvancedMarker
                        key={c.id} title={c.other_handle} zIndex={10 if selected == i else 1}
                        className={"gm-pop" if phase == "revealing" else ""}
                        position={{"lat": c.other_trip.origin_lat, "lng": c.other_trip.origin_lng}}
                        onClick={lambda { onSelect(i); }}
                    >
                        <span className={"result-marker " + info["accent"] + (" active" if selected == i else "")}>
                            <span>{info["marker"]}</span>
                            {selected == i and <b>{when_text(c)}</b>}
                        </span>
                    </AdvancedMarker>
                }
            }}
        </GoogleMap>
        <div className="traffic-legend">
            <strong>Live traffic</strong>
            <span><i className="legend-green" /> Clear</span>
            <span><i className="legend-amber" /> Moderate</span>
            <span><i className="legend-red" /> Busy</span>
        </div>
        <div className="type-legend">
            {if relay is not None {
                <span key="l1" className="type-legend-you first"><i className="leg-swatch" />Leg 1</span>
                <span key="l2" className="type-legend-you"><i className="leg-swatch blue" />Leg 2</span>
                <span key="h" className="type-legend-you"><span className="tiny-end handoff">H</span>Handoff</span>
            } else {
                <span key="m" className="type-legend-you first"><span className={"tiny-marker " + info["accent"]}>{info["marker"]}</span>{info["marker_label"]}</span>
                if my_trip is not None {
                    <span key="you" className="type-legend-you"><span className="tiny-end">A</span>Your route</span>
                }
                if other_route is not None {
                    <span key="their" className="type-legend-you"><i className={"dash-swatch " + info["accent"]} />Their route</span>
                }
            }}
        </div>
    </APIProvider>;
}

# Draws the route polylines + Google's live traffic layer onto the parent map,
# then fits the view to them. Renders nothing itself.
def:pub RouteLines(lines: list[dict], signature: str) -> JsxElement {
    gmap: any = useMap();

    useEffect(lambda {
        if not gmap {
            return lambda { };
        }
        g: any = window.google;  # jac:ignore[E1030]
        traffic = new(g.maps.TrafficLayer);  # jac:ignore[E1053]
        traffic.setMap(gmap);
        drawn: list[any] = [];
        bounds = new(g.maps.LatLngBounds);  # jac:ignore[E1053]
        for line in lines {
            path = [{"lat": p[0], "lng": p[1]} for p in line["points"]];
            options: dict = {"path": path, "strokeColor": line["color"], "strokeWeight": 5, "strokeOpacity": 0.9};
            if line["dashed"] {
                options = {
                    **options, "strokeOpacity": 0,
                    "icons": [{"icon": {"path": "M 0,-1 0,1", "strokeOpacity": 1, "scale": 3}, "offset": "0", "repeat": "14px"}]
                };
            }
            if not line["dashed"] {
                # White casing underneath keeps the line readable over busy roads.
                casing = new(g.maps.Polyline, {"path": path, "strokeColor": "#ffffff", "strokeWeight": 9, "strokeOpacity": 1});  # jac:ignore[E1053]
                casing.setMap(gmap);
                drawn.append(casing);
            }
            poly = new(g.maps.Polyline, options);  # jac:ignore[E1053]
            poly.setMap(gmap);
            drawn.append(poly);
            for pt in path {
                bounds.extend(pt);
            }
        }
        if len(drawn) > 0 {
            gmap.fitBounds(bounds, 48);
        }
        return lambda {
            traffic.setMap(None);
            for poly in drawn {
                poly.setMap(None);
            }
        };
    }, [gmap, signature]);

    return <span className="route-lines" hidden={True} />;
}

# Scan dots scattered around the route while searching (degrees, ~5-9 km).
glob PROBE_DEG: list[list[float]] = [
    [0.06, -0.08], [-0.05, 0.07], [0.08, 0.06], [-0.07, -0.06], [0.04, 0.09],
    [-0.04, -0.1], [0.09, -0.02], [-0.09, 0.03], [0.03, -0.07], [-0.03, 0.08],
];

# The map-side half of the search animation, drawn with plain Google Maps
# overlays: searching = route trace + radar pulse + blinking scan dots;
# revealing = graph edges growing from your start to each match, one by one.
def:pub SearchOverlay(origin: list[float], trace: list[list[float]], targets: list[list[float]], phase: str) -> JsxElement {
    gmap: any = useMap();
    sig = phase + ":" + str(len(trace)) + ":" + str(len(targets)) + ":" + (f"{origin[0]:.3f}" if len(origin) == 2 else "none");

    useEffect(lambda {
        if not gmap or len(origin) != 2 or phase == "ready" {
            return lambda { };
        }
        g: any = window.google;  # jac:ignore[E1030]
        drawn: list[any] = [];
        timers: list[float] = [];
        home = {"lat": origin[0], "lng": origin[1]};
        pulse: dict[str, float] = {"r": 0.0};
        at: dict[str, int] = {"i": 0};

        if phase == "searching" {
            radar = new(g.maps.Circle, {  # jac:ignore[E1053]
                "center": home, "radius": 100, "map": gmap, "clickable": False, "zIndex": 40,
                "strokeColor": "#176b45", "strokeWeight": 2, "fillColor": "#c9e96c", "fillOpacity": 0.3
            });
            drawn.append(radar);
            timers.append(setInterval(lambda {  # jac:ignore[W2001]
                pulse["r"] = (pulse["r"] + 350.0) if pulse["r"] < 15000.0 else 0.0;
                fade = 1.0 - pulse["r"] / 15000.0;
                radar.setRadius(pulse["r"]);
                radar.setOptions({"fillOpacity": 0.3 * fade, "strokeOpacity": 0.9 * fade});
            }, 40));

            path = [{"lat": p[0], "lng": p[1]} for p in trace];
            if len(path) > 1 {
                tracer = new(g.maps.Polyline, {  # jac:ignore[E1053]
                    "path": [], "map": gmap, "zIndex": 50, "clickable": False,
                    "strokeColor": "#c9e96c", "strokeWeight": 7, "strokeOpacity": 1
                });
                drawn.append(tracer);
                stride = max(1, int(len(path) / 70));
                timers.append(setInterval(lambda {  # jac:ignore[W2001]
                    at["i"] = (at["i"] + stride) if at["i"] < len(path) else 0;
                    tracer.setPath(path[0:at["i"]]);
                }, 30));
            }

            for (k, off) in enumerate(PROBE_DEG) {
                base = trace[min(int(k * (len(trace) - 1) / (len(PROBE_DEG) - 1)), len(trace) - 1)] if len(trace) > 0 else origin;
                probe = new(g.maps.Circle, {  # jac:ignore[E1053]
                    "center": {"lat": base[0] + off[0], "lng": base[1] + off[1]}, "radius": 1400,
                    "map": gmap, "clickable": False, "zIndex": 45, "strokeOpacity": 0,
                    "fillColor": "#386fa4", "fillOpacity": 0.0
                });
                drawn.append(probe);
                timers.append(setInterval(lambda {  # jac:ignore[W2001]
                    probe.setOptions({"fillOpacity": 0.7 if probe.get("fillOpacity") < 0.3 else 0.12});
                }, 520 + k * 70));
            }
        }

        if phase == "revealing" {
            for (k, t) in enumerate(targets[0:6]) {
                timers.append(setTimeout(lambda {  # jac:ignore[W2001]
                    link = new(g.maps.Polyline, {  # jac:ignore[E1053]
                        "path": [home, home], "map": gmap, "zIndex": 55, "clickable": False,
                        "strokeColor": "#176b45", "strokeWeight": 3, "strokeOpacity": 0.9, "geodesic": True
                    });
                    dot = new(g.maps.Circle, {  # jac:ignore[E1053]
                        "center": {"lat": t[0], "lng": t[1]}, "radius": 900, "map": gmap, "zIndex": 56,
                        "clickable": False, "strokeColor": "#176b45", "strokeWeight": 2,
                        "fillColor": "#c9e96c", "fillOpacity": 0.8
                    });
                    drawn.append(link);
                    drawn.append(dot);
                    grow: dict[str, int] = {"f": 0};
                    timers.append(setInterval(lambda {  # jac:ignore[W2001]
                        if grow["f"] < 12 {
                            grow["f"] = grow["f"] + 1;
                            f = grow["f"] / 12;
                            link.setPath([home, {"lat": origin[0] + (t[0] - origin[0]) * f, "lng": origin[1] + (t[1] - origin[1]) * f}]);
                        }
                    }, 25));
                }, k * 420));
            }
        }

        return lambda {
            for tm in timers {
                clearInterval(tm);
                clearTimeout(tm);
            }
            for o in drawn {
                o.setMap(None);
            }
        };
    }, [gmap, sig]);

    return <span className="search-overlay" hidden={True} />;
}

def _signature(r: RouteView | None) -> str {
    if r is None or len(r.points) == 0 {
        return "none";
    }
    first = r.points[0];
    last = r.points[len(r.points) - 1];
    return f"{len(r.points)}:{first[0]:.4f},{first[1]:.4f}:{last[0]:.4f},{last[1]:.4f}";
}

def _accent_hex(accent: str) -> str {
    if accent == "blue" {
        return "#386fa4";
    }
    if accent == "purple" {
        return "#7256a5";
    }
    if accent == "amber" {
        return "#c57928";
    }
    return "#0e4d31";
}
