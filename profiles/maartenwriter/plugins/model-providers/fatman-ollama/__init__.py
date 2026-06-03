"""Fatman Ollama provider profile.

Ollama/OpenAI-compatible endpoint on fatman:11434. Mirrors the built-in custom
provider's Ollama-specific request behavior while giving this endpoint a stable
first-class provider id.
"""

from typing import Any, Optional

from providers import register_provider
from providers.base import ProviderProfile


class FatmanOllamaProfile(ProviderProfile):
    """Fatman Ollama endpoint — preserve custom/Ollama extras."""

    def build_api_kwargs_extras(
        self,
        *,
        reasoning_config: Optional[dict] = None,
        ollama_num_ctx: Optional[int] = None,
        **ctx: Any,
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        extra_body: dict[str, Any] = {}

        if ollama_num_ctx:
            options = extra_body.get("options", {})
            options["num_ctx"] = ollama_num_ctx
            extra_body["options"] = options

        if reasoning_config and isinstance(reasoning_config, dict):
            effort = (reasoning_config.get("effort") or "").strip().lower()
            enabled = reasoning_config.get("enabled", True)
            if effort == "none" or enabled is False:
                extra_body["think"] = False

        return extra_body, {}


register_provider(FatmanOllamaProfile(
    name="fatman-ollama",
    aliases=("fatman", "fatman:11434"),
    display_name="Fatman Ollama",
    description="Ollama/OpenAI-compatible endpoint on fatman:11434",
    env_vars=("FATMAN_OLLAMA_API_KEY", "FATMAN_OLLAMA_BASE_URL"),
    base_url="http://fatman:11434/v1",
    auth_type="api_key",
    api_mode="chat_completions",
    default_aux_model="qwen3.6:35b-a3b-mlx-bf16",
    fallback_models=("qwen3.6:35b-a3b-mlx-bf16",),
))
