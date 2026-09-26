"""MobilityGraph — 'How Along Found This Match.' Renders the actual node/edge
path the matching walkers discovered, for the live hackathon demo."""

import from "@jac/runtime" { Link, useParams }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowLeft01Icon, ShareKnowledgeIcon }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.skeleton { Skeleton }
import from .BrandMark { BrandMark }
sv import from ..graph.along { get_match_graph, GraphView }

def:pub MobilityGraph() -> JsxElement {
    params = useParams();
    match_id: str = (params["matchId"] or "") as str;

    has graph: GraphView | None = None,
        loading: bool = True;

    async can with entry {
        if match_id {
            graph = await get_match_graph(match_id);
        }
        loading = False;
    }

    if loading {
        return <div className="mx-auto max-w-3xl pt-10 pl-6 pr-6"><Skeleton className="h-80 w-full rounded-2xl" /></div>;
    }

    return <div className="min-h-svh bg-muted/30">
        <div className="mx-auto flex max-w-3xl flex-col gap-6 pt-10 pb-16 pl-6 pr-6">
            <div className="flex items-center justify-between">
                <BrandMark />
                <Link to={"/matches/" + match_id} className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-4" />
                    Back to match
                </Link>
            </div>

            <div className="flex flex-col gap-1">
                <h1 className="text-2xl font-semibold tracking-tight">How Along found this match</h1>
                <p className="text-sm text-muted-foreground">The discovered path through the mobility graph, node by node.</p>
            </div>

            {if graph == None {
                <p className="text-sm text-muted-foreground">No graph data yet — open a match first.</p>
                skip;
            }}

            {graph and <Card className="shadow-sm">
                <CardContent className="flex flex-col items-center gap-3 pt-8 pb-8">
                    {for (i, n) in enumerate((graph as GraphView).nodes) {
                        <div key={n.id} className="flex flex-col items-center gap-3">
                            <div className={"rounded-full pt-2 pb-2 pl-4 pr-4 text-sm font-medium " + _node_tone(n.kind)}>
                                {n.label}
                            </div>
                            {i < len((graph as GraphView).nodes) - 1 and <div className="flex flex-col items-center gap-1 text-xs text-muted-foreground">
                                <div className="h-6 w-px bg-border" />
                                <span>{(graph as GraphView).edges[i].label}</span>
                                <div className="h-6 w-px bg-border" />
                            </div>}
                        </div>
                    }}
                </CardContent>
            </Card>}

            <Card className="border-primary/30 bg-primary/5 shadow-sm">
                <CardHeader className="flex flex-row items-center gap-2">
                    <HugeiconsIcon icon={ShareKnowledgeIcon} strokeWidth={2} className="size-4 text-primary" />
                    <CardTitle className="text-base">Why a graph</CardTitle>
                </CardHeader>
                <CardContent>
                    <p className="text-sm leading-relaxed text-muted-foreground">
                        Along does not require identical origins and destinations. Jac walkers traverse a mobility graph to identify overlapping journeys and evaluate whether a connection is practical.
                    </p>
                </CardContent>
            </Card>
        </div>
    </div>;
}

def _node_tone(kind: str) -> str {
    if kind == "user" { return "bg-primary text-primary-foreground"; }
    if kind == "match" { return "bg-emerald-600 text-white"; }
    if kind == "route" { return "bg-sky-100 text-sky-900"; }
    return "bg-muted text-foreground";
}
