# Release Sequence Enforcement

> [!CRITICAL]
> **NEVER push `appcast.xml` before the GitHub Release is fully published and the assets are uploaded.**

## Anti-Pattern (What went wrong)
- Committing `appcast.xml` along with code changes and pushing them simultaneously.
- Result: Sparkle points to a non-existent download link, causing update failures for users.

## Correct Workflow
1.  **Commit & Push Code**: Handle everything except `appcast.xml`.
2.  **Create Release**: Use `gh release create` or the web UI. Upload the DMG.
3.  **Generate Appcast**: Local run of `release.sh`.
4.  **Final Push**: Commit and push `appcast.xml` ONLY after step 2 is confirmed.
