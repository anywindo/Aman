## Aman Baseline Smoke Test

Use this checklist after cloning or migrating the project to confirm that the security checks still execute as expected.

1. **Build the macOS app in Debug configuration**
   - Open `Aman.xcodeproj` in Xcode.
   - Select the *Aman* scheme and *My Mac* destination.
   - Build (`⌘B`) and confirm the target compiles without errors.

2. **Run a full scan**
   - Launch the app (`⌘R`).
   - Click **Start Scan**.
   - Observe the progress indicator until the scan completes (approximately 30–60 seconds depending on host).

3. **Verify result population**
   - Ensure the results list shows entries across the expected categories (CIS Benchmark, Privacy, Security).
   - Confirm the status summary reflects Pass/Review/Action counts once the scan ends.

4. **Filter checks**
   - Use the segmented control to switch between categories and confirm the list updates accordingly.

5. **Reset state**
   - Click **Clear Results** and confirm the list empties and status summary reverts to “No checks run.”

6. **Manual spot checks (optional)**
   - Compare one or two findings with the system settings on the test Mac to validate accuracy.
   - Capture console logs if any module reports an unexpected error.

> Record any issues in the project tracker before proceeding to Phase 1 enhancements.
