# app/integrations/ai.py
from functools import lru_cache
from typing import Any

from anthropic import Anthropic
from openai import OpenAI

from app.core.config import get_settings

_settings = get_settings()

_SAFETY_SYSTEM_PREFIX: str = (
    "You are the AI layer embedded inside VIVRE, a personal operating system. "
    "You must never provide medical advice, diagnoses, risk assessments, or clinical "
    "interpretations of health data. Any health-related information you receive is "
    "contextual only. If asked for medical guidance, decline and suggest consulting "
    "a qualified professional."
)


@lru_cache
def _get_openai_client() -> OpenAI:
    return OpenAI(api_key=_settings.AI_PROVIDER_API_KEY)


@lru_cache
def _get_anthropic_client() -> Anthropic:
    return Anthropic(api_key=_settings.AI_PROVIDER_API_KEY)


def generate_chat_completion(
    messages: list[dict[str, str]], system_prompt_suffix: str | None = None
) -> str:
    system_prompt = (
        _SAFETY_SYSTEM_PREFIX
        if not system_prompt_suffix
        else f"{_SAFETY_SYSTEM_PREFIX}\n\n{system_prompt_suffix}"
    )
    if _settings.AI_PROVIDER == "anthropic":
        anthropic_client = _get_anthropic_client()
        anthropic_messages = [
            {"role": message["role"], "content": message["content"]} for message in messages
        ]
        anthropic_response: Any = anthropic_client.messages.create(
            model=_settings.AI_MODEL_NAME,
            system=system_prompt,
            max_tokens=1024,
            messages=anthropic_messages,
        )
        return str(anthropic_response.content[0].text)
    openai_client = _get_openai_client()
    openai_messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}, *messages]
    completion: Any = openai_client.chat.completions.create(
        model=_settings.AI_MODEL_NAME, messages=openai_messages
    )
    return str(completion.choices[0].message.content)