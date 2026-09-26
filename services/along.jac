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

import from byllm.lib { Model }

glob explain_llm: Model = Model(model_name="gpt-4o-mini");

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
        handle_number: int = 0;
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
        demo_name: str = "";         # display name revealed for seeded demo users
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
        suggested_cost_share: float = 0.0, notes: str = "", owner_handle: str = "";
}

obj MatchCardView {
    has id: str = "", overall_score: int = 0, route_score: int = 0, time_score: int = 0,
        detour_minutes: int = 0, preference_score: int = 0, cost_benefit_score: int = 0,
        estimated_rider_savings: float = 0.0, status: str = "",
        driver_trip: TripView | None = None, rider_trip: TripView | None = None;
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
        other_display_name: str = "", other_verified: bool = False;
}

obj ProfileView {
    has display_name: str = "", home_region: str = "", rider_handle: str = "",
        driver_handle: str = "", verified: bool = False;
}

obj ImpactView {
    has journeys_matched: int = 0, estimated_rider_savings: float = 0.0,
        empty_seats_activated: int = 0, shared_miles: float = 0.0,
        communities_connected: int = 0, cities: list[str] = [];
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

def get_match_results() -> list[MatchCardView];

def get_match_details(match_id: str) -> MatchDetailView | None;

def explain_match(match_id: str) -> str;

def get_match_graph(match_id: str) -> GraphView | None;

def create_anonymous_connection(match_id: str) -> ConversationView | None;

def send_message(match_id: str, body: str) -> ConversationView | None;

def approve_identity_reveal(match_id: str) -> ConversationView | None;

def get_conversation(match_id: str) -> ConversationView | None;

def:pub get_impact_metrics() -> ImpactView;
