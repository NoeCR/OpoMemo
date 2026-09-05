"""Convierte tests de OpoTest-content.json en mazos de tarjetas por ley y título."""

from __future__ import annotations

import html
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"C:\Users\noecr\OneDrive\Escritorio\Repositories\Flutter\OpoTest\releases\OpoTest-content.json")
OUT = ROOT / "assets" / "seed" / "opotest_decks.json"

LAWS = {
    "5": {"short": "CE", "group": "Constitución Española", "domain": "leyes"},
    "1": {"short": "LPACAP", "group": "Ley 39/2015 · Procedimiento", "domain": "leyes"},
    "10": {"short": "LRJSP", "group": "Ley 40/2015 · Sector público", "domain": "leyes"},
    "4": {"short": "TREBEP", "group": "TREBEP", "domain": "leyes"},
}

MAX_FACTS = 36
MAX_PROMPT = 280
MAX_ANSWER = 220
BAD_ANSWER = (
    "todas las anteriores",
    "ninguna de las anteriores",
    "a y b son correctas",
    "a y c son correctas",
    "b y c son correctas",
)

TAG_RE = re.compile(r"<[^>]+>")
SPACE_RE = re.compile(r"\s+")


def pretty_code(code: str) -> str:
    return (
        code.replace("TÍTULO", "Título")
        .replace("DISPOSICIONES", "Disposiciones")
        .replace("ESTRUCTURA Y PREÁMBULO", "Estructura y preámbulo")
    )


def clean(text: str) -> str:
    text = TAG_RE.sub(" ", text or "")
    text = html.unescape(text)
    return SPACE_RE.sub(" ", text).replace("\r", " ").strip()


def question_items(payload: dict) -> list[dict]:
    test = payload.get("test") or {}
    raw = test.get("q")
    if not isinstance(raw, list) or len(raw) < 2:
        return []
    items = raw[1]
    if not isinstance(items, list):
        return []
    return [item for item in items if isinstance(item, dict)]


def fact_from_item(item: dict, source: str) -> dict | None:
    q = item.get("q") or {}
    prompt = clean(str(q.get("text_es") or ""))
    if not prompt or len(prompt) > MAX_PROMPT:
        return None
    try:
        solution = int(str(q.get("solution") or "0"))
    except ValueError:
        return None
    if solution < 1 or solution > 4:
        return None
    answer = clean(str(q.get(f"answer{solution}_es") or ""))
    if not answer or len(answer) > MAX_ANSWER:
        return None
    lowered = answer.lower()
    if any(bad in lowered for bad in BAD_ANSWER):
        return None
    qid = str(q.get("id") or item.get("id") or "")
    if not qid:
        return None
    return {
        "id": f"opotest.q.{qid}",
        "prompt": prompt,
        "answer": answer,
        "source": source,
    }


def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    titles = {
        str(row["id"]): row
        for row in data.get("titles") or []
        if str(row.get("law_id")) in LAWS
    }
    buckets: dict[tuple[str, str], list[dict]] = defaultdict(list)
    seen_prompts: dict[tuple[str, str], set[str]] = defaultdict(set)

    for test in data.get("tests") or []:
        law_id = str(test.get("law_id") or "")
        title_id = str(test.get("title_id") or "")
        if law_id not in LAWS or title_id in {"", "0", "None"}:
            continue
        meta = LAWS[law_id]
        payload = test.get("payload") or {}
        source = f"{meta['short']}"
        title = titles.get(title_id) or {}
        code = str(title.get("code") or "")
        if code:
            source = f"{meta['short']} · {code}"
        key = (law_id, title_id)
        for item in question_items(payload):
            fact = fact_from_item(item, source)
            if fact is None:
                continue
            prompt_key = fact["prompt"].casefold()
            if prompt_key in seen_prompts[key]:
                continue
            seen_prompts[key].add(prompt_key)
            buckets[key].append(fact)

    decks = []
    for (law_id, title_id), facts in buckets.items():
        title = titles.get(title_id) or {}
        meta = LAWS[law_id]
        raw_name = clean(str(title.get("name") or ""))
        code = pretty_code(clean(str(title.get("code") or "")))
        display = raw_name or code or f"Título {title_id}"
        facts.sort(key=lambda f: (len(f["answer"]), len(f["prompt"])))
        chosen = facts[:MAX_FACTS]
        if len(chosen) < 8:
            continue
        decks.append(
            {
                "id": f"opotest.{law_id}.{title_id}",
                "name": display,
                "description": "" if display == code else code,
                "group": meta["group"],
                "domain": meta["domain"],
                "facts": chosen,
            }
        )

    order = {law_id: index for index, law_id in enumerate(LAWS)}
    decks.sort(key=lambda d: (order.get(d["id"].split(".")[1], 99), d["name"]))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"decks": decks}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{len(decks)} mazos, {sum(len(d['facts']) for d in decks)} cartas -> {OUT}")
    for deck in decks:
        print(f"  {deck['group']} · {deck['name']}: {len(deck['facts'])}")


if __name__ == "__main__":
    main()
