# Haptic Feedback Guidelines

## Overview

This document provides comprehensive guidelines for implementing tactile feedback in cstatiWarehouse iOS app using `UIFeedbackGenerator`. Haptic feedback enhances user experience by providing physical confirmation of actions and states.

## Haptic Feedback Types

iOS provides three main types of haptic feedback generators:

### 1. UIImpactFeedbackGenerator

**Purpose**: Physical collision or impact sensation

**Styles**:
- `.light` - Subtle, delicate interactions
- `.medium` - Standard interactions
- `.heavy` - Significant, important interactions
- `.soft` - Gentle, smooth interactions (iOS 13+)
- `.rigid` - Sharp, precise interactions (iOS 13+)

**Use Cases**:
- Item selection/deselection
- Toggle switches
- Slider value changes
- Pull-to-refresh completion
- Drag and drop

### 2. UINotificationFeedbackGenerator

**Purpose**: Communicate task completion or status

**Types**:
- `.success` - Task completed successfully
- `.warning` - Warning or caution needed
- `.error` - Task failed or error occurred

**Use Cases**:
- Form submission success/failure
- Item creation/update confirmation
- Archive operation completion
- Delete confirmation
- Network request results

### 3. UISelectionFeedbackGenerator

**Purpose**: Selection change in a list or picker

**Use Cases**:
- Scrolling through picker values
- Segmented control changes
- Tab switching
- Filter selection
- Category selection

## Implementation Patterns

### Pattern 1: Haptic Service (Recommended)

Create centralized haptic service for consistent usage across app.

**`ios/cstatiWarehouse/Services/Haptics/HapticService.swift`**:

```swift
//
//  HapticService.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import UIKit

/// Centralized haptic feedback service
final class HapticService {
    
    // MARK: - Singleton
    
    static let shared = HapticService()
    
    private init() {}
    
    // MARK: - Impact Feedback
    
    /// Light impact - subtle interactions
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Medium impact - standard interactions
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Heavy impact - significant interactions
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Soft impact - gentle, smooth interactions
    func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Rigid impact - sharp, precise interactions
    func rigidImpact() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    /// Success notification - task completed successfully
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Warning notification - caution needed
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    /// Error notification - task failed
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    /// Selection changed - picker, list, segmented control
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
```

### Pattern 2: View Extension

Add convenience methods to View for SwiftUI integration.

**`ios/cstatiWarehouse/Extensions/View+Haptics.swift`**:

```swift
//
//  View+Haptics.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import SwiftUI

extension View {
    /// Trigger haptic feedback on tap
    func hapticFeedback(_ style: HapticFeedbackStyle) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                style.trigger()
            }
        )
    }
}

enum HapticFeedbackStyle {
    case light
    case medium
    case heavy
    case soft
    case rigid
    case success
    case warning
    case error
    case selection
    
    func trigger() {
        switch self {
        case .light:
            HapticService.shared.lightImpact()
        case .medium:
            HapticService.shared.mediumImpact()
        case .heavy:
            HapticService.shared.heavyImpact()
        case .soft:
            HapticService.shared.softImpact()
        case .rigid:
            HapticService.shared.rigidImpact()
        case .success:
            HapticService.shared.success()
        case .warning:
            HapticService.shared.warning()
        case .error:
            HapticService.shared.error()
        case .selection:
            HapticService.shared.selectionChanged()
        }
    }
}
```

## cstatiWarehouse Integration Points

### 1. Warehouse Tab (MyWarehouseView)

#### Item Selection
```swift
// In warehouseRootRowButton
Button {
    HapticService.shared.lightImpact()
    presenter.editItemRequested(item)
} label: {
    WarehouseItemRow(item: item)
}
```

#### Archive Action
```swift
// In archiveItemRequested
func archiveItemRequested(_ item: Item) {
    HapticService.shared.mediumImpact()
    pendingArchiveItem = item
    interactor.prepareArchive(for: item)
}

// On archive success
func itemArchived(_ item: Item) {
    HapticService.shared.success()
    // ... rest of logic
}
```

