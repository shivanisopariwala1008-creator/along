"""ChatView — Figma conversations: inbox, anonymous chat with mutual identity
reveal, and journey details. Both sides stay anonymous until BOTH approve;
the server decides which side the caller is and what they may see.

/chat             inbox only (pick a conversation)
/chat/:matchId    opens (or starts) the conversation for that match
"""

import from "@jac/runtime" { useNavigate, useParams, useEffect, __jacClearCache }
import from .Icon { Icon }
import from .MapCanvas { MapCanvas }
import from .SafetyActions { SafetyDialog }
import from .ShareTrip { share_trip }
import from ...lib.along { flow_of_trip, initials, fmt_time, short_place, trip_timing }
sv import from ...services.along {
    create_anonymous_connection, send_message, approve_identity_reveal, get_conversation,
    get_my_conversations, get_match_details, close_match, complete_match,
    get_my_notifications, mark_notifications_read, respond_relay_leg, NotificationView,
    ConversationView, ConversationSummaryView, MatchDetailView, MatchCardView, TripView
}

# Keyed on the match so switching conversations starts from a clean state.
def:pub ChatRoute() -> JsxElement {
    params = useParams();
    match_id: str = (params["matchId"] or "") as str;
    return <ChatView key={match_id or "inbox"} match_id={match_id} />;
}

