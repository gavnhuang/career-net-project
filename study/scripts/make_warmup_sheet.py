#!/usr/bin/env python3
"""Build the warm-up scoring sheet (D116).

Run from the `04 R Project` folder AFTER generating the 3 AI warm-up answers:
    Rscript study/scripts/07_generate_answers.R --set warmups
    python3 study/scripts/make_warmup_sheet.py

Writes:
  07 Study Materials/02 Training/Warm-ups/Warm-up Scoring Sheet.xlsx   (blind: no source shown)
  study/data/05_assignments/warmup_items_key.csv                        (unblinding key, never shared)
Items are shuffled once with seed 20261107 (fixed before scoring); items 1-3 are the pilot training's practice items.
Human answers get the same typography normalization as the pilot (D102).
"""
import csv, glob, os, random, re, sys
import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

csv.field_size_limit(10**9)
ROOT = os.getcwd()
STUDY = os.path.join(ROOT, "study")
if not os.path.isdir(STUDY):
    sys.exit("Run this from the '04 R Project' folder.")
OUT_DIR = os.path.normpath(os.path.join(ROOT, "..", "07 Study Materials", "02 Training", "Warm-ups"))

def norm(x):
    x = re.sub("[‘’]", "'", x)
    x = re.sub("[“”]", '"', x)
    x = re.sub("[–—]", " - ", x)
    return re.sub(" {2,}", " ", x).strip()

def question_cell(title, body):
    # Title + blank line + body, as in the pilot sheet. An empty body shows the title alone;
    # a body that already starts with the title is shown alone so the title isn't repeated.
    t, b = norm(title or ""), norm(body or "")
    if not b or b.lower().startswith(t.lower()):
        return b or t
    return t + "\n\n" + b if t else b

qs = list(csv.DictReader(open(os.path.join(STUDY, "data/02_reserved/warmups.csv"), encoding="utf-8")))
qs.sort(key=lambda r: int(r["draw_order"]))
random.Random(20261107).shuffle(qs)  # fixed order, set before anyone scores (D116)
runs = sorted(glob.glob(os.path.join(STUDY, "data/04_generated/warmups/answers_*.csv")))
if not runs:
    sys.exit("No AI warm-up answers yet. First run: Rscript study/scripts/07_generate_answers.R --set warmups")
run_file = runs[-1]
run_id = re.search(r"answers_(.+)\.csv", os.path.basename(run_file)).group(1)
ai = {r["question_id"]: r for r in csv.DictReader(open(run_file, encoding="utf-8"))}

items, key = [], []
for i, q in enumerate(qs, 1):
    if q["planned_version"] == "ai":
        a = ai.get(q["question_id"])
        if a is None or a["status"] not in ("accepted", "closest_length"):
            sys.exit(f"AI answer missing or failed for question {q['question_id']} in {run_file}")
        ans, words, aid, st = a["response_text"], a["word_count"], "", a["status"]
    else:
        ans, words, aid, st = norm(q["answer_text_display"]), q["answer_word_count"], q["answer_id"], ""
    items.append((i, question_cell(q["question_title"], q["question_text_display"]), ans))
    key.append({"item": i, "question_id": q["question_id"], "draw_order": q["draw_order"], "order_seed": 20261107,
                "version": q["planned_version"], "answer_id": aid,
                "ai_run": run_id if q["planned_version"] == "ai" else "", "ai_status": st, "answer_words": words})

os.makedirs(OUT_DIR, exist_ok=True)
wb = openpyxl.Workbook()
rm = wb.active; rm.title = "Read me"
for line in ["Warm-up scoring sheet: 6 training examples", "",
             "Each row is one career question and one answer. Score all five dimensions with the rubric and write a one-line reason for each score.",
             "Scores are 1 to 4. Correctness can also be UJ (unable to judge). The reasons become the explanations shown in training, so keep them plain.",
             "The source of each answer (human or AI) is not shown.",
             "Items 1-3 are the practice items in the pilot training; all 6 are used in the advisor training.", "",
             f"Built from warmups.csv and AI run {run_id}. Item order shuffled with seed 20261107."]:
    rm.append([line])
rm.column_dimensions["A"].width = 120
ws = wb.create_sheet("Score")
dims = ["Completeness", "Correctness", "Coherency", "Actionability", "Supportiveness"]
head = ["Item", "Question", "Answer"] + dims + [d + " reason" for d in dims] + ["Notes"]
ws.append(head)
for it in items:
    ws.append(list(it) + [None] * 11)
widths = {"A": 6, "B": 45, "C": 70}
for col, w in widths.items(): ws.column_dimensions[col].width = w
for c in range(4, 9): ws.column_dimensions[openpyxl.utils.get_column_letter(c)].width = 13
for c in range(9, 15): ws.column_dimensions[openpyxl.utils.get_column_letter(c)].width = 32
for cell in ws[1]:
    cell.font = Font(bold=True); cell.fill = PatternFill("solid", fgColor="EEEEEE")
for row in ws.iter_rows(min_row=2):
    for cell in row: cell.alignment = Alignment(wrap_text=True, vertical="top")
n = len(items) + 1
dv = DataValidation(type="list", formula1='"1,2,3,4"', allow_blank=True, showErrorMessage=True, errorTitle="Score", error="Enter 1, 2, 3 or 4.")
dv.add(f"D2:D{n}"); dv.add(f"F2:H{n}")
dv2 = DataValidation(type="list", formula1='"1,2,3,4,UJ"', allow_blank=True, showErrorMessage=True, errorTitle="Score", error="Enter 1, 2, 3, 4 or UJ.")
dv2.add(f"E2:E{n}")
ws.add_data_validation(dv); ws.add_data_validation(dv2)
ws.freeze_panes = "D2"
xlsx = os.path.join(OUT_DIR, "Warm-up Scoring Sheet.xlsx")
wb.save(xlsx)
kp = os.path.join(STUDY, "data/05_assignments/warmup_items_key.csv")
with open(kp, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(key[0].keys())); w.writeheader(); w.writerows(key)
print("Wrote", xlsx); print("Wrote", kp, "(key: never share)")