#### Delete Action
```swift
// In confirmHardDelete
func confirmHardDelete() {
    guard let item = pendingDeleteItem else { return }
    HapticService.shared.warning() // Warning before destructive action
    interactor.deleteItem(id: item.id)
    pendingDeleteItem = nil
}

// On delete success
func itemDeleted(id: UUID) {
    HapticService.shared.heavyImpact() // Heavy for destructive action
    // ... rest of logic
}
```

#### Pull to Refresh
```swift
// In performPullToRefresh
func performPullToRefresh() async {
    // ... loading logic
    HapticService.shared.softImpact() // Soft impact on completion
    finishPullToRefreshIfNeeded()
}
```

#### Scope Switching
```swift
// In selectScope
func selectScope(_ newScope: WarehouseScope) {
    guard newScope != currentScope else { return }
    HapticService.shared.selectionChanged()
    currentScope = newScope
    // ... rest of logic
}
```

#### Filter Application
```swift
// In applyFilters
func applyFilters(_ filters: WarehouseFilters) {
    HapticService.shared.lightImpact()
    currentFilters = filters
    rebuildSections()
}
```

### 2. Item Edit (ItemEditView)

#### Save Success
```swift
// In ItemEditInteractor after successful save
func itemSaved(_ item: Item) {
    HapticService.shared.success()
    output?.itemSaved(item)
}
```

#### Validation Error
```swift
// In ItemEditPresenter validation
func saveButtonTapped() {
    guard validateForm() else {
        HapticService.shared.error()
        return
    }
    // ... save logic
}
```

#### Photo Upload
```swift
// After successful photo upload
func photoUploaded(_ url: URL) {
    HapticService.shared.lightImpact()
    photoURL = url
}
```

#### Quantity Stepper
```swift
Stepper(value: $quantity, in: 0...9999) {
    Text("Количество: \(quantity)")
}
.onChange(of: quantity) { _, _ in
    HapticService.shared.selectionChanged()
}
```

### 3. Organization Tab (OrganizationView)

#### Organization Switch
```swift
// In selectOrganization
func selectOrganization(_ summary: OrganizationSummary) {
    HapticService.shared.mediumImpact()
    interactor.selectActiveOrganization(summary.id)
}
```

#### Create Organization
```swift
// On organization created
func organizationCreated(_ summary: OrganizationSummary) {
    HapticService.shared.success()
    // ... rest of logic
}
```

#### Join Organization
```swift
// On join success
func organizationJoined(_ summary: OrganizationSummary) {
    HapticService.shared.success()
    // ... rest of logic
}

// On join failure
func joinAlreadyInOrganization() {
    HapticService.shared.warning()
    // ... show message
}
```

#### Role Change
```swift
// After role change
func roleChanged(for member: OrganizationMember) {
    HapticService.shared.mediumImpact()
    // ... update UI
}
```

### 4. Settings Tab (SettingsView)

#### Logout
```swift
Button("Выйти") {
    HapticService.shared.warning()
    showLogoutConfirmation = true
}
```

#### Toggle Switches
```swift
Toggle("Push-уведомления", isOn: $notificationsEnabled)
    .onChange(of: notificationsEnabled) { _, _ in
        HapticService.shared.lightImpact()
    }
```

#### Language Selection
```swift
Picker("Язык", selection: $selectedLanguage) {
    ForEach(AppLanguage.allCases) { language in
        Text(language.displayName).tag(language)
    }
}
.onChange(of: selectedLanguage) { _, _ in
    HapticService.shared.selectionChanged()
}
```

### 5. Authentication (LoginView)

#### Login Success
```swift
func loginSucceeded() {
    HapticService.shared.success()
    router?.navigateToMain()
}
```

