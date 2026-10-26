# Backlog of a recipe app, in tracker order

## P-1 Search recipes by ingredient
Goal: a user types an ingredient and sees each recipe that uses it.
User value: home cooks find a recipe for what they already have.
Metric: share of sessions with a search. No data exists yet.
Acceptance: a search for "egg" lists each recipe with egg, and no other recipe. An empty search shows the full list.
Out of scope: search by tag.
Open questions: none.
Size: S

## P-2 Share a recipe link
Goal: a user shares a link that opens the recipe.
User value: cooks send recipes to friends.
Acceptance: the link opens the recipe on a device with the app.
Size: S

## P-3 Offline mode for saved recipes
Goal: saved recipes open with no network.
User value: cooks use recipes in a kitchen with a weak signal.
Metric: share of recipe opens that fail. 4% in the last 30 days.
Acceptance: a saved recipe opens in airplane mode, with its photo.
Out of scope: offline search.
Open questions: none.
Size: L

## P-4 Fix the crash when a recipe has no photo
Goal: a recipe with no photo opens.
User value: every recipe opens.
Metric: crash count on the recipe screen. 120 in the last 7 days.
Acceptance: a recipe with no photo opens and shows the placeholder.
Out of scope: photo upload.
Open questions: none.
Size: XS
Blocks: P-5

## P-5 Recipe photo gallery
Goal: a user swipes through all photos of a recipe.
User value: cooks see each step.
Metric: photo views for each recipe open. No data exists yet.
Acceptance: a recipe with three photos shows three pages.
Out of scope: photo upload.
Open questions: how many photos at most? The gate owner answers.
Size: M
