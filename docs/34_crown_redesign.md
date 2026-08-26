# 34 — THE CROWN REDESIGN (v11 / v11.1 / v11.2, 2026-08-25)

> User: *"At the top of this tower we have a crown building. It doesnt look as scary
> or visually pleasing as I hoped. Can you make the crown larger and more gold and
> look more like a crown. When players see it they should be magnitized towards it.
> We dont need to edit the floor of the room or space. This is more outside design
> work for visuals. Im just expecting it to be a lot bigger... It just looks like a
> castle with spikes. We can do so so so much better if we take our time and
> actually put the effort in."*
>
> And, mid-session: *"Also inside we have these 4 pillars with this weird looking
> pipe level model on top. Lets remove that. So weird."*

Everything below is implemented in `tools/gen_tower_map.js` §5f (`THE CIRCLET`).
**The `.map` is generated** — never hand-edit it; change the generator and run
`node tools/gen_tower_map.js`.

**Renders.** `docs/crown_now_*.png` is the original citadel (the before-shot, and
the evidence for §1). `docs/crown_v12_*.png` plus `docs/crown_v12_road_gate.png`
are the crown at `CR_SCALE` 1.4 BEFORE the detail pass; **`docs/crown_v13_*.png`
is the shipped state** (see §11); `docs/crown_v11_*.png` is one scale step back
at 1.0. Regenerate any of them with `tools/preview_crown.js` — see §10. Note the
v11/v12 sets were rendered with the OLD directional shading and the OLD collapsed
palette, so they overstate relief and hide the value ladder (§11.1).

---

## 1. WHAT WAS ACTUALLY WRONG — measured, not felt

The old citadel was a 1536-wide, 576-tall blue box with nine narrowing spires on
it, standing on a navy underside. Two numbers explain the whole complaint.

### 1.1 The legibility floor

Every sight line to the crown from anywhere on the tower comes from the **south**
and from **below**. At the base-arena slant distance of **22,079 units**, BO3's
65° FOV puts **29.5 px on one degree**, and anything under about half a degree
aliases into noise. In world units at that distance:

| angle | world units | px @1920 |
|---|---|---|
| 0.5° | **193** | 15 |
| 1.0° | **385** | 29 |
| 2.0° | 771 | 59 |

> **Nothing narrower than ~384 units can carry any part of the read.**

Measured against that ruler, the old crown was one 4°-wide box plus a fringe of
things at or below the vanishing threshold:

| old feature | width | angle | px |
|---|---|---|---|
| gate spire tip | 20 | 0.05° | **1.5** |
| pilaster tip | 24 | 0.06° | **1.8** |
| corner-tower tip | 40 | 0.10° | 3 |
| corner tower body | 192 | 0.50° | 15 |
| hall wall | 1536 | 4.0° | 118 |

Six of the nine spires were literally invisible from every point in the map.
That is "a castle with spikes": a box with hair on it.

### 1.2 The underside is 60% of the pixels, and it was black

The near (south) rim occludes the interior, the far rim and everything behind
them for the whole climb. What a player below can see is exactly three things:
**the underside**, **the south band's outer face**, and **the south rim's points
against the night sky**. The old underside was `MAT.ground`
(`dark_blue_tinted`) — within a few percent of the atmosphere's own fog colour
(`_tod_atmosphere.gsc`, `0.16 0.14 0.30`) — so it rendered as a black square.
See `docs/crown_now_under.png`, kept as the before-shot.

### 1.3 You cannot light your way out of it

Every crown light is radius 460–900 (`gen_tower_map.js`, the `CL(...)` block).
**A 900-unit light does nothing for a 4096-unit object** — still less for the
6128-unit one it became at `CR_SCALE` 1.4.

> The exterior read is carried by **MATERIAL**, not by light entities. The
> circlet adds exactly three lights (two in v11, the third in v12), all for
> red bloom on the vertical axis: the apex beacon, the great ruby, and the
> girandole under the bell (§12).

---

## 2. THE SHAPE

A rectangular gold **circlet around the hall**, so the play floor sits inside it
the way a head sits inside a crown.

### 2.0 `CR_SCALE` — the one knob (v11.1)

> User, after seeing v11: *"I want the scale to be even more. I want players to be
> in awe when they see the crown."*

Every proportion here was derived against the heraldic canon and against the
384-unit legibility floor, and the look had already been signed off — so the
correct way to make it bigger is to **multiply, not to re-litigate ratios one at
a time**. `CR_SCALE` does exactly that, and `CS(v) = round(v × CR_SCALE / 16) × 16`
scales any literal while keeping it on the 16-grid. It is currently **1.4**.

| | `CR_SCALE` 1.0 | **1.4 (shipped)** | the old citadel |
|---|---|---|---|
| width | 4096 | **6128** | 1568 |
| total height | 9920 | **13 888** | 2688 |
| angular width from the base arena | 10.6° | **14.8°** | 4.0° |
| LED bake (but read the correction in §8) | 38.2 s | **~32 s** | — |

**Two things deliberately do NOT scale:**

- **`BAND_T`** (320). Band thickness is the *depth of the tunnel* the causeway
  walks through — already the deepest passage in the map, against a hall gate of
  40. You only ever see the band's face, never its thickness, so scaling it would
  buy nothing and deepen a known navmesh risk.
