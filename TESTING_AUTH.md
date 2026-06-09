# 🧪 Testing Authentication & Authorization

## Quick Start

### 1. Setup

```bash
# Install dependencies
cd backend
npm install

# Create .env file
cp .env.example .env

# Fill in your Supabase credentials in .env
# Then run migrations in Supabase (from database/migrations/001_init_schema.sql)
```

### 2. Start Backend Server

```bash
npm run dev
```

Expected output:
```
╔═══════════════════════════════════════════════════════════════╗
║  Renacer Vital - Clinical Management System Backend           ║
║  Server running on http://localhost:3000                      ║
║  API documentation: http://localhost:3000/api/health          ║
╚═══════════════════════════════════════════════════════════════╝
```

### 3. Test Health Endpoint

```bash
curl http://localhost:3000/api/health
```

Should return:
```json
{
  "status": "ok",
  "timestamp": "2026-06-09T12:00:00.000Z"
}
```

## Test Scenarios

### Scenario 1: Register Admin User (First User)

**Important:** The first admin user needs to be created directly in Supabase Auth and profiles table, or use the API with initial admin bypass.

For testing, let's assume you have an admin user already. If not, you can:

1. Go to Supabase Dashboard → Authentication → Users
2. Create a user manually
3. Create corresponding profile in profiles table with role='admin'

### Scenario 2: Admin Creates Therapist User

**Step 1: Get Admin Token**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "AdminPassword123!"
  }'
```

**Response:**
```json
{
  "message": "Login successful",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "admin@example.com",
    "role": "admin",
    "profile": {
      "first_name": "Admin",
      "last_name": "User"
    }
  }
}
```

**Save the access_token** for next steps.

**Step 2: Register Therapist (Admin only)**
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -d '{
    "email": "therapist1@example.com",
    "password": "TherapistPass123!",
    "first_name": "Juan",
    "last_name": "Pérez",
    "role": "therapist",
    "phone": "+34123456789",
    "specialization": "Psychology"
  }'
```

**Response:**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "650e8400-e29b-41d4-a716-446655440001",
    "email": "therapist1@example.com",
    "profile": {
      "id": "750e8400-e29b-41d4-a716-446655440002",
      "role": "therapist",
      "first_name": "Juan",
      "last_name": "Pérez"
    }
  }
}
```

**Step 3: Register Reception (Admin only)**
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -d '{
    "email": "reception1@example.com",
    "password": "ReceptionPass123!",
    "first_name": "María",
    "last_name": "García",
    "role": "reception",
    "phone": "+34987654321"
  }'
```

### Scenario 3: Test Role-Based Access

#### Test 3A: Therapist Login & Access

**Login as Therapist:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "therapist1@example.com",
    "password": "TherapistPass123!"
  }'
```

**Save therapist token**

**Try to get all profiles (should fail - not admin):**
```bash
curl -X GET http://localhost:3000/api/profiles \
  -H "Authorization: Bearer THERAPIST_TOKEN"
```

**Expected response (403):**
```json
{
  "error": "Admin access required"
}
```

**Get therapist's own profile (should work):**
```bash
curl -X GET http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer THERAPIST_TOKEN"
```

**Expected response (200):**
```json
{
  "user": {
    "id": "650e8400-e29b-41d4-a716-446655440001",
    "email": "therapist1@example.com",
    "role": "therapist",
    "profile": {
      "id": "750e8400-e29b-41d4-a716-446655440002",
      "role": "therapist",
      "first_name": "Juan",
      "last_name": "Pérez",
      "phone": "+34123456789",
      "specialization": "Psychology",
      "active": true
    }
  }
}
```

#### Test 3B: Reception Access

**Login as Reception:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "reception1@example.com",
    "password": "ReceptionPass123!"
  }'
```

**Save reception token**

**Reception can see active profiles (should work):**
```bash
curl -X GET http://localhost:3000/api/profiles/role/therapist \
  -H "Authorization: Bearer RECEPTION_TOKEN"
```

**Expected response (200):**
```json
{
  "profiles": [
    {
      "id": "750e8400-e29b-41d4-a716-446655440002",
      "user_id": "650e8400-e29b-41d4-a716-446655440001",
      "first_name": "Juan",
      "last_name": "Pérez",
      "email": "therapist1@example.com",
      "role": "therapist",
      "specialization": "Psychology",
      "active": true
    }
  ]
}
```

#### Test 3C: Admin Privileges

**Login as Admin (already have token from Step 1)**

