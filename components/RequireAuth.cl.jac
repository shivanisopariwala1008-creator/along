"""RequireAuth — layout route that only renders its child routes for a logged-in
user; everyone else is sent to /login?next=<where they were going>."""

import from "@jac/runtime" { Outlet, Navigate, useLocation, jacIsLoggedIn }

def:pub RequireAuth() -> JsxElement {
    location = useLocation();
    if jacIsLoggedIn() {
        return <Outlet />;
    }
    target = encodeURIComponent(location.pathname + location.search);  # jac:ignore[W2001,E1032,E1055]
    return <Navigate to={"/login?next=" + target} replace={True} />;
}
