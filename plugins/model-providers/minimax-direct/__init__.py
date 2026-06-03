"""MiniMax Direct provider profile.

OpenAI-compatible /v1 endpoint. This is intentionally separate from the
bundled minimax profile, which targets MiniMax's Anthropic-compatible endpoint.
"""

from providers import register_provider
from providers.base import ProviderProfile


register_provider(ProviderProfile(
    name="minimax-direct",
    aliases=("minimax-openai", "minimax-v1"),
    display_name="MiniMax Direct",
    description="MiniMax OpenAI-compatible /v1 endpoint",
    signup_url="https://api.minimax.io/",
    env_vars=("MINIMAX_API_KEY", "MINIMAX_BASE_URL"),
    base_url="https://api.minimax.io/v1",
    auth_type="api_key",
    api_mode="chat_completions",
    default_aux_model="MiniMax-M3",
    fallback_models=("MiniMax-M3",),
))