#### Login Error
```swift
func loginFailed(error: String) {
    HapticService.shared.error()
    errorMessage = error
}
```

#### OAuth Button Tap
```swift
Button {
    HapticService.shared.lightImpact()
    presenter.telegramLoginTapped()
} label: {
    TelegramLoginButton()
}
```

## Best Practices

### 1. Timing and Preparation

**DO**: Prepare generators before use
```swift
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.prepare() // Reduces latency
generator.impactOccurred()
```

**DON'T**: Create generators without preparation
```swift
// Avoid - may have noticeable latency
UIImpactFeedbackGenerator(style: .medium).impactOccurred()
```

### 2. Frequency

**DO**: Use haptics sparingly for important interactions
```swift
// Good - important action
func deleteItem() {
    HapticService.shared.warning()
    performDelete()
}
```

**DON'T**: Overuse haptics for every minor interaction
```swift
// Bad - too frequent
func scrollViewDidScroll() {
    HapticService.shared.lightImpact() // NO!
}
```

### 3. Consistency

**DO**: Use consistent haptic patterns for similar actions
```swift
// All destructive actions use warning
func deleteItem() { HapticService.shared.warning() }
func archiveItem() { HapticService.shared.warning() }
```

**DON'T**: Use random haptic types
```swift
// Bad - inconsistent
func deleteItem() { HapticService.shared.success() } // Wrong!
```

### 4. User Preferences

**DO**: Respect system haptic settings
```swift
// iOS automatically respects user's haptic settings
// No need to check manually
```

**DON'T**: Force haptics when disabled by user
```swift
// Bad - don't override system settings
if UIDevice.current.userInterfaceIdiom == .phone {
    // Force haptic even if disabled
}
```

### 5. Device Compatibility

**DO**: Use haptics only on supported devices
```swift
// Haptics work automatically on:
// - iPhone 7 and later
// - Apple Watch Series 4 and later
// iOS handles gracefully on unsupported devices
```

## Haptic Intensity Guidelines

### Light Impact
- **When**: Subtle, non-critical interactions
- **Examples**: 
  - Filter chip selection
  - Search field focus
  - Minor UI state changes
  - Expanding/collapsing sections

### Medium Impact
- **When**: Standard, important interactions
- **Examples**:
  - Item selection
  - Button taps
  - Organization switching
  - Form field validation

### Heavy Impact
- **When**: Significant, impactful actions
- **Examples**:
  - Destructive actions (delete)
  - Major state changes
  - Critical confirmations
  - Drag and drop completion

### Soft Impact
- **When**: Gentle, smooth transitions
- **Examples**:
  - Pull-to-refresh completion
  - Smooth animations
  - Gradual state changes

### Rigid Impact
- **When**: Precise, sharp interactions
- **Examples**:
  - Snapping to grid
  - Locking into position
  - Precise value selection

### Success Notification
- **When**: Task completed successfully
- **Examples**:
  - Item created
  - Form submitted
  - Upload completed
  - Login successful

### Warning Notification
- **When**: Caution or confirmation needed
- **Examples**:
  - Before destructive action
  - Validation warning
  - Duplicate detection
  - Already exists

### Error Notification
- **When**: Task failed or error occurred
- **Examples**:
  - Network error
  - Validation failed
  - Login failed
  - Server error

### Selection Changed
- **When**: Selection changes in picker/list
- **Examples**:
  - Scope picker
  - Category picker
  - Date picker
  - Segmented control

## Performance Considerations

### 1. Generator Lifecycle

**Efficient**:
```swift
class MyViewController: UIViewController {
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        impactGenerator.prepare()
    }
    
    func buttonTapped() {
        impactGenerator.impactOccurred()
        impactGenerator.prepare() // Prepare for next use
    }
}
```

**Inefficient**:
```swift
func buttonTapped() {
    // Creates new generator every time
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
}
```

### 2. Preparation Timing

