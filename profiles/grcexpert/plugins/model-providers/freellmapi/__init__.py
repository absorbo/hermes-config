"""FreeLLM API provider profile.

Local OpenAI-compatible FreeLLM API gateway.
"""

from providers import register_provider
from providers.base import ProviderProfile


register_provider(ProviderProfile(
    name="freellmapi",
    aliases=("free-llm-api", "local-freellmapi"),
    display_name="FreeLLM API",
    description="Local OpenAI-compatible FreeLLM API gateway",
    env_vars=("FREELLMAPI_API_KEY", "FREELLMAPI_BASE_URL"),
    base_url="http://localhost:3001/v1",
    auth_type="api_key",
    api_mode="chat_completions",
    default_aux_model="auto",
    fallback_models=("auto",),
))
