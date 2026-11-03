# Prototype 02 — Design and Experiment Plan

## Status

Design draft started on 3 November 2026. The complete duel loop is confirmed for
this prototype; detailed rules remain under discussion.
This document records prototype-specific decisions; the general design notes remain
the source for the broader game direction. A proposal here is not a confirmed
requirement for either this prototype or the final game.

Prototype 01 explores attribute swapping. Prototype 02 is intended to explore the
new auto-battler direction with single-target shapeshifting. Prototype 01's
controls, combat rules and presentation are not inherited automatically.

## Source documents

- [[Game Vision]] — concept, opponent and intended experience.
- [[Gameplay Loop]] — combat, preparation and round structure.
- [[Shapeshifting]] — random transformation network and casting rules.
- [[Economy and Progression]] — purchases, resources and progression proposals.
- [[Art Direction]] — readability and presentation preferences.
- [[Ideas to Explore]] — optional features awaiting validation.
- [[Meeting - 2026-11-02]] — origin and status of the design directions.

## Primary learning goal — confirmed

Does shapeshifting make the auto-battler more fun and add something interesting
to the experience?

The user expects the underlying auto-battler to be enjoyable in its own right.
That is a design expectation, not a playtest finding. Prototype 02 must establish
that foundation so the contribution of shapeshifting can be evaluated in context.
Isolated battles with fixed teams are insufficient as the prototype's final scope.

The required playable experience is the complete duel loop described in
[[Gameplay Loop]]: shop, preparation, real-time automatic combat with player
spellcasting, round resolution, then another round until one wizard has no health.
Creature purchases and gold income every round are essential parts of this base.
This confirms the loop, without automatically approving every optional feature
mentioned in the general notes.

Prototype work in this repository may be reused in later prototypes. There is no
requirement to discard the auto-battler foundation after this experiment.

## Confirmed working rules

- Each round starts with shop access, including the first round. The first shop
  has special starting conditions. The current starting proposal is a choice of
  packs containing three creatures; pack contents, price and remaining purchases
  still need definition.
- Gold is granted each round. Income increases as the duel progresses to help
  accelerate its pace and eventually tip the balance. The income increment is
  +1 gold each round. The working starting value is 3 gold, giving grants of
  3, 4, 5, 6, etc.; the starting value remains tunable. Unspent gold is retained as a delegated simple default.
- Preparation uses a placement grid. During combat, creatures move in continuous
  space within the board boundaries; movement is not restricted to grid cells.
- On death, the gameplay entity is destroyed. A separate visual effect throws
  the creature's sprite or head off the board, without collisions or game logic.
- Combat is real time. No gameplay pause is planned for this prototype.
- Shapeshifting is reset between rounds. Combat transformations do not change
  the next round's creature forms, keeping casting a tactical intervention
  without lasting changes to the roster.
- Bench shapeshifting remains a secondary possibility, not a core requirement.
  Its timing and interaction with the reset rule are unresolved.
- The duel ends when either wizard has no health remaining.
- Creature merging and wizard upgrades are excluded from Prototype 02. The
  separate progression-resource economy is not needed for those upgrades here;
  the broader game's two-resource direction remains separate from this scope.

## Roster and transformation design

The central design work is to build the creature roster, its statistics and its
transformation connections, then test whether shapeshifting has a meaningful,
enjoyable impact in the full loop.

The requested network has heroic fantasy forms pointing to three possible
Super Auto Pets-inspired creature forms each, and those forms likewise pointing
to three heroic fantasy forms each. Concrete creatures and weights are undefined.
The intent is to travel through this map with repeated casts. Three outgoing
options per form does not by itself guarantee full connectivity or that each
individual connection is reversible. The later anti-cancellation rule explicitly
forbids direct reverse connections; the revised draft is fully reachable.

### Roster size — selected on 3 November 2026

Prototype 02 should contain **12 heroic fantasy forms and 12 animal forms**.
The user selected this size to provide enough variety for the experiment.
With three outgoing options per form, this requires 72 directed transformation
connections. The following roster is an assistant proposal awaiting review;
individual candidates, abilities, statistics, prices and connections are not
approved merely by selecting the roster size.

An editable first draft is available in [[Roster and Transformation Map]], with
24 creature sheets, a complete Obsidian Canvas map and two directional views.
It proposes 72 directed links with equal 1/3 chances, not approved connections or
balance values. The initial map allows every form to reach every other form.
Shared base-statistic definitions are proposed there; creature base values remain
TBD. Temporary level scaling has a delegated starting value specified below.

