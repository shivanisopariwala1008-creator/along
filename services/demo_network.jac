"""Demo network — about 270 sample journeys across 20 Southeast/Mid Michigan
cities, so every journey type (and every filter) has realistic matches.

  Find a ride   -> drivers commuting home <-> workplaces
  Offer a ride  -> riders commuting home <-> workplaces
  Share a rental-> moving (home -> home, trucks/vans) and trips (home ->
                   landmarks, weekend getaways, driving-test sites)
  Share a cab   -> home <-> airports, landmark <-> landmark, home <-> home

Everything is generated deterministically from the tables below, so
re-seeding never duplicates or reshuffles anyone. Every person has an age
and a gender (matching their first name); a few set their own preferences.
"""

# key -> [display name, lat, lng]
glob PLACES: dict[str, list] = {
    # Residential areas (20 cities + a few neighborhoods)
    "Detroit": ["Detroit, MI", 42.3314, -83.0458],
    "Midtown Detroit": ["Midtown, Detroit, MI", 42.3569, -83.0663],
    "Ann Arbor": ["Ann Arbor, MI", 42.2808, -83.7430],
    "Novi": ["Novi, MI", 42.4806, -83.4755],
    "Flint": ["Flint, MI", 43.0125, -83.6875],
    "Plymouth": ["Plymouth, MI", 42.3714, -83.4702],
    "Troy": ["Troy, MI", 42.6064, -83.1498],
    "Southfield": ["Southfield, MI", 42.4734, -83.2219],
    "Dearborn": ["Dearborn, MI", 42.3223, -83.1763],
    "Livonia": ["Livonia, MI", 42.3684, -83.3527],
    "Farmington Hills": ["Farmington Hills, MI", 42.4990, -83.3677],
    "Royal Oak": ["Royal Oak, MI", 42.4895, -83.1446],
    "Canton": ["Canton, MI", 42.3086, -83.4820],
    "Ypsilanti": ["Ypsilanti, MI", 42.2411, -83.6130],
    "Sterling Heights": ["Sterling Heights, MI", 42.5803, -83.0302],
    "Warren": ["Warren, MI", 42.5145, -83.0147],
    "Grand Blanc": ["Grand Blanc, MI", 42.9269, -83.6410],
    "Auburn Hills": ["Auburn Hills, MI", 42.6875, -83.2341],
    "Birmingham": ["Birmingham, MI", 42.5467, -83.2113],
    "Rochester Hills": ["Rochester Hills, MI", 42.6584, -83.1499],
    "Lansing": ["Lansing, MI", 42.7325, -84.5555],
    "East Lansing": ["East Lansing, MI", 42.7370, -84.4839],
    # Workplaces and campuses
    "GM Tech Center": ["GM Global Technical Center, Warren, MI", 42.5140, -83.0400],
    "GM RenCen": ["GM Renaissance Center, Detroit, MI", 42.3293, -83.0398],
    "Ford Dearborn": ["Ford Research & Engineering Center, Dearborn, MI", 42.2960, -83.2300],
    "Stellantis": ["Stellantis HQ, Auburn Hills, MI", 42.6503, -83.2364],
    "Rocket": ["Rocket Companies, Downtown Detroit, MI", 42.3334, -83.0469],
    "Michigan Medicine": ["Michigan Medicine, Ann Arbor, MI", 42.2837, -83.7282],
    "Domino's Farms": ["Domino's Farms Office Park, Ann Arbor, MI", 42.3100, -83.6960],
    "Corewell Royal Oak": ["Corewell Health Royal Oak Hospital, MI", 42.5178, -83.1942],
    "Henry Ford Hospital": ["Henry Ford Hospital, Detroit, MI", 42.3677, -83.0852],
    "Big Beaver": ["Big Beaver office corridor, Troy, MI", 42.5630, -83.1500],
    "Southfield Town Center": ["Southfield Town Center, MI", 42.4812, -83.2470],
    "Novi Business": ["Novi business district (12 Mile & Novi Rd), MI", 42.4955, -83.4755],
    "Trinity Livonia": ["Trinity Health, Livonia, MI", 42.4190, -83.3740],
    "GM Flint": ["GM Flint Assembly, Flint, MI", 42.9890, -83.7330],
    "Hurley": ["Hurley Medical Center, Flint, MI", 43.0200, -83.7010],
    "State Capitol": ["Michigan State Capitol, Lansing, MI", 42.7336, -84.5555],
    "MSU": ["Michigan State University, East Lansing, MI", 42.7018, -84.4822],
    "UM Campus": ["University of Michigan Central Campus, Ann Arbor, MI", 42.2780, -83.7382],
    "EMU": ["Eastern Michigan University, Ypsilanti, MI", 42.2506, -83.6243],
    "Wayne State": ["Wayne State University, Detroit, MI", 42.3591, -83.0665],
    "Oakland U": ["Oakland University, Rochester Hills, MI", 42.6734, -83.2150],
    # Airports
    "DTW": ["Detroit Metro Airport (DTW), Romulus, MI", 42.2162, -83.3554],
    "FNT": ["Bishop International Airport (FNT), Flint, MI", 42.9655, -83.7436],
    "LAN": ["Capital Region Airport (LAN), Lansing, MI", 42.7787, -84.5874],
    # Landmarks and venues
    "Comerica Park": ["Comerica Park, Detroit, MI", 42.3390, -83.0485],
    "Little Caesars Arena": ["Little Caesars Arena, Detroit, MI", 42.3411, -83.0553],
    "Ford Field": ["Ford Field, Detroit, MI", 42.3400, -83.0456],
    "The Henry Ford": ["The Henry Ford museum, Dearborn, MI", 42.3036, -83.2345],
    "DIA": ["Detroit Institute of Arts, Detroit, MI", 42.3594, -83.0645],
    "Michigan Stadium": ["Michigan Stadium, Ann Arbor, MI", 42.2658, -83.7487],
    "Somerset": ["Somerset Collection, Troy, MI", 42.5620, -83.1840],
    "Twelve Oaks": ["Twelve Oaks Mall, Novi, MI", 42.4912, -83.4695],
    "Great Lakes Crossing": ["Great Lakes Crossing Outlets, Auburn Hills, MI", 42.7040, -83.2960],
    "Belle Isle": ["Belle Isle Park, Detroit, MI", 42.3401, -82.9824],
    "Eastern Market": ["Eastern Market, Detroit, MI", 42.3470, -83.0410],
    "Detroit Zoo": ["Detroit Zoo, Royal Oak, MI", 42.4770, -83.1500],
    "Pine Knob": ["Pine Knob Music Theatre, Clarkston, MI", 42.7440, -83.3740],
    "Kensington": ["Kensington Metropark, Milford, MI", 42.5330, -83.6590],
    # Weekend getaways (rentals)
    "Traverse City": ["Traverse City, MI", 44.7631, -85.6206],
    "Mackinaw City": ["Mackinaw City, MI", 45.7775, -84.7278],
    "Sleeping Bear": ["Sleeping Bear Dunes, Empire, MI", 44.8830, -86.0420],
    "Holland": ["Holland, MI", 42.7875, -86.1089],
    "Grand Rapids": ["Grand Rapids, MI", 42.9634, -85.6681],
    "Grand Haven": ["Grand Haven, MI", 43.0631, -86.2284],
    "Frankenmuth": ["Frankenmuth, MI", 43.3317, -83.7380],
    "Petoskey": ["Petoskey, MI", 45.3736, -84.9553],
    # Driving-test sites (you need a car for the road test)
    "Test Livonia": ["Driving test site, Livonia, MI", 42.3780, -83.3700],
    "Test Troy": ["Driving test site, Troy, MI", 42.5900, -83.1300],
    "Test Ann Arbor": ["Driving test site, Ann Arbor, MI", 42.2560, -83.7120],
    "Test Southfield": ["Driving test site, Southfield, MI", 42.4650, -83.2400],
    "Test Flint": ["Driving test site, Flint, MI", 42.9980, -83.6950],
    "Test Lansing": ["Driving test site, Lansing, MI", 42.7200, -84.5300],
    "Test Novi": ["Driving test site, Novi, MI", 42.4700, -83.4600]
};

