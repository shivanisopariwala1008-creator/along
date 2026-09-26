"""AnonymousChat — chat between the two participants of a match, plus mutual
identity reveal. Both sides stay anonymous until BOTH approve; only then are
names/verification revealed. The server decides which side the caller is."""

import from "@jac/runtime" { Link, useParams, useEffect, __jacClearCache }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowLeft01Icon, ShieldIcon, SentIcon, CheckmarkCircle02Icon }
import from .ui.button { Button }
import from .ui.input { Input }
import from .ui.badge { Badge }
import from .ui.avatar { Avatar, AvatarFallback }
import from .BrandMark { BrandMark }
sv import from ..services.along { create_anonymous_connection, send_message, approve_identity_reveal, get_conversation, ConversationView }

def:pub AnonymousChat() -> JsxElement {
    params = useParams();
    match_id: str = (params["matchId"] or "") as str;

    has convo: ConversationView | None = None,
        draft: str = "",
        loading: bool = True;

    async can with entry {
        if match_id {
            convo = await create_anonymous_connection(match_id);
        }
        loading = False;
    }

    # Poll for the other participant's messages / approval. Reader responses are
    # cached client-side for 60s, so clear the cache before each refresh.
    async def refresh -> None {
        latest: ConversationView | None = None;
        __jacClearCache();
        latest = await get_conversation(match_id);
        if latest {
            convo = latest;
        }
    }

    useEffect(lambda {
        if not match_id {
            return lambda { };
        }
        interval = setInterval(lambda { refresh(); }, 4000);  # jac:ignore[W2001]
        return lambda { clearInterval(interval); };  # jac:ignore[W2001]
    }, [match_id]);

    def handle_draft(e: ChangeEvent) { draft = e.target.value; }

    async def handle_send -> None {
        text = draft.strip();
        if not text or not match_id {
            return;
        }
        draft = "";
        convo = await send_message(match_id, text);
    }

    async def handle_approve -> None {
        if match_id {
            convo = await approve_identity_reveal(match_id);
        }
    }

    if loading {
        return <div className="flex min-h-svh items-center justify-center"><p className="text-sm text-muted-foreground">Opening the conversation...</p></div>;
    }

    c = convo;

    return <div className="flex h-svh flex-col bg-background">
        <header className="flex h-16 shrink-0 items-center justify-between border-b pl-6 pr-6">
            <div className="flex items-center gap-3">
                <Link to={"/matches/" + match_id} className="text-muted-foreground hover:text-foreground">
                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-5" />
                </Link>
                <BrandMark />
                <span className="text-sm font-medium text-muted-foreground">Anonymous Match</span>
            </div>
            {c and <Badge variant={"secondary" if not c.identity_revealed else "default"}>
                {"Anonymous" if not c.identity_revealed else "Identity revealed"}
            </Badge>}
        </header>

        <div className="border-b bg-amber-50 pt-3 pb-3 pl-6 pr-6">
            <p className="flex items-center gap-2 text-sm text-amber-900">
                <HugeiconsIcon icon={ShieldIcon} strokeWidth={2} className="size-4" />
                You're chatting anonymously. Avoid sharing personal details until you're comfortable.
            </p>
        </div>

        <div className="flex flex-1 flex-col gap-4 overflow-y-auto pt-6 pb-6 pl-6 pr-6">
            {if c {
                for (i, msg) in enumerate(c.messages) {
                    <div key={str(i)} className={"flex items-start gap-3 " + ("flex-row-reverse" if msg.mine else "")}>
                        <Avatar className="size-8 shrink-0"><AvatarFallback>{msg.sender_anonymous_handle[:1]}</AvatarFallback></Avatar>
                        <div className={"flex max-w-md flex-col gap-1 rounded-2xl pt-2.5 pb-2.5 pl-3.5 pr-3.5 text-sm " + ("bg-primary text-primary-foreground" if msg.mine else "bg-muted")}>
                            <span className="text-xs font-medium opacity-70">{("You" if msg.mine else msg.sender_anonymous_handle) + " · " + msg.timestamp}</span>
                            <span className="leading-relaxed">{msg.body}</span>
                        </div>
                    </div>
                }
            }}
        </div>

        {if c {
            cv = c as ConversationView;
            <div key="composer" className="border-t pt-4 pb-4 pl-6 pr-6">
                {if cv.identity_revealed {
                    <div key="revealed" className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 pt-3 pb-3 pl-4 pr-4 text-sm text-emerald-900">
                        <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} className="size-4" />
                        <span>{"Mutual approval complete — you're connected with " + (cv.other_display_name or cv.other_handle) + (" (verified)" if cv.other_verified else "") + ". You can now share contact details."}</span>
                    </div>
                    skip;
                }}
                <div className="flex flex-col gap-3">
                    <div className="flex items-center gap-2 rounded-xl border bg-background pt-1.5 pb-1.5 pl-3 pr-1.5 shadow-sm focus-within:ring-2 focus-within:ring-ring/40">
                        <Input value={draft} onChange={handle_draft} placeholder="Write a message" className="border-0 shadow-none focus-visible:ring-0" />
                        <Button size="sm" disabled={not draft.strip()} onClick={handle_send}>
                            <HugeiconsIcon icon={SentIcon} strokeWidth={2} className="size-4" />
                            Send
                        </Button>
                    </div>
                    <div className="flex items-center justify-between rounded-xl border pt-3 pb-3 pl-4 pr-4">
                        <span className="text-sm">
                            {"You (" + cv.my_handle + "): " + ("approved" if cv.me_approved else "not yet") + "  ·  " + cv.other_handle + ": " + ("approved" if cv.other_approved else "waiting")}
                        </span>
                        <Button variant="outline" size="sm" onClick={handle_approve} disabled={cv.me_approved}>
                            I'm comfortable connecting
                        </Button>
                    </div>
                </div>
            </div>
        }}
    </div>;
}