### Heroic fantasy candidates

| Candidate | Proposed combat identity | Main limitation |
| --- | --- | --- |
| Pitchfork Peasant | Very cheap, weak melee body; candidate for purchasing transformation potential. | Poor standalone combat strength. |
| Shield Guardian | Slow frontline defender with high damage reduction. | Low damage and mobility. |
| Berserker | Sustained melee attacker whose attack speed increases as health falls. | Vulnerable before reaching a target and when focused. |
| Duelist | Single-target melee specialist who periodically parries a basic attack. | Limited protection against several attackers. |
| Assassin | Fragile attacker who initially seeks a distant backline target. | Poor durability in a prolonged fight. |
| Spearman | Attacks from behind the frontline with greater melee reach. | Fragile when directly engaged. |
| Archer | Mobile ranged attacker with frequent, light shots. | Weak individual hits against armour. |
| Crossbowman | Slow ranged attacker with heavy, armour-piercing shots. | Long delay between attacks. |
| Pyromancer | Fragile ranged caster dealing damage in a small area. | Less efficient against isolated targets. |
| Frost Mage | Ranged support whose attacks slow enemy movement. | Low direct damage. |
| Cleric | Periodically heals a wounded ally in range. | Low offensive contribution; needs allies to protect. |
| Bard | Increases nearby allies' attack speed through a local aura. | Weak alone; depends on formation. |

### Animal candidates

These are familiar animals in the playful spirit of Super Auto Pets. Their
proposed abilities below are original design suggestions for this prototype,
not descriptions of their abilities in Super Auto Pets. Flight is visual only
unless a later rule explicitly introduces different collision or targeting.

| Candidate | Proposed combat identity | Main limitation |
| --- | --- | --- |
| Turtle | Very slow defender that periodically withdraws into its shell, gaining protection while unable to attack. | Gives up offensive pressure while protected. |
| Rhinoceros | Charges in a straight line on initial engagement, pushing its target back. | Limited turning and slow follow-up attacks. |
| Gorilla | Slow, heavy melee blows damaging a small area in front. | Vulnerable to ranged pressure and separation. |
| Wolf | Gains attack speed while an ally is close by. | Loses effectiveness when isolated. |
| Leopard | Fast predator that prioritizes nearby wounded enemies. | Fragile; may leave a protective formation. |
| Rabbit | Very weak but fast; periodically hops away from its melee attacker. | Little damage and vulnerable to ranged attacks. |
| Snake | Applies damage over time with its bite. | Damage takes time to pay off. |
| Skunk | Short-range spray temporarily reduces enemy armour in a small area. | Needs allied damage to exploit the opening. |
| Eagle | Periodically dives onto a distant enemy, delivering one hit before normal melee combat resumes. | Vulnerable after landing; no permanent flight immunity. |
| Hedgehog | Returns a small amount of damage when struck by a melee attack. | Weak against ranged attackers. |
| Deer | Supports nearby allies with a modest healing aura. | Fragile and weak offensively. |
| Peacock | Periodically displays its tail, briefly reducing the attack speed of nearby enemies. | Needs proximity to enemies despite low durability. |

### How this candidate set supports transformations

The proposal covers defence, sustained damage, burst damage, reach, area damage,
mobility, healing and support across both rosters. Overlapping roles are useful:
a transformation can preserve a broad purpose while changing how a creature
performs it. Each form should have a recognizable strength and weakness.

Do not pair rows across the two tables as transformation links. Design the network
separately. Assistant proposal: give each form one destination preserving part of
its role, one changing its role and one offering a more situational trade-off.
These are design intentions for the three choices, not fixed probabilities or
guaranteed power tiers. Check that the completed graph permits travel across
the roster rather than splitting into isolated groups.

The base-form statistics and abilities establish those differences alongside
the powerful casting rules and temporary level gains specified below. Do not assign a unique new subsystem to
every creature automatically. The proposed set avoids summons and resurrection
for now, keeping those interactions outside this candidate design.

### Powerful shapeshifting — selected on 3 November 2026

Start deliberately powerful to make the spell's contribution visible; reduce its
strength later if playtests require it. The latest rules supersede the earlier
modest allied buff / enemy debuff proposal.

- Preserve current health percentage, then heal 10% of the new maximum health,
  capped at full health. Working interpretation: 50% becomes 60%, not 55%.
