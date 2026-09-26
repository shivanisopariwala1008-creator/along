"""AppHeader — sticky top bar from the Figma prototype: brand, the four
journey types, conversations, and the profile avatar (or log in / sign up)."""

import from "@jac/runtime" { useNavigate, jacIsLoggedIn, jacLogout }
import from .Icon { Icon }
import from ...lib.along { flow_keys, flow_info, initials }
sv import from ...services.along { get_my_profile, ProfileView }

def:pub AppHeader(progress: bool = False) -> JsxElement {
    has menu_open: bool = False,
        avatar: str = "",
        logged_in: bool = jacIsLoggedIn();

    nav = useNavigate();

    # Every page renders its own header, so this runs on each navigation.
    can with entry {
        window.scrollTo(0, 0);
    }

    async can with entry {
        if logged_in {
            try {
                profile: ProfileView | None = await get_my_profile();
                if profile {
                    avatar = initials(profile.display_name or profile.rider_handle);
                }
            } except Exception as e {
                # Expired/invalid token: treat as logged out.
                jacLogout();
                logged_in = False;
            }
        }
    }

    def go(path: str) {
        menu_open = False;
        nav(path);
    }

    def toggle_menu(e: MouseEvent) { menu_open = not menu_open; }

    def handle_logout(e: MouseEvent) {
        jacLogout();
        logged_in = False;
        menu_open = False;
        nav("/");
    }

    return <header className="topbar">
        <button className="brand" onClick={lambda (e: MouseEvent) { go("/"); }} aria-label="Along home">
            <span className="brand-mark"><span /></span>
            <span>Along</span>
        </button>
        <nav className="desktop-nav" aria-label="Main navigation">
            {for key in flow_keys() {
                <button key={key} onClick={lambda (e: MouseEvent) { go("/journey/" + key); }}>{flow_info(key)["title"]}</button>
            }}
        </nav>
        <div className="header-actions">
            {if logged_in {
                <button key="convos" className="icon-link" onClick={lambda (e: MouseEvent) { go("/chat"); }}>
                    <Icon name="chat" /><span className="desktop-only">Conversations</span>
                </button>
                <button key="avatar" className="avatar avatar-small" onClick={lambda (e: MouseEvent) { go("/profile"); }} aria-label="Profile">
                    {avatar or <Icon name="user" size={16} />}
                </button>
            } else {
                <button key="login" className="icon-link" onClick={lambda (e: MouseEvent) { go("/login"); }}>Log in</button>
                <button key="signup" className="btn btn-primary header-cta" onClick={lambda (e: MouseEvent) { go("/signup"); }}>Sign up</button>
            }}
            <button className="mobile-menu" onClick={toggle_menu} aria-label="Open menu">
                <Icon name={"x" if menu_open else "list"} />
            </button>
        </div>
        {if menu_open {
            <div key="mobile" className="mobile-nav">
                {for key in flow_keys() {
                    <button key={key} onClick={lambda (e: MouseEvent) { go("/journey/" + key); }}>{flow_info(key)["title"]}</button>
                }}
                <button onClick={lambda (e: MouseEvent) { go("/matches"); }}>My matches</button>
                <button onClick={lambda (e: MouseEvent) { go("/chat"); }}>Conversations</button>
                <button onClick={lambda (e: MouseEvent) { go("/profile"); }}>Profile &amp; trust</button>
                <button onClick={lambda (e: MouseEvent) { go("/impact"); }}>Local impact</button>
                {if logged_in {
                    <button key="out" onClick={handle_logout}>Log out</button>
                } else {
                    <button key="in" onClick={lambda (e: MouseEvent) { go("/login"); }}>Log in</button>
                }}
            </div>
        }}
        {progress and <div className="progress-line" />}
    </header>;
}
