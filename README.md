# 🏪 Vendex - Vendor Reputation NFT System

## 📋 Overview

Vendex is a decentralized vendor reputation system built on Stacks blockchain using Clarity smart contracts. It allows vendors to mint NFTs representing their business identity while customers can submit reviews and ratings, creating a transparent and immutable reputation system.

## ✨ Features

- 🎫 **Vendor NFTs**: Each vendor gets a unique NFT representing their business
- ⭐ **Rating System**: 1-5 star rating system for vendor reviews  
- 💬 **Review Comments**: Detailed feedback with up to 200 characters
- 🔒 **Ownership Control**: Only vendor owners can update their information
- 📊 **Reputation Scoring**: Automatic calculation of reputation scores
- 🚫 **Anti-Spam**: One review per customer per vendor
- 🔄 **Transferable**: Vendor NFTs can be transferred to new owners

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Navigate to project directory
3. Run Clarinet console:

```bash
clarinet console
```

## 📖 Usage Guide

### For Vendors

#### 1️⃣ Register as a Vendor
```clarity
(contract-call? .Vendex register-vendor "Alice's Electronics" "Electronics")
```

#### 2️⃣ Update Vendor Information
```clarity
(contract-call? .Vendex update-vendor-info u1 "Alice's Premium Electronics" "Electronics")
```

#### 3️⃣ Transfer Vendor NFT
```clarity
(contract-call? .Vendex transfer-vendor-nft u1 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)
```

#### 4️⃣ Deactivate Vendor Profile
```clarity
(contract-call? .Vendex deactivate-vendor u1)
```

### For Customers

#### 1️⃣ Submit a Review
```clarity
(contract-call? .Vendex submit-review u1 u5 "Excellent service and fast delivery!")
```

### Read-Only Functions

#### 📊 Get Vendor Information
```clarity
(contract-call? .Vendex get-vendor u1)
```

#### 📝 Get Review Details
```clarity
(contract-call? .Vendex get-review u1)
```

#### 🏆 Get Reputation Score
```clarity
(contract-call? .Vendex get-vendor-reputation-score u1)
```

#### 👤 Get Vendor by Owner
```clarity
(contract-call? .Vendex get-vendor-by-owner 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### ✅ Check if User Reviewed
```clarity
(contract-call? .Vendex has-reviewed u1 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)
```

## 🏗️ Contract Structure

### Data Storage
- **vendors**: Main vendor information and statistics
- **reviews**: Individual review data
- **vendor-reviews**: Mapping to prevent duplicate reviews
- **vendor-owner-lookup**: Quick owner-to-vendor lookup

### Key Features
- **Rating Scale**: 1-5 stars ⭐
- **Reputation Algorithm**: Average rating × review count multiplier
- **NFT Integration**: Each vendor profile is an NFT
- **Access Control**: Owner-only functions protected

## 🔧 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Vendor not found |
| u102 | Invalid rating (must be 1-5) |
| u103 | Already reviewed this vendor |
| u104 | Vendor already exists for this owner |
| u105 | NFT not found |

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is open source and available under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)

---

Built with ❤️ for the Stacks ecosystem


