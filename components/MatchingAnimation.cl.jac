"""MatchingAnimation — 'Along AI is exploring the mobility graph.' Animates
the walker pipeline (discover -> route -> time -> preferences -> savings ->
score) while run_matching actually executes on the server, then hands off
to Match Results."""

import from "@jac/runtime" { useNavigate, useLocation }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Search01Icon, Route01Icon, Clock01Icon, ShieldIcon, Money03Icon, ChartIcon, CheckmarkCircle02Icon
}
import from .ui.card { Card, CardContent }
import from .BrandMark { BrandMark }
sv import from ..services.along { run_matching }

glob STEPS: list[dict] = [
    {"label": "Discovering nearby journeys", "icon": Search01Icon},
    {"label": "Comparing route corridors", "icon": Route01Icon},
    {"label": "Checking schedules", "icon": Clock01Icon},
    {"label": "Calculating detours", "icon": Route01Icon},
    {"label": "Evaluating preferences", "icon": ShieldIcon},
    {"label": "Estimating savings", "icon": Money03Icon},
    {"label": "Building matches", "icon": ChartIcon},
];

def:pub MatchingAnimation() -> JsxElement {
    location = useLocation();
    params: any = new(URLSearchParams, location.search);  # jac:ignore[E1032,E1053]
    trip_id: str = (params.get("tripId") or "") as str;

    has active_step: int = 0,
        done: bool = False;

    nav = useNavigate();

    async can with entry {
        if not trip_id {
            nav("/create-trip");
            return;
        }
        i = 0;
        while i < len(STEPS) {
            active_step = i;
            await _sleep(320);
            i = i + 1;
        }
        matches = await run_matching(trip_id);
        done = True;
        await _sleep(280);
        nav("/matches");
    }

    return <div className="flex min-h-svh items-center justify-center bg-muted/30 pt-10 pb-10 pl-6 pr-6">
        <div className="flex w-full max-w-md flex-col items-center gap-8 animate-in fade-in slide-in-from-bottom-2 duration-500">
            <BrandMark />
            <div className="flex flex-col items-center gap-2 text-center">
                <h1 className="text-balance text-2xl font-semibold tracking-tight">Along AI is exploring the mobility graph...</h1>
                <p className="text-sm text-muted-foreground">Jac walkers are traversing trips, routes and preferences to find your best matches.</p>
            </div>
            <Card className="w-full shadow-sm">
                <CardContent className="flex flex-col gap-3 pt-2 pb-2">
                    {for (i, step) in enumerate(STEPS) {
                        <div key={str(i)} className={"flex items-center gap-3 rounded-lg pt-2 pb-2 pl-3 pr-3 transition-colors " + ("bg-primary/10" if i == active_step and not done else "")}>
                            <div className={"flex size-8 shrink-0 items-center justify-center rounded-full " + ("bg-emerald-600 text-white" if (i < active_step or done) else ("bg-primary text-primary-foreground" if i == active_step else "bg-muted text-muted-foreground"))}>
                                {(<HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} className="size-4" />) if (i < active_step or done) else <HugeiconsIcon icon={step["icon"]} strokeWidth={2} className="size-4" />}
                            </div>
                            <span className={"text-sm " + ("font-medium text-foreground" if i <= active_step or done else "text-muted-foreground")}>{step["label"]}</span>
                        </div>
                    }}
                </CardContent>
            </Card>
        </div>
    </div>;
}

async def _sleep(ms: int) -> None {
    await new(Promise, lambda (resolve: any, reject: any) { setTimeout(resolve, ms); });
}
