"""ALONG — core mobility graph: nodes, edges, and every walker/endpoint.

Data placement (multi-user, see `jac guide jac-sv-multi-user`):
  - User (profile)      -> caller's private root; shared with a match partner
                           only when that user approves the identity reveal.
  - Trip, Preference    -> root.shared, readable by every logged-in user.
  - Match, Conversation -> root.shared, opened to the two participants only.
  - Message             -> owned by the sender, opened to the other participant.

Graph shape:
  User -POSTS-> Trip -STARTS_AT-> Location
                     -ENDS_AT-> Location
                     -HAS_PREFERENCE-> Preference
                     -CANDIDATE_MATCH-> Trip
  User -PARTICIPATES_IN-> Match -CONNECTS-> Trip
                          Match -OPENS-> Conversation (messages stored inline)
  User -APPROVES_IDENTITY_REVEAL-> Conversation
  Trip -CREATES_IMPACT-> ImpactRecord

Deterministic scoring lives in along.impl.jac; the LLM only narrates a
match that has already been scored — it never invents a number.
"""


# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------

node User {
    has anonymous_handle: str = "",
        display_name: str = "",
        email: str = "",
        phone: str = "",
        verified: bool = False,
        rating: float = 4.8,
        completed_connections: int = 0,
        home_region: str = "",
        identity_reveal_allowed: bool = False,
        trust_score: int = 80,
        handle_number: int = 0,
        member_since: str = "";
}

node Trip {
    has trip_type: str = "commute",       # commute | one_time
        role: str = "RIDER",              # DRIVER | RIDER
        origin_name: str = "",
        origin_lat: float = 0.0,
        origin_lng: float = 0.0,
        destination_name: str = "",
        destination_lat: float = 0.0,
        destination_lng: float = 0.0,
        departure_time: str = "",
        arrival_deadline: str = "",
        recurring: bool = True,
        recurrence_days: str = "Mon-Fri",
        seats_available: int = 0,
        flexible_minutes: int = 15,
        max_detour_minutes: int = 10,
        suggested_cost_share: float = 0.0,
        active: bool = True,
        luggage: str = "light",
        notes: str = "",
        owner_handle: str = "",
        owner_root: str = "",        # jid of the poster's root; "demo" for seeded trips
        is_demo: bool = False,
        demo_name: str = "",         # display name revealed for seeded demo users
        # Journey flavour from the Figma flows: ride (RIDER/DRIVER), rental / cab (PEER).
        mode: str = "ride",
        travel_date: str = "",
        time_preference: str = "arrive_by",   # arrive_by | depart_at
        people: int = 1,
        vehicle: str = "",
        moving_help: bool = False,
        pickup_distance: str = "Up to 5 miles",
        age_pref: str = "No preference",
        gender_pref: str = "No preference",
        demo_rating: float = 0.0,             # seeded reputation for demo users only
        demo_reviews: int = 0,
        route_json: str = "",                 # cached Google road route, see get_trip_route
        round_trip: bool = False,
        return_date: str = "",                # rentals: when the car goes back
        space_needed: str = "",               # rentals when moving: how much cargo space
        matchmaker_done: bool = False;        # have others been told about this journey yet?
}

node Location {
    has name: str = "", latitude: float = 0.0, longitude: float = 0.0,
        city: str = "", state: str = "MI";
}

node RouteSegment {
    has sequence: int = 0, latitude: float = 0.0, longitude: float = 0.0, label: str = "";
}

node Preference {
    has smoking: bool = False,
        conversation_level: str = "moderate",   # quiet | moderate | chatty
        pets: bool = True,
        accessibility: bool = False,
        gender_preference_optional: str = "no preference",
        quiet_ride: bool = False,
        luggage: str = "light",
        other: str = "";
}

