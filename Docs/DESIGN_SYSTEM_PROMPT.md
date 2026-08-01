# Design System Reproduction Prompt

Use this prompt to build **another role dashboard** (different domain, same product family) that feels visually and structurally identical to the UNZA Invigilator Dashboard. Fill in the `{{PLACEHOLDERS}}` for the new product; keep every design rule below unchanged.

---

## Prompt (copy from here)

```
Build a Next.js App Router dashboard for {{PRODUCT_NAME}} — {{ROLE_NAME}} role —
that matches the UNZA Invigilator Dashboard design system exactly. New domain and
copy only; layout language, tokens, components, and interaction patterns must stay
identical so the UI feels like the same product family.

────────────────────────────────────────
1. VISUAL IDENTITY (LOCKED)
────────────────────────────────────────

Brand palette (CSS variables — do not invent new hues):

  --background / --surface:     #f3f4f6
  --surface-muted:              #eceff3
  --ink / --foreground:         #0b0f19
  --muted:                      #6b7280
  --brand-gold (unza-gold):     #f7a81b
  --brand-green (unza-green):   #008b45
  --brand-red (unza-red):       #ed1c24

Semantic usage:
- Ink (#0b0f19) = primary actions, active nav, live timers, page titles
- Gold = warning / highlight accent (hover borders, soft amber washes)
- Green = success / positive metrics
- Red = danger / incidents / absences / destructive confirm
- Muted gray = secondary labels, helper text, inactive nav
- Soft gray page canvas (#f3f4f6), never flat pure white full-bleed pages
  for authenticated screens

Atmosphere:
- Page background is soft gray with subtle dual radial washes:
  gold at top-right (~12% opacity), green at bottom-left (~8% opacity)
- White content panels sit on that canvas with a soft diffuse shadow:
  shadow-[0_10px_30px_rgba(15,23,42,0.04)]
- No purple themes, no neon glow, no multi-layer dramatic shadows,
  no dark-mode default, no cream/terracotta “AI default” look

Typography:
- Font: Inter (next/font, --font-inter), ui-sans-serif fallback
- Page title (header h1): text-3xl md:text-4xl, font-bold, tracking-tight, text-ink
- Section titles (h2): text-lg font-semibold text-ink
- Section helper: text-sm text-muted under the h2
- Body / labels: text-sm; muted labels for dt / captions
- Large metric numbers: text-4xl md:text-5xl font-bold tracking-tight tabular-nums
- Live countdown numbers: font-mono, bold, tabular-nums
- Selection highlight: gold mixed ~35% with white

Shape language (universal):
- Corner radius is almost always rounded-[10px] — panels, tiles, buttons,
  badges, inputs (in-app), avatar squares, nav items, empty states
- Login is the exception: square inputs and CTA (rounded-none) for a
  sharper auth split

Motion:
- Content area uses a single intentional entrance: fade-up
  (opacity 0→1, translateY 10px→0, 0.45s ease-out)
- Transitions elsewhere are short color/hover transitions (~200ms)
- Do not add decorative animation noise

────────────────────────────────────────
2. APP SHELL (AUTHENTICATED)
────────────────────────────────────────

Structure:
- Fixed left sidebar, width 290px, white, rounded-r-[10px],
  soft right shadow (8px 0 30px rgba(15,23,42,0.04))
- Main column: pl-[290px], padding p-4 md:p-8
- Brand mark centered at top of sidebar (large logo ~144×144, object-contain)
- Nav items: lowercase labels, Heroicons 24/outline, gap-3, rounded-[10px],
  px-3 py-3, text-sm font-medium
  - Active: bg-ink text-white + shadow-lg shadow-black/10
  - Idle: text-muted; hover → bg-surface-muted text-ink
- Sign out pinned at bottom of sidebar as a muted text button
  (no loud red logout)

Header row (top of main):
- Left: page title (h1) as defined above
- Center (sm+): search bar — h-12, max-w-md, rounded-[10px],
  bg-surface-muted, magnifying-glass + optional mic icon,
  focus-within → white + ring-4 ring-ink/5
- Right: compact user chip — white/70 backdrop-blur, rounded-[10px],
  square initials avatar with gold→amber gradient, name (semibold) +
  role (xs, capitalize, muted)

────────────────────────────────────────
3. LOGIN (DISTINCT FROM APP CHROME)
────────────────────────────────────────

Split screen (lg:grid-cols-2):
- Left half: solid black, brand logo centered large (up to ~256×256)
- Right half: white, form not in a card — sits on the page
- Headline: “Sign in As {{ROLE_LABEL}}” — text-2xl font-semibold tracking-tight
- Fields: square borders (border-black/20), white fill, focus black ring
- Primary CTA: full-width black rectangle, h-11, white text
- Errors in brand-red text, no alert cards
- Mobile: black brand band on top (~220px min), form below

────────────────────────────────────────
4. CORE UI PRIMITIVES (REUSE THESE PATTERNS)
────────────────────────────────────────

Tile (primary content atom):
- White panel, min-h ~160px (quick actions ~140px), p-6, rounded-[10px],
  soft shadow, transparent border that gains accent on hover
- Top row: optional icon in 44×44 muted square + optional uppercase
  subtitle chip (11px, tracking-wide, surface-muted)
- Bottom: muted title (text-sm) + huge metric value OR short helper blurb
- Accents: default | gold | green | red | ink (hover border tint only)
- Optional soft gradient wash for primary CTAs
  (e.g. from-white to-emerald-50/60, rose-50/50, amber-50/60)
- Tiles may be links or buttons; non-interactive tiles stay as divs

Button variants:
- primary: bg-ink text-white
- secondary: white + border-black/8
- ghost: transparent, hover black/5
- danger: #b91c1c
- Sizes: sm h-9, md h-11, lg h-12; all rounded-[10px], font-medium

Badge tones:
- neutral: surface-muted / muted
- success: green/10 bg + green text
- warning: gold/15 bg + amber-800 text
- danger: red/10 bg + red text
- info: slate-900/5 + ink
- Shape: rounded-[10px], text-xs font-semibold tracking-wide

Form fields (in-app, not login):
- rounded-[10px], border-black/8, bg-surface-muted, px-4 py-3, text-sm
- Focus: white bg, border-ink/20, ring-4 ring-ink/5
- Labels: text-sm font-medium text-ink/80, mb-1.5
- Field stacks with space-y-1.5

Toaster:
- sonner, top-right, richColors, closeButton, Inter font

Icons:
- @heroicons/react/24/outline only; consistent 20–24px sizing

────────────────────────────────────────
5. PAGE COMPOSITION PATTERNS
────────────────────────────────────────

Home / dashboard:
1. Responsive stats grid (sm:2 / xl:3) of metric Tiles
2. “Quick actions” section — h2 + one helper line + 2–4 action Tiles
3. Domain list section — h2 + helper + card grid (lg:2 columns)

Workspace pages (lookup, registers, reports, forms):
- Prefer two-column layouts on xl:
  left = controls / form panel, right = preview / list / results
- Each panel: white, rounded-[10px], p-6, soft shadow
- Section intros always: title + one muted sentence
- Empty states: centered icon in muted square, short title + helper,
  min-height ~280px inside the panel — no illustrated empty art
- Status callouts: ink bar for live/countdown; surface-muted for
  blocked/disabled guidance; gold/10 for soft warnings; red/5 for errors
- Definition lists for metadata: muted dt + medium/semibold dd;
  mono for IDs / codes / countdowns

List / register rows:
- Flat white list or simple stacked rows; badges for status
- Filter input above the list; keep chrome quiet

Confirmations for destructive actions:
- Two-step inline confirm (button flips to danger “Confirm …” briefly),
  not modal dialogs by default

Feedback:
- Toast success/error for mutations; inline red for form validation /
  load failures at page top when API is down

────────────────────────────────────────
6. INFORMATION HIERARCHY RULES
────────────────────────────────────────

- One page title in the header; do not duplicate a huge hero under it
- Each section has one job: stats, shortcuts, or domain entities
- Cards/tiles are interaction or metric containers — not decorative wrappers
- Prefer whitespace (space-y-8 between major sections, gap-4 in grids)
  over borders and nested boxes
- Avoid pill clusters, stat strips of tiny chips, icon-only toolbars,
  and multi-promo banners
- Lowercase nav labels; Title Case / sentence case for page content
- Role dashboards stay operational and calm — institutional, not playful
────────────────────────────────────────
8. DOMAIN SWAP (CHANGE ONLY THIS)
────────────────────────────────────────

Product: {{PRODUCT_NAME}}
Organization / brand asset: {{LOGO_PATH}} (same logo treatment as UNZA.png)
Role: {{ROLE_NAME}}
Login headline: Sign in As {{ROLE_LABEL}}

Sidebar routes (same chrome, new labels/icons as needed):
{{NAV_ITEMS}}  // e.g. dashboard, primary-action, register, exceptions, reports

Dashboard metrics (same Tile grid language):
{{STAT_TILES}}

Quick actions (same Tile shortcuts):
{{QUICK_ACTIONS}}

Primary operational flow (two-panel workspace like check-in):
{{PRIMARY_FLOW_DESCRIPTION}}

Secondary flows:
{{SECONDARY_FLOWS}}

Tone of copy: short, procedural, institutional English — same voice as
“Start and end sessions here” / “Lookup results appear here for visual
verification.”

────────────────────────────────────────
9. ACCEPTANCE CHECKLIST
────────────────────────────────────────

- [ ] Same palette tokens and soft dual radial page atmosphere
- [ ] 290px white sidebar, ink active nav, large centered brand mark
- [ ] Header = bold title + muted search + gold-initials user chip
- [ ] Universal 10px radius (except square login controls)
- [ ] White soft-shadow panels on gray canvas — no heavy card chrome
- [ ] Stats as large tabular numbers in Tiles; quick actions as Tiles
- [ ] Workspace pages use left control / right preview pattern
- [ ] Inter everywhere; Heroicons outline only
- [ ] fade-up on main content; restrained hover transitions
- [ ] Login remains black/white split with logo hero — no in-app shell
- [ ] Someone familiar with the Invigilator Dashboard should recognize
      this as the same design system within one glance
```

