"""Shared brand mark — two converging path shapes, used on every screen."""

def:pub BrandMark(inverted: bool = False) -> JsxElement {
    tile = "bg-primary-foreground/15 text-primary-foreground ring-1 ring-primary-foreground/20" if inverted else "bg-primary text-primary-foreground shadow-sm";
    return <div className="flex items-center gap-2.5">
        <div className={"flex size-8 items-center justify-center rounded-lg " + tile}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M4 20C8 12 8 6 12 4" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
                <path d="M20 20C16 12 16 6 12 4" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
            </svg>
        </div>
        <span className="text-base font-semibold tracking-tight">Along</span>
    </div>;
}