- Reset the basic attack cooldown: the next attack is ready immediately if a
  legal target is in range. This is intentionally exploitable for stronger casts.
- Preserve positive status effects and their remaining durations. Remove negative
  status effects as a working implementation of the user's cleansing suggestion.
- A status effect means a temporary modifier such as poison, slow, armour
  reduction, regeneration or an attack-speed bonus. A previous form's innate
  ability is replaced by the new form's ability; it is not retained as a bonus.
  Source-dependent auras still require an active eligible source.
- These health, attack-reset and status rules apply to either target team under
  the literal general casting rule. **Consequently, transforming an enemy also
  heals and cleanses it and readies its attack.** This consequence must be visible
  in testing; no unapproved enemy-only exception is silently introduced.
- Each creature starts combat at level 1. Casting on an ally grants **+1 level**;
  casting on an enemy preserves its level. The user's final +1 statement takes
  precedence over their earlier mention of +2.
- Levels belong to the creature, not its form. They survive further casts by
  either wizard until the end of combat; an enemy cast cannot remove earned levels.
  No level loss or separate generic enemy debuff is added.
- Delegated tuning default: each level above 1 adds 20% of the destination form's
  base maximum health and basic attack damage (additive scaling: levels 1/2/3
  use multipliers 1.0/1.2/1.4). Other statistics do not scale initially. No level
  cap is needed for this first test. This number is adjustable, not user-selected.
- Apply the destination form and updated level before converting health and
  adding the heal. Existing positive percentage modifiers then apply normally.
- Combat form changes, earned levels and status effects reset between rounds.
  This temporary level system is unrelated to merging or wizard progression;
  both remain outside scope.

### Charges and target immunity

- Start each combat with one charge, storing at most three.
- Recharge one missing charge every three seconds, sequentially. Additional casts
  do not reset an already running recharge timer. Stop the timer at full charges.
- Three seconds is the charge recharge interval, not a global lockout between
  casts: stored charges can be spent in succession on eligible targets.
- Starting with one charge gives two at t=3 seconds and three at t=6 seconds if
  none are spent. Recharging from zero to three takes nine seconds. This resolves
  the arithmetic discrepancy in the spoken description using the selected
  starting charge and three-second interval.
- Retain three seconds of target immunity after a transformation as a delegated
  default from the existing proposal. Both wizards obey it. Invalid casts consume
  neither a charge nor recharge progress. Timers use real-time combat seconds.

### Avoiding immediate cancellation

The user does not want a wizard to easily undo the other wizard's intervention.
Earned levels and beneficial status effects survive enemy casts. Form connections
must not allow a direct reversal; returning to a previous form should require a
long trip through the graph, rather than repeated back-and-forth transformations.

The revised Canvas draft uses eight alternating stages with three forms per
stage, each pointing to the three forms in the next stage. The shortest possible
return to any form is eight casts; all 24 forms remain reachable. This is a
**provisional interpretation of a long trip**, not a claim that nearly all 24
forms must be visited. A stricter meaning of 'almost a complete tour' would
require further network design. See [[Roster and Transformation Map]].

### Exploratory hypothesis: cheap creatures with transformation potential

The user suggested a weak, inexpensive pitchfork peasant as an example of a
creature that might become valuable through shapeshifting. This could create a
purchase choice between immediate strength and cheaper transformation potential.
Neither that creature nor a rule that every cast makes its form stronger is
approved yet.

The user also mentioned investing in shapeshifting capacity while thinking aloud.
This does not override the explicit exclusion of wizard upgrades. Whether fixed
casting capacity alone can support this purchase trade-off is a question to test.

## Candidate experiments — not yet selected

