# Anchor check

Testing the actionability and supportiveness anchors before the instrument is built.
Method and reasoning are in the vault: `02 Design/Protocol.md`, under the rating instrument.

## Why

Neither dimension has ever been rated by anyone. Three things are unknown and all three
are cheap to find out now and expensive to find out during norming:

1. Whether the anchors can be applied consistently at all
2. Whether actionability separates from completeness, or just tracks it
3. **Which direction the supportiveness difference runs.** The study predicts human
   answers higher. That prediction may be wrong — models acknowledge stated emotional
   content almost reflexively, and volunteer forum answers are frequently terse and do
   no self-efficacy work at all

## Files

| File | What it is |
|---|---|
| `anchor_check_items.csv` | 36 question and human answer pairs, blank rating columns. **Rate here** |
| `anchor_check_items.md` | the same 36, formatted to read comfortably |
| `anchor_check_key.csv` | CareerNet's own ratings, goal labels, scenario, question ids. **Do not open until rating is finished** |
| `build_anchor_check.py` | regenerates the set, seed 20260919 |
| `generate_ai_answers.py` | ten LLM answers under the study's prompt and length matching |

The 36 span goal type (validation, instrumental, other) crossed with CareerNet's
completeness rating (low, mid, high), four per cell, shuffled so the strata are not
visible while rating. Drawn from the eligible pool: 2021 or later, answers 40 to 600
words, questions 10 or more words, `unclear_goal` null. One answer per question, drawn
at random (D35).

## Order of work

1. Rate all 36 on actionability and supportiveness, four-point anchors (D37), without
   looking at the key. Note every case where an anchor felt ambiguous — those notes are
   the real output, more than the numbers
2. Generate the ten LLM answers, rate those the same way
3. Only then open the key

## Reading the result

**Anchors are usable** if the ambiguous cases cluster on one boundary rather than
scattering. A single problem boundary is fixable with a worked example. Scattered
ambiguity means the construct is not anchored yet.

**Actionability is distinct** if its correlation with CareerNet's completeness ratings
is visibly lower than completeness's correlation with itself would be. If actionability
tracks completeness closely across all 36, it is measuring the same thing and the
dimension contrast loses its meaning.

**Direction.** Compare the ten LLM answers against their human pairs. If the model is
ahead on supportiveness, H3 is wrong and the two-sided primary (D38) is what saves the
thesis. Better to know now.

Ten items decides nothing on its own. It is a directional read and a check on whether
the instrument is ready, not a result.

## Afterwards

Every question id used here is in `anchor_check_key.csv`. **Exclude them from the study
sampling frame**, along with the norming and pilot pool, before the sampling script runs.
