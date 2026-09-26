"""Redirects that keep the pre-Figma URLs working."""

import from "@jac/runtime" { Navigate, useLocation }

# /create-trip?role=DRIVER -> /journey/buddy, anything else -> /journey/ride
def:pub LegacyCreateTrip() -> JsxElement {
    location = useLocation();
    params: any = new(URLSearchParams, location.search);  # jac:ignore[E1032,E1053]
    role: str = (params.get("role") or "RIDER") as str;
    return <Navigate to={"/journey/buddy" if role == "DRIVER" else "/journey/ride"} replace={True} />;
}

# /matching?tripId=<id> -> /results?tripId=<id> (the results screen runs matching now)
def:pub LegacyMatching() -> JsxElement {
    location: any = useLocation();
    query: str = (location.search or "") as str;
    return <Navigate to={"/results" + query} replace={True} />;
}