# [mode, role, from, to, departure times, extra]
#   extra for rentals: "<vehicle>" or "<vehicle>|move"
glob ROUTES: list[list] = [
    # --- Find a ride: drivers, mornings home -> work -------------------------
    ["ride", "DRIVER", "Flint", "GM Tech Center", ["06:45"], ""],
    ["ride", "DRIVER", "Flint", "Michigan Medicine", ["07:00"], ""],
    ["ride", "DRIVER", "Flint", "Stellantis", ["06:55"], ""],
    ["ride", "DRIVER", "Grand Blanc", "Stellantis", ["07:15"], ""],
    ["ride", "DRIVER", "Grand Blanc", "Hurley", ["06:30"], ""],
    ["ride", "DRIVER", "Lansing", "Michigan Medicine", ["06:50"], ""],
    ["ride", "DRIVER", "Lansing", "Novi Business", ["07:00"], ""],
    ["ride", "DRIVER", "East Lansing", "State Capitol", ["08:10"], ""],
    ["ride", "DRIVER", "Ann Arbor", "Ford Dearborn", ["07:30"], ""],
    ["ride", "DRIVER", "Ann Arbor", "GM RenCen", ["07:15"], ""],
    ["ride", "DRIVER", "Ann Arbor", "Rocket", ["07:45"], ""],
    ["ride", "DRIVER", "Ann Arbor", "Domino's Farms", ["08:20"], ""],
    ["ride", "DRIVER", "Ypsilanti", "Michigan Medicine", ["07:40"], ""],
    ["ride", "DRIVER", "Ypsilanti", "Ford Dearborn", ["07:10"], ""],
    ["ride", "DRIVER", "Canton", "Ford Dearborn", ["07:35"], ""],
    ["ride", "DRIVER", "Canton", "Rocket", ["07:20"], ""],
    ["ride", "DRIVER", "Plymouth", "Trinity Livonia", ["08:00"], ""],
    ["ride", "DRIVER", "Plymouth", "Michigan Medicine", ["07:25"], ""],
    ["ride", "DRIVER", "Novi", "Big Beaver", ["07:50"], ""],
    ["ride", "DRIVER", "Novi", "Southfield Town Center", ["08:10"], ""],
    ["ride", "DRIVER", "Novi", "Ford Dearborn", ["07:30"], ""],
    ["ride", "DRIVER", "Livonia", "Henry Ford Hospital", ["07:00"], ""],
    ["ride", "DRIVER", "Livonia", "GM RenCen", ["07:40"], ""],
    ["ride", "DRIVER", "Farmington Hills", "Stellantis", ["07:30"], ""],
    ["ride", "DRIVER", "Farmington Hills", "Rocket", ["08:00"], ""],
    ["ride", "DRIVER", "Southfield", "GM Tech Center", ["07:45"], ""],
    ["ride", "DRIVER", "Southfield", "Henry Ford Hospital", ["07:20"], ""],
    ["ride", "DRIVER", "Royal Oak", "Rocket", ["08:15"], ""],
    ["ride", "DRIVER", "Royal Oak", "Stellantis", ["07:40"], ""],
    ["ride", "DRIVER", "Birmingham", "GM RenCen", ["08:00"], ""],
    ["ride", "DRIVER", "Troy", "Stellantis", ["08:05"], ""],
    ["ride", "DRIVER", "Troy", "Wayne State", ["07:50"], ""],
    ["ride", "DRIVER", "Sterling Heights", "GM Tech Center", ["07:30"], ""],
    ["ride", "DRIVER", "Sterling Heights", "Rocket", ["07:15"], ""],
    ["ride", "DRIVER", "Warren", "Corewell Royal Oak", ["06:50"], ""],
    ["ride", "DRIVER", "Rochester Hills", "Big Beaver", ["08:20"], ""],
    ["ride", "DRIVER", "Rochester Hills", "Rocket", ["07:10"], ""],
    ["ride", "DRIVER", "Auburn Hills", "Oakland U", ["08:30"], ""],
    ["ride", "DRIVER", "Dearborn", "Rocket", ["08:10"], ""],
    ["ride", "DRIVER", "Dearborn", "Michigan Medicine", ["07:05"], ""],
    ["ride", "DRIVER", "Detroit", "Stellantis", ["07:00"], ""],
    ["ride", "DRIVER", "Detroit", "Ford Dearborn", ["07:40"], ""],
    ["ride", "DRIVER", "Midtown Detroit", "Big Beaver", ["07:55"], ""],
    # --- Find a ride: drivers, evenings work -> home -------------------------
    ["ride", "DRIVER", "Michigan Medicine", "Flint", ["17:10"], ""],
    ["ride", "DRIVER", "Michigan Medicine", "Lansing", ["17:00"], ""],
    ["ride", "DRIVER", "Michigan Medicine", "Canton", ["16:45"], ""],
    ["ride", "DRIVER", "Michigan Medicine", "Plymouth", ["17:30"], ""],
    ["ride", "DRIVER", "Ford Dearborn", "Ann Arbor", ["17:00"], ""],
    ["ride", "DRIVER", "Ford Dearborn", "Canton", ["16:30"], ""],
    ["ride", "DRIVER", "Ford Dearborn", "Novi", ["17:15"], ""],
    ["ride", "DRIVER", "Rocket", "Royal Oak", ["17:30"], ""],
    ["ride", "DRIVER", "Rocket", "Ann Arbor", ["17:15"], ""],
    ["ride", "DRIVER", "Rocket", "Sterling Heights", ["17:00"], ""],
    ["ride", "DRIVER", "Rocket", "Farmington Hills", ["17:45"], ""],
    ["ride", "DRIVER", "GM RenCen", "Birmingham", ["17:20"], ""],
    ["ride", "DRIVER", "GM RenCen", "Livonia", ["17:00"], ""],
    ["ride", "DRIVER", "Stellantis", "Troy", ["17:10"], ""],
    ["ride", "DRIVER", "Stellantis", "Grand Blanc", ["16:45"], ""],
    ["ride", "DRIVER", "Stellantis", "Farmington Hills", ["17:30"], ""],
    ["ride", "DRIVER", "Stellantis", "Detroit", ["16:50"], ""],
    ["ride", "DRIVER", "GM Tech Center", "Southfield", ["16:40"], ""],
    ["ride", "DRIVER", "GM Tech Center", "Flint", ["16:15"], ""],
    ["ride", "DRIVER", "Big Beaver", "Novi", ["17:20"], ""],
    ["ride", "DRIVER", "Big Beaver", "Rochester Hills", ["17:40"], ""],
    # --- Offer a ride: riders, mornings home -> work -------------------------
    ["ride", "RIDER", "Flint", "Michigan Medicine", ["07:10"], ""],
    ["ride", "RIDER", "Grand Blanc", "GM Tech Center", ["06:40"], ""],
    ["ride", "RIDER", "Grand Blanc", "Rocket", ["07:00"], ""],
    ["ride", "RIDER", "Lansing", "Novi Business", ["07:15"], ""],
    ["ride", "RIDER", "East Lansing", "MSU", ["08:30"], ""],
    ["ride", "RIDER", "Ann Arbor", "Rocket", ["07:30"], ""],
    ["ride", "RIDER", "Ann Arbor", "Ford Dearborn", ["07:45"], ""],
    ["ride", "RIDER", "Ypsilanti", "Rocket", ["07:20"], ""],
    ["ride", "RIDER", "Ypsilanti", "Michigan Medicine", ["08:00"], ""],
    ["ride", "RIDER", "Ypsilanti", "UM Campus", ["08:40"], ""],
    ["ride", "RIDER", "Canton", "Michigan Medicine", ["07:30"], ""],
    ["ride", "RIDER", "Canton", "Henry Ford Hospital", ["07:00"], ""],
    ["ride", "RIDER", "Plymouth", "Ford Dearborn", ["07:40"], ""],
    ["ride", "RIDER", "Plymouth", "Novi Business", ["08:15"], ""],
    ["ride", "RIDER", "Novi", "Rocket", ["07:35"], ""],
    ["ride", "RIDER", "Novi", "Stellantis", ["07:50"], ""],
    ["ride", "RIDER", "Livonia", "Ford Dearborn", ["07:45"], ""],
    ["ride", "RIDER", "Livonia", "Southfield Town Center", ["08:10"], ""],
    ["ride", "RIDER", "Farmington Hills", "GM RenCen", ["07:25"], ""],
    ["ride", "RIDER", "Farmington Hills", "Big Beaver", ["08:05"], ""],
    ["ride", "RIDER", "Southfield", "Rocket", ["08:00"], ""],
    ["ride", "RIDER", "Royal Oak", "GM Tech Center", ["07:30"], ""],
    ["ride", "RIDER", "Royal Oak", "Wayne State", ["08:20"], ""],
    ["ride", "RIDER", "Birmingham", "Stellantis", ["08:10"], ""],
    ["ride", "RIDER", "Troy", "Rocket", ["07:40"], ""],
    ["ride", "RIDER", "Troy", "GM Tech Center", ["07:55"], ""],
    ["ride", "RIDER", "Sterling Heights", "Stellantis", ["07:45"], ""],
    ["ride", "RIDER", "Warren", "Rocket", ["07:20"], ""],
    ["ride", "RIDER", "Rochester Hills", "GM Tech Center", ["07:35"], ""],
    ["ride", "RIDER", "Auburn Hills", "Rocket", ["07:15"], ""],
    ["ride", "RIDER", "Dearborn", "Michigan Medicine", ["07:15"], ""],
    ["ride", "RIDER", "Detroit", "Ford Dearborn", ["07:30"], ""],
    ["ride", "RIDER", "Midtown Detroit", "Oakland U", ["08:00"], ""],
    # --- Offer a ride: riders, evenings work -> home -------------------------
    ["ride", "RIDER", "Michigan Medicine", "Ypsilanti", ["17:15"], ""],
    ["ride", "RIDER", "Michigan Medicine", "Canton", ["17:00"], ""],
    ["ride", "RIDER", "Rocket", "Novi", ["17:20"], ""],
    ["ride", "RIDER", "Rocket", "Troy", ["17:30"], ""],
    ["ride", "RIDER", "Rocket", "Ann Arbor", ["17:10"], ""],
    ["ride", "RIDER", "Ford Dearborn", "Plymouth", ["16:50"], ""],
    ["ride", "RIDER", "Ford Dearborn", "Detroit", ["17:05"], ""],
    ["ride", "RIDER", "GM Tech Center", "Royal Oak", ["16:45"], ""],
    ["ride", "RIDER", "GM Tech Center", "Rochester Hills", ["16:30"], ""],
    ["ride", "RIDER", "Stellantis", "Sterling Heights", ["17:15"], ""],
    ["ride", "RIDER", "Stellantis", "Novi", ["17:00"], ""],
    ["ride", "RIDER", "Big Beaver", "Farmington Hills", ["17:30"], ""],
    ["ride", "RIDER", "Henry Ford Hospital", "Canton", ["19:30"], ""],
    ["ride", "RIDER", "Southfield Town Center", "Livonia", ["17:40"], ""],
    ["ride", "RIDER", "Trinity Livonia", "Plymouth", ["17:10"], ""],
    # --- Share a rental: moving, home -> home --------------------------------
    ["rental", "PEER", "Ann Arbor", "Detroit", ["09:00"], "Box truck|move"],
    ["rental", "PEER", "Ypsilanti", "Ann Arbor", ["10:00"], "Cargo van|move"],
    ["rental", "PEER", "Novi", "Royal Oak", ["08:30"], "Box truck|move"],
    ["rental", "PEER", "Royal Oak", "Novi", ["09:30"], "Pickup truck|move"],
    ["rental", "PEER", "Detroit", "Dearborn", ["10:30"], "Cargo van|move"],
    ["rental", "PEER", "Lansing", "Ann Arbor", ["08:00"], "Box truck|move"],
    ["rental", "PEER", "East Lansing", "Ann Arbor", ["09:00"], "Cargo van|move"],
    ["rental", "PEER", "Flint", "Grand Blanc", ["11:00"], "Pickup truck|move"],
    ["rental", "PEER", "Flint", "Ann Arbor", ["08:30"], "Box truck|move"],
    ["rental", "PEER", "Troy", "Sterling Heights", ["09:00"], "Cargo van|move"],
    ["rental", "PEER", "Canton", "Plymouth", ["10:00"], "Pickup truck|move"],
    ["rental", "PEER", "Southfield", "Farmington Hills", ["09:30"], "Cargo van|move"],
    ["rental", "PEER", "Birmingham", "Detroit", ["08:30"], "Box truck|move"],
    ["rental", "PEER", "Livonia", "Canton", ["12:00"], "Minivan|move"],
    ["rental", "PEER", "Rochester Hills", "Auburn Hills", ["10:30"], "Pickup truck|move"],
    ["rental", "PEER", "Warren", "Troy", ["09:00"], "Cargo van|move"],
    ["rental", "PEER", "Dearborn", "Ann Arbor", ["08:00"], "Box truck|move"],
    ["rental", "PEER", "Detroit", "Royal Oak", ["09:30"], "Cargo van|move"],
    # --- Share a rental: trips, home -> landmarks & getaways -----------------
    ["rental", "PEER", "Ann Arbor", "Traverse City", ["08:00"], "SUV"],
    ["rental", "PEER", "Detroit", "Traverse City", ["07:30"], "SUV"],
    ["rental", "PEER", "Novi", "Mackinaw City", ["07:00"], "SUV"],
    ["rental", "PEER", "Troy", "Mackinaw City", ["06:30"], "Minivan"],
    ["rental", "PEER", "Lansing", "Holland", ["09:00"], "Sedan"],
    ["rental", "PEER", "Ann Arbor", "Grand Rapids", ["09:30"], "Sedan"],
    ["rental", "PEER", "Royal Oak", "Frankenmuth", ["10:00"], "Compact car"],
    ["rental", "PEER", "Flint", "Frankenmuth", ["11:00"], "Compact car"],
    ["rental", "PEER", "Canton", "Sleeping Bear", ["07:00"], "SUV"],
    ["rental", "PEER", "Plymouth", "Holland", ["08:30"], "Sedan"],
    ["rental", "PEER", "Ypsilanti", "Traverse City", ["08:00"], "SUV"],
    ["rental", "PEER", "Southfield", "Grand Haven", ["08:00"], "Sedan"],
    ["rental", "PEER", "Birmingham", "Petoskey", ["07:30"], "SUV"],
    ["rental", "PEER", "Sterling Heights", "Frankenmuth", ["09:30"], "Minivan"],
    ["rental", "PEER", "Farmington Hills", "Kensington", ["09:00"], "Compact car"],
    ["rental", "PEER", "Dearborn", "Grand Rapids", ["08:30"], "Sedan"],
    ["rental", "PEER", "Livonia", "Traverse City", ["07:00"], "SUV"],
    ["rental", "PEER", "East Lansing", "Grand Haven", ["09:00"], "Compact car"],
    ["rental", "PEER", "Novi", "Holland", ["08:00"], "Sedan"],
    # --- Share a rental: driving tests ---------------------------------------
    ["rental", "PEER", "Canton", "Test Livonia", ["09:00"], "Compact car"],
    ["rental", "PEER", "Plymouth", "Test Livonia", ["10:30"], "Sedan"],
    ["rental", "PEER", "Royal Oak", "Test Troy", ["09:30"], "Compact car"],
    ["rental", "PEER", "Warren", "Test Troy", ["11:00"], "Sedan"],
    ["rental", "PEER", "Ypsilanti", "Test Ann Arbor", ["10:00"], "Compact car"],
    ["rental", "PEER", "Detroit", "Test Southfield", ["09:00"], "Compact car"],
    ["rental", "PEER", "Grand Blanc", "Test Flint", ["10:00"], "Sedan"],
    ["rental", "PEER", "East Lansing", "Test Lansing", ["09:30"], "Compact car"],
    ["rental", "PEER", "Farmington Hills", "Test Novi", ["10:30"], "Compact car"],
    # --- Share a cab: home -> airport ----------------------------------------
    ["cab", "PEER", "Ann Arbor", "DTW", ["05:30", "08:30", "12:00", "15:30", "18:30"], ""],
    ["cab", "PEER", "Novi", "DTW", ["05:45", "09:30", "14:00", "17:30"], ""],
    ["cab", "PEER", "Detroit", "DTW", ["06:00", "10:00", "15:00", "19:00"], ""],
    ["cab", "PEER", "Troy", "DTW", ["05:15", "09:00", "16:00"], ""],
    ["cab", "PEER", "Dearborn", "DTW", ["06:30", "13:30"], ""],
    ["cab", "PEER", "Canton", "DTW", ["06:00", "11:30", "17:00"], ""],
    ["cab", "PEER", "Plymouth", "DTW", ["07:00", "14:30"], ""],
    ["cab", "PEER", "Livonia", "DTW", ["05:30", "12:30"], ""],
    ["cab", "PEER", "Southfield", "DTW", ["06:15", "15:45"], ""],
    ["cab", "PEER", "Royal Oak", "DTW", ["05:45", "13:00"], ""],
    ["cab", "PEER", "Farmington Hills", "DTW", ["07:30", "16:30"], ""],
    ["cab", "PEER", "Ypsilanti", "DTW", ["06:45", "14:00"], ""],
    ["cab", "PEER", "Birmingham", "DTW", ["06:00", "11:00"], ""],
    ["cab", "PEER", "Sterling Heights", "DTW", ["05:00", "12:00"], ""],
    ["cab", "PEER", "Rochester Hills", "DTW", ["05:30", "14:30"], ""],
    ["cab", "PEER", "Auburn Hills", "DTW", ["06:30"], ""],
    ["cab", "PEER", "Warren", "DTW", ["07:00"], ""],
    ["cab", "PEER", "Flint", "FNT", ["06:00", "13:00"], ""],
    ["cab", "PEER", "Grand Blanc", "FNT", ["07:30"], ""],
    ["cab", "PEER", "Lansing", "LAN", ["06:15", "15:00"], ""],
    ["cab", "PEER", "East Lansing", "LAN", ["10:30"], ""],
    # --- Share a cab: airport -> home ----------------------------------------
    ["cab", "PEER", "DTW", "Ann Arbor", ["11:00", "17:00", "21:30"], ""],
    ["cab", "PEER", "DTW", "Novi", ["16:00", "22:00"], ""],
    ["cab", "PEER", "DTW", "Detroit", ["12:30", "20:00"], ""],
    ["cab", "PEER", "DTW", "Troy", ["18:30"], ""],
    ["cab", "PEER", "DTW", "Canton", ["19:00"], ""],
    ["cab", "PEER", "DTW", "Dearborn", ["14:00"], ""],
    ["cab", "PEER", "DTW", "Royal Oak", ["21:00"], ""],
    ["cab", "PEER", "DTW", "Southfield", ["17:30"], ""],
    ["cab", "PEER", "DTW", "Plymouth", ["20:30"], ""],
    ["cab", "PEER", "DTW", "Livonia", ["15:30"], ""],
    ["cab", "PEER", "DTW", "Birmingham", ["19:30"], ""],
    ["cab", "PEER", "FNT", "Flint", ["18:00"], ""],
    ["cab", "PEER", "LAN", "East Lansing", ["20:00"], ""],
    # --- Share a cab: landmark <-> landmark / home ---------------------------
    ["cab", "PEER", "Michigan Stadium", "DTW", ["16:30", "17:15"], ""],
    ["cab", "PEER", "Ford Field", "DTW", ["17:00"], ""],
    ["cab", "PEER", "Comerica Park", "DTW", ["22:15"], ""],
    ["cab", "PEER", "The Henry Ford", "DIA", ["13:00"], ""],
    ["cab", "PEER", "DIA", "Belle Isle", ["15:00"], ""],
    ["cab", "PEER", "Eastern Market", "Comerica Park", ["11:30"], ""],
    ["cab", "PEER", "Somerset", "Little Caesars Arena", ["18:00"], ""],
    ["cab", "PEER", "Twelve Oaks", "Somerset", ["13:30"], ""],
    ["cab", "PEER", "Great Lakes Crossing", "Somerset", ["14:00"], ""],
    ["cab", "PEER", "Detroit Zoo", "DIA", ["14:30"], ""],
    ["cab", "PEER", "Pine Knob", "Somerset", ["23:00"], ""],
    ["cab", "PEER", "Little Caesars Arena", "Royal Oak", ["22:30"], ""],
    ["cab", "PEER", "Little Caesars Arena", "Birmingham", ["22:45"], ""],
    ["cab", "PEER", "Pine Knob", "Royal Oak", ["23:15"], ""],
    ["cab", "PEER", "Royal Oak", "Little Caesars Arena", ["18:30"], ""],
    ["cab", "PEER", "Troy", "Ford Field", ["11:30"], ""],
    ["cab", "PEER", "Ann Arbor", "Michigan Stadium", ["10:30"], ""],
    ["cab", "PEER", "Dearborn", "Comerica Park", ["17:45"], ""],
    ["cab", "PEER", "Novi", "Pine Knob", ["18:00"], ""],
    ["cab", "PEER", "Birmingham", "DIA", ["10:00"], ""],
    ["cab", "PEER", "Southfield", "Ford Field", ["11:00"], ""],
    # --- Share a cab: home -> home -------------------------------------------
    ["cab", "PEER", "Ann Arbor", "Ypsilanti", ["20:00"], ""],
    ["cab", "PEER", "Ypsilanti", "Ann Arbor", ["09:00"], ""],
    ["cab", "PEER", "Royal Oak", "Midtown Detroit", ["19:00"], ""],
    ["cab", "PEER", "Midtown Detroit", "Royal Oak", ["23:30"], ""],
    ["cab", "PEER", "Birmingham", "Troy", ["08:30"], ""],
    ["cab", "PEER", "Dearborn", "Detroit", ["18:00"], ""],
    ["cab", "PEER", "Canton", "Plymouth", ["12:00"], ""],
    ["cab", "PEER", "Farmington Hills", "Novi", ["19:30"], ""],
    ["cab", "PEER", "Sterling Heights", "Warren", ["07:30"], ""],
    ["cab", "PEER", "East Lansing", "Lansing", ["21:00"], ""],
    ["cab", "PEER", "Flint", "Grand Blanc", ["17:30"], ""],
    # --- Added later: always append, so earlier people keep their handles ---
    ["rental", "PEER", "Detroit", "Mackinaw City", ["07:00"], "SUV"],
    ["rental", "PEER", "Detroit", "Grand Rapids", ["09:00"], "Sedan"],
    ["rental", "PEER", "Detroit", "Sleeping Bear", ["06:30"], "SUV"],
    ["rental", "PEER", "Royal Oak", "Traverse City", ["08:30"], "Minivan"],
    ["rental", "PEER", "Ann Arbor", "Mackinaw City", ["07:30"], "SUV"],
    ["rental", "PEER", "Novi", "Traverse City", ["07:30"], "SUV"],
    ["rental", "PEER", "Troy", "Traverse City", ["08:00"], "Sedan"],
    ["rental", "PEER", "Canton", "Holland", ["09:00"], "Compact car"],
    ["rental", "PEER", "Flint", "Mackinaw City", ["08:00"], "SUV"],
    ["rental", "PEER", "Lansing", "Traverse City", ["09:00"], "Sedan"],
    ["rental", "PEER", "Dearborn", "Frankenmuth", ["10:00"], "Compact car"],
    ["rental", "PEER", "Ann Arbor", "Frankenmuth", ["09:30"], "Sedan"]
];

