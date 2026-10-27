"""
Generate LLM answers for ten of the anchor-check items, under the study's
generation protocol, so the draft anchors can be tested against both sources.

Not the study's generation run. Same prompt, same length matching, same format
suppression, so the comparison is meaningful, but these items are a reading set
and must be excluded from the study sample later (ids are in anchor_check_key.csv).

Needs an API key in the environment. If that is not available, the manual
fallback at the bottom of this file works just as well for ten items.
"""
import csv, io, os, re, json, random

MODEL = os.environ.get("ANCHOR_CHECK_MODEL", "")   # set to the flagship you plan to use
N = 10
SEED = 20260919

PROMPT = (
    "You are answering a question posted by a student on a public career advice forum. "
    "Volunteers with professional experience answer these questions. Write one answer, "
    "in continuous prose. Do not use headings, bullet points, numbered lists, bold text, "
    "or a sign-off. Aim for approximately {N} words."
)

LIST_MARKERS = re.compile(r"(^\s*[-*•]\s|^\s*\d+[.)]\s|^#{1,6}\s|\*\*)", re.M)

def words(s): return len(s.split())

items = list(csv.DictReader(io.open("anchor_check_items.csv", encoding="utf-8")))
rng = random.Random(SEED)
picked = rng.sample(items, N)

def generate(question_title, question_body, target_words):
    """Replace the body of this function with a call to whichever API you use.
    It must return a single string. Everything around it — the prompt, the
    length target, the format check, the retry — is the study protocol and
    should not change."""
    raise NotImplementedError(
        "Wire this to an API, or use the manual fallback described at the bottom of this file."
    )

out = []
for it in picked:
    target = words(it["answer_body"])
    text, tries = None, 0
    while tries < 3:
        tries += 1
        cand = generate(it["question_title"], it["question_body"], target)
        if LIST_MARKERS.search(cand):            # format suppression (D10)
            continue
        if not (0.8 * target <= words(cand) <= 1.2 * target):   # length match (D10)
            continue
        text = cand
        break
    out.append({
        "item": it["item"], "source": "llm", "response_text": text or "",
        "word_count": words(text or ""), "target_words": target,
        "model": MODEL, "regenerations": tries - 1,
    })

with io.open("anchor_check_ai_answers.csv", "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys()))
    w.writeheader(); w.writerows(out)
io.open("anchor_check_ai_raw.json", "w", encoding="utf-8").write(json.dumps(out, indent=2))
print(f"wrote {len(out)} LLM answers for items " + ", ".join(o["item"] for o in out))

# ---------------------------------------------------------------------------
# MANUAL FALLBACK, which is fine for ten items and costs nothing
#
# 1. Run this file with the generate() body left as-is; it will fail, but the
#    ten selected item numbers print in the traceback. Or read them from the
#    seed, which is fixed.
# 2. For each, open a fresh chat — no memory, no prior turns, so nothing carries
#    over between items — and paste the prompt above with {N} replaced by that
#    item's human answer word count, then the question title and body.
# 3. Paste the reply into anchor_check_ai_answers.csv. Reject and redo anything
#    containing a list, heading or bold text, or falling outside 20% of the
#    target length. Note how many retries each needed; the retry rate is itself
#    worth knowing before the real generation run.
# ---------------------------------------------------------------------------
