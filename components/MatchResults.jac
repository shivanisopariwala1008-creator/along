"""MatchResults — ranked list of candidate matches, star pairing on top."""

import from "@jac/runtime" { Link, useNavigate }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowLeft01Icon, Route01Icon, Clock01Icon, UserGroupIcon, Money03Icon
}
import from .ui.button { Button }
import from .ui.card { Card, CardHeader, CardTitle, CardContent }
import from .ui.badge { Badge }
import from .ui.skeleton { Skeleton }
import from .ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription, EmptyContent }
import from .BrandMark { BrandMark }
sv import from ..graph.along { get_match_results, MatchCardView }

def:pub MatchResults() -> JsxElement {
    has matches: list[MatchCardView] = [],
        loading: bool = True;

    nav = useNavigate();

    async can with entry {
        matches = await get_match_results();
        loading = False;
    }

    def open_match(match_id: str) {
        nav("/matches/" + match_id);
    }

    return <div className="min-h-svh bg-muted/30">
        <div className="mx-auto flex max-w-4xl flex-col gap-6 pt-10 pb-16 pl-6 pr-6">
            <div className="flex items-center justify-between">
                <BrandMark />
                <Link to="/create-trip" className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-4" />
                    Post another trip
                </Link>
            </div>

            <div className="flex flex-col gap-1">
                <h1 className="text-2xl font-semibold tracking-tight">Your matches</h1>
                <p className="text-sm text-muted-foreground">Ranked by Along's weighted score — route, schedule, detour, preferences and cost.</p>
            </div>

            {if loading {
                <div className="flex flex-col gap-4">
                    <Skeleton className="h-40 w-full rounded-2xl" />
                    <Skeleton className="h-40 w-full rounded-2xl" />
                </div>
                skip;
            }}

            {if not loading and len(matches) == 0 {
                <Empty className="border border-dashed pt-12 pb-12">
                    <EmptyHeader>
                        <EmptyMedia variant="icon"><HugeiconsIcon icon={Route01Icon} strokeWidth={2} /></EmptyMedia>
                        <EmptyTitle>No matches yet</EmptyTitle>
                        <EmptyDescription>Post a journey and Along's walkers will search the mobility graph for you.</EmptyDescription>
                    </EmptyHeader>
                    <EmptyContent><Link to="/create-trip"><Button>Post a journey</Button></Link></EmptyContent>
                </Empty>
                skip;
            }}

            <div className="flex flex-col gap-4">
                {for m in matches {
                    <MatchResultCard key={m.id} card={m} onOpen={open_match} />
                }}
            </div>
        </div>
    </div>;
}

def MatchResultCard(card: MatchCardView, onOpen: Callable[[str], None]) -> JsxElement {
    tone = "bg-emerald-600 text-white hover:bg-emerald-600" if card.overall_score >= 80 else "bg-amber-500 text-white hover:bg-amber-500";
    driver = card.driver_trip;

    def handle_click(e: MouseEvent) { onOpen(card.id); }

    return <Card className="cursor-pointer shadow-sm transition-shadow hover:shadow-md" onClick={handle_click}>
        <CardHeader className="flex flex-row items-start justify-between gap-4">
            <div className="flex flex-col gap-1">
                <CardTitle>{(driver.origin_name if driver else "Driver") + " -> " + (driver.destination_name if driver else "")}</CardTitle>
                <p className="text-sm text-muted-foreground">
                    {"Leaves " + (driver.departure_time if driver else "") + " · " + (driver.recurrence_days if driver else "")}
                </p>
            </div>
            <Badge className={tone}>{str(card.overall_score) + "% Match"}</Badge>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <HugeiconsIcon icon={UserGroupIcon} strokeWidth={2} className="size-4" />
                <span>{str(driver.seats_available if driver else 0) + " seats available"}</span>
            </div>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <div className="rounded-lg bg-muted/60 pt-2 pb-2 text-center">
                    <p className="text-sm font-semibold tabular-nums">{str(card.route_score) + "%"}</p>
                    <p className="text-xs text-muted-foreground">Route overlap</p>
                </div>
                <div className="rounded-lg bg-muted/60 pt-2 pb-2 text-center">
                    <p className="text-sm font-semibold tabular-nums">{"+" + str(card.detour_minutes) + " min"}</p>
                    <p className="text-xs text-muted-foreground">Detour</p>
                </div>
                <div className="rounded-lg bg-muted/60 pt-2 pb-2 text-center">
                    <p className="text-sm font-semibold tabular-nums">{str(card.time_score) + "%"}</p>
                    <p className="text-xs text-muted-foreground">Schedule</p>
                </div>
                <div className="rounded-lg bg-muted/60 pt-2 pb-2 text-center">
                    <p className="text-sm font-semibold tabular-nums">{"~$" + str(int(card.estimated_rider_savings)) + "/wk"}</p>
                    <p className="text-xs text-muted-foreground">Savings</p>
                </div>
            </div>
            <div className="flex justify-end">
                <Button variant="outline" size="sm">View Match</Button>
            </div>
        </CardContent>
    </Card>;
}
