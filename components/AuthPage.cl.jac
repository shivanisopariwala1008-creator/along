"""AuthPage — email + password login and signup (one component, two modes).
Signup is three awaited steps: create account, log in, save the display name."""

import from "@jac/runtime" { Link, useNavigate, useLocation, jacLogin, jacSignup }
import from .along.Icon { Icon }
sv import from ..services.along { update_profile }

def:pub AuthPage(mode: str = "login") -> JsxElement {
    location = useLocation();
    params: any = new(URLSearchParams, location.search);  # jac:ignore[E1032,E1053]
    raw_next: str = (params.get("next") or "/") as str;
    # Only allow in-app paths so ?next= can't bounce users to another site.
    next_path: str = raw_next if raw_next.startswith("/") and not raw_next.startswith("//") else "/";
    is_signup: bool = mode == "signup";

    has email: str = "",
        password: str = "",
        display_name: str = "",
        busy: bool = False,
        error: str = "";

    nav = useNavigate();

    def handle_email(e: ChangeEvent) { email = e.target.value; }
    def handle_password(e: ChangeEvent) { password = e.target.value; }
    def handle_name(e: ChangeEvent) { display_name = e.target.value; }

    async def handle_submit(e: FormEvent) {
        e.preventDefault();
        clean_email = email.strip().lower();
        if not clean_email or "@" not in clean_email {
            error = "Please enter a valid email address.";
            return;
        }
        if len(password) < 8 {
            error = "Password must be at least 8 characters.";
            return;
        }
        if is_signup and not display_name.strip() {
            error = "Please tell us your name.";
            return;
        }

        busy = True;
        error = "";
        signup_result: dict | None = None;
        login_ok: bool = False;
        try {
            if is_signup {
                signup_result = await jacSignup([{"type": "email", "value": clean_email}], password);
                if not signup_result["success"] {
                    error = "Couldn't create that account — the email may already be registered.";
                    busy = False;
                    return;
                }
            }
            login_ok = await jacLogin({"type": "email", "value": clean_email}, password);
            if not login_ok {
                error = "Account created, but logging in failed — please try logging in." if is_signup else "Incorrect email or password.";
                busy = False;
                return;
            }
            if is_signup {
                _ = await update_profile(display_name.strip(), "");
            }
        } except Exception as ex {
            error = "Something went wrong. Please try again.";
            busy = False;
            return;
        }
        busy = False;
        nav(next_path, {"replace": True});
    }

    switch_link: str = ("/login" if is_signup else "/signup") + "?next=" + encodeURIComponent(next_path);  # jac:ignore[W2001]

    return <div className="app-shell auth-page">
        <Link to="/" className="brand auth-brand" aria-label="Along home">
            <span className="brand-mark"><span /></span>
            <span>Along</span>
        </Link>
        <form onSubmit={handle_submit} className="auth-card">
            <span className="step-kicker">{"Join Along" if is_signup else "Welcome back"}</span>
            <h1>{"Create your account" if is_signup else "Log in"}</h1>
            <p>{"Other members only see your anonymous name until you both choose to connect." if is_signup else "Pick up where you left off — your journeys and messages are waiting."}</p>
            {if is_signup {
                <label key="name" className="field">
                    <span>Your name</span>
                    <div><Icon name="user" /><input id="name" value={display_name} onChange={handle_name} placeholder="Priya" autoComplete="name" /></div>
                </label>
            }}
            <label className="field">
                <span>Email</span>
                <div><Icon name="chat" /><input id="email" type="email" value={email} onChange={handle_email} placeholder="you@example.com" autoComplete="email" /></div>
            </label>
            <label className="field">
                <span>Password</span>
                <div>
                    <Icon name="lock" />
                    <input
                        id="password" type="password" value={password} onChange={handle_password}
                        placeholder={"At least 8 characters" if is_signup else ""}
                        autoComplete={"new-password" if is_signup else "current-password"}
                    />
                </div>
            </label>
            {error and <p className="form-error" role="alert">{error}</p>}
            <button type="submit" className="btn btn-primary full-button" disabled={busy}>
                {("Creating account…" if is_signup else "Logging in…") if busy else ("Create account" if is_signup else "Log in")}
            </button>
            <p className="auth-switch">
                {"Already have an account? " if is_signup else "New to Along? "}
                <Link to={switch_link}>{"Log in" if is_signup else "Create an account"}</Link>
            </p>
            <div className="auth-note"><Icon name="shield" size={16} /> Your identity stays private until you both agree.</div>
        </form>
    </div>;
}