node Match {
    has overall_score: int = 0,
        route_score: int = 0,
        time_score: int = 0,
        detour_minutes: int = 0,
        preference_score: int = 0,
        cost_benefit_score: int = 0,
        estimated_rider_savings: float = 0.0,
        estimated_driver_contribution: float = 0.0,
        status: str = "suggested",   # suggested | connected | closed
        explanation: str = "",
        rider_handle: str = "",
        driver_handle: str = "",
        rider_trip_id: str = "",
        driver_trip_id: str = "",
        rider_root: str = "",
        driver_root: str = "",
        created_at: str = "",
        mode: str = "ride",
        pickup_gap_miles: float = -1.0,
        rider_rated: bool = False,
        driver_rated: bool = False,
        agent_notes: dict[str, str] = {},   # each matching agent's one-line finding
        # Set when this match is one leg of a booked 2-ride trip. Only THIS
        # driver's part is stored here — never who drives the other leg.
        relay_plan_id: str = "", relay_leg: str = "",      # first | second
        relay_status: str = "",                              # pending | accepted | declined | replaced | cancelled
        relay_stop: str = "", relay_time: str = "";
}

# A booked 2-ride trip. Owned by the rider and never shared with either
# driver: each driver only sees their own leg (on their Match).
node RelayPlan {
    has rider_root: str = "", rider_trip_id: str = "",
        leg1_match_id: str = "", leg2_match_id: str = "",
        handoff_name: str = "", handoff_address: str = "", handoff_lat: float = 0.0, handoff_lng: float = 0.0,
        handoff_time: str = "", pickup_time: str = "", wait_min: int = 0, arrive_time: str = "",
        status: str = "active",                              # active | cancelled
        created_at: str = "";
}

node Conversation {
    has status: str = "anonymous",   # anonymous | pending_reveal | revealed
        identity_revealed: bool = False,
        rider_approved: bool = False,
        driver_approved: bool = False,
        rider_profile_id: str = "",   # set when that side approves the reveal
        driver_profile_id: str = "",
        # Messages live on the conversation itself: both participants hold
        # WritePerm on it, whereas attaching nodes to a node you don't own
        # does not persist across users.
        messages: list[dict[str, str]] = [],
        created_at: str = "";
}

node Message {
    has sender_anonymous_handle: str = "", sender_root: str = "", body: str = "", timestamp: str = "";
}

# Anonymous feedback. Stores who was rated (a root id, or "demo:<handle>"),
# never who rated — only the aggregate is ever read back.
node Rating {
    has ratee_key: str = "", stars: int = 0, comment: str = "", created_at: str = "",
        tags: list[str] = [],        # quick compliments, e.g. "On time", "Friendly"
        rated_on: str = "",          # "Sep 2026" — month only, to keep reviews anonymous
        mode: str = "";              # journey type the review is about
}

# One traveler blocking another. Keys are root ids ("demo:<handle>" for demo
# travelers). Enforced both ways: neither sees nor can message the other.
node Block {
    has blocker_key: str = "", blocked_key: str = "", blocked_handle: str = "", created_at: str = "";
}

# A safety report for review by the Along team. Never shown to the reported person.
node Report {
    has reporter_root: str = "", reported_key: str = "", reported_handle: str = "",
        match_id: str = "", reason: str = "", details: str = "", created_at: str = "",
        status: str = "open";
}

# A read-only snapshot of a trip a traveler chose to share with a friend.
# Public by token; holds only what the share page shows.
node ShareLink {
    has token: str = "", owner_root: str = "", created_at: str = "",
        traveler: str = "", kind: str = "", route_from: str = "", route_to: str = "",
        when: str = "", driver: str = "", driver_rating: str = "",
        handoff: str = "", handoff_time: str = "", second_driver: str = "",
        second_rating: str = "", arrive: str = "", revoked: bool = False;
}

# Public "email verified" badge for one traveler (key = root id). Carries no
# personal data — only that the account's email address was confirmed.
node VerifiedBadge {
    has user_key: str = "", since: str = "";
}

# In-app notification for one recipient (new match, new message). Created by
# whoever triggers it and shared with the recipient only.
node Notification {
    has recipient_root: str = "", kind: str = "",   # match | message
        title: str = "", body: str = "", match_id: str = "", trip_id: str = "",
        created_at: str = "", read: bool = False;
}

node ImpactRecord {
    has estimated_savings: float = 0.0,
        estimated_shared_miles: float = 0.0,
        trips_matched: int = 0,
        connections_created: int = 0,
        local_transportation_capacity_used: str = "";
}

# ---------------------------------------------------------------------------
# Edges
# ---------------------------------------------------------------------------

