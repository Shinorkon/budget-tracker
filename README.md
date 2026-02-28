# 💰 Budget Tracker

A beautifully designed personal budget tracker built with **Flutter**. Track your income, expenses, and spending habits with an intuitive, modern dark-themed interface.

> Built with ❤️ using Flutter, Hive, Provider, and fl_chart.

---

## ✨ Features

### 🏠 Dashboard (Home)
- **Balance overview** — See your monthly balance at a glance with animated counters
- **Income & Expense tiles** — Color-coded, tappable tiles that open the Add Transaction sheet
- **Spending by Category** — Interactive pie chart with color-coded legend
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
- **Top spending categories** — Ranked list with category icons, amounts, percentages, and progress bars

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
```

---

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point with Provider setup
├── theme/
│   └── app_theme.dart           # Design system: colors, theme, decorations
├── models/
│   ├── budget_model.dart        # Data models (Category, Transaction, Hive adapters)
│   └── budget_provider.dart     # State management, CRUD, analytics
├── screens/
│   ├── main_layout.dart         # Navigation shell + Add Transaction bottom sheet
│   ├── home_screen.dart         # Dashboard with balance, charts, categories
│   ├── transactions_screen.dart # Transaction history with search & filters
│   ├── statistics_screen.dart   # Charts and spending analytics
│   ├── categories_screen.dart   # Category CRUD with icon/color pickers
│   └── settings_screen.dart     # App settings & preferences
└── utils/
    └── formatters.dart          # Currency, date, and number formatters
```

---

## 📱 Screenshots

| Home | Transactions | Statistics | Settings |
|------|-------------|------------|----------|
| Balance card, pie chart, category grid | Search, filters, grouped by date | 6-month chart, top categories | Currency, data management |

---

## 🔮 Roadmap

- [ ] Data export (CSV/PDF)
- [ ] Recurring transactions
- [ ] Budget notifications
- [ ] Multiple accounts/wallets
- [ ] Biometric lock
- [ ] Cloud sync
- [ ] Themes (light mode, custom colors)

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

Made with 💜 by [Shinorkon](https://github.com/Shinorkon)