glob WOMEN: list[str] = [
    "Maya", "Aisha", "Emily", "Sofia", "Hannah", "Grace", "Leila", "Olivia", "Chloe", "Fatima",
    "Rachel", "Nina", "Ava", "Zara", "Lauren", "Mei", "Isabel", "Tara", "Jasmine", "Claire",
    "Priyanka", "Megan", "Yasmin", "Brooke", "Elena"
],
     MEN: list[str] = [
    "Omar", "Ethan", "Lucas", "Daniel", "Ravi", "Jamal", "Noah", "Kevin", "Adam", "Carlos",
    "Tyler", "Hassan", "Ben", "Marco", "Victor", "Andre", "Liam", "Jin", "Owen", "Mateo",
    "Arjun", "Caleb", "Tariq", "Nathan", "Diego"
],
     NONBINARY: list[str] = ["Rowan", "Sky", "Jules", "Remy", "Sage", "Ellis", "Robin", "Emerson", "Kit", "Arden"],
     ADJ: list[str] = [
    "Maple", "Cedar", "River", "Harbor", "Pine", "Birch", "Summit", "Meadow", "Copper", "Willow",
    "Aspen", "Prairie", "Lantern", "Beacon", "Cobalt", "Juniper", "Sparrow", "Heron", "Orchard",
    "Ridge", "Sunny", "Tidal", "Amber", "Frost", "Clover", "Harvest", "Marble", "Oak", "Coral", "Dune"
],
     NOUNS: dict[str, list[str]] = {
    "DRIVER": ["Driver", "Wheels", "Cruiser", "Commuter", "Pilot", "Navigator"],
    "RIDER": ["Rider", "Passenger", "Hopper", "Traveler", "Tagalong"],
    "rental": ["Mover", "Roamer", "Voyager", "Packer", "Tripper"],
    "cab": ["Flyer", "Jetsetter", "Runner", "Hailer", "Wanderer"]
},
     NOTES: dict[str, list[str]] = {
    "DRIVER": [
        "Drive this every weekday — happy to pick up on the way.",
        "Quiet ride, podcasts welcome.",
        "Can wait 5–10 minutes if you’re running late.",
        "Coffee stop optional, always on time.",
        "Clean car, no smoking."
    ],
    "RIDER": [
        "Can meet at a park-and-ride or main road.",
        "Happy to chip in for gas every week.",
        "Flexible by 15 minutes either way.",
        "Just need a lift most weekdays.",
        "Light bag, quick pickup."
    ],
    "move": [
        "Mostly boxes plus a couch — two sets of hands help.",
        "Splitting the truck and the gas, I can help you load too.",
        "Studio move, done in a morning.",
        "Have dollies and straps already."
    ],
    "trip": [
        "Weekend trip, happy to split driving and gas.",
        "Leaving early to beat traffic.",
        "Two-day trip, flexible on stops.",
        "Easygoing, good playlist guaranteed."
    ],
    "test": [
        "Road test that morning — need a car and a licensed driver.",
        "Booked a road test, splitting the rental for the day.",
        "Practice drive first, then the test."
    ],
    "cab": [
        "One suitcase, happy to split the fare.",
        "Carry-on only, quick pickup.",
        "Early flight — I’ll book the cab.",
        "Split evenly, I’ll pay by app.",
        "Heading there after work."
    ]
};