def:pub ChatView(match_id: str) -> JsxElement {
    has convo: ConversationView | None = None,
        detail: MatchDetailView | None = None,
        inbox: list[ConversationSummaryView] = [],
        search: str = "",
        draft: str = "",
        loading: bool = True,
        busy: bool = False,
        menu_open: bool = False,
        dialog: str = "",
        toast: str = "";

    nav = useNavigate();

    async can with entry {
        if match_id {
            convo = await create_anonymous_connection(match_id);
            detail = await get_match_details(match_id);
        }
        inbox = await get_my_conversations();
        loading = False;
        # Opening a chat clears its "new message" notifications.
        if match_id {
            pending: list[NotificationView] = await get_my_notifications();
            ids = [n.id for n in pending if n.match_id == match_id and n.kind == "message" and not n.read];
            if len(ids) > 0 {
                _ = await mark_notifications_read(ids);
            }
        }
    }

    # Poll for the other participant's messages / approval. Reader responses are
    # cached client-side for 60s, so clear the cache before each refresh.
    async def refresh -> None {
        __jacClearCache();
        latest_inbox = await get_my_conversations();
        inbox = latest_inbox;
        if match_id {
            latest: ConversationView | None = await get_conversation(match_id);
            if latest {
                convo = latest;
            }
        }
    }

    useEffect(lambda {
        interval = setInterval(lambda { refresh(); }, 4000);  # jac:ignore[W2001]
        return lambda { clearInterval(interval); };  # jac:ignore[W2001]
    }, [match_id]);

    async def handle_send -> None {
        body = draft.strip();
        if not body or not match_id {
            return;
        }
        draft = "";
        updated = await send_message(match_id, body);
        if updated {
            convo = updated;
        }
    }

    def handle_key(e: KeyboardEvent) {
        if e.key == "Enter" {
            handle_send();
        }
    }

    async def handle_approve -> None {
        busy = True;
        updated = await approve_identity_reveal(match_id);
        if updated {
            convo = updated;
        }
        busy = False;
    }

    async def handle_decline -> None {
        busy = True;
        _ = await close_match(match_id);
        busy = False;
        nav("/chat");
    }

    async def respond(accept: bool) -> None {
        busy = True;
        _ = await respond_relay_leg(match_id, accept);
        __jacClearCache();
        updated: ConversationView | None = await get_conversation(match_id);
        if updated {
            convo = updated;
        }
        busy = False;
    }

    async def share -> None {
        menu_open = False;
        toast = await share_trip(match_id);
    }

    async def handle_complete -> None {
        busy = True;
        _ = await complete_match(match_id);
        busy = False;
        nav("/rate/" + match_id);
    }

    card: MatchCardView | None = None;
    my_trip: TripView | None = None;
    if detail is not None and detail.card is not None {
        card = detail.card;
        my_trip = detail.card.my_trip;
    }
    kind = flow_of_trip(my_trip);
    needle = search.strip().lower();
    visible = [
        s for s in inbox
        if not needle or needle in s.other_handle.lower() or needle in s.other_display_name.lower()
    ];
    c = convo;
    revealed = c is not None and c.identity_revealed;
    other_handle = c.other_handle if c is not None else "";
    display_name = (c.other_display_name or other_handle) if (c is not None and revealed) else other_handle;
    closed = c is not None and c.match_status == "closed";
    completed = c is not None and c.match_status == "completed";

    return <div className="app-shell">
        {if dialog == "remove" {
            <div key="remove" className="dialog-backdrop" role="dialog" aria-modal="true" aria-label="Remove match">
                <div className="dialog-card">
                    <h2>{"Remove " + display_name + "?"}</h2>
                    <p className="dialog-sub">This match and conversation leave your list. They aren’t told, and you can still find each other in future searches.</p>
                    <div className="dialog-actions">
                        <button className="btn btn-secondary" onClick={lambda (e: MouseEvent) { dialog = ""; }}>Keep</button>
                        <button className="btn btn-danger" disabled={busy} onClick={lambda (e: MouseEvent) { handle_decline(); }}>Remove match</button>
                    </div>
                </div>
            </div>
        } elif dialog and c is not None {
            <SafetyDialog key="safety" match_id={match_id} handle={display_name} mode={dialog} onClose={lambda { dialog = ""; }} />
        }}
        <main className={"chat-page" + ("" if match_id else " no-selection")}>
            <aside className="conversation-sidebar">
                <div className="conversation-heading">
                    <button className="back-link" onClick={lambda (e: MouseEvent) { nav("/"); }} aria-label="Home"><Icon name="back" /></button>
                    <h1>Messages</h1>
                    <button onClick={lambda (e: MouseEvent) { nav("/matches"); }} aria-label="All matches"><Icon name="tune" /></button>
                </div>
                <label className="search-box">
                    <Icon name="search" />
                    <input placeholder="Search conversations" value={search} onChange={lambda (e: ChangeEvent) { search = e.target.value; }} />
                </label>
                {if not loading and len(visible) == 0 {
                    <p key="none" className="inbox-empty">{"No conversations match your search." if needle else "No conversations yet. Message a match to start one."}</p>
                }}
                {for s in visible {
                    <button
                        key={s.match_id}
                        className={"conversation" + (" active" if s.match_id == match_id else "")}
                        onClick={lambda (e: MouseEvent) { nav("/chat/" + s.match_id); }}
                    >
                        <span className={"avatar" + (" muted" if s.match_status == "closed" else "")}>{initials(s.other_handle)}</span>
                        <span>
                            <strong>{s.other_display_name or s.other_handle}</strong>
                            <small>{"Conversation closed" if s.match_status == "closed" else s.last_message}</small>
                        </span>
                        <time>{fmt_time(s.last_time)}</time>
                    </button>
                }}
            </aside>

            <section className="chat-window">
                {if not match_id {
                    <div key="pick" className="empty-state chat-placeholder">
                        <span><Icon name="chat" size={30} /></span>
                        <h3>Your conversations</h3>
                        <p>Pick a conversation, or message a match to start one. You stay anonymous until you both agree.</p>
                        <button className="btn btn-primary" onClick={lambda (e: MouseEvent) { nav("/matches"); }}>See my matches</button>
                    </div>
                } elif loading {
                    <div key="loading" className="loading-state"><span className="spinner" /><h3>Opening the conversation</h3></div>
                } elif c is None {
                    <div key="missing" className="empty-state">
                        <span><Icon name="lock" size={30} /></span>
                        <h3>Conversation unavailable</h3>
                        <p>This match may belong to someone else or no longer exist.</p>
                        <button className="btn btn-primary" onClick={lambda (e: MouseEvent) { nav("/chat"); }}>Back to messages</button>
                    </div>
                } else {
                    <header key="head" className="chat-header">
                        <button className="mobile-chat-back" onClick={lambda (e: MouseEvent) { nav("/chat"); }} aria-label="Back to messages"><Icon name="back" /></button>
                        <span className="avatar">{initials(display_name)}</span>
                        <div>
                            <strong>{display_name}</strong>
                            <small><i /> {"Identity revealed" if revealed else "Anonymous match"}</small>
                        </div>
                        <div>
                            <button aria-label="View match" onClick={lambda (e: MouseEvent) { nav("/matches/" + match_id); }}><Icon name="map" /></button>
                            <button aria-label="View profile" title="View profile" onClick={lambda (e: MouseEvent) { nav("/people/" + match_id); }}><Icon name="user" /></button>
                            <span className="menu-wrap">
                                <button aria-label="More options" aria-expanded={menu_open} onClick={lambda (e: MouseEvent) { menu_open = not menu_open; }}><Icon name="dots" /></button>
                                {if menu_open {
                                    <div key="menu" className="pop-menu" role="menu">
                                        <button role="menuitem" onClick={lambda (e: MouseEvent) { share(); }}><Icon name="share" size={16} /> Share my trip</button>
                                        <button role="menuitem" onClick={lambda (e: MouseEvent) { menu_open = False; dialog = "report"; }}><Icon name="flag" size={16} /> Report</button>
                                        <button role="menuitem" onClick={lambda (e: MouseEvent) { menu_open = False; dialog = "remove"; }}><Icon name="x" size={16} /> Remove match</button>
                                        <button role="menuitem" className="danger" onClick={lambda (e: MouseEvent) { menu_open = False; dialog = "block"; }}><Icon name="block" size={16} /> Block</button>
                                    </div>
                                }}
                            </span>
                        </div>
                    </header>
                    <div key="banner" className="identity-banner">
                        <Icon name={"check" if revealed else "lock"} />
                        <div>
                            <strong>{"You both agreed — identities revealed" if revealed else ("You agreed to reveal your identity" if c.me_approved else "You’re chatting anonymously")}</strong>
                            <span>{"You can now see names and volunteered contact details." if revealed else (other_handle + " still needs to approve. Nothing has been revealed yet." if c.me_approved else "Share only what feels comfortable. Exact addresses stay private.")}</span>
                        </div>
                        {if not revealed and not c.me_approved and not closed {
                            <button className="btn btn-primary" onClick={handle_approve} disabled={busy}>Agree to reveal identity</button>
                        }}
                    </div>
                    if c.i_am_driver_of_leg and c.relay_status in ["pending", "accepted", "declined"] {
                        <div key="leg" className={"relay-banner " + c.relay_status}>
                            <Icon name="pin" />
                            <div>
                                <strong>{"2-ride trip · you’re the " + ("first" if c.relay_leg == "first" else "second") + " ride"}</strong>
                                <span>{("Drop-off at " if c.relay_leg == "first" else "Pickup at ") + c.relay_stop + " around " + fmt_time(c.relay_time)}</span>
                            </div>
                            {if c.relay_status == "pending" {
                                <span key="btns" className="relay-banner-actions">
                                    <button className="btn btn-secondary" disabled={busy} onClick={lambda (e: MouseEvent) { respond(False); }}>Can’t make it</button>
                                    <button className="btn btn-primary" disabled={busy} onClick={lambda (e: MouseEvent) { respond(True); }}>Accept</button>
                                </span>
                            } else {
                                <em key="st">{"Accepted" if c.relay_status == "accepted" else "You said you can’t make it"}</em>
                            }}
                        </div>
                    }
                    if c.relay_plan_id {
                        plan_link = "/plans/" + c.relay_plan_id;
                        <button key="plan" className="relay-banner rider" onClick={lambda (e: MouseEvent) { nav(plan_link); }}>
                            <Icon name="pin" />
                            <div><strong>Part of your 2-ride trip</strong><span>{"Stop: " + c.relay_stop + " · " + fmt_time(c.relay_time)}</span></div>
                            <em>View trip plan →</em>
                        </button>
                    }
                    if toast {
                        <p key="toast" className="chat-toast" role="status">{toast}</p>
                    }
                    <div key="messages" className="messages">
                        <div className="date-divider">TODAY</div>
                        <div className="system-message"><Icon name="shield" /> Along keeps this conversation anonymous until you both agree.</div>
                        {if my_trip is not None {
                            <div key="loc" className="location-message">
                                <div className="location-mini-map"><span><Icon name="pin" /></span></div>
                                <div>
                                    <strong>Approximate pickup area</strong>
                                    <p>{short_place(my_trip.origin_name) + " public area · Not an exact address"}</p>
                                </div>
                            </div>
                        }}
                        {for (i, m) in enumerate(c.messages) {
                            if m.sender_anonymous_handle == "Along" {
                                <div key={str(i)} className="system-message along-note"><Icon name="shield" /> {m.body}</div>
                            } elif m.mine {
                                <div key={str(i)} className="bubble-row mine">
                                    <div><p>{m.body}</p><time>{fmt_time(m.timestamp) + " · Delivered"}</time></div>
                                </div>
                            } else {
                                <div key={str(i)} className="bubble-row theirs">
                                    <span className="avatar avatar-small">{initials(display_name)}</span>
                                    <div><p>{m.body}</p><time>{fmt_time(m.timestamp)}</time></div>
                                </div>
                            }
                        }}
                        {if c.me_approved and not revealed {
                            <div key="waiting" className="approval-message">
                                <Icon name="lock" />
                                <span><strong>You approved identity reveal</strong>{"Waiting for " + other_handle + ". Your identity remains hidden."}</span>
                            </div>
                        }}
                        {if revealed {
                            <div key="ok" className="approval-message success">
                                <Icon name="check" />
                                <span><strong>Identities revealed</strong>You both independently agreed to connect as yourselves.</span>
                            </div>
                            <div key="contact" className="contact-card">
                                <span className="avatar">{initials(display_name)}</span>
                                <div>
                                    <strong>{display_name + (" · verified" if c.other_verified else "")}</strong>
                                    <small>{("Volunteered contact · " + c.other_phone) if c.other_phone else "No contact details shared yet — ask in chat."}</small>
                                </div>
                                <Icon name="shield" />
                            </div>
                        }}
                    </div>
                    if closed {
                        <div key="closed" className="chat-closed"><Icon name="lock" /> This conversation is closed.</div>
                    } else {
                        <div key="composer" className="composer">
                            <input
                                value={draft} placeholder="Message…" aria-label="Message"
                                onChange={lambda (e: ChangeEvent) { draft = e.target.value; }} onKeyDown={handle_key}
                            />
                            <button className="send-button" onClick={handle_send} disabled={not draft.strip()} aria-label="Send"><Icon name="arrow" /></button>
                        </div>
                    }
                    if completed {
                        <div key="done" className="chat-footer-actions">
                            <span>Trip done</span>
                            {if not c.i_rated {
                                <button onClick={lambda (e: MouseEvent) { nav("/rate/" + match_id); }}><Icon name="star" /> Leave a review</button>
                            }}
                        </div>
                    } elif not closed {
                        <div key="actions" className="chat-footer-actions">
                            <button onClick={handle_decline} disabled={busy}>Not interested</button>
                            <button onClick={handle_complete} disabled={busy}><Icon name="check" /> Trip done</button>
                        </div>
                    }
                }}
            </section>

            <aside className="chat-details">
                {if card is not None and my_trip is not None {
                    <div key="map" className="chat-details-map">
                        <MapCanvas my_trip={my_trip} cards={[card as MatchCardView]} selected={0} onSelect={lambda (i: int) { }} kind={kind} />
                    </div>
                    <h3 key="h">Your journey</h3>
                    <div key="it" className="mini-itinerary">
                        <i />
                        <span>
                            <strong>{my_trip.origin_name}</strong><small>Pickup area</small>
                            <strong>{my_trip.destination_name}</strong><small>{trip_timing(my_trip)}</small>
                        </span>
                    </div>
                    <button key="b" className="btn btn-secondary full-button" onClick={lambda (e: MouseEvent) { nav("/matches/" + match_id); }}>View match details</button>
                } else {
                    <p key="none" className="inbox-empty">Journey details appear here when a conversation is open.</p>
                }}
            </aside>
        </main>
    </div>;
}
