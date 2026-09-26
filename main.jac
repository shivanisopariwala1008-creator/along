"""Mobile starter — one Jac source, running on iOS, Android and the web.

    jac start main.jac --dev                        # web preview (react-native-web)
    jac setup react-native                          # one-time Expo scaffold
    jac start main.jac --client react-native --dev  # native (Expo Go / simulator)

The backend graph and the UI live in the same file. Notes persist on the graph,
so they survive a reload — there is no database to configure.

## The one rule that is different from a web app

This project sets `client_kind = "mobui"` in jac.toml, which turns on the
compiler's no-HTML guard. `<div>`, `<span>`, `<button>`, `className` and CSS are
all rejected with **E1105**. Build the UI from `@jac/mobui` primitives instead:

    <div>   -> <View>        <button> -> <Pressable>
    <span>  -> <Text>        <input>  -> <TextInput>
    <p>/<h1>-> <Text>        <ul>     -> <ScrollView>

**All text must sit inside a `<Text>`** — a bare string in a `<View>` crashes on
native. Styling is `style={...}` objects via StyleSheet, never className.

⚠ Keep the UI in this file. The guard covers main.jac and `.native.jac` files
but NOT plain modules, so a `<div>` in a helper module compiles clean here and
then breaks on a real device.
"""

import datetime;
import from uuid { uuid4 }
import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    TextInput,
    ScrollView,
    useWindowDimensions
}
import from .theme { DARK, buildStyles }


# ---------------------------------------------------------------------------
# Backend — the graph is the database, walkers are the API
# ---------------------------------------------------------------------------

node Note {
    has text: str,
        done: bool = False,
        # Stable id the UI can key rows on and address a single note with.
        nid: str = str(uuid4()),
        created_at: str = datetime.datetime.now().strftime("%H:%M");
}


"""Read every note on the shared graph."""
walker:pub load_notes {
    can go with Root entry {
        visit [-->[?:Note]];
    }

    can collect with Note entry {
        report here;
    }
}


"""Add a note. Blank text is ignored rather than stored."""
walker:pub add_note {
    has text: str;

    can make with Root entry {
        clean = self.text.strip();
        if clean {
            here ++> Note(text=clean);
        }
        visit [-->[?:Note]];
    }

    can collect with Note entry {
        report here;
    }
}


"""Flip one note's done flag, then return the whole list."""
walker:pub toggle_note {
    has nid: str;

    can go with Root entry {
        visit [-->[?:Note]];
    }

    can collect with Note entry {
        if here.nid == self.nid {
            here.done = not here.done;
        }
        report here;
    }
}


# ---------------------------------------------------------------------------
# UI — @jac/mobui primitives only
# ---------------------------------------------------------------------------

glob styles = buildStyles(DARK);


"""One note row — tap anywhere on it to toggle done."""
def NoteRow(note: Note, onToggle: Callable[[str], None]) -> JsxElement {
    return <Pressable style={styles.card} onPress={lambda { onToggle(note.nid); }}>
        <View style={styles.row}>
            <View style={styles.checkOn if note.done else styles.check}>
                <Text style={styles.checkMark}>{"✓" if note.done else ""}</Text>
            </View>
            <Text style={styles.noteDone if note.done else styles.noteText}>
                {note.text}
            </Text>
            <Text style={styles.subtitle}>{note.created_at}</Text>
        </View>
    </Pressable>;
}


def:pub app -> JsxElement {
    has notes: list[Note] = [],
        draft: str = "";

    # `flex: 1` needs a parent with a real height. On native the root has one; on
    # web the mount node collapses to content height, so the screen background
    # stops where the content stops and the rest of the phone renders white.
    # Giving the root an explicit viewport height is the fix (same as littlex).
    viewport = useWindowDimensions();

    async can with entry {
        result = root spawn load_notes();
        notes = result.reports;
    }

    async def addNote {
        txt = draft.strip();
        if not txt {
            return;
        }
        # Clear the field first so the input feels instant, then persist.
        draft = "";
        result = root spawn add_note(text=txt);
        notes = result.reports;
    }

    async def toggle(nid: str) {
        result = root spawn toggle_note(nid=nid);
        notes = result.reports;
    }

    return <ScrollView
        style={[styles.screen, {height: viewport.height}]}
        contentContainerStyle={styles.content}
    >
        <View>
            <Text style={styles.title}>Notes</Text>
            <Text style={styles.subtitle}>
                Stored on the graph — they survive a reload.
            </Text>
        </View>

        <View style={styles.row}>
            <TextInput
                style={styles.input}
                value={draft}
                placeholder="Write a note"
                placeholderTextColor={DARK["muted"]}
                onChangeText={lambda (t: str) { draft = t; }}
                onSubmitEditing={lambda { addNote(); }}
            />
            <Pressable style={styles.addButton} onPress={lambda { addNote(); }}>
                <Text style={styles.addLabel}>Add</Text>
            </Pressable>
        </View>

        {(
            <View style={styles.empty}>
                <Text style={styles.subtitle}>No notes yet.</Text>
            </View>
        ) if not notes else <View style={styles.content}>
            {[<NoteRow key={n.nid} note={n} onToggle={toggle}/> for n in notes]}
        </View>}
    </ScrollView>;
}
