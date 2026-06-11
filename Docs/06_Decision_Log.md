# Decision Log

## SwiftPM First

The project uses SwiftPM for reproducible local builds without requiring a generated Xcode project.

## Shared Core

All product truth logic lives in `LocalForgeCore`; the app and CLI stay thin.

## V1 Stops at Recommend

Mutating Git, cleanup, and automatic fixes are blocked in V1.