edge Posts: User --> Trip {}
edge StartsAt: Trip --> Location {}
edge EndsAt: Trip --> Location {}
edge PassesThrough: Trip --> RouteSegment {}
edge HasPreference: Trip --> Preference {}
edge CandidateMatch: Trip --> Trip {}
edge ParticipatesIn: User --> Match {}
edge Connects: Match --> Trip {}
edge Opens: Match --> Conversation {}
edge Contains: Conversation --> Message {}
edge ApprovesIdentityReveal: User --> Conversation {}
edge CreatesImpact: Trip --> ImpactRecord {}

# ---------------------------------------------------------------------------
# View models — what the client actually receives
# ---------------------------------------------------------------------------

obj TripView {
    has id: str = "", role: str = "", origin_name: str = "", destination_name: str = "",
        departure_time: str = "", arrival_deadline: str = "", recurrence_days: str = "",
        seats_available: int = 0, max_detour_minutes: int = 0, flexible_minutes: int = 0,
        suggested_cost_share: float = 0.0, notes: str = "", owner_handle: str = "",
        mode: str = "ride", travel_date: str = "", time_preference: str = "",
        people: int = 1, vehicle: str = "", moving_help: bool = False,
        pickup_distance: str = "", age_pref: str = "", gender_pref: str = "",
        recurring: bool = True, smoking: bool = False,
        origin_lat: float = 0.0, origin_lng: float = 0.0,
        destination_lat: float = 0.0, destination_lng: float = 0.0,
        owner_rating: float = 0.0, owner_reviews: int = 0, round_trip: bool = False,
        return_date: str = "", space_needed: str = "";
}

# A place that rents cars near a pickup point (Google Places).
obj RentalSpotView {
    has name: str = "", address: str = "", lat: float = 0.0, lng: float = 0.0,
        rating: float = 0.0, reviews: int = 0, km: float = 0.0, maps_url: str = "";
}

obj AgentNoteView {
    has agent: str = "", note: str = "";
}

obj MatchCardView {
    has id: str = "", overall_score: int = 0, route_score: int = 0, time_score: int = 0,
        detour_minutes: int = 0, preference_score: int = 0, cost_benefit_score: int = 0,
        estimated_rider_savings: float = 0.0, status: str = "",
        driver_trip: TripView | None = None, rider_trip: TripView | None = None,
        # Caller-relative view: which trip is mine and which is the other person's.
        my_trip: TripView | None = None, other_trip: TripView | None = None,
        mode: str = "ride", fit_label: str = "", why: str = "",
        other_handle: str = "", has_conversation: bool = False,
        agent_notes: list[AgentNoteView] = [], pickup_gap_miles: float = -1.0;
}

obj MatchDetailView {
    has card: MatchCardView | None = None, explanation: str = "";
}

obj GraphNodeView {
    has id: str = "", label: str = "", kind: str = "";
}

obj GraphEdgeView {
    has source: str = "", target: str = "", label: str = "";
}

obj GraphView {
    has nodes: list[GraphNodeView] = [], edges: list[GraphEdgeView] = [];
}

obj MessageView {
    has sender_anonymous_handle: str = "", body: str = "", timestamp: str = "", mine: bool = False;
}

obj ConversationView {
    has match_id: str = "", status: str = "", identity_revealed: bool = False,
        my_role: str = "",              # RIDER | DRIVER
        my_handle: str = "", other_handle: str = "",
        me_approved: bool = False, other_approved: bool = False,
        messages: list[MessageView] = [],
        other_display_name: str = "", other_verified: bool = False,
        other_phone: str = "", match_status: str = "", mode: str = "ride",
        i_rated: bool = False,
        # 2-ride trips: the rider sees plan_id; a driver sees only their own leg.
        relay_plan_id: str = "", relay_leg: str = "", relay_status: str = "",
        relay_stop: str = "", relay_time: str = "", i_am_driver_of_leg: bool = False;
}

obj RelayLegView {
    has match_id: str = "", leg: str = "", handle: str = "", rating: str = "",
        status: str = "", depart: str = "", arrive: str = "";
}

