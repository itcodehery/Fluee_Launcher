# Privacy Policy for Fluee Launcher

**Last Updated:** November 11, 2026

Fluee Launcher ("we", "our", or "the app") is designed from the ground up to respect your privacy. This Privacy Policy explains our commitment to handling your information with complete transparency.

---

### 1. Zero Personal Data Collection
Fluee Launcher is a **100% offline, local-only application**. 
- We do **not** collect, store, transmit, or share any personal information.
- We do **not** use tracking SDKs, analytics frameworks, advertising identifiers, or telemetries.
- The app operates without internet permissions (`android.permission.INTERNET` is not included in the application manifest).

---

### 2. Device Permissions and How They Are Used
Fluee Launcher requests only the minimum permissions necessary to function as a home screen replacement on Android:

#### A. Query All Packages (`QUERY_ALL_PACKAGES`)
- **Purpose**: As an Android home screen launcher, Fluee Launcher requires package visibility to discover, display, categorize, and launch the apps installed on your device.
- **Privacy**: The list of installed apps never leaves your device. It is used strictly locally to render your app drawer and search results.

#### B. Accessibility Service (`BIND_ACCESSIBILITY_SERVICE`)
- **Purpose**: Used exclusively to provide convenience gestures:
  1. Turning off / locking the screen when you double-tap empty space on the home screen (`GLOBAL_ACTION_LOCK_SCREEN`).
  2. Displaying the system power menu when triggered from the dashboard (`GLOBAL_ACTION_POWER_DIALOG`).
- **Privacy & Safety**: Fluee Launcher's Accessibility Service has `canRetrieveWindowContent="false"` and empty event types. It does **not** read screen contents, monitor keystrokes, intercept user input, or interact with other applications.

#### C. Notification Listener (`BIND_NOTIFICATION_LISTENER_SERVICE`)
- **Purpose**: Optional. Used solely to display the "Now Playing" music title and artist on the home screen clock complication.
- **Privacy**: Only active media playback metadata (title and artist) is read. No personal notification text, messages, or sender identities are accessed or stored.

#### D. Write System Settings (`WRITE_SETTINGS`)
- **Purpose**: Optional. Allows you to adjust screen brightness directly via the dashboard slider without leaving the home screen.

#### E. Bluetooth (`BLUETOOTH_CONNECT`)
- **Purpose**: Optional. Checks whether Bluetooth audio or accessories are connected to display the status indicator in the Quick Apps shade.

---

### 3. Local Storage and Backups
- All launcher preferences (app layouts, pinned quick apps, custom app names, hidden apps, and theme colors) are stored locally on your device via Android's secure `SharedPreferences`.
- When you use the **Backup & Restore** feature, layout files (`.json`) are exported or imported using Android's standard Storage Access Framework directly to your chosen destination (such as your local Downloads folder or personal cloud storage). We have no access to your backup files.

---

### 4. Children's Privacy
Fluee Launcher does not collect data from any user, including children under the age of 13.

---

### 5. Changes to This Policy
If we update this Privacy Policy in future versions, updates will be reflected in the application settings and this repository.

---

### 6. Contact
For any questions regarding this privacy policy or the application, please open an issue in the project repository.
