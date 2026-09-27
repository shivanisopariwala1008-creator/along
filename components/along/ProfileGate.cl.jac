"""ProfileGate — accounts made before age and gender were required are asked
for them once (they power the travel-preference filters). It can't be
skipped; the details are used for matching only and never shown."""

import from .Icon { Icon }
import from ...lib.along { parse_age }
sv import from ...services.along { update_profile_details, ProfileView }

def:pub ProfileGate(profile: ProfileView, onDone: Callable[[], None]) -> JsxElement {
    has age_text: str = str(profile.age) if profile.age else "",
        gender: str = profile.gender,
        busy: bool = False,
        error: str = "";

    async def save(e: FormEvent) {
        e.preventDefault();
        if not (13 <= parse_age(age_text) <= 120) {
            error = "Please enter your age (13 or older).";
            return;
        }
        if not gender {
            error = "Please choose your gender.";
            return;
        }
        busy = True;
        age: int = parse_age(age_text);
        _ = await update_profile_details(profile.display_name, profile.home_region, profile.phone, age, gender);
        busy = False;
        onDone();
    }

    return <div className="dialog-backdrop" role="dialog" aria-modal="true" aria-label="Finish your profile">
        <form className="dialog-card" onSubmit={save}>
            <h2>One quick thing</h2>
            <p className="dialog-sub">Along now lets travelers choose who they ride with by age and gender. Add yours so you show up in their matches — it’s never shown on your profile.</p>
            <div className="field-pair">
                <label className="field">
                    <span>Age</span>
                    <div><input type="number" min="13" max="120" inputMode="numeric" value={age_text} onChange={lambda (e: ChangeEvent) { age_text = e.target.value; }} placeholder="e.g. 28" autoFocus={True} /></div>
                </label>
                <label className="field">
                    <span>Gender</span>
                    <div>
                        <select value={gender} onChange={lambda (e: ChangeEvent) { gender = e.target.value; }}>
                            <option value="" disabled>Choose…</option>
                            <option value="woman">Woman</option>
                            <option value="man">Man</option>
                            <option value="non-binary">Non-binary</option>
                        </select>
                    </div>
                </label>
            </div>
            {error and <p className="form-error">{error}</p>}
            <div className="dialog-actions">
                <button type="submit" className="btn btn-primary" disabled={busy}><Icon name="check" /> {"Saving…" if busy else "Save"}</button>
            </div>
        </form>
    </div>;
}
