"""LLM narration for match explanations. Imported lazily by explain_match only
when OPENAI_API_KEY is set, because loading byllm/litellm costs ~150 MB of
RAM — too much for small hosts that never use it. The LLM only narrates
numbers the deterministic scorer already produced; it never invents them."""

import from byllm.lib { Model }

glob explain_llm: Model = Model(model_name="gpt-4o-mini");

def narrate_match(
    route_score: int, time_score: int, detour_minutes: int, preference_score: int,
    cost_benefit_score: int, overall_score: int, rider_handle: str, driver_handle: str,
    estimated_weekly_savings: float
) -> str by explain_llm();
sem narrate_match = "Write ONE short, warm, human-friendly paragraph (2-3 sentences) explaining why these two anonymous commuters are a good rideshare match. Use ONLY the numbers given — never invent a route detail, address, or statistic not passed in. Refer to them only by their anonymous handles, never assume real names.";
sem narrate_match.route_score = "Percent overlap between the two commute routes (0-100).";
sem narrate_match.time_score = "Schedule compatibility score (0-100).";
sem narrate_match.detour_minutes = "Extra minutes the driver detours to pick up the rider.";
sem narrate_match.preference_score = "Ride preference compatibility score (0-100).";
sem narrate_match.cost_benefit_score = "Cost-benefit score (0-100).";
sem narrate_match.overall_score = "Final weighted match score (0-100).";
sem narrate_match.rider_handle = "The rider's anonymous handle.";
sem narrate_match.driver_handle = "The driver's anonymous handle.";
sem narrate_match.estimated_weekly_savings = "Estimated weekly savings for the rider in US dollars, already computed.";
