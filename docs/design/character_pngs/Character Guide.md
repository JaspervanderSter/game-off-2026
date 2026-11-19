# Character guide

Meet the game's 12 fantasy fighters and 12 animal forms. Fighters can be
recruited; animals appear through shapeshifting. Each has its own combat role.
The illustrations show their current appearance in the prototype.

## Fantasy fighters

### Pitchfork Peasant (`peasant`)

A humble farmer in brown, with a straw-coloured hat and a pitchfork.

**Combat role:** Economy. A fielded peasant generates gold at the start of
each round, with higher yields after merging. Cheap to recruit, but weak in
combat: fielding one trades immediate fighting strength for future income.

### Shield Guardian (`guardian`)

A helmeted defender whose large blue-and-gold shield dominates the silhouette.

**Combat role:** Steady frontline protection through high health and armour.
Unlike the Turtle, the Guardian keeps fighting without a defensive pause. Slow
movement and low damage make holding the line its main contribution; it has no
taunt or shield ability that directly protects another unit.

### Berserker (`berserker`)

A red-clad melee fighter with two crossed axes and a jagged orange headpiece.

**Combat role:** Attacks faster as its health falls. A wounded Berserker
becomes more dangerous, but can still be killed before that pressure pays off.
Its identity is escalating aggression rather than the Guardian's endurance.

### Duelist (`duelist`)

A blue-clad swordsman with a fine blade and a dark, feathered hat.

**Combat role:** Fast single-target melee combat with a recurring parry
that cancels one incoming basic attack, including a ranged shot. The parry then
needs to recharge, so several attackers can overwhelm it. It does not block every
kind of damage.

### Assassin (`assassin`)

A purple-hooded figure with a concealed face, bright eyes and a small dagger.

**Combat role:** Initially selects a distant enemy and runs towards it,
putting pressure on the backline with strong melee hits. It has no teleport,
stealth or leap, and may switch to a reachable enemy along the way. Low durability
makes getting caught dangerous.

### Spearman (`spearman`)

A lightly equipped fighter with a helmet, green clothing and a long upright spear.

**Combat role:** Melee reach. Can strike from behind the frontline rather
than standing directly against the enemy. Its specificity comes from weapon
range, without an activated ability; it is less suited to absorbing attacks.

### Archer (`archer`)

A green-clad bow user with a pointed green cap.

**Combat role:** Frequent light shots and evasive footwork. Steps away from
nearby melee enemies while reloading, trying to preserve shooting distance.
Fragile when cornered, and each individual arrow deals modest damage.

### Crossbowman (`crossbowman`)

A helmeted marksman in reddish brown, carrying a broad horizontal crossbow.

**Combat role:** Slow, heavy shots that ignore armour. From one merge star,
bolts also seek additional enemies, losing damage at each bounce. Compared with
the Archer, it favours powerful individual shots over mobility and firing rate.

### Pyromancer (`pyromancer`)

A red-and-orange wizard with a pointed hat and a bright flame beside one hand.

**Combat role:** Fire damage, burns and bursts. Regular shots splash around
their target and apply burning; the caster tries to spread burns between enemies.
Periodically channels a much heavier, armour-ignoring fireball at one target.
The channel creates a pause, and the wizard needs protection.

### Frost Mage (`frost_mage`)

A blue wizard with a pointed hat and a pale snowflake.

**Combat role:** Slows both enemy movement and attack speed. Frost shots
chill a target; a periodically channelled blizzard damages and slows enemies in
a fixed three-by-three-cell area. Its distinction is controlling the fight's
pace, with relatively modest basic damage.

### Cleric (`cleric`)

A white-robed healer with a golden halo and a heart on the chest.

**Combat role:** Periodically restores health to the most wounded ally
within range, judged by remaining health percentage; can also heal itself.
Concentrates healing on one unit at a time, unlike the Deer's nearby regeneration.
Its own offensive contribution is small.

### Bard (`bard`)

A colourful musician in magenta, with a feathered cap and a round-bodied string instrument.