| Question | Hypothesis / proposed response | How to investigate | Evidence to discuss |
| --- | --- | --- | --- |
| Can randomness coexist with player control? | A small, learnable network gives players useful expectations without choosing the result. | Repeat battles with a small roster and defined weighted connections; decide what outcomes the interface reveals. | Can players explain why they chose a target and what they hoped would happen? |
| Does casting add tactical decisions? | Friendly and enemy targets offer different useful interventions. | Make both teams targetable; compare battles with and without player casts. | Do players identify useful moments to cast or save a cast? Are both target types useful? |
| Do powerful casts support the player's intention? | Healing, attack resets and allied level gains make casts impactful. | Test the selected rules, including healing/cleansing enemy targets. | Are allied casts dominant? Are enemy transformations still useful? Does persistent level gain prevent easy cancellation? |
| Does the roster create interesting purchases? | Cheap creatures with useful transformation routes can compete with immediately strong creatures. | Include contrasting costs, base strength and network routes as a proposed roster experiment. | Are both purchases useful under fixed casting limits, or does one dominate? |
| Is the battle readable enough to act? | Distinct roles, visible health and clear transformation feedback support timely decisions. | Test a small team size and simple visuals; adjust battle pace if needed. | Can players identify teams, roles and the consequence of a transformation? |
| Do stored charges create timing choices? | Up to three charges allow useful bursts and saving decisions. | Define starting charges and recharge; use three as a candidate tuning value. | Do players save charges for a reason, or simply cast whenever possible? |
| Does shapeshifting add fun to the complete loop? | Temporary combat transformations create enjoyable surprises and useful interventions within team building. | Assistant proposal: play complete duels with and without casting, keeping the underlying rules comparable. | What moments do players enjoy, want to repeat or find frustrating? Does casting improve the experience? |

These are assistant-proposed experiments, not established findings or a mandatory
test protocol. Tactical depth and readability may help explain fun, but do not
replace the primary question. Numerical success thresholds remain undefined.
Persistence is no longer a required comparison: reversion is the selected rule.

## Scope decisions

The full loop is committed. Optional features and detailed rules still need
explicit decisions, as recorded below.

| Area | Existing direction or proposal | Prototype 02 decision |
| --- | --- | --- |
| Core combat | Automatic unit combat with player shapeshifting. | Included, in real time without gameplay pause; continuous movement bounded by the board. Attack and target-selection rules pending. |
| Active spell | Single-target shapeshifting; friendly and enemy targets. | Included; exact interaction and transformation effects pending. |
| Opponent | Single-player against an AI wizard. | Included; enemy casting, preparation and spending behaviour pending. |
| Battle scale | Board and team sizes are unspecified. | Three-creature starting packs proposed; board, field and reserve capacities pending. |
| Roster and network | Weighted outcomes depend on current form. | 12 fantasy forms and 12 animal forms, with three outgoing cross-roster outcomes per form. Candidate roster proposed above; individual forms, links and probabilities pending approval. |
| Form effects | Deliberately powerful first test. | Preserve health percentage, heal 10% maximum HP, ready attack, keep positive effects, cleanse negative effects; +1 allied level, preserve enemy level. See detailed rules. |
| Casting limits | One starting charge, capacity three. | One charge recharges every three seconds; retain three-second target immunity as a delegated default. |
| Information and pace | Outcome inspection is unresolved. | Real-time combat, no gameplay pause; interface details pending. |
| Preparation | Place creatures before combat. | Included on a grid; dimensions and legal placement zones pending. |
| Multiple rounds | Intended for the full duel. | Included, until one wizard has no health; draws and damage formula pending. |
| Transformation persistence | General notes left this for prototyping. | Forms, temporary levels and statuses reset each round. |
| Shop and gold | Intended creature-purchase economy. | Included every round, with increasing income and special first-shop conditions; values and offers pending. |
| Wizard progression | Separate resource and spell upgrades intended for the broader game. | Excluded from Prototype 02. |
| Creature merging | Working proposal for the broader game. | Excluded from Prototype 02. |
| Bench and bench casting | Working proposal with undefined purpose. | Pending: inclusion or deferral. |
| Starting packs and power-up | Replayability proposal. | Three-creature packs proposed for round 1; contents and purchase rules pending. No starting power-up selected. |
| Presentation | Readable 2D wizard board game preferred. | Cross-roster transformations and visual-only death ejection specified; camera, assets, other effects and audio pending. |

The general notes already defer multi-target transformations and attribute
exchanges beyond the initial single-target experiment. Additional active spells
are outside that initial spell scope. Multiplayer is outside the current project
scope. Any change to these boundaries should be recorded explicitly.

## Decision log

### 3 November 2026 — first scope discussion

The user selected the complete auto-battler loop as the necessary foundation for
evaluating the fun added by shapeshifting. They selected increasing round income,
transformation resets between rounds and real-time combat without gameplay pause.
Bench casting remains secondary. Exact rules and values are not implied by these
choices; see the scope table and working rules above.

### 3 November 2026 — combat, network and progression follow-up