- **`CR_S_FACE`** (6912), the south outer face. It is **pinned**, and everything
  else moves around it — see §2.3.

> **CORRECTION, 2026-08-25 — the paragraph that used to be here was wrong.**
> It read: *"1.4 is where this stops, and the bake says so. 38.2 s → 126.2 s is
> 3.3× the time for ~2× the lit area."* That was a conclusion drawn from **one
> bake reading, never repeated.** It did not reproduce. The same map at
> `CR_SCALE` 1.4 has since baked at **35.1, 31.9 and 31.8 s**, and an A/B with
> byte-identical geometry differing only in material distribution baked **31.3 s**.
> See §8 for the full series. `CR_SCALE` is still 1.4 because the crown looks
> right at 1.4 — **not** because the bake forbids more.

**Why 1.4 and not more:** because the proportions read correctly there and the
user signed the look off, which is a design reason. The bake is a **pass/fail
gate**, not a budget meter — see §8 before quoting a number from it.

| symbol | value at 1.4 | note |
|---|---|---|
| `CR_HX` / `CR_HY` | 2864 / 2288 | **6128 × 4768** outer footprint |
| `CR_S_FACE` | 6912 | **pinned** — the road's mouth lives here |
| `CR_CY` | 9296 | *derived*: `CR_S_FACE + CR_ERM + CR_HY` |
| `BAND_T` | 320 | ring wall thickness — not scaled |
| `CR_CHAM` / `CR_CHAM_N` | 720 / 4 | corner chamfer — the plan reads octagonal |
| `CROWN_BOT` → `CROWN_TOP` | 15008 → 28896 | **13,888 tall** including the skirt |
| height / width | 1.61 | preserved by uniform scaling; see §2.2 |

**12.4x the hall floor footprint and 24x its wall height.** The band's bottom
is 1168 *below* the floor and its top 992 *above* the wall tops.

### 2.1 Why a rectangle and not a square

Width is what you see; depth is invisible. A 4096-square ring would put its south
rim 2048 in front of centre and bury its own monde behind that rim until floor
~35. At `CR_HY` 1632 the monde clears at floor 7 and the finial clears from the
ground.

### 2.2 Why height/width is 1.61 and not the heraldic 1.4

From the base the elevation angle is 67°, so vertical extent is foreshortened by
`cos 67° = 0.39`. Building the true 1.4 would read as **0.55:1** — a squashed
plate — from the street. Do not push past 1.7 or it becomes a papal tiara.

### 2.3 The south face is PINNED, and the crown grows north around the hall

The south band has to land inside the causeway's **F APPROACH** — the one stretch
that is flat, on-axis, 160 wide and at `TOP2`. Anywhere else and the ring would
have to be pierced by three separate mouths through a fork that is on stairs at
three different heights. That stretch is only 800 deep, and at v11's `CR_HY` 1632
the ring was already within 32 units of the J4 merge: **there was no room to grow
southward at all.**

So `CR_S_FACE` is a constant and `CR_CY` is *derived* from it. The crown is no
longer centred on the hall — it is **anchored to the road** and grows north. The
hall now sits nearer the south rim than the north.

Nobody can ever see that. Every sight line is from the south, depth is invisible
(§2.1), and the hall's own 576 walls occlude the ring's inner faces from inside —
standing on the hall floor, the near wall subtends 37° while the ring's inner face
tops out at 22°, so the ring is not visible from in there at all.

There is a generator assert on the road placement; it throws rather than shipping
a road that ends in a wall.

---

## 3. THE VERTICAL SCHEDULE

All z relative to `TOP2` = 19392, **quoted at `CR_SCALE` 1.0** — multiply by
`CR_SCALE` (currently 1.4) for the shipped numbers. The RATIOS are the point:
they land on the St Edward's canon to within about 2% on every element, and
uniform scaling preserves every one of them. That is the whole argument for
having one knob instead of thirty literals.

| element | z | outer half-extents | material | ratio of H |
|---|---|---|---|---|
| glowing core | −3136 → −2880 | 192 | `red_tinted_edge` | — |
| skirt T7…T0 (8 tiers, ×0.80 each) | −2880 → −832 | 400 → 1984 | gold / brass alternating | — |
| cap velvet + gold fillet | −832 → −16 | 832 / 856 | `purple_tinted`, `yellow` | — |
| **ERMINE RIM** | −832 → −576 | **2112 × 1696** | **`white`** | 0.00 → 0.04 |
| band C1 | −576 → −40 | 1856 | `yellow_tinted` | → 0.12 |
| *(hall floor)* | 0 | 768 | unchanged | **0.126 — the head** |
| band C2 *(mouth)* | −40 → +160 | 1920 | `yellow_tinted` | → 0.15 |
| band C3 *(mouth)* | +160 → +384 | 1984 | `yellow_tinted` | → 0.18 |
| band C4 *(the lintel)* | +384 → +640 | **2048** | `yellow_tinted` | → 0.22 |
| pearl rim strip | +640 → +704 | 2096 | `yellow` (plain) | → 0.23 |
| **SHORT points ×8** (fleur-de-lis) | +704 → +2256 | head 560 | gold | → 0.45 |
| **TALL points ×7** (cross pattée) | +704 → +2880 | head 640 | gold | → 0.55 |
| **FRONT CROSS** ×1 | +704 → +3456 | arm span 1024 | gold + ruby | → 0.65 |
| arch springing / crown | +2880 / +3840 | ribbon 352 × 320 | gold | 0.55 / 0.72 |
| **MONDE** Ø1008 | +3840 → +4864 | 8 stepped slabs + equator fillet | gold | 0.79 |
| **FINIAL CROSS PATTÉE** | +4864 → +5760 | arm span 768, **on both axes** | gold + emerald crossing | **1.00** |
| **BEACON STAR** | +5760 → +6784 | 448 core + 768 cross arms | gold + `red_tinted_edge` | — |

