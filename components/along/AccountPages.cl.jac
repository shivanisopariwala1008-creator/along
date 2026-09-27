"""Account pages for email verification and password reset. They call
jac-scale's built-in auth endpoints directly; the emails link back here.

/forgot-password          ask for a reset link
/reset-password?token=    choose a new password
/verify-email?token=      confirm your email address
"""

import from "@jac/runtime" { Link, useLocation, useNavigate }
import from .Icon { Icon }

# POST to a jac-scale auth endpoint; returns {"ok": bool, "message": str}.
async def:pub auth_post(path: str, body: dict, with_token: bool) -> dict {
    headers = {"Content-Type": "application/json"};
    if with_token {
        token: any = localStorage.getItem("jac_token");
        if token {
            headers["Authorization"] = "Bearer " + str(token);
        }
    }
    try {
        resp: any = await fetch(path, {"method": "POST", "headers": headers, "body": JSON.stringify(body)});
        data: any = await resp.json();
        ok: bool = bool(resp.ok) and data["ok"] != False;
        message = "";
        if data["error"] and data["error"]["message"] {
            message = data["error"]["message"] as str;
        } elif data["data"] and data["data"]["message"] {
            message = data["data"]["message"] as str;
        }
        return {"ok": ok, "message": message};
    } except Exception as e {
        return {"ok": False, "message": "Couldn’t reach Along. Please try again."};
    }
}

def _token_from(search: any) -> str {
    params: any = new(URLSearchParams, search);  # jac:ignore[E1032,E1053]
    return (params.get("token") or "") as str;
}

def AccountShell(children: any = None) -> JsxElement {
    return <div className="app-shell auth-page">
        <Link to="/" className="brand auth-brand" aria-label="Along home">
            <span className="brand-mark"><span /></span>
            <span>Along</span>
        </Link>
        <div className="auth-card">{children}</div>
    </div>;
}

def:pub ForgotPasswordPage() -> JsxElement {
    has email: str = "",
        busy: bool = False,
        sent: bool = False,
        error: str = "";

    async def submit(e: FormEvent) {
        e.preventDefault();
        clean = email.strip().lower();
        if not clean or "@" not in clean {
            error = "Please enter the email you signed up with.";
            return;
        }
        busy = True;
        _ = await auth_post("/user/forgot-password", {"identity": {"type": "email", "value": clean}}, False);
        busy = False;
        sent = True;   # same message either way, so nobody can probe which emails exist
    }

    return <AccountShell>
        <span className="step-kicker">Password help</span>
        <h1>Reset your password</h1>
        {if sent {
            <div key="sent">
                <p>If an account exists for that email, we’ve sent a link to reset your password. It expires in 30 minutes.</p>
                <Link to="/login" className="btn btn-primary full-button">Back to log in</Link>
            </div>
        } else {
            <form key="form" onSubmit={submit} className="account-form">
                <p>Enter your email and we’ll send you a link to choose a new password. (This works once your email is verified — we send that link when you sign up.)</p>
                <label className="field">
                    <span>Email</span>
                    <div><Icon name="chat" /><input id="email" type="email" value={email} onChange={lambda (e: ChangeEvent) { email = e.target.value; }} placeholder="you@example.com" autoComplete="email" /></div>
                </label>
                {error and <p className="form-error">{error}</p>}
                <button type="submit" className="btn btn-primary full-button" disabled={busy}>{"Sending…" if busy else "Send reset link"}</button>
                <p className="auth-switch"><Link to="/login">Back to log in</Link></p>
            </form>
        }}
    </AccountShell>;
}

def:pub ResetPasswordPage() -> JsxElement {
    location: any = useLocation();
    token = _token_from(location.search);

    has password: str = "",
        confirm: str = "",
        busy: bool = False,
        done: bool = False,
        error: str = "";

    async def submit(e: FormEvent) {
        e.preventDefault();
        if len(password) < 8 {
            error = "Password must be at least 8 characters.";
            return;
        }
        if password != confirm {
            error = "The two passwords don’t match.";
            return;
        }
        busy = True;
        result = await auth_post("/user/reset-password", {"token": token, "new_password": password}, False);
        busy = False;
        if result["ok"] {
            done = True;
        } else {
            error = "This reset link is invalid or has expired. Please request a new one.";
        }
    }

    return <AccountShell>
        <span className="step-kicker">Password help</span>
        <h1>Choose a new password</h1>
        {if not token {
            <div key="none"><p>This link is missing its code. Please use the link from your email, or request a new one.</p><Link to="/forgot-password" className="btn btn-primary full-button">Request a new link</Link></div>
        } elif done {
            <div key="done"><p>Your password has been changed. You can log in with it now.</p><Link to="/login" className="btn btn-primary full-button">Log in</Link></div>
        } else {
            <form key="form" onSubmit={submit} className="account-form">
                <label className="field">
                    <span>New password</span>
                    <div><Icon name="lock" /><input id="password" type="password" value={password} onChange={lambda (e: ChangeEvent) { password = e.target.value; }} placeholder="At least 8 characters" autoComplete="new-password" /></div>
                </label>
                <label className="field">
                    <span>Confirm password</span>
                    <div><Icon name="lock" /><input id="confirm" type="password" value={confirm} onChange={lambda (e: ChangeEvent) { confirm = e.target.value; }} autoComplete="new-password" /></div>
                </label>
                {error and <p className="form-error">{error}</p>}
                <button type="submit" className="btn btn-primary full-button" disabled={busy}>{"Saving…" if busy else "Save new password"}</button>
            </form>
        }}
    </AccountShell>;
}

def:pub VerifyEmailPage() -> JsxElement {
    location: any = useLocation();
    token = _token_from(location.search);
    nav = useNavigate();

    has state: str = "checking",   # checking | done | failed
        message: str = "";

    async can with entry {
        if not token {
            state = "failed";
            return;
        }
        result = await auth_post("/user/verify-identity", {"token": token}, False);
        state = "done" if result["ok"] else "failed";
    }

    return <AccountShell>
        <span className="step-kicker">Email verification</span>
        {if state == "checking" {
            <div key="c" className="loading-state"><span className="spinner" /><h3>Confirming your email…</h3></div>
        } elif state == "done" {
            <div key="d">
                <span className="success-icon"><Icon name="check" size={26} /></span>
                <h1>Email verified</h1>
                <p>Thanks! Your profile now shows an “Email verified” badge, so other travelers know your account is real.</p>
                <button className="btn btn-primary full-button" onClick={lambda (e: MouseEvent) { nav("/profile"); }}>Go to your profile</button>
            </div>
        } else {
            <div key="f">
                <h1>Link expired</h1>
                <p>This verification link is invalid or has expired. Send yourself a new one from your profile.</p>
                <button className="btn btn-primary full-button" onClick={lambda (e: MouseEvent) { nav("/profile"); }}>Go to your profile</button>
            </div>
        }}
    </AccountShell>;
}
