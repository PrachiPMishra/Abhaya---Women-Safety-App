# 🛡️ Abhaya

**Abhaya** is a safety-focused mobile application designed to provide users with quick access to emergency assistance, trusted contacts, authentication, and essential personal safety features.

The project combines a **Flutter mobile application**, **FastAPI backend**, and **PostgreSQL database** to provide a secure and scalable foundation for personal safety services.

---

## 🚀 Overview

Abhaya aims to make emergency assistance simple, accessible, and reliable through a single mobile application.

The application provides a secure flow for:

* User registration and authentication
* Personal information management
* Trusted emergency contacts
* Emergency assistance workflows
* Secure backend APIs
* Persistent PostgreSQL database storage

---

## 🏗️ Architecture

```text
┌─────────────────────────┐
│     Flutter Mobile      │
│          App            │
└────────────┬────────────┘
             │
             │ REST API
             ▼
┌─────────────────────────┐
│        FastAPI          │
│        Backend          │
└────────────┬────────────┘
             │
             │ SQLAlchemy
             ▼
┌─────────────────────────┐
│       PostgreSQL        │
│        Database         │
└─────────────────────────┘
```

### Application Flow

```text
Flutter UI
     ↓
FastAPI REST API
     ↓
Authentication / Business Logic
     ↓
SQLAlchemy ORM
     ↓
PostgreSQL
```

---

## 🛠️ Tech Stack

### Frontend

* Flutter
* Dart

### Backend

* Python
* FastAPI
* SQLAlchemy
* Alembic
* JWT Authentication

### Database

* PostgreSQL

### Development & Tools

* Git
* GitHub
* Docker
* REST APIs
* Postman
* VS Code

---

## 📁 Project Structure

```text
Abhaya/
│
├── backend/
│   ├── app/
│   ├── alembic/
│   ├── tests/
│   ├── requirements.txt
│   └── ...
│
├── mobile/
│   ├── lib/
│   ├── android/
│   ├── ios/
│   ├── pubspec.yaml
│   └── ...
│
├── .gitignore
└── README.md
```

> The exact structure may evolve as new features are added.

---

# 🔐 Core Features

## Authentication

* User registration
* User login
* Secure authentication
* JWT-based authorization
* Protected backend endpoints

## 👤 Personal Information

* User profile management
* Secure storage of user information
* Update personal information
* Authenticated user-specific data access

## 👥 Trusted Contacts

* Add trusted emergency contacts
* Update contact information
* Remove trusted contacts
* Associate contacts with the authenticated user

## 🚨 Emergency Assistance

* Emergency-focused application workflow
* Quick access to safety-related functionality
* Backend support for emergency operations
* Trusted-contact integration

---

# 🗄️ Database

Abhaya uses **PostgreSQL** for persistent data storage.

Database schema changes are managed using **Alembic migrations**.

Run migrations using:

```bash
alembic upgrade head
```

---

# ⚙️ Backend Setup

## 1. Clone the Repository

```bash
git clone https://github.com/HarshEvolves/Abhaya.git
cd Abhaya/backend
```

## 2. Create a Virtual Environment

```bash
python3 -m venv venv
```

Activate it:

### macOS / Linux

```bash
source venv/bin/activate
```

### Windows

```bash
venv\Scripts\activate
```

## 3. Install Dependencies

```bash
pip install -r requirements.txt
```

## 4. Configure Environment Variables

If an example environment file is provided:

```bash
cp .env.example .env
```

Update `.env` with the required configuration, including:

* PostgreSQL database URL
* JWT configuration
* Authentication secrets
* Other required service credentials

> Never commit `.env` or other files containing secrets.

## 5. Run Database Migrations

```bash
alembic upgrade head
```

## 6. Start the FastAPI Server

```bash
uvicorn app.main:app --reload
```

The backend will be available at:

```text
http://127.0.0.1:8000
```

### API Documentation

FastAPI automatically provides interactive API documentation:

```text
http://127.0.0.1:8000/docs
```

Alternative documentation:

```text
http://127.0.0.1:8000/redoc
```

---

# 📱 Mobile Setup

Navigate to the Flutter application:

```bash
cd mobile
```

## Install Dependencies

```bash
flutter pub get
```

## Check Connected Devices

```bash
flutter devices
```

## Run the Application

```bash
flutter run
```

---

# 🧪 Testing

## Backend

Run backend tests using:

```bash
pytest
```

## Flutter

Run Flutter tests using:

```bash
flutter test
```

---

# 🔄 Development Workflow

```text
┌───────────────┐
│ Flutter / Dart│
│   Mobile UI   │
└───────┬───────┘
        │
        │ REST API
        ▼
┌───────────────┐
│    FastAPI    │
│    Backend    │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│ Authentication│
│   & Services  │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│   SQLAlchemy  │
│      ORM      │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  PostgreSQL   │
│    Database   │
└───────────────┘
```

Database schema changes are managed through:

```text
Alembic
   ↓
PostgreSQL
```

---

# 🔒 Security

Security is a core consideration of the Abhaya architecture.

The application uses:

* JWT-based authentication
* Protected API endpoints
* User-specific data access
* Environment variables for sensitive configuration
* PostgreSQL for persistent storage
* Database migrations through Alembic
* Git-based version control

### ⚠️ Important

Never commit the following to GitHub:

```text
.env
API keys
Passwords
JWT secrets
Database credentials
Private keys
```

---

# 🗺️ Development Roadmap

Abhaya is being developed incrementally.

### Phase 1 — MVP & Core Foundation

* Flutter application foundation
* FastAPI backend
* PostgreSQL integration
* Authentication
* Basic application flows

### Phase 2 — User & Contact Management

* User profiles
* Personal information
* Trusted contacts
* Contact management APIs

### Phase 3 — Emergency & Alert System

* SOS functionality
* Emergency workflows
* Real-time alerts
* Notification system

### Phase 4 — Security & Advanced Features

* Advanced security mechanisms
* Monitoring
* Error tracking
* Reliability improvements

### Phase 5 — Scaling & Production

* Performance optimization
* Production deployment
* CI/CD
* Infrastructure improvements
* Scalability enhancements

---

# 📊 Phase-wise Technology Evolution

```text
Phase 1
Flutter + FastAPI + PostgreSQL
        ↓
Phase 2
SQLAlchemy + Alembic + Docker
        ↓
Phase 3
Redis + Background Tasks + Notifications
        ↓
Phase 4
Advanced Authentication + Monitoring
        ↓
Phase 5
CI/CD + Cloud Infrastructure + Scaling
```

The technology stack may evolve as the project grows, with the primary goals of **security, reliability, maintainability, and scalability**.

---

# 📌 Project Status

**Status: 🚧 Active Development**

Abhaya is currently under active development, with the Flutter frontend and FastAPI/PostgreSQL backend being integrated into a complete personal safety platform.

---

# 👨‍💻 Authors

This project was developed collaboratively by:

### Harsh Kukutkar

GitHub:
https://github.com/HarshEvolves

### Pravin Kumar Mahato

GitHub:
https://github.com/Pravin1105

### Prachi Pratyasha Mishra

GitHub:
https://github.com/PrachiPMishra

---

# 📄 License

This project is currently intended for **development, educational, and project demonstration purposes**.

A formal open-source license may be added in the future.

---

## ⭐ Abhaya

**Safety. Secure. Always.**