# The rider's view of a booked 2-ride trip, with options if a leg fell through.
obj RelayPlanView {
    has id: str = "", status: str = "", needs_attention: bool = False,
        route_from: str = "", route_to: str = "",
        handoff_name: str = "", handoff_address: str = "", handoff_lat: float = 0.0, handoff_lng: float = 0.0,
        handoff_time: str = "", pickup_time: str = "", wait_min: int = 0, arrive_time: str = "",
        legs: list[RelayLegView] = [], alternatives: list[RelayView] = [],
        direct_options: list[MatchCardView] = [];
}

# Browser-side Google Maps settings. The key is a browser key (restrict it by
# HTTP referrer in Google Cloud); empty means "no key, use the drawn map".
obj MapsConfigView {
    has api_key: str = "", map_id: str = "";
}

# A trip's road route as [lat, lng] points. source: google | straight.
obj RouteView {
    has points: list[list[float]] = [], distance_km: float = 0.0,
        duration_min: int = 0, source: str = "straight";
}

obj ConversationSummaryView {
    has match_id: str = "", other_handle: str = "", other_display_name: str = "",
        last_message: str = "", last_time: str = "", status: str = "",
        match_status: str = "", mode: str = "ride";
}

# One anonymous review as shown on a profile — never who wrote it.
obj ReviewView {
    has stars: int = 0, comment: str = "", tags: list[str] = [], rated_on: str = "", mode: str = "";
}

# Another traveler's public profile, seen through a match you share with them.
# Name, area and verification appear only after a mutual identity reveal.
obj TravelerProfileView {
    has match_id: str = "", handle: str = "", revealed: bool = False,
        display_name: str = "", home_region: str = "", verified: bool = False,
        member_since: str = "", rating: float = 0.0, review_count: int = 0,
        is_new: bool = True, top_tags: list[str] = [], reviews: list[ReviewView] = [],
        journeys_posted: int = 0, journey_types: list[str] = [], is_demo: bool = False,
        can_review: bool = False, already_reviewed: bool = False,
        email_verified: bool = False;
}

obj ProfileView {
    has display_name: str = "", home_region: str = "", rider_handle: str = "",
        driver_handle: str = "", verified: bool = False,
        phone: str = "", member_since: str = "", has_ratings: bool = False,
        completed_connections: int = 0;
}

obj ImpactView {
    has journeys_matched: int = 0, estimated_rider_savings: float = 0.0,
        empty_seats_activated: int = 0, shared_miles: float = 0.0,
        communities_connected: int = 0, cities: list[str] = [];
}

# ---------------------------------------------------------------------------
# Matching agents — five walkers that each do one job on the journey graph.
# They pass one shared list of Candidates along; the Coordinator turns the
# survivors into Match nodes. Every score stays deterministic.
# ---------------------------------------------------------------------------

obj Candidate {
    has trip_id: str = "", handle: str = "", owner_root: str = "",
        route_score: int = 0, detour: int = 0, origin_gap_km: float = 0.0, dest_gap_km: float = 0.0,
        time_score: int = 0, time_gap_min: int = 0,
        preference_score: int = 0, trust_bonus: int = 0, rating: float = 0.0, reviews: int = 0,
        cost_score: int = 0, rider_savings: float = 0.0, driver_contribution: float = 0.0,
        overall: int = 0, notes: dict[str, str] = {};
}

# A journey drafted from plain English by the trip assistant. The user always
# reviews it on the normal form before anything is posted.
obj TripDraftView {
    has ok: bool = False, source: str = "",        # gemini | rules
        kind: str = "ride",                         # ride | buddy | rental | cab
        origin_name: str = "", destination_name: str = "",
        origin_lat: float = 0.0, origin_lng: float = 0.0,
        destination_lat: float = 0.0, destination_lng: float = 0.0,
        time: str = "", time_preference: str = "arrive_by",
        recurring: bool = False, travel_date: str = "", round_trip: bool = False,
        seats: int = 0, people: int = 1, vehicle: str = "", moving_help: bool = False,
        summary: str = "", missing: list[str] = [];
}

obj SharedTripView {
    has traveler: str = "", kind: str = "", route_from: str = "", route_to: str = "",
        when: str = "", driver: str = "", driver_rating: str = "",
        handoff: str = "", handoff_time: str = "", second_driver: str = "",
        second_rating: str = "", arrive: str = "", created_at: str = "";
}

