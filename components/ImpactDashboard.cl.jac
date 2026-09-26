"""ImpactDashboard — Local Impact metrics for the hackathon judging criterion.
Values are a labeled prototype simulation, not real production statistics."""

import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowLeft01Icon, UserGroupIcon, Money03Icon, Route01Icon, ChartIcon, MapIcon
}
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.badge { Badge }
import from .ui.skeleton { Skeleton }
import from .BrandMark { BrandMark }
sv import from ..services.along { get_impact_metrics, ImpactView }

def:pub ImpactDashboard() -> JsxElement {
    has metrics: ImpactView | None = None,
        loading: bool = True;

    async can with entry {
        metrics = await get_impact_metrics();
        loading = False;
    }

    if loading {
        return <div className="mx-auto max-w-5xl pt-10 pl-6 pr-6"><Skeleton className="h-64 w-full rounded-2xl" /></div>;
    }

    m = metrics as ImpactView;

    return <div className="min-h-svh bg-muted/30">
        <div className="mx-auto flex max-w-5xl flex-col gap-6 pt-10 pb-16 pl-6 pr-6">
            <div className="flex items-center justify-between">
                <BrandMark />
                <Link to="/" className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-4" />
                    Home
                </Link>
            </div>

            <div className="flex flex-col gap-1">
                <h1 className="text-2xl font-semibold tracking-tight">Local impact</h1>
                <p className="text-sm text-muted-foreground">Along helps connect Michigan communities using transportation capacity that already exists.</p>
                <Badge variant="secondary" className="mt-1 w-fit">Prototype simulation</Badge>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
                <StatTile icon={Route01Icon} label="Journeys matched" value={str(m.journeys_matched)} />
                <StatTile icon={Money03Icon} label="Estimated rider savings" value={"$" + str(int(m.estimated_rider_savings))} />
                <StatTile icon={UserGroupIcon} label="Empty seats activated" value={str(m.empty_seats_activated)} />
                <StatTile icon={ChartIcon} label="Shared miles" value={str(int(m.shared_miles))} />
            </div>

            <Card className="shadow-sm">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2"><HugeiconsIcon icon={MapIcon} strokeWidth={2} className="size-4" />Michigan communities connected</CardTitle>
                    <CardDescription>Better access to transportation can improve access to work, education, healthcare, and community opportunities.</CardDescription>
                </CardHeader>
                <CardContent>
                    {if len(m.cities) == 0 {
                        <p className="text-sm text-muted-foreground">Load the Michigan demo network from Home to populate this map.</p>
                        skip;
                    }}
                    <div className="flex flex-wrap gap-2">
                        {for city in m.cities {
                            <Badge key={city} variant="outline" className="pt-1.5 pb-1.5 pl-3 pr-3 text-sm">{city}</Badge>
                        }}
                    </div>
                </CardContent>
            </Card>
        </div>
    </div>;
}

def StatTile(icon: any, label: str, value: str) -> JsxElement {
    return <Card className="shadow-sm transition-shadow hover:shadow-md">
        <CardContent className="flex flex-col gap-3">
            <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">{label}</span>
                <div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                    <HugeiconsIcon icon={icon} strokeWidth={2} className="size-4" />
                </div>
            </div>
            <span className="text-3xl font-semibold tracking-tight tabular-nums">{value}</span>
        </CardContent>
    </Card>;
}