---

## Reference snapshot (this codebase)

| Token / pattern | Value / rule |
|-----------------|--------------|
| Canvas | `#f3f4f6` + gold/green radial washes |
| Ink | `#0b0f19` (primary UI) |
| Accents | Gold `#f7a81b`, Green `#008b45`, Red `#ed1c24` |
| Radius | `10px` almost everywhere |
| Shadow | `0 10px 30px rgba(15,23,42,0.04)` |
| Font | Inter |
| Icons | Heroicons outline |
| Shell | Fixed 290px sidebar + padded main |
| Auth | Black / white split, square controls |
| Motion | `.animate-fade-up` on page content |

### Example filled placeholders (Lecturer Dashboard)

```
{{PRODUCT_NAME}} = UNZA Lecturer Dashboard
{{ROLE_NAME}} / {{ROLE_LABEL}} = lecturer
{{LOGO_PATH}} = /UNZA.png
{{NAV_ITEMS}} = dashboard, my exams, attendance overview, incidents review, reports
{{STAT_TILES}} = live exams, venues today, students expected, absences, scripts pending, open incidents
{{QUICK_ACTIONS}} = view live exam, attendance overview, review incident, download report
{{PRIMARY_FLOW_DESCRIPTION}} = select exam → browse allocated students → mark notes / confirm scripts
{{SECONDARY_FLOWS}} = incident review list; generate session report metadata
```

Keep visual and structural rules locked. Only swap domain copy, routes, and data.
