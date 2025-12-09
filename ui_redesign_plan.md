# UI Redesign Plan

## 1. Theme & Background
- [ ] Create `GradientScaffold` or similar wrapper to apply a subtle gradient background globally.
- [ ] Update `AppTheme` to ensure colors work well with the gradient (transparency, contrast).

## 2. Home Screen Redesign (`lib/screens/home_screen.dart`)
- [ ] Remove `TabBar` and `TabBarView`.
- [ ] Display only the main gallery feed (All images).
- [ ] Update `NavigationBar` to include a new "Collections" tab.
- [ ] Ensure the gradient background is used.

## 3. Collections Screen (`lib/screens/collections_screen.dart`)
- [ ] Create a new screen `CollectionsScreen`.
- [ ] Implement "Album" cards for:
    - Favourites
    - Archived
    - Bin
- [ ] Card Design:
    - Rounded corners (Material 3).
    - Subtle shadows.
    - Gradient/blurred background.
    - Preview of images inside (if possible, or just an icon/cover).

## 4. Collection Detail Screen (`lib/screens/collection_detail_screen.dart`)
- [ ] Create a screen to view images for a specific collection.
- [ ] Reuse the grid layout logic from `HomeScreen` (maybe extract `_buildMonthSection` or similar logic into a reusable widget).

## 5. Friends Screen Redesign (`lib/screens/friends_screen.dart`)
- [ ] Replace basic `TabBar` with a modern look (e.g., `SegmentedButton` or styled `TabBar` in a container).
- [ ] Use `Card` based layouts for friend requests and list items.
- [ ] Add animations and better spacing.

## 6. Global Polish
- [ ] Verify responsiveness.
- [ ] Check dark/light mode consistency.
