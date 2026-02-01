Here is a detailed breakdown of the **"Prism" Design Philosophy** to replicate the "design gene" for the web application.

### **1. Core Aesthetic: "Tech-Noir Minimalist"** with some **"Utilitarian Dark-Mode Futurism."** 
The overall vibe is sleek, modern, and privacy-centric. It leans heavily into a "Dark Mode Only" aesthetic that suggests high-tech processing (AI) without being overly cluttered. It feels like a utility tool built for efficiency.  The interface relies heavily on negative space, a strict dark color palette, and a signature "Electric Pastel" accent color to guide user attention

*   **Keywords:** Dark Mode, High Contrast, Soft-Tech, Matte Finish, Floating, Stealth, Precision, Gen-Z Professional.

---


### **2. Color Palette**
The application does not use a white background. It is strictly dark-mode.

**Primary Colors:**
*   **Void Black (Background):** `#0E0E0E` or `#121212` (Avoid pure `#000000` to reduce eye strain).
*   **Surface Gray (Cards/Modals):** `#1C1C1E` (Slightly lighter than background).
*   **Input/interactive Gray:** `#2C2C2E` (Used for text fields and secondary buttons).

**Accent Colors:**
*   **Prism Yellow (Primary Action):** `#F3E68F` (A pale, buttery yellow). Used for primary buttons, active states, and key calls to action.
*   **Text on Yellow:** `#000000` (Always use black text on the yellow buttons for maximum legibility).
*   **Neon Pink (Face ID/Scanning):** `#EFA9B6` (Soft pastel pink).
*   **Cyan (Loading/AI Processing):** `#4AF2EA` to `#2E86DE` gradients.
*   **Success Green:** `#2E5C38` (Background) with `#4ADE80` (Icon/Text).
*   **Destructive Red:** `#FF0000` (Vivid red for "Stop" or "Delete").

**Text Hierarchy:**
*   **Primary Text:** `#FFFFFF` (Headings, main labels).
*   **Secondary Text:** `#A1A1AA` (Subtitles, timestamps, placeholders).

---

### **3. Typography**
*   **Font Family:** Use a modern, neo-grotesque sans-serif.
    *   *Recommendation:* **Inter** (Google Fonts) or **SF Pro Display** (Apple system stack).
*   **Weights:**
    *   **Headings:** Semi-Bold (600) or Bold (700).
    *   **Body:** Regular (400).
    *   **Button Text:** Medium (500) or Semi-Bold (600).
*   **Scaling:** Large, confident headings (e.g., "Welcome Back") paired with relatively small, tight body copy.

---

### **4. Component Library (The "Atoms")**

#### **A. Buttons**
*   **Primary Button:** Full "Pill" shape (rounded-full).
    *   *Style:* Background `#F3E68F`, Text `#000000`.
    *   *Hover:* Slight opacity reduction (90%) or slight lift.
*   **Secondary/Ghost Button:** Full "Pill" shape.
    *   *Style:* Background `#2C2C2E`, Text `#FFFFFF`.
    *   *Used for:* "Decline", "Pending", "Google/Apple Login".
*   **Destructive Button:**
    *   *Style:* Background Red, Text White.

#### **B. Input Fields**
*   **Shape:** Rounded rectangles (Border radius: `12px`).
*   **Style:** Background `#2C2C2E` (Dark Gray). No visible border unless focused.
*   **Focus State:** A subtle white or yellow ring (`ring-1`).
*   **Placeholder:** Low contrast gray (`#6B7280`).

#### **C. Cards & Modals**
*   **Shape:** Soft rounded corners (Border radius: `16px` to `20px`).
*   **Background:** `#1C1C1E`.
*   **Separators:** Very subtle thin lines (`border-b border-white/10`) or usually just whitespace.
*   **Sleek Dialogs (Settings):**
    *   **Background:** `#1C1C1E` (Surface Gray).
    *   **Header:** Clean, minimal header with bold title.
    *   **List Items:** Rounded-xl items with hover effects (`hover:bg-white/5`).
    *   **Avatars:** Rounded-full with ring effects on hover.
    *   **Buttons:** Gold (`#F3E68F`) for primary actions, transitioning to dark gray for "Pending" state.

#### **E. Scrollbars**
*   **Global:** Custom dark-mode scrollbar to match the "Void Black" aesthetic.
    *   *Track:* Transparent.
    *   *Thumb:* Zinc-700 (`#3f3f46`) with rounded corners (`radius-4px`).
    *   *Hover:* Zinc-600 (`#52525b`).
    *   *Hover:* Zinc-600 (`#52525b`).
