"""AppHeader — sticky top bar from the Figma prototype: brand, the four
journey types, conversations, and the profile avatar (or log in / sign up)."""

import from "@jac/runtime" { useNavigate, jacIsLoggedIn, jacLogout, __jacClearCache }
import from react { useEffect }
import from .Icon { Icon }
import from ...lib.along { flow_keys, flow_info, initials, time_ago }
sv import from ...services.along { get_my_profile, get_my_notifications, mark_notifications_read, ProfileView, NotificationView }

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
                # Only an explicit auth rejection ends the session; a blip
                # (network, server restart) must not log you out.
                message: str = str(e);
                if "401" in message or "UNAUTHORIZED" in message.upper() or "INVALID TOKEN" in message.upper() {
                    jacLogout();
                    logged_in = False;
                }
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
                <NotificationBell key="bell" />
                <button key="convos" className="icon-link" onClick={lambda (e: MouseEvent) { go("/chat"); }}>
                    <Icon name="chat" /><span className="desktop-only">Messages</span>
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
                <button onClick={lambda (e: MouseEvent) { go("/chat"); }}>Messages</button>
                <button onClick={lambda (e: MouseEvent) { go("/profile"); }}>Profile &amp; trust</button>
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

# Header bell: unread count + dropdown of Matchmaker matches and new messages.
def:pub NotificationBell() -> JsxElement {
    has items: list[NotificationView] = [],
        open: bool = False;

    nav = useNavigate();

    async def refresh(fresh: bool) -> None {
        if fresh {
            __jacClearCache();   # function results are cached client-side
        }
        try {
            latest: list[NotificationView] = await get_my_notifications();
            items = latest;
        } except Exception as e {
            items = items;
        }
    }

    useEffect(lambda {
        refresh(False);
        timer = setInterval(lambda { refresh(True); }, 20000);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }, []);

    async def open_item(n: NotificationView) -> None {
        open = False;
        if not n.read {
            ids = [n.id];
            _ = await mark_notifications_read(ids);
            items = [x for x in items if x.id != n.id] + [];
            refresh(True);
        }
        nav(("/chat/" if n.kind == "message" else "/matches/") + n.match_id);
    }

    async def mark_all -> None {
        ids: list[str] = [];
        _ = await mark_notifications_read(ids);
        refresh(True);
    }

    unread = len([n for n in items if not n.read]);

    return <div className="bell-wrap">
        <button
            className={"bell-button" + (" has-unread" if unread > 0 else "")}
            onClick={lambda (e: MouseEvent) { open = not open; }}
            aria-label={"Notifications" + (f", {unread} unread" if unread else "")}
        >
            <Icon name="bell" />
            {unread > 0 and <b>{str(unread) if unread < 10 else "9+"}</b>}
        </button>
        {if open {
            <div key="panel" className="bell-panel" role="dialog" aria-label="Notifications">
                <div className="bell-head">
                    <strong>Notifications</strong>
                    {unread > 0 and <button onClick={mark_all}>Mark all read</button>}
                </div>
                {if len(items) == 0 {
                    <div key="empty" className="bell-empty">
                        <Icon name="spark" size={22} />
                        <p>Along's Matchmaker is watching your routes. You'll hear here the moment someone new fits.</p>
                    </div>
                }}
                <ul>
                    {for n in items {
                        <li key={n.id} className={"" if n.read else "unread"}>
                            <button onClick={lambda (e: MouseEvent) { open_item(n); }}>
                                <span className={"bell-icon " + n.kind}><Icon name={"chat" if n.kind == "message" else "spark"} size={16} /></span>
                                <span>
                                    <strong>{n.title}</strong>
                                    <small>{n.body}</small>
                                    <em>{time_ago(n.created_at)}</em>
                                </span>
                            </button>
                        </li>
                    }}
                </ul>
            </div>
        }}
    </div>;
}
