# 🗳️ Election Smart Contract

A tamper-proof blockchain-based voting system built on Stacks that enables secure, transparent, and anonymous elections with voter registration capabilities.

## ✨ Features

- 🏛️ **Create Elections**: Set up elections with customizable parameters
- 👥 **Candidate Management**: Add candidates with descriptions
- 📝 **Voter Registration**: Optional voter registration and verification system
- 🔒 **Anonymous Voting**: Cast votes securely and anonymously
- ⏰ **Time-bound Elections**: Elections run within specified block ranges
- 📊 **Real-time Results**: Track votes and view election results
- 🛡️ **Tamper-proof**: Immutable voting records on the blockchain

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
clarinet new election-project
cd election-project
```

Copy the contract code into `contracts/Election-Smart-Contract.clar`

### Testing

```bash
clarinet console
```

## 📖 Usage Guide

### 1. Create an Election

```clarity
(contract-call? .Election-Smart-Contract create-election 
  "Presidential Election 2024" 
  "Vote for the next president" 
  u1000 
  u2000 
  true)
```

Parameters:
- `title`: Election title (max 100 chars)
- `description`: Election description (max 500 chars)
- `start-block`: Block height when voting starts
- `end-block`: Block height when voting ends
- `registration-required`: Whether voters need to register

### 2. Add Candidates

```clarity
(contract-call? .Election-Smart-Contract add-candidate 
  u1 
  "John Doe" 
  "Experienced leader with vision")
```

### 3. Register Voters (if required)

```clarity
(contract-call? .Election-Smart-Contract register-voter u1)
```

### 4. Verify Voters (election creator only)

```clarity
(contract-call? .Election-Smart-Contract verify-voter u1 'ST1VOTER...)
```

### 5. Cast Vote

```clarity
(contract-call? .Election-Smart-Contract cast-vote u1 u1)
```

### 6. View Results

```clarity
(contract-call? .Election-Smart-Contract get-election-results u1)
```

## 🔍 Read-Only Functions

- `get-election(election-id)` - Get election details
- `get-candidate(election-id, candidate-id)` - Get candidate info
- `get-candidate-count(election-id)` - Get total candidates
- `has-voted(election-id, voter)` - Check if voter has voted
- `is-election-active(election-id)` - Check if election is currently active
- `get-election-count()` - Get total number of elections

## 🛠️ Contract Functions

### Public Functions
- `create-election` - Create a new election
- `add-candidate` - Add candidate to election
- `register-voter` - Register to vote in election
- `verify-voter` - Verify registered voter (creator only)
- `cast-vote` - Cast vote for candidate
- `end-election` - End election early (creator only)

### Security Features

- ✅ Prevents double voting
- ✅ Time-bound voting periods
- ✅ Creator-only administrative functions
- ✅ Optional voter registration and verification
- ✅ Anonymous vote casting

## 🎯 Error Codes

- `u100` - Owner only operation
- `u101` - Election/candidate not found
- `u102` - Unauthorized access
- `u103` - Already exists
- `u104` - Invalid time parameters
- `u105` - Election not active
- `u106` - Already voted
- `u107` - Not registered to vote
- `u108` - Election has ended
- `u109` - Invalid candidate

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is open source and available under the MIT License.

---

Built with ❤️ using Clarity and Stacks blockchain
```

**Git Commit Message:**
```
feat: implement tamper-proof election smart contract with voter registration
```

**GitHub Pull Request Title:**
```
🗳️ Add Election Smart Contract with Anonymous Voting System
```

**GitHub Pull Request Description:**
```
## Summary
Added a comprehensive election smart contract that enables tamper-proof online elections with voter registration and anonymous voting capabilities.

## Features Added
- ✅ Election creation and management system
- ✅ Candidate registration and management  
- ✅ Optional voter registration with verification
- ✅ Anonymous voting mechanism
- ✅ Time-bound election periods
- ✅ Real-time vote counting and results
- ✅ Comprehensive security measures

## Technical Details
- 150+ lines of Clarity code
- Complete error handling with custom error codes
- Read-only functions for
