# Home & About Aesthetic Overhaul PRD
## "Bold Emerald Terminal" - Design Specification

---

## Overview
Aesthetic overhaul of Home and About pages blending **37Signals typographic confidence** with **subtle Amiga-era precision**, while preserving the **Emerald Terminal** identity.

---

## Design Philosophy

### Core Identity: "Bold Emerald Terminal"
- **37Signals Influence**: Massive headlines, generous whitespace, narrow reading columns, uppercase section labels
- **Amiga Influence**: Chunky 2px borders, sharp 4px corners, pixel-precise edges, high-contrast elements
- **Terminal Identity**: Emerald green palette, monospace accents, structured information density

---

## Typography System

### Base Scale
| Element | Value | Notes |
|---------|-------|-------|
| Base font size | 18px | Up from browser default 16px |
| Body line-height | 1.7 | Generous reading rhythm |
| Content max-width (prose) | 720px | Narrower for focus |
| Content max-width (grids) | 1120px | Keep current for cards |

### Headings
| Level | Desktop | Mobile | Letter-spacing | Line-height |
|-------|---------|--------|----------------|-------------|
| H1 (Hero) | 4rem | 2.5rem | -0.02em | 1.1 |
| H2 | 2.25rem | 1.75rem | -0.02em | 1.15 |
| H3 | 1.5rem | 1.25rem | -0.01em | 1.2 |

### Accent Typography
| Element | Value |
|---------|-------|
| Section labels | 0.875rem, weight 700, 0.18em tracking |
| Monospace accents | "JetBrains Mono", 0.9rem |

---

## Layout & Spacing

### Section Spacing
```
Before: clamp(3rem, 6vw, 4.5rem)
After:  clamp(4rem, 8vw, 7rem)
```

### Hero Section
- Full-width emerald background
- Centered content, max-width: 640px
- Generous top padding: clamp(6rem, 10vw, 9rem)

### Card Grid Spacing
- Gap: 1.5rem (up from 1.4rem)
- Card padding: 2rem (up from 1.5rem)

---

## Component Specifications

### Feature Cards
| Property | Value |
|----------|-------|
| Border-radius | 4px (from 8px) |
| Border-width | 2px (from 1px) |
| Top accent | 2px solid #34d399 |
| Background | var(--sf-panel-bg) |
| Shadow | var(--sf-panel-shadow) |

### Terminal Cards
- Keep existing macOS-style header
- Add subtle scanline overlay:
  ```css
  background: repeating-linear-gradient(
    0deg,
    transparent,
    transparent 2px,
    rgba(0, 0, 0, 0.03) 2px,
    rgba(0, 0, 0, 0.03) 4px
  );
  ```
- Hover glow: `0 0 40px rgba(16, 185, 129, 0.2)`

### Buttons
- Padding: 1rem 2rem (more chunky)
- Border: 2px solid (darker shade)
- Keep existing colors

---

## Color System

### CSS Custom Properties
```css
:root {
  --terminal-glow: 0 0 20px rgba(16, 185, 129, 0.15);
  --accent-bright: #34d399;
  --border-chunky: 2px;
  --radius-sharp: 4px;
}
```

### Existing Palette (Preserve)
- `$scale-dark: #063b30`
- `$scale-medium: #0b5a47`
- `$scale-light: #0d6852`
- `$scale-pale: #edf4ef`
- Primary: #10b981

---

## Copy Changes

### Home Page (`content/en/_index.md`)

**Hero Kicker:**
```
Before: "Native Rust constraint solving for planning and optimization"
After:  "CONSTRAINT SOLVING FOR RUST"
```

**Hero Summary:**
```
Before: "Model shifts, routes, visits, and assignments with ordinary Rust types, 
then optimize them with Constraint Streams, incremental scoring, and solver events 
that fit application code."

After: "Build planning software in Rust. Model your domain with ordinary types, 
optimize with Constraint Streams, and ship production-grade schedulers without 
the academic headache."
```

### About Page (`content/en/about/index.md`)

**Hero Summary:**
```
Before: "SolverForge is a Rust-native constraint solving ecosystem for planning, 
scheduling, routing, and allocation systems. It combines typed domain models, 
Constraint Streams, incremental scoring, and companion crates for real optimization 
workflows."

After: "Rust-native constraint solving for the real world. No PhD required."
```

---

## Responsive Strategy

### Breakpoints
| Range | Target |
|-------|--------|
| < 768px | Mobile: Single column, hero 2.5rem, section padding 3rem min |
| 768-991px | Tablet: Two columns where appropriate |
| > 991px | Desktop: Full layout, maximum scale |

### Functional Requirements
- Touch targets: minimum 44px
- Line length: max 75 characters
- Section padding: never less than 3rem
- Typography: fluid via `clamp()`

---

## File Structure

### New Files
```
assets/scss/
├── _typography_bold.scss      # Typography overrides
└── _amiga_components.scss     # Component refinements
```

### Modified Files
```
assets/scss/_styles_project.scss    # Add imports
content/en/_index.md                # Copy updates
content/en/about/index.md           # Copy updates
```

---

## Reversibility Plan

### Method 1: Git Branch (Recommended)
```bash
git checkout -b feature/bold-emerald-typography
# Make all changes
# To revert: git checkout main
```

### Method 2: Import Toggle
In `_styles_project.scss`:
```scss
// Comment out to revert:
@import "typography_bold";
@import "amiga_components";
```

### Rollback Checklist
- [ ] Remove imports from `_styles_project.scss`
- [ ] Delete `_typography_bold.scss`
- [ ] Delete `_amiga_components.scss`
- [ ] Restore original markdown files

---

## Implementation Checklist

### Phase 1: Typography
- [ ] Create `_typography_bold.scss`
- [ ] Base font-size: 18px
- [ ] Hero H1: 4rem desktop, 2.5rem mobile
- [ ] H2: 2.25rem
- [ ] Section labels: 0.875rem, 0.18em tracking
- [ ] Import in `_styles_project.scss`

### Phase 2: Layout
- [ ] Section padding: clamp(4rem, 8vw, 7rem)
- [ ] Content max-width: 720px (prose)
- [ ] Hero content max-width: 640px
- [ ] Update spacing variables

### Phase 3: Components
- [ ] Create `_amiga_components.scss`
- [ ] Card radius: 4px, border: 2px
- [ ] Add top accent border (#34d399)
- [ ] Terminal scanline overlay
- [ ] Button padding: 1rem 2rem

### Phase 4: Copy
- [ ] Update Home hero kicker
- [ ] Update Home hero summary
- [ ] Update About hero summary

### Phase 5: Testing
- [ ] Desktop (1920px)
- [ ] Desktop (1440px)
- [ ] Tablet (768px)
- [ ] Mobile (375px)
- [ ] Build verification

---

## Success Criteria

1. **Visual Impact**: Hero headline commands attention immediately
2. **Readability**: Body text comfortable at 18px/1.7 line-height
3. **Rhythm**: Sections breathe with generous padding
4. **Identity**: Still recognizably "Emerald Terminal"
5. **Reversibility**: Can be rolled back in under 2 minutes

---

## Notes

- Keep existing triangular section arrows (`.td-arrow-down`)
- No additional hover animations (static design)
- No image treatment required
- Preserve all existing color values
- Changes additive only - don't modify existing rules when possible