- Call `prepare()` 0.5-1 second before expected use
- Preparation keeps Taptic Engine ready for ~1-2 seconds
- Re-prepare after each use for best results

### 3. Battery Impact

- Haptic feedback uses minimal battery
- Modern devices optimize Taptic Engine power usage
- No need to disable haptics for battery saving

## Testing Haptics

### Manual Testing Checklist

- [ ] Test on physical device (Simulator doesn't support haptics)
- [ ] Test with haptics enabled in Settings
- [ ] Test with haptics disabled in Settings
- [ ] Test on different iPhone models (7+, 8+, X+, 11+, 12+)
- [ ] Verify haptic intensity feels appropriate
- [ ] Check timing (no lag between action and haptic)
- [ ] Ensure consistency across similar actions

### Automated Testing

```swift
// Mock HapticService for testing
final class MockHapticService: HapticService {
    var lastHapticType: HapticType?
    
    enum HapticType {
        case light, medium, heavy, success, error, warning, selection
    }
    
    override func lightImpact() {
        lastHapticType = .light
    }
    
    override func success() {
        lastHapticType = .success
    }
    
    // ... other overrides
}

// Test
func testArchiveTriggersSuccessHaptic() {
    let mockHaptic = MockHapticService()
    let presenter = MyWarehousePresenter(hapticService: mockHaptic)
    
    presenter.itemArchived(testItem)
    
    XCTAssertEqual(mockHaptic.lastHapticType, .success)
}
```

## Accessibility Considerations

### VoiceOver Integration

Haptics work alongside VoiceOver:
```swift
// Haptic + VoiceOver announcement
func itemDeleted() {
    HapticService.shared.success()
    UIAccessibility.post(
        notification: .announcement,
        argument: "Позиция удалена"
    )
}
```

### Reduce Motion

Haptics are independent of Reduce Motion setting:
```swift
// Haptics still work when Reduce Motion is enabled
// This is correct behavior - haptics are tactile, not visual
```

## Common Mistakes to Avoid

### ❌ Mistake 1: Haptics in Loops
```swift
// BAD - creates haptic spam
for item in items {
    HapticService.shared.lightImpact() // NO!
    processItem(item)
}
```

### ❌ Mistake 2: Haptics on Background Threads
```swift
// BAD - haptics must be on main thread
DispatchQueue.global().async {
    HapticService.shared.success() // NO!
}
```

### ❌ Mistake 3: Wrong Haptic Type
```swift
// BAD - success haptic for error
func loginFailed() {
    HapticService.shared.success() // NO! Use .error()
}
```

### ❌ Mistake 4: Haptics Without User Action
```swift
// BAD - haptic without user interaction
func dataLoadedFromServer() {
    HapticService.shared.lightImpact() // NO! User didn't do anything
}
```

### ❌ Mistake 5: Multiple Haptics in Quick Succession
```swift
// BAD - haptic overload
func complexAction() {
    HapticService.shared.lightImpact()
    HapticService.shared.mediumImpact()
    HapticService.shared.success()
    // Too many haptics at once!
}
```

## Future Enhancements

1. **Custom Haptic Patterns** (iOS 13+)
   - Use `CHHapticEngine` for custom patterns
   - Create unique haptic signatures for app

2. **Haptic Preferences**
   - Allow users to customize haptic intensity
   - Per-action haptic enable/disable

3. **Contextual Haptics**
   - Different haptics based on context
   - Adaptive intensity based on user behavior

4. **Analytics**
   - Track haptic usage patterns
   - Optimize based on user feedback

## References

- [Apple Human Interface Guidelines - Haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)
- [UIFeedbackGenerator Documentation](https://developer.apple.com/documentation/uikit/uifeedbackgenerator)
- [Core Haptics Framework](https://developer.apple.com/documentation/corehaptics)
- [WWDC 2019 - Introducing Core Haptics](https://developer.apple.com/videos/play/wwdc2019/520/)