*   **Timeline Scrollbar (Gallery):** A specialized, fixed-position scrollbar on the right edge for date-based navigation. It should be distinct from the global scrollbar and provide date tooltips on hover.

#### **F. Action Icons (Gallery)**
*   **Inactive:** White/80 opacity, transparent background.
*   **Hover:** White, White/10 background.
*   **Active:** Prism Yellow (`#F3E68F`), Yellow/10 background, **Filled** icon style.
*   **Feedback:** Instant visual toggle (Optimistic UI) with automatic rollback on error.

#### **D. Navigation (Desktop Adaptation)**
*   *Mobile Original:* Floating bottom dock.
*   *Desktop Translation:* **Floating Sidebar** or **Desktop Adaptation:**
*   Split-pane layout with media grid on left, analysis results on right.
*   Right panel shows categorized friends (Recipients, Contacts, Unknowns) with toggleable selection.
*   Clean progress terminal for CV processing feedback.

**Per-Image Selection Interface:**
*   **Popover Pattern:** Clicking a thumbnail spawns a floating, context-bound popover (not a full modal) for quick recipient customization.
*   **Visual Hierarchy:** Media preview at top, detected faces section with cyan badges, scrollable friends list below.
*   **Selection State:** Selected friends use green highlight (`border-green-500/30`, `bg-green-500/10`) with checkmark icons. Unselected use neutral gray.
*   **Search Integration:** Inline debounced search within popover for quick filtering without leaving the context.
*   **Alphabetical Sorting:** Friends list consistently sorted alphabetically for predictable UX.
*   **State Visualization:** Right panel recipient cards show "Detected" badges (cyan) for CV-identified friends vs. manually added ones.

**Interaction Principles:**
*   **One-Click Workflow:** Selecting a friend in the popover auto-enables them globally, eliminating redundant toggle steps.
*   **Instant Feedback:** Avatar stacks on thumbnails and media counts in right panel update immediately upon popover changes (optimistic UI).
*   **Toggle Controls:** Global recipient toggles in right panel show enabled state with green border/background, disabled with neutral gray.
*   **Dynamic Counts:** Media counts display format "X Photos & Y Video" with singular/plural handling and real-time calculation.

---

### **11. Final Principles**
*   **"A Utility, Not A Game":** Every design decision should prioritize clarity, speed, and confidence. This is not a playful consumer app; it's a utility for managing media intelligently.
*   **Trust Through Transparency:** The user should always know "what is happening" (CV analysis progress) and "what they control" (recipient toggles, per-image customization).
*   **Hierarchy Through Negative Space:** Do not fill the screen with clutter. Use generous whitespace. Use bold labels sparingly.
*   **Consistency in Components:** Once a card style, button treatment, or modal pattern is defined, replicate it everywhere. Users recognize and trust patterns.
*   **State Visualization:** Always provide clear visual feedback for system state (analyzing, selected, disabled) through color, icons, and badges.

### **5. Visual Motifs & Imagery**

*   **3D Elements:** The app uses high-fidelity 3D renders (like the clay-style head mesh in the Face ID screen).
    *   *Instruction:* Use 3D spline-style illustrations or simplistic clay-style avatars to maintain the premium feel.
*   **Wireframes/Scanning UI:** When AI is "working" (Face Detection/Analysis), use thin lines, brackets, and mesh overlays.
*   **Avatars:** Circular. 
    *   **Default Avatars:** Pre-generated SVG images displaying the user's first name initial.
        *   **Background:** Void Black (`#121212`)
        *   **Text:** Prism Yellow (`#F3E68F`)
        *   **Font:** Sans-serif, weight 600, size ~64px (centered)
        *   **Characters:** A-Z, 0-9, and `#` (fallback for unknown characters)
        *   **Storage:** S3 bucket under `default-profile-pics/` folder (e.g., `default-profile-pics/A.svg`)
    *   **Custom Avatars:** User-uploaded photos, stored in the main S3 root and linked via `profile_pic_id`.
    *   **Consistency:** All avatar display uses the `ProfileAvatar` component (`src/components/ui/profile-avatar.tsx`).