def _gender_of(k: int) -> str {
    slot = k % 9;
    if slot == 8 {
        return "non-binary";
    }
    return "woman" if slot % 2 == 0 else "man";
}

def _first_name(k: int, gender: str) -> str {
    if gender == "woman" {
        return WOMEN[(k * 7) % len(WOMEN)];
    }
    if gender == "man" {
        return MEN[(k * 11) % len(MEN)];
    }
    return NONBINARY[(k * 3) % len(NONBINARY)];
}

def _age_for(k: int, dest: str, origin: str) -> int {
    students = ["MSU", "UM Campus", "EMU", "Wayne State", "Oakland U"];
    if dest in students or origin in students {
        return 19 + (k % 6);
    }
    if dest.startswith("Test ") {
        return 18 + (k % 6);
    }
    return 21 + ((k * 17) % 46);
}

# Every sample person, in the same shape as the hand-written demo people.
# `taken` holds handles already in use elsewhere, so none are reused.
def demo_network(taken: list[str] = []) -> list[dict] {
    people: list[dict] = [];
    used: set[str] = set(taken);
    k = 0;
    for r in ROUTES {
        mode = r[0] as str;
        role = r[1] as str;
        origin = r[2] as str;
        dest = r[3] as str;
        extra = r[5] as str;
        for dep in (r[4] as list[str]) {
            gender = _gender_of(k);
            noun_key = role if mode == "ride" else mode;
            nouns = NOUNS[noun_key];
            handle = ADJ[k % len(ADJ)] + nouns[(k // len(ADJ) + k) % len(nouns)];
            bump = 10 + k % 89;
            base = handle;
            while handle in used {
                handle = base + str(bump);
                bump += 1;
            }
            used.add(handle);
            vehicle = "";
            moving = False;
            if mode == "rental" {
                parts = extra.split("|");
                vehicle = parts[0];
                moving = len(parts) > 1 and parts[1] == "move";
            }
            note_key = role if mode == "ride" else mode;
            if mode == "rental" {
                note_key = "move" if moving else ("test" if dest.startswith("Test ") else "trip");
            }
            notes = NOTES[note_key];
            is_new = k % 6 == 0;
            a = PLACES[origin];
            b = PLACES[dest];
            person: dict = {
                "handle": handle, "name": _first_name(k, gender), "gender": gender,
                "age": _age_for(k, dest, origin), "role": role, "mode": mode,
                "from": a[0], "from_lat": a[1], "from_lng": a[2],
                "to": b[0], "to_lat": b[1], "to_lng": b[2],
                "dep": dep, "arr": "",
                "seats": (1 + k % 3) if role == "DRIVER" else 0,
                "people": (2 if k % 4 == 0 else 1) if mode != "ride" else 1,
                "rating": 0.0 if is_new else 4.3 + ((k * 3) % 7) / 10.0,
                "reviews": 0 if is_new else 3 + (k * 7) % 45,
                "note": notes[k % len(notes)], "vehicle": vehicle, "moving": moving,
                "recurring": mode == "ride", "gender_prefs": [], "age_min": 1, "age_max": 100
            };
            # A few people set their own preferences, so filters work both ways.
            if gender == "woman" and k % 10 == 4 {
                person["gender_prefs"] = ["woman", "non-binary"];
            }
            if k % 12 == 7 {
                person["age_min"] = 21;
                person["age_max"] = 65;
            }
            people.append(person);
            k += 1;
        }
    }
    return people;
}