obj EmailStatusView {
    has email: str = "", verified: bool = False;
}

obj BlockedView {
    has key: str = "", handle: str = "", since: str = "";
}

obj NotificationView {
    has id: str = "", kind: str = "", title: str = "", body: str = "",
        match_id: str = "", trip_id: str = "", created_at: str = "", read: bool = False;
}

obj AgentStepView {
    has agent: str = "", role: str = "", summary: str = "", looked_at: int = 0, kept: int = 0;
}

# Where a relay's two rides meet: a real public place near the point where
# both drivers' routes come closest, picked by Gemini (or rules as fallback).
obj HandoffView {
    has name: str = "", address: str = "", lat: float = 0.0, lng: float = 0.0,
        kind: str = "", rating: float = 0.0, reviews: int = 0, open_now: str = "",
        reason: str = "", source: str = "";
}

# A 2-ride route: driver A takes you to the handoff, driver B takes you on.
obj RelayView {
    has id: str = "", leg1_match_id: str = "", leg2_match_id: str = "",
        leg1_handle: str = "", leg2_handle: str = "",
        leg1_rating: float = 0.0, leg1_reviews: int = 0,
        leg2_rating: float = 0.0, leg2_reviews: int = 0,
        pickup_time: str = "", handoff_time: str = "", wait_min: int = 0,
        leg2_depart: str = "", arrive_time: str = "", total_min: int = 0,
        leg1_min: int = 0, leg2_min: int = 0, pickup_gap_mi: float = 0.0,
        score: int = 0, why: str = "", handoff: HandoffView | None = None,
        leg1_points: list[list[float]] = [], leg2_points: list[list[float]] = [];
}

obj AgentRunView {
    has cards: list[MatchCardView] = [], steps: list[AgentStepView] = [],
        relays: list[RelayView] = [];
}

# Walks every journey hanging off the shared root; keeps the ones whose
# role/mode fit and scores how much of the corridor they share.
walker RouteScout {
    has origin_id: str = "", my_root: str = "", scanned: int = 0,
        blocked: list[str] = [],          # travelers hidden by a block (either way)
        candidates: list[Candidate] = [];
    can start with Root entry;
    can inspect with Trip entry;
}

# The other three specialists visit just the Route Scout's shortlist.
walker ScheduleAgent {
    has origin_id: str = "", candidates: list[Candidate] = [];
    can start with Root entry;
    can inspect with Trip entry;
}

walker TrustAgent {
    has origin_id: str = "", candidates: list[Candidate] = [];
    can start with Root entry;
    can inspect with Trip entry;
}

walker CostAgent {
    has origin_id: str = "", candidates: list[Candidate] = [];
    can start with Root entry;
    can inspect with Trip entry;
}

# Runs whenever someone posts a journey: sends the agent team out from the
# new journey and notifies every existing traveler it's a good fit for.
walker Matchmaker {
    has trip_id: str = "", notified: int = 0;
    can watch with Root entry;
}

# Weighs every specialist's score, ranks, and writes/updates the Match nodes.
walker Coordinator {
    has origin_id: str = "", my_root: str = "", candidates: list[Candidate] = [],
        cards: list[MatchCardView] = [];
    can decide with Root entry;
}

# ---------------------------------------------------------------------------
# Public endpoints (implemented in along.impl.jac)
# ---------------------------------------------------------------------------

# Plain `def` = login required; each call runs on the caller's own root.
# Only the aggregate impact numbers are public.

def get_my_profile() -> ProfileView;

def update_profile(display_name: str, home_region: str) -> ProfileView;

def seed_demo_network() -> str;

def create_trip(
    role: str, origin_name: str, destination_name: str, departure_time: str,
    arrival_deadline: str, recurring: bool, recurrence_days: str,
    flexible_minutes: int, seats_available: int, max_detour_minutes: int,
    smoking: bool, quiet_ride: bool, pets: bool, notes: str
) -> str;

def run_matching(trip_id: str) -> list[MatchCardView];

# Same as run_matching, plus each agent's report for the "how we searched" view.
def run_agents(trip_id: str) -> AgentRunView;