**Admin can see all profiles:**
```bash
curl -X GET http://localhost:3000/api/profiles \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

**Expected response (200):**
```json
{
  "profiles": [
    {
      "id": "...",
      "role": "admin",
      "first_name": "Admin",
      "last_name": "User",
      "active": true
    },
    {
      "id": "...",
      "role": "therapist",
      "first_name": "Juan",
      "last_name": "Pérez",
      "active": true
    },
    {
      "id": "...",
      "role": "reception",
      "first_name": "María",
      "last_name": "García",
      "active": true
    }
  ]
}
```

**Admin can deactivate a user:**
```bash
curl -X PATCH http://localhost:3000/api/profiles/THERAPIST_PROFILE_ID/active \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -d '{"active": false}'
```

**Expected response (200):**
```json
{
  "profile": {
    "id": "750e8400-e29b-41d4-a716-446655440002",
    "role": "therapist",
    "first_name": "Juan",
    "last_name": "Pérez",
    "active": false
  }
}
```

**Deactivated user cannot login:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "therapist1@example.com",
    "password": "TherapistPass123!"
  }'
```

**Expected response (403):**
```json
{
  "error": "User account is inactive"
}
```

### Scenario 4: Token Refresh

**Get new access token using refresh token:**
```bash
curl -X POST http://localhost:3000/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "YOUR_REFRESH_TOKEN"
  }'
```

**Expected response (200):**
```json
{
  "access_token": "new_access_token_here",
  "refresh_token": "new_refresh_token_here"
}
```

### Scenario 5: Change Password

**User changes their own password:**
```bash
curl -X POST http://localhost:3000/api/auth/change-password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer USER_TOKEN" \
  -d '{
    "current_password": "OldPassword123!",
    "new_password": "NewPassword456!"
  }'
```

**Expected response (200):**
```json
{
  "message": "Password changed successfully"
}
```

**Old password no longer works:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "therapist1@example.com",
    "password": "OldPassword123!"
  }'
```

**Expected response (401):**
```json
{
  "error": "Invalid credentials"
}
```

**New password works:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "therapist1@example.com",
    "password": "NewPassword456!"
  }'
```

## Testing with Postman Collection

### Import Collection

Create file: `Renacer-Vital-API.postman_collection.json`

```json
{
  "info": {
    "name": "Renacer Vital API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "url": "{{baseUrl}}/api/health"
      }
    },
    {
      "name": "Login",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/api/auth/login",
        "header": [
          {"key": "Content-Type", "value": "application/json"}
        ],
        "body": {
          "mode": "raw",
          "raw": "{\"email\": \"admin@example.com\", \"password\": \"AdminPassword123!\"}"
        }
      }
    },
    {
      "name": "Get Current User",
      "request": {
        "method": "GET",
        "url": "{{baseUrl}}/api/auth/me",
        "header": [
          {"key": "Authorization", "value": "Bearer {{accessToken}}"}
        ]
      }
    },
    {
      "name": "Get All Profiles (Admin)",
      "request": {
        "method": "GET",
        "url": "{{baseUrl}}/api/profiles",
        "header": [
          {"key": "Authorization", "value": "Bearer {{accessToken}}"}
        ]
      }
    },
    {
      "name": "Get Therapists",
      "request": {
        "method": "GET",
        "url": "{{baseUrl}}/api/profiles/role/therapist",
        "header": [
          {"key": "Authorization", "value": "Bearer {{accessToken}}"}
        ]
      }
    },
    {
      "name": "Register User (Admin)",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/api/auth/register",
        "header": [
          {"key": "Content-Type", "value": "application/json"},
          {"key": "Authorization", "value": "Bearer {{accessToken}}"}
        ],
        "body": {
          "mode": "raw",
          "raw": "{\"email\": \"newuser@example.com\", \"password\": \"Password123!\", \"first_name\": \"Test\", \"last_name\": \"User\", \"role\": \"therapist\", \"phone\": \"+34123456789\"}"
        }
      }
    }
  ],
  "variable": [
    {"key": "baseUrl", "value": "http://localhost:3000"},
    {"key": "accessToken", "value": ""}
  ]
}
```

1. Import into Postman
2. Set variables: `baseUrl`, `accessToken` (from login response)
3. Run requests

## Troubleshooting

### Issue: "Missing Supabase configuration"

**Cause:** Missing `.env` file or environment variables

**Solution:**
```bash
cp .env.example .env
# Edit .env with your Supabase credentials
```

### Issue: "User profile not found"

**Cause:** User exists in Auth but not in profiles table

**Solution:** In Supabase Dashboard:
1. Go to SQL Editor
2. Run:
```sql
INSERT INTO profiles (user_id, email, first_name, last_name, role)
VALUES ('user-uuid', 'email@example.com', 'First', 'Last', 'admin');
```

### Issue: CORS errors from frontend

**Cause:** Frontend URL not in CORS_ORIGINS

**Solution:** Update `.env`:
```env
CORS_ORIGINS=http://localhost:3001
```

## Automated Testing

```bash
npm test
```

(Test files coming in next phase)

---

**Ready to test!** 🚀
