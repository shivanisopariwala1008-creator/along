"""Home — Figma landing screen: hero with a live-looking route card, the four
ways to travel, and the trust strip."""

import from "@jac/runtime" { useNavigate, Link }
import from .Icon { Icon }
import from .AppHeader { AppHeader }
import from .TripAssistant { TripAssistant }
import from ...lib.along { flow_keys, flow_info }

def:pub Home() -> JsxElement {
    nav = useNavigate();

    def start(kind: str) {
        nav("/journey/" + kind);
    }

    return <div className="app-shell">
        <AppHeader />
        <main className="home">
            <section className="hero">
                <div className="hero-copy">
                    <div className="eyebrow"><span className="live-dot" />Travel together across Michigan</div>
                    <h1>Shared journeys.<br /><em>Stronger communities.</em></h1>
                    <TripAssistant />
                    <p className="hero-sub">Find people heading your way, make a trusted connection, and move through Michigan together.</p>
                    <button className="demo-button" onClick={lambda (e: MouseEvent) { nav("/demo"); }}>
                        <span className="demo-play">▶</span> View demo <small>4 min · narrated</small>
                    </button>
                </div>
                <div className="mini-map-wrap" aria-hidden="true">
                    <div className="mini-map">
                        <span className="city city-flint">Flint</span>
                        <span className="city city-grand">Grand Blanc</span>
                        <span className="city city-aa">Ann Arbor</span>
                        <span className="city city-detroit">Detroit</span>
                        <svg viewBox="0 0 520 250">
                            <path className="mini-road" d="M20 80C120 70 160 150 245 130S355 80 500 110" />
                            <path className="mini-road" d="M110 10c20 90 30 150 90 230M390 15c-40 80-80 150-60 230" />
                            <path className="mini-route" d="M112 64c26 55 55 100 155 132s146-19 185-57" />
                        </svg>
                        <span className="map-pin pin-a"><Icon name="pin" /></span>
                        <span className="map-pin pin-b"><Icon name="pin" /></span>
                        <div className="floating-match">
                            <span className="avatar avatar-small">MD</span>
                            <span><strong>MapleDriver</strong><small>Route match</small></span>
                            <b>96%</b>
                        </div>
                    </div>
                </div>
            </section>

            <section className="choice-section">
                <div className="section-heading">
                    <div>
                        <span className="step-kicker">Or start here</span>
                        <h2>How are you traveling?</h2>
                    </div>
                </div>
                <div className="action-grid">
                    {for (i, key) in enumerate(flow_keys()) {
                        <button className={"action-card action-" + key} key={key} onClick={lambda (e: MouseEvent) { start(key); }}>
                            <span className="action-icon"><Icon name={flow_info(key)["icon"]} size={25} /></span>
                            <span className="action-title">{flow_info(key)["title"]}</span>
                            <span className="action-detail">{flow_info(key)["detail"]}</span>
                            <span className="action-link">Get started <Icon name="arrow" /></span>
                        </button>
                    }}
                </div>
            </section>

            <section className="trust-strip">
                <div>
                    <Icon name="shield" />
                    <span><strong>Privacy by design</strong><small>Approximate locations until you choose to share</small></span>
                </div>
                <div>
                    <Icon name="chat" />
                    <span><strong>Connect anonymously</strong><small>Get comfortable before revealing your identity</small></span>
                </div>
                <div>
                    <Icon name="star" />
                    <span><strong>Community trust</strong><small>Ratings help others travel with confidence</small></span>
                </div>
            </section>

            <footer className="home-footer">
                <span>Shared journeys. Stronger communities.</span>
                <nav>
                    <Link to="/matches">My matches</Link>
                    <Link to="/profile">Profile</Link>
                </nav>
            </footer>
        </main>
    </div>;
}