**Combat role:** Repeated musical beats increase the basic attack speed of
every living ally on the battlefield, including the Bard. This is currently a
team-wide effect, not a local aura. Its strength depends on allies making use of
the rhythm; its own attacks are weak.

## Animal forms

### Turtle (`turtle`)

A squat green creature with a large patterned shell and small protruding limbs.

**Combat role:** Defensive endurance. After taking damage, can periodically
withdraw into its shell for extra armour, stopping movement and attacks for the
duration. Very slow: it survives pressure at the cost of offensive activity.

### Rhinoceros (`rhino`)

A bulky grey animal with a prominent pale horn.

**Combat role:** A durable frontline disruptor. When its target is far
enough away and the ability is ready, charges into it for a heavy hit and pushes
it back. Unlike the Guardian, it actively displaces an enemy, but its normal
attacks are slow. The charge can recur during a fight.

### Gorilla (`gorilla`)

A broad, dark-furred animal with heavy arms and a contrasting face.

**Combat role:** Slow melee blows damage enemies in a small area around the
target. Punishes enemies clustered together, whereas isolated or distant targets
reduce the value of its area attack.

### Wolf (`wolf`)

A grey predator with pointed ears, a pale muzzle and yellow eyes.

**Combat role:** A pack fighter that gains attack speed while another ally
is nearby. Any allied form counts; it does not require another Wolf. Fast enough
to join the fight quickly, but loses its special bonus when isolated.

### Leopard (`leopard`)

A golden, spotted feline with rounded ears and a pale muzzle.

**Combat role:** Finishes wounded enemies. Regularly reassesses nearby
targets and prefers the one with the lowest remaining health percentage. Fast
movement and attacks help chase prey, but its lack of armour makes exposure risky.

### Rabbit (`rabbit`)

A white rabbit with long pink-lined ears and a small pink nose.

**Combat role:** A surprisingly aggressive backline attacker. Periodically
leaps behind an enemy in the deepest back row, then attacks rapidly in melee.
An allied transformation into Rabbit readies that leap immediately. It has no
armour: agility and pressure, rather than passive weakness, define its role.

### Snake (`snake`)

A bright green, winding body with yellow eyes and a small red tongue.

**Combat role:** Melee bites apply poison that deals damage over time.
Pressure continues after the bite, distinguishing it from immediate burst
attackers. Repeated bites refresh the poison rather than creating independent
stacks; the damage needs time to pay off.

### Skunk (`skunk`)

A black-and-white animal with an oversized raised tail and a strong pale stripe.

**Combat role:** Weakens enemy defences with an area spray that temporarily
reduces nearby enemies' armour. When its own wizard transforms an ally into
Skunk, it also immediately frightens nearby enemies into fleeing and stopping
their attacks. Its normal damage is modest; allies exploit the opening.

### Eagle (`eagle`)

A brown bird with spread wings, a white head and a yellow beak.

**Combat role:** Periodically dives rapidly onto a distant enemy for impact
damage, then continues fighting in melee. Unlike the Rabbit's leap, the dive
itself is a damaging strike. It remains vulnerable during the approach and after
arrival; flight does not grant immunity.

### Hedgehog (`hedgehog`)

A small pale face surrounded by a conspicuous ring of brown spikes.

**Combat role:** Punishes melee attackers with retaliatory thorn damage
whenever their melee hit lands. Its own attacks are weak, and ranged attacks do
not trigger the retaliation. The spikes communicate its main tactical purpose.

### Deer (`deer`)

A warm-brown animal with branching antlers, wide ears and a pale muzzle.

**Combat role:** Continuously supplies regeneration to allies nearby,
including itself. Supports a group through steady healing rather than the
Cleric's periodic single-target heal. Needs to stay close enough to help, while
having no armour and only modest melee damage.

### Peacock (`peacock`)

A blue bird framed by a wide green-and-blue fan of eye-patterned tail feathers.

**Combat role:** Periodic displays slow the attacks of nearby enemies.
Unlike the Frost Mage, this effect does not slow movement: its niche is reducing
incoming attack pressure around itself. Must get close despite having no armour.
