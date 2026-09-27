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
        round_trip: bool = False;
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
        driver_rated: bool = False;
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
        owner_rating: float = 0.0, owner_reviews: int = 0, round_trip: bool = False;
}

obj MatchCardView {
    has id: str = "", overall_score: int = 0, route_score: int = 0, time_score: int = 0,
        detour_minutes: int = 0, preference_score: int = 0, cost_benefit_score: int = 0,
        estimated_rider_savings: float = 0.0, status: str = "",
        driver_trip: TripView | None = None, rider_trip: TripView | None = None,
        # Caller-relative view: which trip is mine and which is the other person's.
        my_trip: TripView | None = None, other_trip: TripView | None = None,
        mode: str = "ride", fit_label: str = "", why: str = "",
        other_handle: str = "", has_conversation: bool = False;
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
        i_rated: bool = False;
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
        can_review: bool = False, already_reviewed: bool = False;
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
    round_trip: bool = False
) -> str;

def get_my_trip(trip_id: str) -> TripView | None;

def get_my_trips() -> list[TripView];

def get_my_conversations() -> list[ConversationSummaryView];

def close_match(match_id: str) -> bool;

def complete_match(match_id: str) -> bool;

def rate_match(match_id: str, stars: int, comment: str, tags: list[str] = []) -> bool;

def get_traveler_profile(match_id: str) -> TravelerProfileView | None;

def update_profile_details(display_name: str, home_region: str, phone: str) -> ProfileView;

# --- Google Maps ---

def get_maps_config() -> MapsConfigView;

def get_trip_route(trip_id: str) -> RouteView;
