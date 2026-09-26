"""HomeDiscovery — the Along landing screen. Persuade, then hand off to
either 'Find a Ride' (create a rider trip) or 'Offer a Ride' (driver trip),
plus the demo-mode shortcuts a live hackathon judge needs."""

import from "@jac/runtime" { Link, useNavigate }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowRight01Icon, UserGroupIcon, Money03Icon, ShieldIcon, Route01Icon,
    Clock01Icon, Airplane01Icon, DeliveryTruck01Icon, SparklesIcon, MapIcon
}
import from .ui.button { Button }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.badge { Badge }
import from .BrandMark { BrandMark }
sv import from ..graph.along { seed_demo_network }

def:pub HomeDiscovery() -> JsxElement {
    has seeding: bool = False,
        seeded: str = "";

    nav = useNavigate();

    async def handle_load_demo -> None {
        seeding = True;
        result = await seed_demo_network();
        seeded = result;
        seeding = False;
    }

    def go_find_ride(e: MouseEvent) { nav("/create-trip?role=RIDER"); }
    def go_offer_ride(e: MouseEvent) { nav("/create-trip?role=DRIVER"); }

    async def handle_run_grand_blanc -> None {
        if not seeded {
            seeding = True;
            _ = await seed_demo_network();
            seeded = "loaded";
            seeding = False;
        }
        nav("/create-trip?role=RIDER&demo=1");
    }

    return <div className="min-h-svh bg-background">
        <nav className="sticky top-0 z-20 border-b bg-background/80 backdrop-blur">
            <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-8 pl-6 pr-6">
                <BrandMark />
                <div className="hidden items-center gap-6 md:flex">
                    <Link to="/impact" className="text-sm font-medium text-muted-foreground hover:text-foreground">Local Impact</Link>
                    <Link to="/trust-safety" className="text-sm font-medium text-muted-foreground hover:text-foreground">Trust &amp; Safety</Link>
                </div>
                <Button onClick={go_find_ride} className="shadow-sm">
                    Find a Ride
                    <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4" />
                </Button>
            </div>
        </nav>

        <section className="relative overflow-hidden">
            <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(60%_50%_at_80%_20%,color-mix(in_oklch,var(--primary)_16%,transparent),transparent)]" />
            <div className="relative mx-auto grid max-w-6xl items-center gap-12 pt-20 pb-16 pl-6 pr-6 lg:grid-cols-2">
                <div className="flex flex-col gap-6 animate-in fade-in slide-in-from-bottom-2 duration-500">
                    <Badge variant="secondary" className="w-fit">Launching in Michigan</Badge>
                    <h1 className="text-balance text-4xl font-semibold leading-[1.1] tracking-tight text-foreground md:text-5xl">
                        Go further together.
                    </h1>
                    <p className="max-w-md text-balance text-lg text-muted-foreground">
                        Find people already traveling your way. Share rides, reduce costs, and make transportation more accessible.
                    </p>
                    <div className="flex flex-wrap gap-3">
                        <Button size="lg" onClick={go_find_ride} className="shadow-sm">
                            Find a Ride
                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4" />
                        </Button>
                        <Button size="lg" variant="outline" onClick={go_offer_ride}>Offer a Ride</Button>
                    </div>
                    <div className="flex items-start gap-3 rounded-2xl border bg-card pt-4 pb-4 pl-4 pr-4 shadow-sm">
                        <div className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                            <HugeiconsIcon icon={ShieldIcon} strokeWidth={2} className="size-4" />
                        </div>
                        <p className="text-sm text-muted-foreground">
                            Transportation should not decide which opportunities you can reach.
                        </p>
                    </div>
                </div>

                <div className="relative">
                    <div className="pointer-events-none absolute -inset-4 rounded-3xl bg-primary/10 blur-2xl" />
                    <Card className="relative shadow-xl">
                        <CardHeader className="flex flex-row items-start justify-between gap-4">
                            <div className="flex flex-col gap-1">
                                <CardTitle>Grand Blanc &rarr; Ann Arbor</CardTitle>
                                <CardDescription>Rider 184 needs to arrive by 9:00 AM</CardDescription>
                            </div>
                            <Badge className="bg-emerald-600 text-white hover:bg-emerald-600">94% Match</Badge>
                        </CardHeader>
                        <CardContent className="flex flex-col gap-4">
                            <div className="flex items-center justify-between text-sm">
                                <span className="text-muted-foreground">Driver 072 &middot; Flint &rarr; Ann Arbor</span>
                                <span className="font-medium tabular-nums">7:40 AM</span>
                            </div>
                            <div className="h-2 overflow-hidden rounded-full bg-muted">
                                <div className="h-full w-[88%] rounded-full bg-primary" />
                            </div>
                            <div className="grid grid-cols-3 gap-3 text-center text-xs">
                                <div className="rounded-lg bg-muted/60 pt-2 pb-2">
                                    <p className="font-semibold tabular-nums">88%</p>
                                    <p className="text-muted-foreground">Route overlap</p>
                                </div>
                                <div className="rounded-lg bg-muted/60 pt-2 pb-2">
                                    <p className="font-semibold tabular-nums">+8 min</p>
                                    <p className="text-muted-foreground">Detour</p>
                                </div>
                                <div className="rounded-lg bg-muted/60 pt-2 pb-2">
                                    <p className="font-semibold tabular-nums">~$40</p>
                                    <p className="text-muted-foreground">Weekly savings</p>
                                </div>
                            </div>
                        </CardContent>
                    </Card>
                </div>
            </div>
        </section>

        <section className="border-y bg-muted/30">
            <div className="mx-auto flex max-w-6xl flex-col gap-4 pt-10 pb-10 pl-6 pr-6 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex flex-col gap-2 sm:max-w-lg">
                    <p className="text-sm font-medium text-foreground">Try the live demo</p>
                    <p className="text-sm text-muted-foreground">
                        {seeded if seeded else "Load the Michigan demo network, then run the Grand Blanc scenario end to end."}
                    </p>
                </div>
                <div className="flex flex-wrap gap-3">
                    <Button variant="outline" onClick={handle_load_demo} disabled={seeding}>
                        <HugeiconsIcon icon={SparklesIcon} strokeWidth={2} className="size-4" />
                        {"Loading..." if seeding else "Load Michigan Demo"}
                    </Button>
                    <Button onClick={handle_run_grand_blanc} disabled={seeding} className="shadow-sm">
                        <HugeiconsIcon icon={MapIcon} strokeWidth={2} className="size-4" />
                        Run Grand Blanc Demo
                    </Button>
                </div>
            </div>
        </section>

        <section className="mx-auto max-w-6xl pt-16 pb-16 pl-6 pr-6">
            <h2 className="text-balance text-3xl font-semibold tracking-tight">What Along makes possible</h2>
            <p className="mt-2 max-w-2xl text-muted-foreground">
                Along uses a graph of journeys already happening across Michigan — this is where that capacity goes next.
            </p>
            <div className="mt-8 grid gap-4 md:grid-cols-2 md:grid-rows-2">
                <div className="flex flex-col justify-between gap-6 rounded-2xl bg-primary pt-8 pb-8 pl-8 pr-8 text-primary-foreground md:col-span-2 md:row-span-2">
                    <div className="flex size-10 items-center justify-center rounded-lg bg-primary-foreground/15">
                        <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-5" />
                    </div>
                    <div className="flex flex-col gap-2">
                        <h3 className="text-xl font-semibold">Daily commute</h3>
                        <p className="text-primary-foreground/80">Recurring Monday-Friday matching between riders and drivers whose schedules and corridors overlap. Fully functional today.</p>
                    </div>
                </div>
                <div className="flex flex-col gap-3 rounded-2xl border bg-card pt-6 pb-6 pl-6 pr-6 shadow-sm">
                    <div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                        <HugeiconsIcon icon={Route01Icon} strokeWidth={2} className="size-4" />
                    </div>
                    <h3 className="font-semibold">One-time trips</h3>
                    <p className="text-sm text-muted-foreground">Post a single journey and match with anyone already headed that way.</p>
                </div>
                <div className="flex flex-col gap-3 rounded-2xl bg-muted/60 pt-6 pb-6 pl-6 pr-6">
                    <div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                        <HugeiconsIcon icon={Airplane01Icon} strokeWidth={2} className="size-4" />
                    </div>
                    <h3 className="font-semibold">Airport / shared rides</h3>
                    <p className="text-sm text-muted-foreground">Conceptual for now — future expansion once demand is proven.</p>
                </div>
            </div>
            <div className="mt-4 grid gap-4 md:grid-cols-2">
                <div className="flex items-center gap-3 rounded-2xl border bg-card pt-5 pb-5 pl-5 pr-5 shadow-sm">
                    <div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                        <HugeiconsIcon icon={UserGroupIcon} strokeWidth={2} className="size-4" />
                    </div>
                    <p className="text-sm text-muted-foreground">Moving &amp; transportation coordination — future expansion.</p>
                </div>
                <div className="flex items-center gap-3 rounded-2xl border bg-card pt-5 pb-5 pl-5 pr-5 shadow-sm">
                    <div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                        <HugeiconsIcon icon={DeliveryTruck01Icon} strokeWidth={2} className="size-4" />
                    </div>
                    <p className="text-sm text-muted-foreground">Employer &amp; university commute programs — future expansion.</p>
                </div>
            </div>
        </section>

        <footer className="border-t">
            <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 pt-8 pb-8 pl-6 pr-6 sm:flex-row">
                <BrandMark />
                <p className="text-sm text-muted-foreground">Shared journeys. Stronger communities.</p>
            </div>
        </footer>
    </div>;
}
