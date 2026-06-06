---
name: tailwind-design-system
description: Build scalable design systems with Tailwind CSS v4, design tokens, component libraries, and responsive patterns. Use when creating component libraries, implementing design systems, or standardizing UI patterns.
---

# Tailwind Design System (v4)

Build production-ready design systems with Tailwind CSS v4, including CSS-first configuration, design tokens, component variants, responsive patterns, and accessibility.

## Key v4 Changes

| v3 Pattern | v4 Pattern |
|---|---|
| `tailwind.config.ts` | `@theme` in CSS |
| `@tailwind base/components/utilities` | `@import "tailwindcss"` |
| `darkMode: "class"` | `@custom-variant dark (&:where(.dark, .dark *))` |
| `theme.extend.colors` | `@theme { --color-*: value }` |
| `require("tailwindcss-animate")` | CSS `@keyframes` in `@theme` + `@starting-style` |

## Quick Start

```css
@import "tailwindcss";

@theme {
  --color-background: oklch(100% 0 0);
  --color-foreground: oklch(14.5% 0.025 264);
  --color-primary: oklch(14.5% 0.025 264);
  --color-primary-foreground: oklch(98% 0.01 264);
  --color-secondary: oklch(96% 0.01 264);
  --color-secondary-foreground: oklch(14.5% 0.025 264);
  --color-muted: oklch(96% 0.01 264);
  --color-muted-foreground: oklch(46% 0.02 264);
  --color-accent: oklch(96% 0.01 264);
  --color-accent-foreground: oklch(14.5% 0.025 264);
  --color-destructive: oklch(53% 0.25 29);
  --color-destructive-foreground: oklch(98% 0.01 264);
  --color-border: oklch(91% 0.02 264);
  --color-input: oklch(91% 0.02 264);
  --color-ring: oklch(14.5% 0.025 264);
  --color-chart-1: oklch(64% 0.25 264);
  --color-chart-2: oklch(58% 0.2 164);
  --color-chart-3: oklch(68% 0.15 44);
  --color-chart-4: oklch(72% 0.18 334);
  --color-chart-5: oklch(60% 0.22 104);
  --radius: 0.625rem;

  /* Typography */
  --font-sans: "Geist", ui-sans-serif, system-ui;
  --font-mono: "Geist Mono", ui-monospace, monospace;

  /* Animation keyframes */
  @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }
  @keyframes slide-in-from-top { from { transform: translateY(-100%); } to { transform: translateY(0); } }
  @keyframes slide-in-from-bottom { from { transform: translateY(100%); } to { transform: translateY(0); } }
}

@custom-variant dark (&:where(.dark, .dark *));

@layer base {
  * { @apply border-border; }
  body { @apply bg-background text-foreground; }
}
```

## Component Patterns

### Button Variants

```tsx
const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground shadow hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground shadow-sm hover:bg-destructive/90",
        outline: "border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground shadow-sm hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2",
        sm: "h-8 rounded-md px-3 text-xs",
        lg: "h-10 rounded-md px-8",
        icon: "h-9 w-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
);
```

### Card Component

```tsx
const Card = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("rounded-xl border bg-card text-card-foreground shadow", className)} {...props} />
);
```

### Input Component

```tsx
const Input = ({ className, type, ...props }: React.InputHTMLAttributes<HTMLInputElement>) => (
  <input
    type={type}
    className={cn(
      "flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors",
      "file:border-0 file:bg-transparent file:text-sm file:font-medium",
      "placeholder:text-muted-foreground",
      "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring",
      "disabled:cursor-not-allowed disabled:opacity-50",
      className
    )}
    {...props}
  />
);
```

## Design Tokens System

### Color System
- Use OKLCH color space for better color perception
- Semantic naming: `background`, `foreground`, `primary`, `secondary`, `muted`, `accent`, `destructive`
- Each semantic color has a `-foreground` pair for contrast

### Spacing Scale
Use the Tailwind spacing scale with `@theme`: `--spacing-*` values for custom spacings.

### Border Radius
One `--radius` token used by border utilities. Default 0.625rem (10px).

## Dark Mode

```css
@custom-variant dark (&:where(.dark, .dark *));
```

Or with CSS media query for system preference:
```css
@custom-variant dark (@media (prefers-color-scheme: dark));
```

## Container Queries

```css
@custom-variant @xs (@container (min-width: 20rem));
@custom-variant @sm (@container (min-width: 24rem));
@custom-variant @md (@container (min-width: 28rem));
@custom-variant @lg (@container (min-width: 32rem));
```

## Utility Classes

```css
@utility scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
  &::-webkit-scrollbar { display: none; }
}
```

## Component Guidelines

1. **Use `cva` (class-variance-authority)** for variants
2. **Accept `className` prop** and merge with `cn()` (clsx + tailwind-merge)
3. **Use `forwardRef`** when the component wraps an HTML element
4. **Export variants object** for consumers to create derived variants
5. **Use `displayName`** for better DevTools experience
6. **Prefers `React.HTMLAttributes<HTMLElement>`** over custom interface

## Responsive Patterns

- Mobile-first with Tailwind breakpoints
- Container queries for reusable components
- `useIsMobile()` hook for JS-responsive logic:
```tsx
const MOBILE_BREAKPOINT = 768;
export function useIsMobile() {
  const [isMobile, setIsMobile] = React.useState<boolean | undefined>(undefined);
  React.useEffect(() => {
    const mql = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`);
    const onChange = () => setIsMobile(window.innerWidth < MOBILE_BREAKPOINT);
    mql.addEventListener("change", onChange);
    setIsMobile(window.innerWidth < MOBILE_BREAKPOINT);
    return () => mql.removeEventListener("change", onChange);
  }, []);
  return !!isMobile;
}
```

## Resources

- [Tailwind CSS v4 Documentation](https://tailwindcss.com/docs)
- [shadcn/ui](https://ui.shadcn.com) — reference component library
- [OKLCH Color Picker](https://oklch.com)
- [CVA Documentation](https://cva.style)