*   **Grid Layouts:** Galleries should be tight grids with minimal gap (approx `2px` to `4px` gaps), mimicking the iOS photo gallery.
*   **Face Registration Grid:** A 3x3 overlay used during signup.
    *   *Inactive Cells:* Transparent with thin white borders.
    *   *Active/Captured Cells:* Filled with semi-transparent Green (`#4ADE80`) to indicate success.
    *   *Guidance:* Central text prompts (\"Look Left\", \"Look Up\") with large, readable typography.
    *   **Completion State:**
        *   Replace live video feed with a 3x3 grid of captured frame thumbnails.
        *   Each cell bordered with semi-transparent green (`border-green-500/30`).
        *   Empty/missing cells show dark background (`bg-black/50`).
        *   Success message below grid: Green banner with Sparkles icon and text \"Face ID Setup Complete\".
        *   \"Retake Scan\" button: Outline variant, full width, positioned below success message.

---

### **6. Interaction Design (UX)**

*   **Modals:** Use centered overlays with a darkened backdrop (backdrop-blur-sm) for critical decisions (Permissions, Confirmations).
*   **Toggles:** iOS-style toggle switches.
    *   *Off:* Dark gray track.
    *   *On:* White or Yellow track.
*   **Feedback:** Instant visual feedback. When a button is clicked, it should scale down slightly (`active:scale-95`).
*   **Interactive Branding:** The sidebar logo should be clickable and act as a "Home" button, with a subtle hover effect (opacity reduction) to indicate interactivity.
*   **Password Visibility:** Use an "Eye" icon toggle inside password fields. It should be positioned absolutely on the right, with sufficient padding to prevent text overlap.
*   **Real-Time Form Validation:**
    *   **Visual States:** Input fields show validation status via border colors (Green: `border-green-500/50`, Red: `border-destructive/50`).
    *   **Icons:** Inline validation icons positioned absolutely on the right:
        *   Green checkmark (`Check`) for available/valid
        *   Red X (`X`) for taken/invalid
        *   Spinner (`Loader2`) for checking
        *   All icons must be centered using `flex items-center justify-center`
    *   **Error Messages:** Use absolute positioning (`absolute top-full mt-0.5`) to prevent layout shift. Text color: `text-destructive`, font size: `text-xs`.
    *   **Debouncing:** Real-time checks should be debounced (500ms) to balance responsiveness with server load.
*   **Debounced Search (Friends):**
    *   **Pattern:** All friend search inputs use 500ms debouncing via `useEffect` with `setTimeout`.
    *   **Minimum Characters:** Search triggers after 2+ characters to reduce unnecessary API calls.
    *   **Auto-trigger:** Search executes automatically after user stops typing, eliminating the need to press Enter.
    *   **Visual Feedback:** Loading spinner during search, immediate result display.
*   **Friend Status Display:**
    *   **Friends Tag:** Gold pill (`bg-accent-gold/10`, `text-accent-gold`) for existing friends.
    *   **Pending Tag:** Gray pill (`bg-zinc-900/50`, `text-zinc-500`) for pending requests.
    *   **Add Button:** Yellow pill (`bg-accent-gold`, `text-black`) for new users.
    *   **Consistency:** Same status display pattern across `/friends` page and all `/settings` dialogs.
*   **RightPanel Tabs:**
    *   **Design:** Horizontal tabs at the top of the panel ("Activity" | "Friend Requests") with active tab highlighted.
    *   **Active State:** Bold text (`font-bold`) with bottom border or background change.
    *   **Inactive State:** Medium text (`font-medium`, `text-zinc-500`) with hover effect (`hover:text-white`).
    *   **Purpose:** Organizes notifications and friend requests without requiring separate pages or additional scrolling.
    *   **Dimensions:** Panel width 400px, height 70vh for compact, focused display.

### **7. Marketing Landing Page (Web Surface)**

*   **Purpose:** The web application includes a dedicated marketing landing page at `/` that introduces Prism, separate from the authenticated dashboard experience.
*   **Layout & Structure:**
    *   Full-height hero section with a split layout: left side typography, right side abstract 3D scanner visual with scanning laser animation.
    *   **Scenarios Section:** Interactive tabbed use-cases (Trips, College, Family, Team) with auto-rotating tabs and 3D perspective visual cards.
    *   **Features Section:** A bento-style grid with spotlight effect on hover and motion graphics for each feature (AutoClean, Video, Privacy, NoAds, CrossPlatform).
    *   **HowItWorks Section:** Vision Engine simulation with particle animations, friend nodes, and routing logic visualization.
    *   **WhyPrism Section:** Data blades with hover-activated micro-visuals displaying key benefits.
    *   **Privacy Section:** Infinite scrolling marquee rails emphasizing privacy statements with highlighted keywords.
    *   **CTA Section:** Terminal-styled call to action with corner bracket decorations and "REQUEST ACCESS" / "SEND FEEDBACK" buttons.
    *   **Footer:** Interactive spotlight typography on "PRISM.AI" text that follows mouse movement, with system status indicator.
    *   The landing layout is implemented via `src/app/(landing)/page.tsx` and `src/components/landing-page/*` and does not inherit the dashboard sidebar/right panel chrome.
*   **Visual System:**
    *   Uses the same dark mode palette and typography as the main app, backed by Prism-specific Tailwind tokens in `globals.css` (`--color-prism-black`, `--color-prism-surface`, `--color-prism-card`, `--color-prism-yellow`, `--color-prism-pink`, `--color-prism-cyan`, `--color-prism-zinc`).
    *   The cinematic noise overlay is a fixed-position `.bg-noise` layer using an SVG fractal noise texture to create a subtle film grain across the entire viewport.
    *   Marquee animations (`.animate-marquee-left`, `.animate-marquee-right`) create infinite scrolling text rails in the Privacy section.
    *   Animations and micro-interactions (navbar morphing on scroll, scanner sweeps, card motion, particle simulations) are driven by `framer-motion`, but must always respect the calm, utility-first tone (no chaotic motion).
*   **Navbar Behavior:**
    *   **Default State:** Full-width transparent bar with logo, nav links, email input, and "Join Waitlist" button.
    *   **Scrolled State:** Morphs into a floating island with pill shape, glassmorphic background (`backdrop-blur`), collapsed email input.
    *   Uses `framer-motion` `layout` props for smooth dimension transitions.
*   **Interaction Principles:**
    *   Primary CTAs ("Join Waitlist", "Request Access") are visually prominent with waitlist pattern for beta access.
    *   Section navigation (Features, How It Works, Privacy) uses anchor links and smooth scrolling, keeping users on the same page.
    *   The landing surface is always accessible, regardless of auth state; authenticated flows begin after the user transitions from landing into `/login` and then into `(dashboard)` routes.

### **8. Legal Pages (Privacy Policy, About)**

*   **Purpose:** Standalone legal and informational pages accessible from the landing page footer and Settings modal.
*   **Layout Pattern:**
    *   Uses `(landing)` route group for consistent public access.
    *   Shared structure: Navbar, gradient backdrop with blur effect, content container, Footer.
    *   **Privacy Policy (`/privacy-policy`):** Cyan gradient backdrop (`bg-prism-cyan/10`).
    *   **About (`/about`):** Yellow gradient backdrop (`bg-prism-yellow/10`).
*   **Component Architecture:**
    *   Content components (`privacy-policy-content.tsx`, `about-content.tsx`) in `src/components/features/legal/` accept `className` prop for styling flexibility.
    *   Used in both standalone pages and embedded in Settings modal with `prose-sm` class.
*   **Settings Integration:**
    *   Settings page sections "Privacy Policy" and "About" render the content components within a scrollable container (`max-h-[600px] overflow-y-auto`).

### **9. Engagement Forms (Waitlist and Feedback)**

*   **Purpose:** Collect early access signups and user feedback through integrated forms across landing page and dashboard.
*   **Waitlist Pattern (Navbar):**
    *   Email input visible in default navbar state, collapses on scroll.
    *   "Join Waitlist" button with loading spinner, success checkmark, or error message.
    *   Mobile menu includes separate full-width email input and button.
    *   Success state: Green background, checkmark icon, "You're in!" text.
    *   Error state: Red background, error message text.
*   **CTA Section Pattern:**
    *   Default view: Terminal-styled card with corner brackets, "REQUEST ACCESS" and "SEND FEEDBACK" buttons.
    *   Slide-in transition: Card slides left, form slides in from right.
    *   Waitlist form: Email input, submit button.
    *   Feedback form: Email input, feedback type dropdown, message textarea, submit button.
    *   Back button to return to default view.
    *   Success state: Centered checkmark with confirmation message.
*   **Dashboard Popover Pattern:**
    *   `MessageSquarePlus` icon triggers popover from header.
    *   Pill-based feedback type selector (General, Feature Request, Bug Report, Praise, Complaint).
    *   Compact textarea for message input.
    *   Auto-populated `user_id` from auth context (no email required for logged-in users).
*   **Form Styling:**
    *   Inputs: `bg-[#1A1A1A]`, `border-white/10`, `rounded-xl`, `focus:border-prism-yellow/50`.
    *   Buttons: `bg-prism-yellow`, `text-black`, `hover:bg-white`.
    *   Error buttons: `bg-red-500/80`, `text-white`.
    *   Success indicators: Green checkmark icon, green background accent.