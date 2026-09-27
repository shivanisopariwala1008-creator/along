"""ALONG — AI-powered peer-to-peer mobility matching for Michigan.

Entry module: registers every server endpoint from services/along.jac and
mounts the client router over the screens in components/. The main journey
screens (components/along/) follow the Figma "Responsive web app prototype".
Everything that touches personal data sits behind RequireAuth (login required).
"""

import from services.along {
    User, Trip, Location, RouteSegment, Preference, Match, Conversation, Message, Rating, ImpactRecord,
    get_my_profile, update_profile, update_profile_details, seed_demo_network, create_trip,
    create_journey, get_my_trip, get_my_trips, get_rental_spots, run_matching, run_agents, get_match_results, get_match_details,
    explain_match, get_match_graph, create_anonymous_connection, send_message,
    approve_identity_reveal, get_conversation, get_my_conversations, close_match,
    complete_match, rate_match, get_my_ratings, get_my_rating, remove_journey, post_journey, switch_journey, get_traveler_profile, get_my_notifications, mark_notifications_read,
    plan_trip, get_email_status, block_user, unblock_user, get_blocked, report_user, create_share_link, get_shared_trip,
    book_relay, get_relay_plan, get_my_relay_plans, respond_relay_leg, replace_relay_leg, cancel_relay,
    get_impact_metrics, get_maps_config, get_trip_route,
}

cl {
    import ".styles.global.css";
    import ".styles.along.css";
    import from "@jac/runtime" { Router, Routes, Route }
    import from .components.along.Home { Home }
    import from .components.along.JourneyForm { JourneyRoute }
    import from .components.along.ResultsView { ResultsRoute }
    import from .components.along.MatchDetail { MatchDetailRoute }
    import from .components.along.ChatView { ChatRoute }
    import from .components.along.RatingView { RatingView }
    import from .components.along.TravelerProfile { TravelerProfileRoute }
    import from .components.along.RelayPlanPage { RelayPlanRoute }
    import from .components.along.ShareTrip { SharedTripPage }
    import from .components.along.DemoPage { DemoPage }
    import from .components.along.AccountPages { ForgotPasswordPage, ResetPasswordPage, VerifyEmailPage }
    import from .components.along.ProfilePage { ProfilePage }
    import from .components.along.Redirects { LegacyCreateTrip, LegacyMatching }
    import from .components.MobilityGraph { MobilityGraph }
    import from .components.TrustSafety { TrustSafety }
    import from .components.ImpactDashboard { ImpactDashboard }
    import from .components.AuthPage { AuthPage }
    import from .components.RequireAuth { RequireAuth }

    def:pub app() -> JsxElement {
        return <Router>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/login" element={<AuthPage mode="login" />} />
                <Route path="/signup" element={<AuthPage mode="signup" />} />
                <Route path="/trust-safety" element={<TrustSafety />} />
                <Route path="/impact" element={<ImpactDashboard />} />
                <Route path="/share/:token" element={<SharedTripPage />} />
                <Route path="/demo" element={<DemoPage />} />
                <Route path="/forgot-password" element={<ForgotPasswordPage />} />
                <Route path="/reset-password" element={<ResetPasswordPage />} />
                <Route path="/verify-email" element={<VerifyEmailPage />} />
                <Route element={<RequireAuth />}>
                    <Route path="/journey/:kind" element={<JourneyRoute />} />
                    <Route path="/results" element={<ResultsRoute />} />
                    <Route path="/matches" element={<ResultsRoute />} />
                    <Route path="/matches/:matchId" element={<MatchDetailRoute />} />
                    <Route path="/graph/:matchId" element={<MobilityGraph />} />
                    <Route path="/chat" element={<ChatRoute />} />
                    <Route path="/chat/:matchId" element={<ChatRoute />} />
                    <Route path="/rate/:matchId" element={<RatingView />} />
                    <Route path="/people/:matchId" element={<TravelerProfileRoute />} />
                    <Route path="/plans/:planId" element={<RelayPlanRoute />} />
                    <Route path="/profile" element={<ProfilePage />} />
                    <Route path="/create-trip" element={<LegacyCreateTrip />} />
                    <Route path="/matching" element={<LegacyMatching />} />
                </Route>
            </Routes>
        </Router>;
    }
}
