# 💰 Budget Tracker

A beautifully designed personal budget tracker built with **Flutter**. Track your income, expenses, and spending habits with an intuitive, modern dark-themed interface.

> Built with ❤️ using Flutter, Hive, Provider, and fl_chart.

---

## ✨ Features

### 🏠 Dashboard (Home)
- **Balance overview** — See your monthly balance at a glance with animated counters
- **Income & Expense tiles** — Color-coded, tappable tiles that open the Add Transaction sheet
- **Category cards** — Grid view with spending amounts, budget progress bars, and quick-add via tap
- **Recent transactions** — Last 5 transactions with tap-to-edit functionality
- **Dynamic greeting** — Time-based greeting (Good morning/afternoon/evening)
- **Month navigation** — Browse through any month/year with arrow buttons

### ➕ Add Transactions
- **Bottom sheet form** — Smooth, modern bottom sheet for adding transactions
- **Expense/Income tabs** — Toggle between expense and income modes
- **Category chips** — Visual category selector with icons and colors
- **Pre-selection** — Tapping a category card or income/expense tile pre-fills the form
- **Date picker** — Choose any date for your transaction
- **Notes** — Optional notes for each transaction
- **Validation** — Form validation with helpful error messages

### ✏️ Edit Transactions
- **Tap to edit** — Tap any transaction on the Home screen to open the edit sheet
- **Full editing** — Modify amount, category, note, and date
- **Delete option** — Delete button with confirmation dialog
- **Inline affordance** — Small edit icon on each transaction for discoverability

### 📝 Transaction History
- **Search** — Search transactions by category name or note
- **Filter tabs** — View All, Expenses only, or Income only
- **Grouped by date** — Transactions grouped by relative dates (Today, Yesterday, etc.)
- **Swipe to delete** — Slide transactions to reveal delete action with confirmation
- **Transaction count & total** — Summary stats at the top

### 📈 Statistics
- **All-time overview** — Total income, expenses, and net balance cards
- **6-month bar chart** — Side-by-side income/expense comparison with touch tooltips
- **Spending by Category** — Interactive pie chart with color-coded legend
- **Top spending categories** — Ranked list with category icons, amounts, percentages, and progress bars
- **Date-range picker** — Scope Top Vendors and drill-downs to any custom range
- **Top vendors** — Pie + ranked list of where your money actually goes, by store name
- **Category drill-down** — Tap a category to see the per-vendor breakdown in a bottom sheet

### 📅 Finance Timeline
- **Vertical, reverse-chronological** view of every transaction, grouped by Month / Quarter / Year
- **Type filter** — All / Income / Expense
- **Per-group totals** — Income, expense, and net on each group header
- **Salary deposits styled distinctly** with a ⚡ bolt icon

### 🧾 Smart Receipt Scanning
- **Gemini-powered OCR** — Scans receipts and auto-extracts store, amount, date, and line items
- **Attach receipts to transactions** — Swipe any expense → Receipt → pick camera/gallery; scan runs in the background while you keep using the app
- **Live scan badges** — Transaction cards show "scanning receipt…" with a spinner until done
- **VendorRules-first categorization** — User rules win over AI guesses

### 📨 SMS Import & Live Sync
- **IslamicBank + BML auto-import** — Parses "Purchase confirmation" and "Salary Transfer" SMS into transactions
- **Live SMS listener** — Catches new bank SMS in real time (opt-in, Android only)
- **Salary / income patterns** — Configurable regex for salary-deposit SMS with live test preview
- **Custom SMS pattern** — Define your own bank's SMS format

### 🏷️ Vendor Rules (Smart Categorization)
- **Pattern → category** — "FITNESS" always goes to Health, "AGORA" always to Food, etc.
- **Contains match or full regex** — Per-rule toggle
- **Priority & income-flip** — Higher-priority rules win; flag a rule as income to redirect matching SMS to the income bucket
- **Rule training from transactions** — Fix a misclassification once, save as a rule, never see it wrong again

### ☁️ Offline-First Sync
- **Connectivity-driven auto-sync** — Returns online → pending changes push automatically
- **Debounced mutation flush** — Rapid edits coalesce into a single sync (10s idle)
- **Sync notifications** — Local notifications summarize what was uploaded/downloaded
- **Round-trips categories, transactions, receipts, and vendor rules**

### 🎯 Branding
- **Custom app icon** — Updated launcher icon for Android and iOS

### 🏷️ Category Management
- **Default categories** — 6 pre-built categories (Rent, Food, Transport, Shopping, Bills, Entertainment)
- **Create custom categories** — Full form with name, icon picker (30+ icons), color picker (16 colors), and optional budget limit
- **Edit categories** — Tap any category to modify it
- **Delete categories** — Swipe left to delete with confirmation (cascade deletes related transactions)
- **Budget limits** — Set monthly spending limits per category with visual progress bars
- **Over-budget warnings** — Red indicators when spending exceeds limits
- **Accessible from** — Home screen "Manage" button + Settings → "Manage Categories"

### ⚙️ Settings
- **Currency picker** — Choose from 10 currencies (MVR, USD, EUR, GBP, AED, INR, LKR, JPY, AUD, CAD)
- **Category management** — Quick access to the full categories screen
- **Clear all data** — Nuclear reset with confirmation dialog
- **About section** — Version info and tech stack

