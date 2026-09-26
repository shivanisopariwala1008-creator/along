"""TrustSafety — static explainer: anonymous-first, mutual reveal, reporting,
verification, progressive trust."""

import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowLeft01Icon, ShieldIcon, UserGroupIcon, StarIcon, CheckmarkCircle02Icon, Alert01Icon
}
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .BrandMark { BrandMark }

glob PRINCIPLES: list[dict] = [
    {"icon": ShieldIcon, "title": "Anonymous-first connection", "body": "You are matched and can talk using an anonymous handle before anyone's name, email or phone is shared."},
    {"icon": CheckmarkCircle02Icon, "title": "Mutual reveal", "body": "Identity only unlocks once BOTH riders and drivers choose to connect. Either side can simply not approve."},
    {"icon": UserGroupIcon, "title": "Verified users", "body": "Verified drivers carry a visible badge. Verification signals are shown before reveal — never full identity."},
    {"icon": StarIcon, "title": "Ride history & community rating", "body": "Completed connections and ratings build trust over time, visible as high-level signals, not raw personal data."},
    {"icon": Alert01Icon, "title": "Reporting & blocking", "body": "Any user can report or block a match at any point in the conversation."},
];

def:pub TrustSafety() -> JsxElement {
    return <div className="min-h-svh bg-muted/30">
        <div className="mx-auto flex max-w-3xl flex-col gap-6 pt-10 pb-16 pl-6 pr-6">
            <div className="flex items-center justify-between">
                <BrandMark />
                <Link to="/" className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-4" />
                    Home
                </Link>
            </div>

            <div className="flex flex-col gap-2">
                <h1 className="text-2xl font-semibold tracking-tight">Trust &amp; safety</h1>
                <p className="text-sm text-muted-foreground">Designed for progressive trust — anonymity first, identity only after both sides agree.</p>
            </div>

            <div className="flex flex-col gap-4">
                {for p in PRINCIPLES {
                    <Card key={p["title"] as str} className="shadow-sm">
                        <CardHeader className="flex flex-row items-start gap-4">
                            <div className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                                <HugeiconsIcon icon={p["icon"]} strokeWidth={2} className="size-4" />
                            </div>
                            <div className="flex flex-col gap-1">
                                <CardTitle className="text-base">{p["title"] as str}</CardTitle>
                                <CardDescription>{p["body"] as str}</CardDescription>
                            </div>
                        </CardHeader>
                    </Card>
                }}
            </div>

            <Card className="border-dashed shadow-none">
                <CardContent className="pt-6 text-sm text-muted-foreground">
                    Along's MVP does not perform criminal background checks. Verification today reflects account and ride-history signals only — this is a prototype built for a hackathon demo, not a production safety system.
                </CardContent>
            </Card>
        </div>
    </div>;
}
