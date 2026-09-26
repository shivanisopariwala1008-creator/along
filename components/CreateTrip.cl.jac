"""CreateTrip — post a journey. Creates the Trip node + edges on the graph,
then hands off to the matching animation screen."""

import from "@jac/runtime" { Link, useNavigate, useLocation }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowLeft01Icon, Route01Icon }
import from .ui.button { Button }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
import from .ui.input { Input }
import from .ui.textarea { Textarea }
import from .ui.field { Field, FieldLabel, FieldGroup }
import from .ui.toggle_group { ToggleGroup, ToggleGroupItem }
import from .ui.switch { Switch }
import from .BrandMark { BrandMark }
sv import from ..services.along { create_trip }

def:pub CreateTrip() -> JsxElement {
    location = useLocation();
    params: any = new(URLSearchParams, location.search);  # jac:ignore[E1032,E1053]
    initial_role: str = (params.get("role") or "RIDER") as str;

    has role: str = initial_role,
        origin_name: str = "Grand Blanc, MI" if initial_role == "RIDER" else "Flint, MI",
        destination_name: str = "Ann Arbor, MI",
        departure_time: str = "07:35" if initial_role == "RIDER" else "07:40",
        arrival_deadline: str = "09:00",
        recurring: bool = True,
        recurrence_days: str = "Mon-Fri",
        flexible_minutes: int = 20,
        seats_available: int = 2,
        max_detour_minutes: int = 10,
        smoking: bool = False,
        quiet_ride: bool = True,
        pets: bool = True,
        notes: str = "",
        submitting: bool = False,
        error: str = "";

    nav = useNavigate();

    def handle_origin(e: ChangeEvent) { origin_name = e.target.value; }
    def handle_destination(e: ChangeEvent) { destination_name = e.target.value; }
    def handle_departure(e: ChangeEvent) { departure_time = e.target.value; }
    def handle_deadline(e: ChangeEvent) { arrival_deadline = e.target.value; }
    def handle_flex(e: ChangeEvent) { flexible_minutes = int(e.target.value or "0"); }
    def handle_seats(e: ChangeEvent) { seats_available = int(e.target.value or "0"); }
    def handle_detour(e: ChangeEvent) { max_detour_minutes = int(e.target.value or "0"); }
    def handle_notes(e: ChangeEvent) { notes = e.target.value; }
    def handle_role(value: str) { if value { role = value; } }

    async def handle_submit(e: FormEvent) {
        e.preventDefault();
        if not origin_name.strip() or not destination_name.strip() {
            error = "Please fill in where you're starting and where you're headed.";
            return;
        }
        submitting = True;
        error = "";
        trip_id = await create_trip(
            role, origin_name, destination_name, departure_time, arrival_deadline,
            recurring, recurrence_days, flexible_minutes,
            seats_available if role == "DRIVER" else 0,
            max_detour_minutes if role == "DRIVER" else 0,
            smoking, quiet_ride, pets, notes
        );
        submitting = False;
        nav("/matching?tripId=" + trip_id);
    }

    return <div className="min-h-svh bg-muted/30">
        <div className="mx-auto flex max-w-2xl flex-col gap-6 pt-10 pb-16 pl-6 pr-6">
            <div className="flex items-center justify-between">
                <BrandMark />
                <Link to="/" className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-4" />
                    Home
                </Link>
            </div>

            <div className="flex flex-col gap-1">
                <h1 className="text-2xl font-semibold tracking-tight">Post your journey</h1>
                <p className="text-sm text-muted-foreground">Along's walkers will search the mobility graph for compatible journeys the moment you submit.</p>
            </div>

            <form onSubmit={handle_submit}>
                <Card className="shadow-sm">
                    <CardHeader>
                        <CardTitle>Journey details</CardTitle>
                        <CardDescription>Tell Along what you need — an exact match to the mile is never required.</CardDescription>
                    </CardHeader>
                    <CardContent className="flex flex-col gap-5">
                        <Field>
                            <FieldLabel>I am</FieldLabel>
                            <ToggleGroup type="single" value={role} onValueChange={handle_role} className="w-full">
                                <ToggleGroupItem value="RIDER" className="flex-1">Looking for a ride</ToggleGroupItem>
                                <ToggleGroupItem value="DRIVER" className="flex-1">Offering a ride</ToggleGroupItem>
                            </ToggleGroup>
                        </Field>

                        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                            <Field>
                                <FieldLabel htmlFor="origin">From</FieldLabel>
                                <Input id="origin" value={origin_name} onChange={handle_origin} placeholder="Grand Blanc, MI" />
                            </Field>
                            <Field>
                                <FieldLabel htmlFor="destination">To</FieldLabel>
                                <Input id="destination" value={destination_name} onChange={handle_destination} placeholder="Ann Arbor, MI" />
                            </Field>
                        </div>

                        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                            <Field>
                                <FieldLabel htmlFor="departure">Preferred departure</FieldLabel>
                                <Input id="departure" type="time" value={departure_time} onChange={handle_departure} />
                            </Field>
                            <Field>
                                <FieldLabel htmlFor="deadline">Must arrive by</FieldLabel>
                                <Input id="deadline" type="time" value={arrival_deadline} onChange={handle_deadline} />
                            </Field>
                        </div>

                        <div className="flex items-center justify-between rounded-lg border pt-3 pb-3 pl-4 pr-4">
                            <div className="flex flex-col gap-0.5">
                                <span className="text-sm font-medium">Recurring commute</span>
                                <span className="text-xs text-muted-foreground">{recurrence_days}</span>
                            </div>
                            <Switch checked={recurring} onCheckedChange={lambda (v: bool) { recurring = v; }} />
                        </div>

                        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                            <Field>
                                <FieldLabel htmlFor="flex">Flexible by (+/- minutes)</FieldLabel>
                                <Input id="flex" type="number" min="0" value={str(flexible_minutes)} onChange={handle_flex} />
                            </Field>
                            {role == "DRIVER" and <Field>
                                <FieldLabel htmlFor="seats">Seats available</FieldLabel>
                                <Input id="seats" type="number" min="1" value={str(seats_available)} onChange={handle_seats} />
                            </Field>}
                        </div>

                        {role == "DRIVER" and <Field>
                            <FieldLabel htmlFor="detour">Maximum detour (minutes)</FieldLabel>
                            <Input id="detour" type="number" min="0" value={str(max_detour_minutes)} onChange={handle_detour} />
                        </Field>}

                        <div className="flex flex-col gap-3 rounded-lg border pt-3 pb-3 pl-4 pr-4">
                            <span className="text-sm font-medium">Preferences</span>
                            <div className="flex items-center justify-between">
                                <span className="text-sm text-muted-foreground">Non-smoking</span>
                                <Switch checked={not smoking} onCheckedChange={lambda (v: bool) { smoking = not v; }} />
                            </div>
                            <div className="flex items-center justify-between">
                                <span className="text-sm text-muted-foreground">Quiet / moderate conversation</span>
                                <Switch checked={quiet_ride} onCheckedChange={lambda (v: bool) { quiet_ride = v; }} />
                            </div>
                            <div className="flex items-center justify-between">
                                <span className="text-sm text-muted-foreground">Comfortable with pets</span>
                                <Switch checked={pets} onCheckedChange={lambda (v: bool) { pets = v; }} />
                            </div>
                        </div>

                        <Field>
                            <FieldLabel htmlFor="notes">Optional note</FieldLabel>
                            <Textarea id="notes" value={notes} onChange={handle_notes} placeholder="Anything Along's matching should know" rows={3} />
                        </Field>

                        {error and <p className="text-sm text-destructive">{error}</p>}
                    </CardContent>
                    <CardFooter className="flex justify-end gap-3">
                        <Button type="submit" disabled={submitting} className="shadow-sm">
                            <HugeiconsIcon icon={Route01Icon} strokeWidth={2} className="size-4" />
                            {"Posting..." if submitting else "Post journey & find matches"}
                        </Button>
                    </CardFooter>
                </Card>
            </form>
        </div>
    </div>;
}