Every tall point is finialled with a **stone** (224 cube, 0.58°, cycling ruby /
emerald / sapphire), so the rim reads as gold teeth *tipped with colour* rather
than gold teeth. The south band carries a raised **frontispiece** — split around
the mouth — that the Cullinan is set into, so the front stone has a facade behind
it instead of floating on a flat wall.

### The apex is a STAR, not a needle — and that was the old mistake again

The first cut was a 160-wide beacon needle. Clearing the near rim's occlusion line
is **not** the same as resolving: 160 units at 22,079 is **0.41° = 12 px**, under
the floor, so it would have shimmered away exactly like the gate spires it
replaced. Worse, **from directly below a vertical member presents almost no area
at all** — the previewer's `street` view rendered the whole upper crown as a
hairline. So the apex is a cross of **horizontal plates** (448 core, 768 arms on
both axes), because horizontal is the only orientation with any area when you are
looking straight up at it. The finial's arms run on both axes for the same reason:
a cross that exists on one axis only disappears from half the map.

### The flare — the single move that kills "castle"

Band courses step **outward** going up: 1856 → 1920 → 1984 → **2048**. That is
192 of batter over 1216 of height, about **9°**. The ermine below them is proud
of even the topmost course, giving the correct crown profile: **a fur roll at the
very bottom that is the widest line in the whole silhouette, a nipped waist above
it, then a splay to the band's top edge.** Plumb walls of constant thickness are
the definition of a curtain wall — that is what the old citadel had.

### The mouth — the road runs *through* the rim

640 × 424 at `CR_SCALE` 1.0, **896 × 592 as shipped at 1.4**, cut through
**C2 and C3 only** — its z is derived from those two courses rather than written
down, so it cannot drift out of the band when the scale moves. C1 stays continuous (it is
entirely below the road) so **the ermine ring is unbroken from below**, which
matters because that ring is the strongest single read from the base. C4 stays
continuous and becomes the lintel. The road's rails reach |x| = 100, so the
jambs at |x| = 320 are 220 clear.

Jambs, corbels, a keystone, a three-course stepped pediment and a glowing-seam
lining turn the hole into a gate. **There is no door here** — `tod_crown_door`
closes at the *hall* gate and `in_crown()` / `in_hall()` are boxes keyed on the
hall walls; a second sealing brush would break the win test.

---

## 4. THE POINTS — sixteen, alternating, every head FLARING

Eight tall crosses pattée alternating with eight short fleurs-de-lis, on the
ring's wall centreline. Across the **south face** — the only face anybody ever
sees from the tower — that reads, left to right:

```
  TALL corner    short    FRONT CROSS    short    TALL corner
      ▲            ▲           ✚            ▲          ▲
```

Five teeth, alternating, with a dominant centre.

**THE HEADS MUST FLARE.** A shape that narrows to a point is a *spire*, and
spires are the single most castle-shaped thing in architecture — every old
`cspike()` tier list narrowed (192→144→96→40, 128→96→56→24, 32→20). A crown point
is the other way round: a thin shaft carrying a head **wider than the shaft**. A
cross *pattée* is literally named for its widening arms. `cspike()` cannot express
that, which is why §5f adds **`cfleuron()`**.

Legibility at the base-arena distance:

At `CR_SCALE` 1.4, from the base arena (22,079 units, 29.5 px per degree at 1920):

| feature | width | angle | px |
|---|---|---|---|
| front-cross arm span | 1440 | 3.74° | **110** |
| beacon star arms | 1088 | 2.82° | **83** |
| tall head | 896 | 2.32° | **69** |
| the Cullinan | 896 | 2.32° | **69** |
| short (fleur) head | 784 | 2.03° | **60** |
| the great ruby | 720 | 1.87° | **55** |
| beacon core | 640 | 1.66° | **49** |
| jewel boss | 448 | 1.16° | **34** |
| *(old corner tower)* | 192 | 0.50° | 15 |
| *(old gate spire)* | 20 | 0.05° | **1.5** |

Every element that carries the read is now over one degree, and the smallest of
them is more than twice the width of the old citadel's largest tower.

**Sky must be visible between and behind every point.** Above the rim strip there
is nothing but points and sky; if the mass carried on up between the teeth they
would read as buttresses.

### The FRONT CROSS

Real crowns have a front; forts are omnidirectional, and four identical faces was
one reason the old citadel read as a keep. The south mid point is 576 taller than
its neighbours and stands on the **near** rim, which means it is the one tall
element that can never be occluded by the crown's own south band from any height
on the tower. It carries **the great ruby** (512 square, 1.33°, 39 px) in a gold
bezel, and it is what magnetises the base arena.

