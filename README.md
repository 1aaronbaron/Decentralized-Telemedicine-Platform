# 🏥 TeleMed - Decentralized Telemedicine Platform

A revolutionary blockchain-based telemedicine platform built on Stacks, enabling secure and transparent remote medical consultations with automated payments and reputation management.

## ✨ Features

### 👩‍⚕️ For Healthcare Providers
- **Doctor Registration**: Register as a healthcare provider with specialty and hourly rates
- **Availability Management**: Control your active status and update consultation rates
- **Consultation Management**: Start, conduct, and complete patient consultations
- **Automated Payments**: Receive payments automatically upon consultation completion
- **Reputation System**: Build credibility through patient ratings and reviews

### 🏥 For Patients
- **Patient Registration**: Simple onboarding process for accessing telemedicine services
- **Appointment Booking**: Schedule consultations with available doctors
- **Flexible Cancellation**: Cancel appointments before scheduled time with full refunds
- **Rating System**: Rate and review completed consultations
- **Consultation History**: Track all your medical appointments and outcomes

### 🔒 Platform Features
- **Secure Payments**: STX-based payment system with escrow functionality
- **Transparent Fees**: Clear platform fee structure (default 5%)
- **Immutable Records**: Blockchain-based consultation records
- **Automated Settlements**: Smart contract handles all payment distributions

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX tokens

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/Decentralized-Telemedicine-Platform
cd Decentralized-Telemedicine-Platform
```

2. Check contract compilation:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📖 Usage Guide

### 🩺 Doctor Workflow

#### 1. Register as a Doctor
```clarity
(contract-call? .TeleMed register-doctor 
  "Dr. Sarah Johnson" 
  "Cardiology" 
  u50) ;; 50 STX per hour
```

#### 2. Update Your Status
```clarity
;; Go offline
(contract-call? .TeleMed update-doctor-status false)

;; Go online
(contract-call? .TeleMed update-doctor-status true)
```

#### 3. Update Hourly Rate
```clarity
(contract-call? .TeleMed update-hourly-rate u75) ;; Update to 75 STX per hour
```

#### 4. Start a Consultation
```clarity
(contract-call? .TeleMed start-consultation u1) ;; Start appointment #1
```

#### 5. Complete Consultation
```clarity
(contract-call? .TeleMed complete-consultation 
  u1 
  "Patient shows normal vital signs. Recommended rest and follow-up in 2 weeks.")
```

#### 6. Withdraw Earnings
```clarity
(contract-call? .TeleMed withdraw-earnings)
```

### 🏥 Patient Workflow

#### 1. Register as a Patient
```clarity
(contract-call? .TeleMed register-patient "John Smith")
```

#### 2. Schedule an Appointment
```clarity
(contract-call? .TeleMed schedule-appointment 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 ;; Doctor's address
  u1050 ;; Scheduled block height
  u1) ;; 1 hour duration
```

#### 3. Cancel Appointment (if needed)
```clarity
(contract-call? .TeleMed cancel-appointment u1) ;; Cancel appointment #1
```

#### 4. Rate Completed Consultation
```clarity
(contract-call? .TeleMed rate-consultation u1 u5) ;; 5-star rating
```

### 📊 Read-Only Functions

#### Get Doctor Information
```clarity
(contract-call? .TeleMed get-doctor 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### Get Appointment Details
```clarity
(contract-call? .TeleMed get-appointment u1)
```

#### Calculate Consultation Cost
```clarity
(contract-call? .TeleMed get-appointment-cost 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  u2) ;; 2 hours
```

#### Check Doctor Rating
```clarity
(contract-call? .TeleMed get-doctor-rating 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 💰 Economics

### Fee Structure
- **Platform Fee**: 5% (configurable by contract owner)
- **Payment Method**: STX tokens
- **Escrow System**: Payments held in smart contract until consultation completion
- **Instant Settlement**: Automatic payment release upon consultation completion

### Payment Flow
1. Patient pays total consultation cost upfront
2. Funds are held in smart contract escrow
3. Upon completion, platform fee is retained
4. Doctor receives remaining amount automatically

## 🛡️ Security Features

- **Authorization Checks**: Only authorized users can perform specific actions
- **Escrow Protection**: Patient funds are protected until service delivery
- **Immutable Records**: All consultations recorded on blockchain
- **Transparent Operations**: All transactions publicly verifiable

## 🏗️ Smart Contract Architecture

### Data Structures

- **Doctors Map**: Stores doctor profiles, rates, and statistics
- **Patients Map**: Tracks patient information and appointment history  
- **Appointments Map**: Manages consultation details and status
- **Earnings Tracking**: Monitors doctor earnings and platform fees

### Status Management

- **Scheduled**: Appointment booked, payment escrowed
- **In-Progress**: Consultation actively taking place
- **Completed**: Service delivered, payment released
- **Cancelled**: Appointment cancelled, refund processed

## 🔧 Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Resource not found |
| u102 | Resource already exists |
| u103 | Invalid amount specified |
| u104 | Invalid status transition |
| u105 | Insufficient funds |
| u106 | Appointment has expired |
| u107 | Invalid rating value |

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

Deploy to testnet:
```bash
clarinet deploy --testnet
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support, email support@telemed-platform.com or join our Discord community.

## 🌟 Acknowledgments

- Built on [Stacks](https://www.stacks.co/) blockchain
- Developed with [Clarinet](https://github.com/hirosystems/clarinet)
- Inspired by the need for accessible healthcare solutions

---

*Making healthcare accessible through blockchain technology* 🚀
