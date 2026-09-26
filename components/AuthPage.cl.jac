"""AuthPage — email + password login and signup (one component, two modes).
Signup is three awaited steps: create account, log in, save the display name."""

import from "@jac/runtime" { Link, useNavigate, useLocation, jacLogin, jacSignup }
import from .ui.button { Button }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
import from .ui.input { Input }
import from .ui.field { Field, FieldLabel }
import from .BrandMark { BrandMark }
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

    return <div className="flex min-h-svh flex-col items-center justify-center gap-6 bg-muted/30 pt-10 pb-10 pl-4 pr-4">
        <Link to="/"><BrandMark /></Link>
        <form onSubmit={handle_submit} className="w-full max-w-sm">
            <Card className="shadow-sm">
                <CardHeader>
                    <CardTitle>{"Create your account" if is_signup else "Welcome back"}</CardTitle>
                    <CardDescription>
                        {"Other members only see your anonymous handle until you both choose to connect." if is_signup else "Log in to post journeys and see your matches."}
                    </CardDescription>
                </CardHeader>
                <CardContent className="flex flex-col gap-4">
                    {is_signup and <Field>
                        <FieldLabel htmlFor="name">Your name</FieldLabel>
                        <Input id="name" value={display_name} onChange={handle_name} placeholder="Priya" autoComplete="name" />
                    </Field>}
                    <Field>
                        <FieldLabel htmlFor="email">Email</FieldLabel>
                        <Input id="email" type="email" value={email} onChange={handle_email} placeholder="you@example.com" autoComplete="email" />
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="password">Password</FieldLabel>
                        <Input
                            id="password" type="password" value={password} onChange={handle_password}
                            placeholder={"At least 8 characters" if is_signup else ""}
                            autoComplete={"new-password" if is_signup else "current-password"}
                        />
                    </Field>
                    {error and <p className="text-sm text-destructive">{error}</p>}
                </CardContent>
                <CardFooter className="flex flex-col gap-3">
                    <Button type="submit" disabled={busy} className="w-full">
                        {("Creating account..." if is_signup else "Logging in...") if busy else ("Create account" if is_signup else "Log in")}
                    </Button>
                    <p className="text-sm text-muted-foreground">
                        {"Already have an account? " if is_signup else "New to Along? "}
                        <Link to={switch_link} className="font-medium text-foreground underline underline-offset-4">
                            {"Log in" if is_signup else "Create an account"}
                        </Link>
                    </p>
                </CardFooter>
            </Card>
        </form>
    </div>;
}
