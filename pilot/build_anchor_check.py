"""
Anchor check: build a blind reading set for testing the actionability and
supportiveness anchors before the instrument is built.

Outputs
  anchor_check_items.csv   36 question/answer pairs, blank rating columns. Rate these.
  anchor_check_key.csv     the CareerNet ratings, goal labels and scenario for each.
                           DO NOT OPEN until rating is finished.
  anchor_check_items.md    the same 36 items, formatted to read.

The sample deliberately spans human answer quality and goal type so the anchors
are tested against the range they will meet in the study, not a convenient slice.
"""
import csv, re, random, io, os

csv.field_size_limit(10**7)
SRC = "../../Career Net Data/Datasets/general_public.csv"
SEED = 20260919
N_PER_CELL = 4

def words(s): return len(s.split())
def year(s):
    m = re.search(r"\b(19|20)\d{2}\b", s or "")
    return int(m.group(0)) if m else 0
def score(s):
    m = re.match(r"\s*(\d)", s or "")
    return int(m.group(1)) if m else None
def na(v): return (v or "").strip().upper() in ("", "NA", "NULL", "NONE")

rows = []
with io.open(SRC, encoding="utf-8", newline="") as f:
    for r in csv.DictReader(f):
        if year(r["answer_added_at"]) < 2021:          continue
        if not na(r["unclear_goal"]):                  continue
        aw = words(r["answer_body"])
        if aw < 40 or aw > 600:                        continue
        if words(r["question_body"]) < 10:             continue
        comp = score(r["completeness"])
        if comp is None:                               continue
        rows.append(r)

print(f"eligible answers: {len(rows)}")

# one answer per question, chosen at random (D35)
rng = random.Random(SEED)
byq = {}
for r in rows: byq.setdefault(r["question_id"], []).append(r)
pool = [rng.choice(v) for v in byq.values()]
print(f"eligible questions: {len(pool)}")

def goal(r):
    if not na(r["validation_support"]): return "validation"
    if not na(r["take_action"]):        return "instrumental"
    return "other"
def band(r):
    c = score(r["completeness"])
    return "low" if c <= 2 else ("mid" if c == 3 else "high")

cells = {}
for r in pool: cells.setdefault((goal(r), band(r)), []).append(r)

picked, shortfall = [], []
for g in ("validation", "instrumental", "other"):
    for b in ("low", "mid", "high"):
        c = cells.get((g, b), [])
        rng.shuffle(c)
        take = c[:N_PER_CELL]
        picked += take
        if len(take) < N_PER_CELL:
            shortfall.append(f"{g}/{b}: {len(take)} of {N_PER_CELL}")
        print(f"  {g:13s} {b:4s} pool {len(c):4d} -> took {len(take)}")
if shortfall: print("SHORTFALL:", "; ".join(shortfall))

rng.shuffle(picked)   # so the strata are not visible while rating

RATING_COLS = ["actionability", "supportiveness", "notes_on_the_anchors"]
with io.open("anchor_check_items.csv", "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["item", "question_title", "question_body", "answer_body"] + RATING_COLS)
    for i, r in enumerate(picked, 1):
        w.writerow([i, r["question_title"], r["question_body"], r["answer_body"], "", "", ""])

with io.open("anchor_check_key.csv", "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["item", "question_id", "answer_id", "goal_cell", "quality_band",
                "careernet_completeness", "careernet_correctness", "careernet_coherency",
                "scenario_labels", "answer_words"])
    for i, r in enumerate(picked, 1):
        w.writerow([i, r["question_id"], r["answer_id"], goal(r), band(r),
                    r["completeness"], r["correctness"], r["coherency"],
                    r["ScenarioLabels"], words(r["answer_body"])])

with io.open("anchor_check_items.md", "w", encoding="utf-8") as f:
    f.write("# Anchor check — reading set\n\n")
    f.write("36 real question and human answer pairs, drawn to span goal type and human answer quality.\n")
    f.write("Rate each on actionability and supportiveness using the draft 4-point anchors, in\n")
    f.write("`anchor_check_items.csv`. Do not open `anchor_check_key.csv` until finished.\n\n---\n\n")
    for i, r in enumerate(picked, 1):
        f.write(f"## {i}\n\n**{r['question_title'].strip()}**\n\n")
        f.write(r["question_body"].strip() + "\n\n**Answer**\n\n")
        f.write(r["answer_body"].strip() + "\n\n---\n\n")

print("\nwrote anchor_check_items.csv, anchor_check_key.csv, anchor_check_items.md")