def get_match_results() -> list[MatchCardView];

def get_match_details(match_id: str) -> MatchDetailView | None;

def explain_match(match_id: str) -> str;

def get_match_graph(match_id: str) -> GraphView | None;

def create_anonymous_connection(match_id: str) -> ConversationView | None;

def send_message(match_id: str, body: str) -> ConversationView | None;

def approve_identity_reveal(match_id: str) -> ConversationView | None;

def get_conversation(match_id: str) -> ConversationView | None;

def:pub get_impact_metrics() -> ImpactView;

# --- Figma flows: four journey types, conversations inbox, closing + rating ---

# mode: ride | rental | cab. role: RIDER | DRIVER for rides, ignored (PEER) otherwise.
def create_journey(
    mode: str, role: str, origin_name: str, destination_name: str, travel_date: str,
    time_preference: str, time: str, recurring: bool, flexible_minutes: int,
    seats_available: int, people: int, max_detour_minutes: int, pickup_distance: str,
    vehicle: str, moving_help: bool, age_pref: str, gender_pref: str, notes: str,
    # Exact coordinates from the Google Places dropdown; 0 = look the name up.
    origin_lat: float = 0.0, origin_lng: float = 0.0,
    destination_lat: float = 0.0, destination_lng: float = 0.0,
    round_trip: bool = False, return_date: str = "", space_needed: str = ""
) -> str;

# Car-rental counters near a point, nearest first (needs a Google Maps key).
def get_rental_spots(lat: float, lng: float) -> list[RentalSpotView];

def get_my_trip(trip_id: str) -> TripView | None;

def get_my_trips() -> list[TripView];

def get_my_conversations() -> list[ConversationSummaryView];

def close_match(match_id: str) -> bool;

def complete_match(match_id: str) -> bool;

def rate_match(match_id: str, stars: int, comment: str, tags: list[str] = []) -> bool;

def get_traveler_profile(match_id: str) -> TravelerProfileView | None;

# --- Trip assistant: plain English -> journey draft (Gemini, with a rules fallback) ---

def plan_trip(text: str) -> TripDraftView;

# --- Email verification (the verify/reset flows themselves are jac-scale's
#     /user/send-verification, /user/verify-identity, /user/forgot-password,
#     /user/reset-password endpoints) ---

def get_email_status() -> EmailStatusView;

# --- Safety: block and report ---

def block_user(match_id: str) -> bool;

def unblock_user(key: str) -> bool;

def get_blocked() -> list[BlockedView];

# reason: unsafe | harassment | spam | no_show | other
def report_user(match_id: str, reason: str, details: str, also_block: bool) -> bool;

# --- 2-ride trips: book both legs as one plan ---

def book_relay(
    leg1_match_id: str, leg2_match_id: str, handoff_name: str, handoff_address: str,
    handoff_lat: float, handoff_lng: float, handoff_time: str, pickup_time: str,
    wait_min: int, arrive_time: str
) -> str;

def get_relay_plan(plan_id: str) -> RelayPlanView | None;

def get_my_relay_plans() -> list[RelayPlanView];

# Driver side: accept or turn down your leg (the rider then gets options).
def respond_relay_leg(match_id: str, accept: bool) -> bool;

# Rider side: swap in another driver from the options, or cancel the whole trip.
def replace_relay_leg(plan_id: str, leg: str, new_match_id: str, handoff_name: str, handoff_address: str,
    handoff_lat: float, handoff_lng: float, handoff_time: str, arrive_time: str, wait_min: int) -> bool;

def cancel_relay(plan_id: str) -> bool;

# --- Share my trip (safety): a public, read-only link for a friend ---

def create_share_link(match_id: str) -> str;

def:pub get_shared_trip(token: str) -> SharedTripView | None;

# --- Notifications (the Matchmaker and chat create them) ---

def get_my_notifications() -> list[NotificationView];

def mark_notifications_read(ids: list[str]) -> int;

def update_profile_details(display_name: str, home_region: str, phone: str) -> ProfileView;

# --- Google Maps ---

def get_maps_config() -> MapsConfigView;

def get_trip_route(trip_id: str) -> RouteView;
