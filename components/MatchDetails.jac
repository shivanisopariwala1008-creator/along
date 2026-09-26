"""MatchDetails — the key judge-demo screen: side-by-side trips, deterministic
metrics, and the AI-generated explanation of why the graph found this match."""

import from "@jac/runtime" { Link, useNavigate, useParams }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowLeft01Icon, Route01Icon, Clock01Icon, ShieldIcon, Money03Icon, MessageIcon, SparklesIcon
}
import from .ui.button { Button }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.badge { Badge }
import from .ui.skeleton { Skeleton }
import from .BrandMark { BrandMark }
sv import from ..graph.along { get_match_details, explain_match, MatchDetailView, MatchCardView }

def:pub MatchDetails() -> JsxElement {
    params = useParams();
    match_id: str = (params["matchId"] or "") as str;

    has detail: MatchDetailView | None = None,
        explanation: str = "",
        loading: bool = True,
        explaining: bool = True;

    nav = useNavigate();

    async can with entry {
        if not match_id {
            loading = False;
            return;
        }
        detail = await get_match_details(match_id);
        loading = False;
        text = await explain_match(match_id);
        explanation = text;
        explaining = False;
    }

    def go_graph(e: MouseEvent) { nav("/graph/" + match_id); }
    def go_chat(e: MouseEvent) { nav("/chat/" + match_id); }

    if loading {
        return <div className="mx-auto flex max-w-4xl flex-col gap-4 pt-10 pl-6 pr-6">
            <Skeleton className="h-10 w-64" />
            <Skeleton className="h-64 w-full rounded-2xl" />
        </div>;
    }

    if detail == None or detail.card == None {
        return <div className="mx-auto flex max-w-md flex-col items-center gap-4 pt-24 text-center pl-6 pr-6">
            <h1 className="text-xl font-semibold">Match not found</h1>
            <Link to="/matches"><Button variant="outline">Back to matches</Button></Link>
        </div>;
    }

    card = detail.card as MatchCardView;
    driver = card.driver_trip;
    rider = card.rider_trip;

    return <div className="min-h-svh bg-muted/30">
        <div className="mx-auto flex max-w-4xl flex-col gap-6 pt-10 pb-16 pl-6 pr-6">
            <div className="flex items-center justify-between">
                <BrandMark />
                <Link to="/matches" className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-4" />
                    Back to matches
                </Link>
            </div>

            <div className="flex flex-col items-start gap-2">
                <Badge className="bg-emerald-600 text-white hover:bg-emerald-600">{str(card.overall_score) + "% Journey Match"}</Badge>
                <h1 className="text-3xl font-semibold tracking-tight">{str(card.overall_score) + "% Journey Match"}</h1>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
                <Card className="shadow-sm">
                    <CardHeader>
                        <CardTitle>Your trip</CardTitle>
                        <CardDescription>{(rider.origin_name if rider else "") + " -> " + (rider.destination_name if rider else "")}</CardDescription>
                    </CardHeader>
                    <CardContent className="flex flex-col gap-2 text-sm text-muted-foreground">
                        <p>{"Need to arrive by " + (rider.arrival_deadline if rider else "")}</p>
                        <p>{rider.recurrence_days if rider else ""}</p>
                    </CardContent>
                </Card>
                <Card className="shadow-sm">
                    <CardHeader>
                        <CardTitle>Their trip</CardTitle>
                        <CardDescription>{(driver.origin_name if driver else "") + " -> " + (driver.destination_name if driver else "")}</CardDescription>
                    </CardHeader>
                    <CardContent className="flex flex-col gap-2 text-sm text-muted-foreground">
                        <p>{"Leaves around " + (driver.departure_time if driver else "")}</p>
                        <p>{driver.recurrence_days if driver else ""}</p>
                    </CardContent>
                </Card>
            </div>

            <Card className="shadow-sm">
                <CardHeader><CardTitle>Match metrics</CardTitle></CardHeader>
                <CardContent className="grid grid-cols-2 gap-4 sm:grid-cols-3">
                    <MetricTile icon={Route01Icon} label="Route overlap" value={str(card.route_score) + "%"} />
                    <MetricTile icon={Clock01Icon} label="Estimated detour" value={"+" + str(card.detour_minutes) + " min"} />
                    <MetricTile icon={Clock01Icon} label="Time compatibility" value={str(card.time_score) + "%"} />
                    <MetricTile icon={ShieldIcon} label="Preference compatibility" value={str(card.preference_score) + "%"} />
                    <MetricTile icon={ShieldIcon} label="Seats available" value={str(driver.seats_available if driver else 0)} />
                    <MetricTile icon={Money03Icon} label="Estimated weekly savings" value={"~$" + str(int(card.estimated_rider_savings))} />
                </CardContent>
            </Card>

            <Card className="border-primary/30 bg-primary/5 shadow-sm">
                <CardHeader className="flex flex-row items-center gap-2">
                    <HugeiconsIcon icon={SparklesIcon} strokeWidth={2} className="size-4 text-primary" />
                    <CardTitle className="text-base">AI explanation</CardTitle>
                </CardHeader>
                <CardContent>
                    {if explaining {
                        <Skeleton className="h-16 w-full" />
                        skip;
                    }}
                    <p className="text-sm leading-relaxed text-foreground">{explanation}</p>
                </CardContent>
            </Card>

            <div className="flex flex-wrap items-center justify-between gap-4 rounded-2xl border bg-card pt-4 pb-4 pl-4 pr-4 shadow-sm">
                <p className="text-sm text-muted-foreground">Your identity remains private until both users choose to connect.</p>
                <div className="flex gap-3">
                    <Button variant="outline" onClick={go_graph}>How Along found this</Button>
                    <Button onClick={go_chat} className="shadow-sm">
                        <HugeiconsIcon icon={MessageIcon} strokeWidth={2} className="size-4" />
                        Start Anonymous Chat
                    </Button>
                </div>
            </div>
        </div>
    </div>;
}

def MetricTile(icon: any, label: str, value: str) -> JsxElement {
    return <div className="flex flex-col gap-1 rounded-lg bg-muted/60 pt-3 pb-3 pl-3 pr-3">
        <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <HugeiconsIcon icon={icon} strokeWidth={2} className="size-3.5" />
            <span>{label}</span>
        </div>
        <span className="text-lg font-semibold tabular-nums">{value}</span>
    </div>;
}
