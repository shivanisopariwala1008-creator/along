"""GoogleMapView — the results/details map on real Google Maps: your driving
route (from the Routes API via get_trip_route), the selected match's route
dashed on top, live traffic, and tappable match markers."""

import from "@vis.gl/react-google-maps" { APIProvider, Map as GoogleMap, AdvancedMarker, useMap }
import from react { useEffect }
import from ...lib.along { flow_info, when_text }
sv import from ...services.along { TripView, MatchCardView, RouteView }

glob MICHIGAN_CENTER: dict[str, float] = {"lat": 42.6, "lng": -83.6};

def:pub GoogleMapView(
    api_key: str, map_id: str, my_trip: TripView | None, my_route: RouteView | None,
    other_route: RouteView | None, cards: list[MatchCardView], selected: int,
    onSelect: Callable[[int], None], kind: str = "ride"
) -> JsxElement {
    info = flow_info(kind);
    lines: list[dict] = [];
    if my_route is not None and len(my_route.points) > 1 {
        # Dark ink so the route stands out against Google's green "clear" traffic.
        lines = lines + [{"points": my_route.points, "color": "#17211a", "dashed": False}];
    }
    if other_route is not None and len(other_route.points) > 1 {
        lines = lines + [{"points": other_route.points, "color": _accent_hex(info["accent"]), "dashed": True}];
    }
    # Redraw only when the routes themselves change, not on every render.
    signature = _signature(my_route) + "|" + _signature(other_route);

    return <APIProvider apiKey={api_key}>
        <GoogleMap
            className="gmap" mapId={map_id} defaultCenter={MICHIGAN_CENTER} defaultZoom={9}
            gestureHandling="greedy" disableDefaultUI={True} zoomControl={True}
        >
            <RouteLines lines={lines} signature={signature} />
            {if my_trip is not None {
                <AdvancedMarker key="a" position={{"lat": my_trip.origin_lat, "lng": my_trip.origin_lng}} title="Your start">
                    <span className="trip-end start">A</span>
                </AdvancedMarker>
                <AdvancedMarker key="b" position={{"lat": my_trip.destination_lat, "lng": my_trip.destination_lng}} title="Your destination">
                    <span className="trip-end">B</span>
                </AdvancedMarker>
            }}
            {for (i, c) in enumerate(cards) {
                if c.other_trip is not None {
                    <AdvancedMarker
                        key={c.id} title={c.other_handle} zIndex={10 if selected == i else 1}
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
            <span className={"tiny-marker " + info["accent"]}>{info["marker"]}</span>{info["marker_label"]}
            {my_trip is not None and <span className="type-legend-you"><span className="tiny-end">A</span>Your route</span>}
            {other_route is not None and <span className="type-legend-you"><i className={"dash-swatch " + info["accent"]} />Their route</span>}
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
