---
name: five-whys
description: 'Run an evidence-grounded five-whys RCA: claims verified by fact-checker subagents, causal links stress-tested by a cynic subagent. For internal RCAs, post-mortems, "why did this happen". Not for customer-facing incident write-ups.'
---

# Five whys — grounded and adversarially verified

Build a causal chain from impact to actionable root cause using the classic
five-whys technique (https://en.wikipedia.org/wiki/Five_whys), with two
additions the classic method lacks: every fact is verified against a primary
source, and the finished chain must survive an adversarial review before it
ships. The output is only done when a skeptical expert reading it can re-derive
every claim from the cited evidence.

## Ground rules (non-negotiable)

1. **Every factual claim cites a primary source.** A metric query you ran, a
   code line (`file:line`), a log entry, a config value read from the live
   system, a timestamped event. "The incident doc says" and "everyone knows"
   are not sources. Keep the query, link, or path next to the claim so a
   reader can re-run it.
2. **Label every claim's epistemic status.**
   - **Measured** — you or a subagent observed it directly during this
     investigation.
   - **Derived** — arithmetic on measured values; show the arithmetic.
   - **Inferred** — a best-fit mechanism not yet directly observed. An
     inferred claim MUST name the observation that would confirm or refute it
     ("inference, pending X"). Never present an inference as fact.
3. **Re-verify inherited numbers.** Figures from earlier write-ups, tickets,
   dashboards, or drafts get re-measured, not copied. Stale blast-radius
   numbers and wrong mechanisms survive in RCA docs precisely because nobody
   re-checks them.
4. **Verify mechanisms at the source.** A plausible mechanism is not a
   verified one. Read the actual code path, config, or vendor source before
   asserting "X does Y". The most dangerous RCA errors are confident,
   plausible, wrong mechanism claims.
5. **Normalize timestamps to UTC before any elapsed-time math.** Mixed-timezone
   subtraction silently corrupts the timeline and every claim built on it.
6. **Honour stated constraints.** If an owner has declared a constraint (for
   example "this setting is customer-facing and stays where it is"), a fix
   that violates it can appear only as a labelled break-glass mitigation,
   never as the standing recommendation.
7. **Claims about people and ownership need the same evidence as claims about
   systems.** Never assert "no owner" or "team X ignored Y" without proof.
   Prefer testable framings: "no standing signal prompted review" can be
   checked; "nobody cared" cannot.

## Process

### 1. Frame the impact

One short paragraph: who was affected, when (UTC), how badly, measured how.
Precise numbers, with floors and ceilings stated as such ("at least 1,200
accounts" if the count is a floor). This is "why zero" — every subsequent
why must chain back up to it.

### 2. Gather evidence, then draft the chain

Collect the timeline, metrics, code paths, and configs FIRST. Draft the chain
from the evidence, not from the incident channel's first theory. For each why:

- **One causal step per why.** If the answer needs "and also", either split
  into two whys or branch explicitly ("two loads coincided: a standing load
  and an acute trigger") and carry both branches down the chain.
- **Test each link four ways:**
  - **Timing** — cause precedes effect on a UTC-normalized timeline.
  - **Mechanism** — a named, source-verified path from cause to effect.
  - **Magnitude** — the numbers are large enough to explain the effect.
  - **Necessity** — hunt for a control or counterfactual: an occasion when
    the trigger fired WITHOUT the cause and the effect did not follow. A good
    control is the single strongest piece of evidence a chain can carry.
- A link that fails any test is not ready for verification — fix it or label
  the gap as an open inference.

### 3. Fact-check every claim (subagents, in parallel)

Dispatch one fact-checker subagent per why via the `Agent` tool, all in a
single message so they run concurrently. Default `model: "sonnet"`.

The numbered whys are not the whole document. Dispatch a checker for every
other section that carries factual claims too — the impact frame (blast
radius, timing, how it was measured), the root causes, and each open
inference. These are exactly the claims that get quoted onward, so an
uncovered one defeats the promise that every fact in the chain was verified.
One checker per section is enough; batch them into the same message as the
per-why checkers.

Each dispatch prompt contains:

- The why's full text (question + answer + cited evidence).
- Where the evidence lives and how to reach it: repo paths, query URLs, log
  locations. If reaching the evidence depends on a skill (for example one that
  wraps your metrics, tracing, or error-tracking tools), the dispatch prompt
  must tell the checker to invoke that skill FIRST — the parent's skill load
  does not carry into a subagent.
- This instruction, verbatim:

> Independently verify every factual claim in the text below. For each claim
> return a verdict: CONFIRMED (you reproduced it from a primary source — name
> the source), UNSUPPORTED (you could not find evidence either way), or
> CONTRADICTED (the source says otherwise — quote it). Do not assess whether
> the causal story is convincing; check only whether the stated facts are
> true. Re-run queries rather than trusting quoted numbers. Return a compact
> claim-by-claim table, nothing else.

### 4. Cynic pass (subagent)

After the fact-checks come back clean, dispatch one cynic subagent with the
FULL chain (it needs cross-link context). Default `model: "sonnet"`. This is
the hardest reasoning stage, so a stronger model is tempting — escalate only
if the user asks for it.
Its prompt, verbatim:

> You are a skeptical senior engineer reviewing this root cause analysis.
> Your job is to break it, not to improve it. For every causal link ("why N →
> why N+1"): propose at least one alternative explanation consistent with the
> same evidence; check whether the link shows correlation or causation; look
> for a missing control (did the trigger ever fire without the claimed cause?);
> check the magnitude actually explains the effect; and identify the single
> weakest link in the whole chain. Verdict per link: HOLDS (you tried and
> failed to break it — say what you tried), SHAKY (survives but on thin
> evidence — say what evidence would firm it up), or BROKEN (an alternative
> explanation fits as well or better — state it). When uncertain, rule
> against the chain.

### 5. Iterate until clean

- **CONTRADICTED claim** → correct it, re-dispatch that why's fact-checker.
- **UNSUPPORTED claim** → find a source, downgrade it to a labelled inference
  with its pending verification, or cut it.
- **BROKEN link** → rework the chain from that level down, then re-run both
  the affected fact-checks and the cynic.
- **SHAKY link** → strengthen it (find the control, verify the mechanism) or
  carry the uncertainty explicitly into the final text.
- Ship only when every claim is CONFIRMED or a labelled inference, and the
  cynic reports no BROKEN links. Do not argue a verdict away — outrank it
  with evidence or accept it.

### 6. Deliver

Format:

```
## Five whys: <incident / problem>

**Impact.** <who, when in UTC, how badly, measured how>

**1. Why <question in the reader's words>?**
<answer> <evidence citations inline>

**2. Why ...?**
...

**Root causes (<N>, compounding):**
1. ...

**Open inferences:** <each labelled inference and the observation that would
settle it — omit the section only if there are none>
```

Root causes are often plural: a slow-building fuel, an acute spark, and
missing firebreaks (no alerting, blind automation) frequently compound.
Naming all of them beats forcing one "true" root cause.

If a prose-humanizing skill is available, run the final document through it
before delivery — but a rewrite that touches a claim, a citation, or an
epistemic label puts the document back into an unverified state. Diff the
humanized text against the verified chain and confirm every number,
citation, and Measured/Derived/Inferred label survived intact. Anything that
moved goes back through its fact-checker before the document ships.

## Writing rules

- Each why is a question a teammate outside the owning team would ask,
  answered so that same teammate can follow it.
- Short sentences. Spell out jargon at first use. Precise numbers over
  adjectives ("42 of 49 slots at 38% CPU", not "mostly idle").
- State uncertainty honestly and exactly once per claim — the epistemic label
  does the work; no hedging padding.

## How many whys

Five is a guideline. The real stop rule: stop when the answer names something
you can change that would have prevented the incident. Deeper than that lands
on "because humans make mistakes", which is true and useless. Fewer than
three usually means you stopped at a symptom. More than about seven usually
means the steps are too small — merge them. Branching (3a/3b) is fine when
two independent causes compound; carry each branch to its own root.
