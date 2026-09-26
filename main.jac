"""ALONG — AI-powered peer-to-peer mobility matching for Michigan.

Entry module: registers every server endpoint from services/along.jac and
mounts the client router over the screens in components/. Everything that
touches personal data sits behind RequireAuth (login required).
"""

import from services.along {
    User, Trip, Location, RouteSegment, Preference, Match, Conversation, Message, ImpactRecord,
    get_my_profile, update_profile, seed_demo_network, create_trip, run_matching, get_match_results, get_match_details,
    explain_match, get_match_graph, create_anonymous_connection, send_message,
    approve_identity_reveal, get_conversation, get_impact_metrics,
}

cl {
    import ".styles.global.css";
    import from "@jac/runtime" { Router, Routes, Route }
    import from .components.HomeDiscovery { HomeDiscovery }
    import from .components.CreateTrip { CreateTrip }
    import from .components.MatchingAnimation { MatchingAnimation }
    import from .components.MatchResults { MatchResults }
    import from .components.MatchDetails { MatchDetails }
    import from .components.MobilityGraph { MobilityGraph }
    import from .components.AnonymousChat { AnonymousChat }
    import from .components.TrustSafety { TrustSafety }
    import from .components.ImpactDashboard { ImpactDashboard }
    import from .components.AuthPage { AuthPage }
    import from .components.RequireAuth { RequireAuth }

    def:pub app() -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/" element={<HomeDiscovery />} />
                <Route path="/login" element={<AuthPage mode="login" />} />
                <Route path="/signup" element={<AuthPage mode="signup" />} />
                <Route path="/trust-safety" element={<TrustSafety />} />
                <Route path="/impact" element={<ImpactDashboard />} />
                <Route element={<RequireAuth />}>
                    <Route path="/create-trip" element={<CreateTrip />} />
                    <Route path="/matching" element={<MatchingAnimation />} />
                    <Route path="/matches" element={<MatchResults />} />
                    <Route path="/matches/:matchId" element={<MatchDetails />} />
                    <Route path="/graph/:matchId" element={<MobilityGraph />} />
                    <Route path="/chat/:matchId" element={<AnonymousChat />} />
                </Route>
            </Routes>
        </Router>;
    }
}
