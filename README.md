# 🧾 Billing Software — Desktop Application

A cross-platform **Flutter desktop billing and POS application** built for small to medium-sized businesses. It enables seamless invoice creation, product management, customer/supplier tracking, and detailed business reporting — all from a clean, dark-themed interface.

---

## ✨ Features

### 🖥️ Dashboard
- At-a-glance summary of today's sales, revenue, and key metrics
- Sales trend chart for the **last 7 days**
- Quick-access navigation to all major modules

### 🧾 POS Billing
- Fast and intuitive **Point-of-Sale billing screen**
- Add products by search, scan, or browse
- Apply discounts, taxes (GST/IGST), and multiple payment modes
- Generate and print **PDF invoices** with a single click
- **QR code** embedded on invoices for quick payment links
- Support for multiple invoice templates

### 📦 Product Management
- Add, edit, and delete products with pricing, HSN codes, and GST rates
- Track **stock levels** with low-stock alerts
- Categorize products and manage bulk imports

### 👥 Parties (Customers & Suppliers)
- Manage both **customers and suppliers** in one place
- View outstanding balances and transaction history
- Search and filter parties with advanced options

### 🛒 Purchases
- Record purchase entries against suppliers
- Track payment status and due dates
- Link purchases to inventory for automatic stock updates

### 📊 Reports
- **Sales reports** — daily, weekly, monthly summaries
- **Purchase reports** with supplier-wise breakdown
- **Profit & loss** overview
- Export-ready formatted data

### 🖨️ Invoice Templates
- Visual **template designer** to customize invoice layout
- Control header, footer, logo placement, and color scheme
- Preview before saving

### ⚙️ Settings
- **Company profile** — name, address, GSTIN, logo, contact details
- Currency and tax configuration
- App preferences and theme options

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev) (Desktop) |
| State Management | [Riverpod](https://riverpod.dev) |
| Local Database | SQLite via `sqflite` + `sqflite_common_ffi` |
| PDF Generation | `pdf` + `printing` |
| QR Code | `qr_flutter` |
| Fonts | Poppins via `google_fonts` |
| Internationalization | `intl` |
| Unique IDs | `uuid` |
| Security | `crypto` |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) — **version ≥ 3.9.2**
- Dart SDK — included with Flutter
- A desktop target enabled: **Windows**, **macOS**, or **Linux**

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/Billing-Software-Desktop-Application.git
cd Billing-Software-Desktop-Application

# Install dependencies
flutter pub get

# Run on desktop (choose your platform)
flutter run -d windows    # Windows
flutter run -d macos      # macOS
flutter run -d linux      # Linux
```

### Build for Release

```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

The output executables will be found in the `build/<platform>/` directory.

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── database/       # SQLite database setup & migrations
│   └── theme/          # App theme, colors, and typography
├── data/
│   ├── models/         # Data models (Invoice, Product, Customer, Purchase, etc.)
│   └── repositories/   # Data access layer
├── domain/
│   ├── services/       # Business logic (tax calculator, template engine)
│   └── state/          # Riverpod providers and state notifiers
├── presentation/
│   ├── screens/        # UI screens (Dashboard, POS, Products, Parties, Reports, etc.)
│   └── widgets/        # Reusable UI components
└── main.dart           # App entry point
```

---

## 📋 Data Models

| Model | Description |
|---|---|
| `Invoice` | Sales invoice with line items, tax, and payment info |
| `Product` | Product catalog with pricing, HSN, GST, and stock |
| `Customer` | Customer details and ledger |
| `Purchase` | Purchase records linked to suppliers |
| `CompanyProfile` | Business info used on invoices and reports |
| `InvoiceTemplate` | Saved invoice layout configurations |

---

## 🖼️ Supported Platforms

| Platform | Status |
|---|---|
| 🪟 Windows | ✅ Supported |
| 🍎 macOS | ✅ Supported |
| 🐧 Linux | ✅ Supported |
| 📱 Android / iOS | ⚠️ Not the primary target |

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## 📄 License

This project is private and not published to pub.dev. All rights reserved.

---

> Built with ❤️ using Flutter
