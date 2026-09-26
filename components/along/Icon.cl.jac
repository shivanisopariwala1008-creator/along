"""Line icons from the Figma prototype — one 24x24 stroke set so every screen
matches the design exactly."""

glob ICON_PATHS: dict[str, JsxElement] = {
    "arrow": <path d="M5 12h14M13 6l6 6-6 6" />,
    "back": <path d="M19 12H5M11 18l-6-6 6-6" />,
    "car": <g><path d="M5 17h14l-1-7-2-3H8l-2 3-1 7Z" /><path d="M7 13h10M8 17v2m8-2v2" /></g>,
    "users": <g><circle cx="9" cy="8" r="3" /><path d="M3 19c0-4 2.5-6 6-6s6 2 6 6M16 5c2 0 3 1.5 3 3s-1 3-3 3M17 13c2.5.5 4 2.5 4 5" /></g>,
    "key": <g><circle cx="8" cy="15" r="4" /><path d="m11 12 8-8m-3 3 3 3" /></g>,
    "cab": <path d="M4 16h16l-1-7H5l-1 7Zm3-7 2-3h6l2 3M7 16v2m10-2v2M8 12h.01M16 12h.01" />,
    "pin": <g><path d="M12 21s7-5.3 7-12a7 7 0 1 0-14 0c0 6.7 7 12 7 12Z" /><circle cx="12" cy="9" r="2" /></g>,
    "clock": <g><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></g>,
    "star": <path d="m12 3 2.7 5.6 6.3.9-4.5 4.4 1 6.2-5.5-3-5.5 3 1-6.2L3 9.5l6.3-.9L12 3Z" />,
    "chat": <path d="M4 5h16v11H9l-5 4V5Z" />,
    "shield": <g><path d="M12 3 5 6v5c0 5 3 8 7 10 4-2 7-5 7-10V6l-7-3Z" /><path d="m9 12 2 2 4-4" /></g>,
    "tune": <g><path d="M4 7h10m4 0h2M4 17h2m4 0h10" /><circle cx="16" cy="7" r="2" /><circle cx="8" cy="17" r="2" /></g>,
    "x": <path d="m6 6 12 12M18 6 6 18" />,
    "check": <path d="m5 12 4 4L19 6" />,
    "user": <g><circle cx="12" cy="8" r="4" /><path d="M5 21c0-5 3-8 7-8s7 3 7 8" /></g>,
    "chevron": <path d="m9 6 6 6-6 6" />,
    "swap": <path d="M7 7h12l-3-3m3 3-3 3M17 17H5l3 3m-3-3 3-3" />,
    "calendar": <g><rect x="4" y="5" width="16" height="15" rx="2" /><path d="M8 3v4m8-4v4M4 10h16" /></g>,
    "lock": <g><rect x="5" y="10" width="14" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3" /></g>,
    "list": <path d="M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01" />,
    "map": <path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3V6Zm6-3v15m6-12v15" />,
    "search": <g><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></g>,
    "graph": <g><circle cx="6" cy="6" r="2.5" /><circle cx="18" cy="8" r="2.5" /><circle cx="10" cy="18" r="2.5" /><path d="M8.3 7 15.6 7.6M16.6 10.1l-5 6M7 8.4l2.2 7.2" /></g>,
    "logout": <path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h11" />,
};

def:pub Icon(name: str, size: int = 20, className: str = "") -> JsxElement {
    return <svg
        width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"
        className={className}
    >
        {ICON_PATHS[name] if name in ICON_PATHS else <circle cx="12" cy="12" r="1" />}
    </svg>;
}

