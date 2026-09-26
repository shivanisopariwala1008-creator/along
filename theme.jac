"""Design tokens and the stylesheet factory.

React Native has no CSS, no Tailwind and no className -- styling is plain
objects of camelCase properties built with StyleSheet.create. Keeping the tokens
here and the sheet in a factory means the whole app re-skins from one place.

There is deliberately no JSX in this file. E1105 (the no-HTML guard) is enforced
on main.jac and .native.jac files but NOT on plain modules like this one, so a
stray <div> here would compile clean and then break on a real device. Keep
rendering in main.jac.
"""

import from "@jac/mobui" { StyleSheet }


glob:pub DARK: dict = {
         "bg": "#0b0d12",
         "surface": "#151922",
         "border": "#232937",
         "text": "#e6e9ef",
         "muted": "#8a93a6",
         "accent": "#7c5cff",
         "accentText": "#ffffff"
     },
     S: dict = {"xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24},
     R: dict = {"sm": 8, "md": 12, "lg": 16, "pill": 999},
     F: dict = {"sm": 13, "md": 15, "lg": 18, "xl": 28};


"""Build the stylesheet for a palette. Call once at module load, not per render.

Returns `any`, not `dict`: StyleSheet.create hands back a sheet whose entries are
read as attributes (`styles.card`). Annotating it `dict` turns every one of those
reads into `error[E1030]: Type "dict" has no attribute "card"`.
"""
def:pub buildStyles(C: dict) -> any {
    return StyleSheet.create(
        {
            "screen": {"flex": 1, "backgroundColor": C["bg"]},
            "content": {"padding": S["xl"], "gap": S["lg"]},
            "title": {
                "fontSize": F["xl"],
                "fontWeight": "bold",
                "color": C["text"]
            },
            "subtitle": {"fontSize": F["sm"], "color": C["muted"]},
            # flexDirection defaults to "column" in RN -- rows must say so.
            "row": {
                "flexDirection": "row",
                "alignItems": "center",
                "gap": S["sm"]
            },
            "input": {
                "flex": 1,
                "padding": S["md"],
                "borderRadius": R["md"],
                "borderWidth": 1,
                "borderColor": C["border"],
                "backgroundColor": C["surface"],
                "color": C["text"]
            },
            "addButton": {
                "paddingVertical": S["md"],
                "paddingHorizontal": S["lg"],
                "borderRadius": R["md"],
                "backgroundColor": C["accent"],
                "alignItems": "center"
            },
            "addLabel": {"color": C["accentText"], "fontWeight": "bold"},
            "card": {
                "padding": S["lg"],
                "borderRadius": R["md"],
                "borderWidth": 1,
                "borderColor": C["border"],
                "backgroundColor": C["surface"]
            },
            "noteText": {"fontSize": F["md"], "color": C["text"], "flex": 1},
            "noteDone": {
                "fontSize": F["md"],
                "color": C["muted"],
                "flex": 1,
                "textDecorationLine": "line-through"
            },
            "check": {
                "width": 22,
                "height": 22,
                "borderRadius": R["pill"],
                "borderWidth": 1,
                "borderColor": C["accent"],
                "alignItems": "center",
                "justifyContent": "center"
            },
            "checkOn": {
                "width": 22,
                "height": 22,
                "borderRadius": R["pill"],
                "backgroundColor": C["accent"],
                "alignItems": "center",
                "justifyContent": "center"
            },
            "checkMark": {"color": C["accentText"], "fontSize": F["sm"]},
            "empty": {
                "padding": S["xl"],
                "alignItems": "center",
                "gap": S["sm"]
            }
        }
    );
}