### 📦 Release Versioning
- **Version label** — The app shows the installed package version and build number in Settings
- **Play Store releases** — Bump the version in `pubspec.yaml` for each public release
- **Build number** — Increase the build number for every new uploaded artifact
- **Source of truth** — Android `versionName` and `versionCode` are driven from Flutter's `pubspec.yaml`

---

## 🎨 Design

- **Deep dark theme** with subtle gradients and glassmorphism effects
- **Consistent color system** — Purple primary, cyan accent, green income, red expenses
- **Custom bottom navigation** with animated gradient floating action button
- **Smooth animations** and transitions throughout
- **Responsive layout** that works on mobile and web
- **Empty state illustrations** with helpful guidance text
- **Visual affordances** — `+` icons on tappable elements, edit icons on transactions
- **Google Fonts (Inter)** — Modern, clean typography

---

## 🛠️ Tech Stack

| Technology | Purpose |
|-----------|---------|
| **Flutter** 3.41+ / **Dart** 3.11+ | App framework |
| **Provider** | State management |
| **Hive** + **hive_flutter** | Local NoSQL storage (offline-first) |
| **fl_chart** | Pie charts and bar charts |
| **Google Fonts** (Inter) | Modern typography |
| **flutter_slidable** | Swipe-to-delete actions |
| **uuid** | Unique identifiers for records |
| **intl** | Date and currency formatting |
| **google_generative_ai** (Gemini 2.5 Flash) | Receipt OCR + fallback categorization |
| **image_picker** + **flutter_image_compress** | Receipt capture & on-device compression |
| **connectivity_plus** | Live online/offline detection for auto-sync |
| **flutter_local_notifications** | Sync + receipt-scan notifications |
| **another_telephony** | SMS ingestion (Android) |
| **table_calendar** | Month-grid calendar view |
| **FastAPI + SQLAlchemy + Alembic** (backend) | Cloud sync API |

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.x or later installed ([Install Flutter](https://docs.flutter.dev/get-started/install))

### Run the app

```bash
# Clone the repository
git clone https://github.com/Shinorkon/budget-tracker.git
cd budget-tracker

# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome

# Run on web-server (headless)
flutter run -d web-server --web-port 8080

# Run on connected mobile device
flutter run

### Build a release APK

```bash
# Update the version in pubspec.yaml first, then build the release artifact
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```

For Play Store uploads, prefer `flutter build appbundle --release` and increment the version/build number in `pubspec.yaml` before each major release.
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point, Provider setup, live-sync bootstrap
├── theme/
│   └── app_theme.dart                 # Design system: colors, theme, decorations
├── models/
│   ├── budget_model.dart              # Category, Transaction, Receipt, VendorRule + Hive adapters
│   └── budget_provider.dart           # State, CRUD, analytics, range helpers
├── screens/
│   ├── main_layout.dart               # Navigation shell + Add Transaction bottom sheet
│   ├── home_screen.dart               # Dashboard with balance, charts, categories
│   ├── transactions_screen.dart       # History + swipe-to-delete + swipe-to-attach-receipt
│   ├── statistics_screen.dart         # Charts, date-range, top vendors, drill-downs
│   ├── finance_timeline_screen.dart   # Vertical income+expense timeline
│   ├── calendar_screen.dart           # Month-grid calendar view
│   ├── categories_screen.dart         # Category CRUD with icon/color pickers
│   ├── vendor_rules_screen.dart       # Vendor → Category rule CRUD with regex toggle
│   ├── scan_receipt_flow.dart         # Guided receipt scan flow (legacy entry)
│   ├── sms_import_screen.dart         # Bulk SMS import & preview
│   └── settings_screen.dart           # App settings, salary SMS config, sync controls
├── services/
│   ├── sync_service.dart              # One-shot pull/push against backend
│   ├── live_sync_service.dart         # Connectivity listener + debounced auto-sync
│   ├── sync_queue.dart                # Pending-mutation queue
│   ├── sms_transaction_service.dart   # SMS parsing + VendorRule-aware categorization
│   ├── live_sms_listener_service.dart # Real-time SMS ingestion
│   ├── receipt_ai_service.dart        # Gemini receipt OCR
│   ├── receipt_scan_queue.dart        # Detached-future scan queue for transaction-attached receipts
│   └── notification_service.dart      # flutter_local_notifications wrapper
└── utils/
    └── formatters.dart                # Currency, date, and number formatters

backend/
├── app/
│   ├── api/routes/sync.py             # /api/sync endpoint — transactions, categories, receipts, vendor rules
│   └── models/                        # SQLAlchemy models
└── alembic/versions/                  # Schema migrations (incl. 0007_add_vendor_rules)
```

---

## 📱 Screenshots

| Home | Transactions | Statistics | Settings |
|------|-------------|------------|----------|
| Balance card, pie chart, category grid | Search, filters, grouped by date | 6-month chart, top categories | Currency, data management |

---

## 🔮 Roadmap

- [x] Cloud sync
- [x] Biometric lock
- [x] Budget / sync notifications
- [x] Smart receipt scanning (Gemini)
- [x] Live SMS ingestion + salary detection
- [x] Vendor → Category rules (user-trainable)
- [x] Finance timeline + date-range analytics
- [ ] Data export (CSV/PDF)
- [ ] Recurring transactions
- [ ] Multiple accounts/wallets
- [ ] Themes (light mode, custom colors)
- [ ] Receipt image upload to backend (metadata-only today)
- [ ] Multi-device conflict resolution beyond last-write-wins

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

Made with 💜 by [Shinorkon](https://github.com/Shinorkon)