### The reveal is staged across the climb

| what appears | first visible at |
|---|---|
| ermine rim, band, jewels, south teeth, front cross + great ruby, apex beacon | **floor 0 — the base arena** |
| the monde | floor 7 |
| the arch crowns | floor 18 |
| the whole upper crown | floor ~25 |
| the interior and the vault overhead | the terrace / the road |

---

## 5. THE UNDERSIDE

Ten tiers, each **0.80 of the one above on both axes**, so the taper is
proportional and reads as a **cone**. A linear step-in runs the short axis out
first and produces a keel. Each tier is chamfered (`crownSolidTier()`, six boxes:
two overlapping bars plus one corner box each) so the outline is octagonal rather
than a stack of rectangles.

Tiers alternate **bright gold** (`yellow`, scaleRGB 15) and **brass**
(`orange_tinted`, #ed871a). From below you look almost straight up the cone and
see a set of **concentric rings** whose visible width is the step-in — 400 units
at the top (1.04°, 31 px) — radiating out from a glowing red core.

**Not the glowing-seam family, and that is measured rather than taste:**
`_tinted_edge` is scaleRGB **5** where `_tinted` is 10 and plain is 15, so the
seam materials are the *dimmest* in the pack. On a surface that has to survive
22,000 units of sight line and 20–25% fog wash toward a cold purple, brightness
beats texture. The seam materials earn their place at arm's length — the mouth
lining.

**No radial ribs.** At 128 wide they would be 0.33° and would shimmer.
Concentric material banding beats radial geometry at this distance and costs
nothing.

---

## 6. MATERIALS — the "much more gold" answer

The vertigo pack has **30 materials and no metal** (verified against
`emox_mwiii_vertigo_assets.gdt`, 2026-08-25). There is no gold shader to reach
for, so the gold is built out of **value**:

| role | material | note |
|---|---|---|
| bright gold | `..._yellow` | scaleRGB 15 — points, arches, finial, ribs, rim |
| gold panel | `..._yellow_tinted` | #e3cd3b @10 — the band courses |
| brass foil | `..._orange_tinted` | #ed871a — the dark tone gold reads against |
| glowing seam | `..._yellow_tinted_edge` | @5 — inlays and the mouth lining only |
| velvet | `..._purple_tinted` | the cap, and the hall walls |
| ermine | `..._white` | ⚠ needed a new lint entry, see §8 |
| jewels | `..._red/blue/green_tinted_edge` | there is **no** `purple_tinted_edge` or `cyan_tinted_edge` |

**"More gold" is not "everything gold."** Gold only reads as gold against a dark
foil. Target proportions on the exterior are roughly **60% gold, 25% velvet or
brass, 10% white, 5% jewel**. The old citadel was ~70% blue.

The hall walls were re-skinned blue → velvet. They are invisible from outside
once the band exists, but they are the whole interior of the hold-out arena, and
purple-and-gold is what the inside of a crown looks like.

**A future option, deliberately not taken here:** clone the pack's
`yellow_tinted` GDT block into `source_data/tod_materials.gdt` with a real gold
`colorTint1` and a scaleRGB ladder (5 / 10 / 15 / 25). It is cheap and exactly on
style, but a `.gdt` edit is **always a full build**, it needs matching
`lint_tod_geometry.js` entries, and the failure mode (a material that does not
build) is a white crown. Do the form first; the tone is a follow-up.

---

## 7. THE FOUR PYLONS ARE GONE (v11) — and the bare PILLARS returned (v12)

The hall's four 176-tall plinths carrying `p7_zm_ctl_deathray_sphere_coil` were
deleted, along with `PYL_OFF` / `PYL_HALF` / `PYL_H` and `MAT.pylonPad`.
**v12 correction:** the user's objection was to the COIL MODELS, not the posts
("I think the last agent thought I wanted the entire pillars removed") — the
four bare pillars are back at the original ±448 spots as scenery/cover (gold
base, ruby shaft, gold cap; §5d of the generator), with **no script contract**.
Everything below about the quarter-progress read moving to the circlet still
stands.

Their **job** survives: they were the finale's quarter-progress read, one
igniting per quarter of the closing song. `pylon_orgs()` — same name, so
`_tod_finale.gsc` needed a model swap and not a rewrite — now returns the
**circlet's four corner point caps**. The progress read is now *the crown lighting
up around you*, legible from inside the hall, from the causeway, and from the
tower. The model is the mast beacon's `p7_zm_asc_light_cage_warning_red`: it is
2,432 units above the floor, the **aura** is the read, and reusing it costs no new
asset. The dead `xmodel,p7_zm_ctl_deathray_sphere_coil` zone line was removed.

The four hall lights that hung over the plinths moved to the floor's quarter
points — the room still needs lighting, the furniture does not.

---

## 8. THE GATES THIS HAD TO PASS

### `tools/lint_tod_geometry.js` — HOLES AND MISPLACED WALLS

Green, whole map, against an all-zero baseline. Three rules governed every brush:

1. **Plain colours are BLOCK and can never become floor at any size**;
   `_tinted` / `_tinted_edge` are DECK and become **floor** at ≤ `MAX_SLAB` (64)
   thick **in Z**. So: *any horizontal element 64 units thick or thinner must use
   a plain colour.* That is why the rim strip, the astragals and every fillet are
   plain `yellow`, and why the mouth soffit is 80 thick and not 24 — as a
   24-thick `_tinted_edge` slab it would have become a floor node hanging over
   the causeway with no guard on any edge.
2. **An unknown material is a hard abort**, not a warning.
   `mwiii_vertigo_retro_synth_white` was added to the table as `BLOCK`
   deliberately (it is a 256-tall ring 19,000 units in the air that nothing can
   reach; calling it DECK would invent ~800 unguarded edges out of decoration).
3. **The 20×20 column at (x ∈ [0,20), y ∈ [7840,7860)) is the lint's only working
   citadel reachability anchor** — its fallback at y = 9360 is already blocked by
   `crown wall N`. Nothing may go there above `TOP2+18`. No threshold, no
   portcullis, no centre monolith at the hall mouth.

Labels all start with `crown ` — labels starting with `causeway` or `terrace`
land in the ROAD detachment bucket, which is gated at zero.

### `tools/lint_tod_geometry_parity.js`

Green. The whole circlet is authored in the **odd frame** and mirrored by `CM`,
so it welds correctly at `LAPS=49` (CM = −1) as well. *Never special-case the top
by parity* — that lesson is from v9 and it still holds.

### `tools/_bake_test.ps1` — and the number this project should stop quoting

**BAKED.** The full measured series, in the order it was taken:

| map | brushes | lit area | bake |
|---|---|---|---|
| earlier still | 3,447 | — | 53 s |
| pre-crown | 4,245 | — | 47.5–68.5 s |
| crown at `CR_SCALE` 1.0 | 4,700 | 962 M | **38.2 s** |
| crown at `CR_SCALE` 1.4 | 4,700 | ~1,360 M | **126.2 s** ← *never reproduced* |
| 1.4 + detail pass | 4,743 | 1,005 M | **35.1 s** |
| same map, repeat | 4,743 | 1,005 M | **31.9 s** |
| same geometry, materials reverted (A/B) | 4,743 | 1,005 M | **31.3 s** |
| 1.4 + full detail pass | 4,758 | ~1,010 M | **31.8 s** |

**THE 126.2 s READING WAS NOT A PROPERTY OF THE MAP.** It was taken once and
used to justify a design limit ("1.4 is where this stops"). Four later bakes of a
*larger* map came in at 31–35 s. To rule out the obvious suspect — that
redistributing the band and rib materials had changed atlas packing — a variant
was generated with byte-identical geometry and only the materials reverted
(`TOD_MAP_OUT` exists for exactly this) and baked at **31.3 s** against the
shipped map's **31.9 s**. Materials were not it either.

> **So: bake time on this map is dominated by HOST STATE, not by map content,
> across everything measured here.** The KB's "the same map varies by 20 s run to
> run" understates it — the observed spread on near-identical input is
> **31.3 to 126.2 s, a factor of four.**

**What to do with that:**

- Treat `_bake_test.ps1` as a **PASS/FAIL gate** — `BAKED` or `CRASHED`. It is
  not a budget meter and a single reading from it justifies nothing.
- **Never draw a design conclusion from one bake.** If a number is going to
  decide something, bake at least twice, and A/B it against a variant if you
  think you know the cause.
- Use `node tools/measure_lit_area.js` for the budget question instead. It is
  deterministic, instant, and it tells you what actually changed.
- If it ever does go red (`brush.cpp:1860` — a D3D allocation failure on the
  bake host's iGPU, per the KB), the drop order is: chamfers → 0, pendilia,
  arches, merge the skirt tiers in pairs. Never drop the points, the ermine or
  the skirt — they are the read. To buy real headroom, `caulk` (noDraw and still
  solid, stock, used in Treyarch's own `zm_giant.map` source) on buried faces is
  untouched here; it needs a per-face `boxFaces()` variant of `box()` plus a
  deliberate `lint_tod_geometry.js` material entry.

### The seal

`SKY_IN` used to be `max(2900, HN + 384)` — derived from `HN` **in y only** — and
`SKY_TOP` was `MAST_TOP + 300`, derived from the **mast only**. The two existing
asserts test the **causeway**, never the crown. Nothing whatsoever would have
fired when the beacon needle went 4,564 units through the roof of the world.
Both are now `max()`'d over the crown's real extents, and §5f.1 asserts the crown
against the sky ceiling, the sky wall, the sky floor **and** the umbra/fpstool
lid. `VOL_R` follows too.

### What did NOT move

Verified in the regenerated `_tod_crown_data.gsc`: `crown_z`, `dais_org`,
`causeway_gate_org`, `beyond_gate`, `crown_door_org`, `exfil_org`,
`exfil_radius`, `hall_center`, `gate_org`, `mast_tip_org`, `station_org`,
`sconce_orgs`, and both containment boxes `in_crown()` (x ±720, y 7880–9336,
z 19328–19792) and `in_hall()` — **byte-identical**. The win test, the extraction
pad, the crown door, the upgrade station and the twelve sconces are untouched.
Only `pylon_orgs()` moved, on purpose.

---

## 9. THE FIFTEEN WAYS A CASTLE FAILS TO BE A CROWN

Kept as the checklist for any future edit up here.

| # | the castle mistake | the crown move |
|---|---|---|
| 1 | plumb wall of constant thickness | **flare the band 9°**, ermine proud at the bottom |
| 2 | points that narrow upward | **every head FLARES** — thin shaft, wide head, small cap |
| 3 | sub-degree detail | **nothing under 384 carries the read**; two detail scales |
| 4 | crenellations | few, large points on a thin rim — 5 teeth at 944 pitch, not 20 at 100 |
| 5 | points growing out of a solid box | **sky between and behind every point** |
| 6 | uniform points | alternate tall / short, 8 + 8, at a 1.5:1 height ratio |
| 7 | points only at the corners | 3 per side + 4 corners = 16, giving 5 across the face |
| 8 | square plan | 4-step chamfers — the plan reads octagonal |
| 9 | dark underside | white ermine + alternating gold/brass cone, 3136 deep |
| 10 | open flat top | two dipped arches → monde → cross pattée → beacon. A crown **converges** |
| 11 | no front | the **front cross** with the great stone, facing the only direction anyone looks from |
| 12 | one tonal value | 60% gold / 25% velvet / 10% white / 5% jewel |
| 13 | a setback pyramid underneath | proportional ogee taper (v12 `SK_F`, was ×0.80), concentrically banded |
| 14 | the band as a plinth | the band must **grip** the floor — play floor at 12.6% of H |
| 15 | detail without mass | **size and silhouette first, detail last** |

---

## 10. ITERATING ON THIS

`tools/preview_crown.js` renders the generated `.map` to SVG **and PNG** without
a bake or a game launch. Six views, ~1 s:

```
node tools/gen_tower_map.js
node tools/preview_crown.js --filter "^(crown (?!stair|step|door))" --out docs/crown_v11
```

- `_street` — base arena, eye height 64, looking up 19,000 units. **The magnetise test.**
- `_approach` — standing on the terrace where the causeway starts.
- `_gate` — on the causeway, 900 units short of the mouth.
- `_under` — straight up from underneath. **If this is dark, nothing else counts.**
- `_elevation` / `_plan` — orthographic silhouette and plan.

It parses only the 6-plane AABB template and reports anything it skipped.

### Why everything here is axis-aligned boxes

True convex brushes **are** supported — 51% of the mod tools' shipped content is
non-axis-aligned, and map 1's own `.map` has 160 such brushes on visible
materials — but `lint_tod_geometry.js` counts axis-constant planes and **silently
drops** anything that is not the 6-plane template, and so does `preview_crown.js`.
Using them here would blind the map's only whole-map hole/edge/walkability proof
and the 1-second preview loop at exactly the spot taking the most new geometry.
A 128-unit chamfer step subtends 0.33° at the base-arena distance — below the
shimmer threshold — so the plan reads octagonal anyway.

Convex brushes are the right tool for the **arch ribbons** later. Prerequisites,
in order: teach `preview_crown.js` to project plane-intersection hulls; extend
the lint's `parseWorld` to build a conservative AABB hull and tag `nonAabb` so
`isDeck` is forced false and `isBlock` stays true; re-run
`lint_tod_geometry_selftest.js`. Never hand-order plane points — declare
`{outward normal, point on plane}` and derive them, and assert the solid is
non-empty, or a single inverted side plane produces a sliver floating outside the
intended footprint **with no error**.

---

## 11. THE DETAIL PASS (v11.2) — and the finding that rewrote it

> User: *"Its scale is perfect. It looks fantastic. Now I want to review the
> design and add some details to it. To make it look nicer and more pleasing and
> impressive."*

### 11.1 EVERY MATERIAL IN THIS PACK IS SELF-LIT. Geometry does not self-shadow.

All 30 materials in `emox_mwiii_vertigo_assets.gdt` are `lit_emissive_*` — 27
`lit_emissive_advanced`, 3 scroll variants. A face pointing down and a face
pointing at the sky **emit identically**, and the crown carries exactly two light
entities on its entire fabric (the great ruby and the apex beacon).

> **Consequence: a corbel, a ledge, a moulding or a collar produces NO value
> change on its own.** Relief only pays when it (a) breaks the silhouette against
> sky or a darker neighbour, or (b) **carries a different material.**

This inverted the pass. The tool is not relief, it is the **value ladder**,
measured from `colorTint1 × scaleRGB` with the usual luma weights:

| material | value | role on the crown |
|---|---|---|
| `..._yellow` (plain) | **13.5** | bright gold — points, arches, rim, panels, dentils |
| `..._white` | 13.1 | the ermine |
| `..._orange` (plain) | 8.5 | unused |
| `..._yellow_tinted` | 7.8 | gold panel — band courses C2/C3 |
| `..._orange_tinted` | 5.8 | **brass — the dark foil: C1, the ribs, shaft bands, point caps** |
| `..._yellow_tinted_edge` | 3.9 | dim gold, 512 tile — the mouth lining only |
| `..._purple_tinted` | 2.9 | velvet — hall interior |
| `..._dark_white` | 2.8 | **the ermine's tails** |
| `..._off` | 0.0 | unused — pure black reads as a hole, not a material |

**And the previewer had been lying about all of it.** It shaded faces by
direction across a 0.45–1.15 spread — flattering every ledge in every render of
this crown — and its palette collapsed `yellow`, `yellow_tinted` and
`yellow_tinted_edge` into one swatch, so the value scheme was invisible in the
exact images being used to judge it. Both are fixed: near-flat face shading
(0.88–1.06) and a palette keyed to the measured values, **suffix-ordered** so
`_tinted_edge` resolves before `_tinted` before the plain colour.

### 11.2 Where detail goes, and where it must not

A player can stand in the base arena, on the spiral, on the breathers, on the
terrace, anywhere on the causeway, in the mouth, and on the hall floor. **Nowhere
else** — they cannot fly and cannot reach the band. Every reachable close view is
therefore from the **south**.

One measurement reshaped this too: the flat, head-on run in front of the mouth is
**192 units** (the J4 merge ends at y 6880, the crown's face is at 6912). The
approach a player actually reads the crown from is **THE PLANK** — the raised
centre route of the second fork, 120 wide and +192 above the deck, running y
4960–6240. That is the money view, and `preview_crown.js`'s `gate` camera now
sits on it.

**Detailed:** the south band, the mouth, the ermine, the south row of points.
**Deliberately left plain:** the E/W/N band faces (only ever seen from 22,000
units, where sub-degree detail shimmers — a brush spent there is pure bake for a
surface nobody resolves), the skirt, the monde/finial/beacon, the arch ribbons,
and the rim strip and astragals, which only read as order lines because the field
around them is quiet.

### 11.3 The six defects, all found by measuring the `.map`

| # | defect | fix |
|---|---|---|
| 1 | **mouth jambs 100% buried** inside the frontispiece, south faces COPLANAR (a two-material z-fight) | jambs CS(240) proud, frontispiece pushed back to CS(16) |
| 2 | **two jewel bosses sealed inside the frontispiece** — 448-wide slabs in solid gold, pure bake cost | inner south pair skipped; north keeps all four |
| 3 | **ribs narrower than the points they carry** (256 under a 384 shaft) | CS(144)/CS(176), wider than their load |
| 4 | **all articulation inside a 96-unit slot** on a 6128-wide elevation | split rib depth by axis — rule H is about X, so S/N ribs may protrude in Y. 80 → 320 proud, **zero brushes** |
| 5 | **the spire came back**: points ran 400→896→496→**208**→320, and 208 = 0.54° | pip → 400, stone → 448 so it FLARES; fleur centre lobe 336 → 448 (it was narrower than its own shaft) |
| 6 | **the last causeway portal stood inside the crown's throat** (y 7344 vs the band's inner face at 7328), in cyan | re-skinned gold; the first two keep the road's cyan |

### 11.4 What was added

Ermine spots (`dark_white`, two staggered rows — heraldic ermine is white *with
dark tails*, which is the whole reason a white band reads as fur); the band's
value ladder (C1 brass → C2/C3 panel → C4 bright); sunken panel frames in the
outer south bays (raised frames implying a recess, because additive boxes cannot
cut one); the Cullinan rebuilt as a stepped cabochon in four claws; gold/brass
shaft banding on every tall and corner point; dentils under the south rim; boss
collets; jamb bases and capitals; mouth vault ribs; point plinths.

The old `collar` box was **deleted**: 40 units proud in the same material as the
shaft, which on self-lit geometry is no value change and no outline change — i.e.
invisible from everywhere, and still paid for in bake.

**Bays are now derived from where the points actually are** (the midpoint between
two adjacent points), not from a fraction of the wall. The fraction form put the
outer bosses at 2028 while the corner point sits at 2344, so widening the ribs
partly buried them. Midpoints cannot drift.

### 11.5 Cost

4,700 → 4,758 world brushes (+58). Lit area 962M → ~1,010M (+5%) — against a
crown that is already 84% of the map's entire lit area, so the whole pass costs
about what nine of the forty-eight skirt-tier brushes already cost. Run
`node tools/measure_lit_area.js` to see the split.

### 11.6 The second round — a design review found defects in the detail pass

A four-lens critique of the *shipped* v11.2 tree found eleven more issues. The
important ones, and what they teach:

**THE ONE THAT MATTERED: four gold blocks were standing on the causeway.**
Pushing the mouth jambs `CS(240)` proud took them to y 6672 — and the causeway's
**J4 landing** is 960 wide (x ±480) running y 6720–6880 at `TOP2`. So the jamb and
its base sat on walkable deck and passed through the landing's north guard rail.

> **No existing gate could see it.** `lint_tod_geometry`'s misplaced-wall check
> only fires on a `clip` brush with no visible solid beside it; a *visible* solid
> just drops the node from `stand` **silently**. And the reachability flood still
> walked the middle of a 960-wide landing, so that stayed green too.

Fixed by splitting the projection: `MP1` (6912) for anything reaching down to the
deck, `MP_DEEP` (6672) only for the cap and corbels, which oversail well above
head height — which is what corbelling *is*. And **§5f.9 now asserts it against
the emitted brushes**: any crown brush south of `cwY[8]`, within `CW_LAND`, below
`TOP2+96` throws. That assert caught a leftover 64-unit overhang on the base the
moment it was written.

**Other defects fixed:** the mouth keystone was ~93% behind the Cullinan's bezel
(deleted); `crown arch NS south 1` was 90% inside the front cross (skipped); the
beacon needle was *wider* than the finial pip it stood on; the rib back faces were
coplanar with C4's inner face — brass against gold, on a surface the hold-out
looks straight at; point stone colours were keyed on **array index**, and since
`CR_POINTS` lists the corners last that made the south face read ruby on one side
and emerald on the other; the front cross's ruby was 720 tall against a 448 arm,
so the *pattée* flare — the whole point of the element — never appeared; and 20
brushes carried fractional coordinates against a generator whose entire discipline
is the 16-grid.

### 11.7 NEW TOOL: `tools/audit_hidden_faces.js`

Four of the burials above were found **by hand**, by a human reading coordinates.
That does not scale and it does not repeat. This samples every face of every
brush in a label group and reports what nothing can see.

It immediately found what hand-inspection had missed: **both stiles of every
sunken panel were 100% buried.** The panel had been centred on the bay midpoint
with a literal half-width, which put its sides behind the very buttresses that
define the bay — *a frame with no sides is not a frame*. The panel now derives
its span from rib-outer to post-inner. Same for the dentil course: it runs in the
clear stretches **between** the obstructions, which is how a real dentil course
behaves anyway, and it is only 6 long because at rim height the south face has
~456 units of clear run per side and no more.

**It is advisory, not a gate** — a tenon keyed into a wall is *supposed* to be
buried. What it is for is the two cases that are always wrong: a brush buried on
all six faces (pure cost), and a visible face coplanar with a neighbour in a
different material (a z-fight).

**Known and accepted:** 16 chamfer steps on the C2 and lower-astragal corners sit
inside the corner posts — 5.2M u², **0.52%** of the crown. The posts are
deliberately wide enough to match the shafts they carry, and suppressing the
steps would mean threading an exclusion through a generic helper that runs before
`PT_CX` even exists. Priced, judged not worth it, written down.

## 12. THE VORTEX BELL (v12, 2026-08-26) — the underside becomes the show

User: *"I want even more granular detail and an even more sense of leaving the
player in awe … you can take the perspective that players climb the tower and …
can see the bottom of the crown building as they get higher. Maybe a cool
design on bottom is something worth thinking about. They look up and see this
MASSIVE bulding."*

This deliberately re-opens §5's "the skirt stays plain" decision — on the
user's explicit instruction — but it does it with §5's own measurements. The
key new number: **the underside's audience keeps getting CLOSER.** The 384-unit
legibility floor is a base-arena number; from floor 25 the slant distance to
the bell is ~11,000 (0.5° ≈ 98 u) and from floor 40 it is ~9,500 (0.5° ≈ 85 u).
So the underside can carry a second detail scale (~300 u, resolves everywhere)
and it REVEALS progressively — the higher you climb, the more the crown
resolves, which is the awe mechanic itself.

What changed (`gen_tower_map.js` §5f.2):

* **10 tiers on an ogee** (weights `SK_W`, factors `SK_F`), not 8 on a line.
  Side silhouette = a bell; from below the ring widths **accelerate toward the
  centre** (160 → 416 → 48), which is the dome-coffer depth illusion. Heights
  are weight-derived from the same span — cumulative-fraction z bounds, so the
  last floor lands exactly on `CR_SKIRT_BOT` at any `CR_SCALE`.
* **Corona teeth** — brass blocks 320 wide hanging below the gold tiers' south
  lips, keyed up and in. NOT the §5-rejected radial ribs: 2.5× that size, and
  they serrate the EDGE (outline against another value — the dentil mechanism
  turned downward) rather than lining the field.
* **Jewel collars** on brass tiers 1 and 5, stud reach clamped to the straight
  face (`umax` — an unclamped first cut would have floated studs past the
  chamfer, the sunken-panel lesson §11 again).
* **Ermine underside row** — tail-spots under the south rim, for the top third
  of the climb where the sight line has risen past the ermine's face.
* **Pearl beading on the arches** (segments 2/4/6; 7 skipped — the arches
  cross there), white on gold: no value step, pure silhouette serration.
* **THE GIRANDOLE** — the 544-sq core cube becomes an 8-stage chandelier drop:
  collar → chain → stepped ruby ORB → flaring coronet → pip → drop stone,
  every stage wider than what it hangs from (the pendilia rule at
  architectural size). Crown bottom 15008 → 13696. It completes the red
  vertical axis: beacon above, great ruby front, girandole below — and it
  takes the crown's THIRD red light. **The light sits SOUTH of the orb, not
  centred on it**: at (0, CR_CY) the origin landed inside the ruby equator
  brush — the entombed-beacon trap of §7, caught by arithmetic this time.

Gates: generator asserts green, lint 0/0/0/0 both routes walkable, bake BAKED
38.4 s, lit area 1000 → 1118M u² (skirt +101 — the ogee holds width longer),
`audit_hidden_faces` no new all-six-buried brushes. The road redesign that
shipped alongside (THE RIDGE / BROKEN STAIR / NARROWS / UNDERCROFT / PLANK
+256 / WEAVE, same span budget) is recorded in CHANGELOG v12 — its crown-facing
consequence is that the RIDGE (+256, fork 1 west) and the UNDERCROFT cistern
(−384, fork 2 west) are now the road's best crown viewpoints, up and down.