The user specified grid placement followed by continuous combat movement, and a
visual-only death ejection after destroying the gameplay entity. They proposed
three-creature starting packs, specified three cross-roster transformation options
per form in both directions and requested an allied buff / enemy debuff per cast.
They confirmed +1 gold to round income each round, with 3 as a working starting
grant, and explicitly excluded creature merging and wizard upgrades. Cheap
creatures with transformation potential remain an exploratory hypothesis.

## Playtest plan and completion criteria

The expected audience includes jam players trying other participants' games, as
well as the two developers playing, exchanging feedback and iterating together.
No development time budget has been supplied. The prototype must support a
complete playable duel; a polished jam release is not automatically implied.

Detailed playtest procedure remains open. For each selected question, define the playable
setup, the variant to compare if needed, observations to collect and what result
would lead us to retain, change or discard the proposal.

Completing implementation and validating a design hypothesis are separate outcomes.
A playable prototype may reveal that a proposal should be changed or rejected.

## Delegated simple defaults for production

The user authorized choosing the simplest generic rules for the remaining loop,
without further design approval. These are adjustable implementation defaults,
not claims that the user personally selected each value.

| Area | Initial default |
| --- | --- |
| Board | 8 x 6 placement cells, with each team preparing in its own 8 x 3 half. Continuous movement during combat. |
| Capacity | Up to 6 fielded creatures and 6 reserves per team. No movement between board and reserve during combat. |
| Starting pack | Choose one free pack of three creatures; then receive the first 3-gold grant and access the normal shop. Pack contents selected from the candidate roster during implementation. |
| Shop | Three random fantasy creature offers; each offer can be bought once. Free refresh at each round's start; no manual reroll initially. Animals are transformation outcomes only. |
| Prices and sales | Initial prices: 1/2/3 gold according to baseline creature strength, assigned with numerical stats. Sell during shopping/preparation for purchase price; keep unspent gold. |
| Combat roster | All owned creatures return for preparation, including those killed, at full health in their purchased form and level 1. |
| Targeting | Nearest living enemy, retained until dead or unreachable. Creature-specific candidate behaviours override only when implemented explicitly. |
| Movement | Direct steering plus local separation, confined to an obstacle-free board; target hitboxes and soft body separation. No terrain/pathfinding subsystem initially. |
| Wizard health | 10 starting HP each; the loser takes 1 damage per surviving enemy creature, independent of temporary levels. |
| Draws and timeout | Mutual elimination or a 60-second timeout is a draw with no wizard damage. Evaluate after resolving the current simulation tick. |
| Enemy wizard | Same health, capacity, income and casting rules; simple affordable purchases and fixed placement priorities. Cast on a random eligible target when a charge is available. |
| Controls and information | Drag to place in preparation; explicit start-combat button; right-click to cast. Show health, temporary levels, charges, immunity and the three possible outcomes with their chances on hover, without pausing. |
| Bench casting | Deferred; combat casts target living fielded units only. |
| Ability cooldowns | Keep their remaining time across form changes; new forms cannot obtain an immediate ability cast merely by entering the form. Basic attack readiness is the explicit exception. Initial ability cadence is assigned with creature data. |

Implementation can now begin using these defaults. Candidate abilities, numerical
base statistics, prices and pack compositions are data-authoring tasks during
production; they need not block the shared combat foundation. All 24 forms remain
in scope. Validate the candidate set while implementing it rather than silently
reducing the roster.

### 3 November 2026 — powerful spell follow-up

The user selected a strong initial spell, health-percentage preservation plus a
10% heal, basic attack reset, retained positive effects, possible cleansing,
allied level gains and preservation of enemy levels. Their final level increment
was +1. They rejected easy cancellation of opposing casts and requested long
form-return routes. They selected one starting charge, capacity three and a
three-second recharge, and delegated the simplest choices for remaining rules.
The concrete defaults and the eight-stage network above are assistant choices
under that delegation. No Godot implementation is made by these design updates.

### 3 November 2026 — implementation scoping

Before the first implementation in `prototypes/prototype_02`, the user selected:
procedural shapes and icons with as little on-screen text as possible (stated as
a rule for every prototype), a top-down board, synthesized sound effects and
English for the rare interface text; all 24 candidate abilities; short combats of
about 20-30 seconds; visible homing projectiles; outcomes and chances on hover;
three thematic starting packs; a simple casting heuristic and role-balanced
purchases for the AI; a no-spell comparison mode, x2 combat speed and automated
tests. Numerical statistics, ability parameters and pack contents are assistant
values documented in the prototype's README; they are not approved balance.
