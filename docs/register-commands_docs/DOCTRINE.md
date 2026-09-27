# NORTHPAW DOCTRINE — D1–D8

**Vault: v1.0 · Frozen 2026-09-18 · Freeze evidence: VAULT_MANIFEST.v1.0.txt (sha256 per file)**
Status: DRAFTED, pending ratification (PAC-001 in REVIEW — sign-off by Heat closes it)

The refusal rules of the project. Any asset, change, or proposal violating a doctrine escalates to design review (NP_13 §5 doctrine gate). D-violations are never fixed by exception.

| ID | Doctrine | Statement | Source |
| --- | --- | --- | --- |
| **D1** | Never sand down | The shonen register is played dead straight, always — no winking, no adult-proofing. Televised seventh-graders, arena-freezing haymakers, fake-death backstories: delivered with full sincerity | NP_12 §1; Hino doctrine |
| **D2** | Opponent is the screen | The fixed camera exists so the opponent is the content. Nothing may block reads; tell readability overrides all presentation, spectacle, and camera ambition | NP_03 §1; NP_04 §3 |
| **D3** | Authored offense, adaptive defense | Opponent attack behavior is scripted pattern logic — learnable, characterful. Only defense adapts, only to player repetition, and every adaptation is narrated aloud. The asymmetry is the game | NP_03 §10; NP_04 §1 |
| **D4** | Three fight sizes | Scrap (<60 s total loop) / Spar (one segment) / Dual. Same verbs at every scale. Scrap brevity is sacred; any design pushing it up is rejected at review | NP_02 §2, §5 |
| **D5** | Friendship is mechanical power | Bonds, relay chains, shared Tension, Inheritance — relationships are numbers, and the numbers are load-bearing, never cosmetic | NP_05 §6; NP_08 §5; NP_09 §5 |
| **D6** | Inherited style, individual fighter | The house style is inherited; the fighter is a person. Every house with ≥2 depicted members shows distinct personalities inside one style (Neji/Hinata/Hanabi rule). Celebration, never caricature — consultation with veto authority where living cultures are drawn on | NP_07 §1, §9 |
| **D7** | Mixed clubs | Rosters look like Canadian classrooms. Houses live everywhere; clubs draw from all of them; diversity is ambient and unremarked | NP_07 §1.3 |
| **D8** | No feature removal | No system is cut, simplified away, or MVP-ed without explicit design review and sign-off. Implementation ease never steers a design decision silently — if effort drives a tradeoff, it is named as effort, in the open | NP_13 §1; project rule |

## Amendment procedure

1. Amendment proposal filed as a PAC (P0 phase, `#doctrine` tag) naming the doctrine, the change, and the playtest or production evidence motivating it.
2. Design review with evidence attached — playtest metrics (NP_13 §6) or documented production blocker. Assertion is not evidence.
3. Ratification by Heat. On approval: DOCTRINE.md updated, vault version incremented, every mapped PAC in the register gets a same-day Note (vault/register no-drift rule, NP_13 §9).
4. Rejected amendments are logged here with the rejection reason:
   - *(none)*

## Doctrine-adjacent constants (amendment-track changes, lighter evidence bar)

- Affinity stacking hard cap ×1.5 (NP_06 §4; sole exception: Awakening ×1.75, NP_09 §6)
- Tension never decays (NP_05 §1 — tested and cut; do not reintroduce)
- Fair-windup floors: 400/700/1200 ms (NP_04 §1)
- No-invalidation rule: unsealing/Awakening ADDS, never replaces (NP_07 §7; NP_11 §2)
- Style triangle direction is sacred; balance levers are the parameter packages only (NP_06 §7)
