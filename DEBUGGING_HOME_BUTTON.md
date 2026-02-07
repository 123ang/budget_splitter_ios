# Debugging the Home Button (Back to Trip List)

## 1. Run with debug prints

The app has `#if DEBUG` prints that only run in **Debug** builds (not Release).

1. In Xcode, run the app on simulator or device ( **Run** or ⌘R ).
2. Open the **Debug console** (View → Debug Area → Activate Console, or ⇧⌘C).
3. Select a trip so you see the tab bar (Overview, Expenses, Settle up, Members, Settings).
4. Tap the **home** button (house icon) on **Overview** – you should see:
   ```
   [HomeBtn] Tap received. dataStore id=..., events=..., selectedEvent=...
   [HomeBtn] clearSelectedTrip() called. mainThread=true, selectedEvent before=...
   [HomeBtn] selectedEvent set to nil on main thread. selectedEvent now=nil
   ```
5. Select a trip again, switch to **Expenses** (or Settle up / Members / Settings), then tap the home button.

**What to check:**

- **If you see NO `[HomeBtn]` lines** when tapping home on Expenses/Settle/Members/Settings  
  → The tap is not reaching the button (button not in the hierarchy, or another view is on top). Focus on why the toolbar/button isn’t active on that tab.

- **If you see `[HomeBtn] Tap received` but NO `clearSelectedTrip() called`**  
  → Unlikely; would mean `clearSelectedTrip` isn’t called from the button.

- **If you see both** but the screen doesn’t go back to the trip list  
  → `selectedEvent` is being set to `nil` but the UI isn’t updating (e.g. not on main thread, or a different `dataStore` instance). Check that `dataStore id=` is the same when you tap from different tabs.

- **If `dataStore id=` is different** when tapping from different tabs  
  → Some tabs might not be getting the same `environmentObject(dataStore)`; fix the environment injection so every tab uses the same store.

## 2. Use a breakpoint (step-through debugging)

1. In Xcode, open `BudgetSplitterApp.swift` and find `BackToTripsButton` (the `Button { ... }`).
2. Click in the **gutter** (left of the line numbers) next to the line `dataStore.clearSelectedTrip()` to add a breakpoint (blue arrow).
3. Run the app (⌘R), select a trip, go to another tab (e.g. Expenses), tap the home button.
4. If execution stops at the breakpoint: the tap is working; step over (F6) and step into (F7) to see what `clearSelectedTrip()` does.
5. If execution never stops: the button tap isn’t firing on that tab (same as “no [HomeBtn] prints” above).

## 3. Inspect the view hierarchy (is the button there?)

1. Run the app and go to a tab where the home button doesn’t work.
2. In Xcode menu: **Debug → View Debugging → Capture View Hierarchy**.
3. In the captured view tree, look for the button (e.g. search for “Back to trip list” or the house icon). Check if it’s covered by another view or has zero size.

## 4. Remove debug prints for Release

The prints are wrapped in `#if DEBUG`, so they don’t run in Release. To remove them later, delete the `#if DEBUG` / `#endif` blocks and the `print(...)` lines in:

- `BudgetSplitterApp.swift` (BackToTripsButton)
- `BudgetDataStore.swift` (clearSelectedTrip)
