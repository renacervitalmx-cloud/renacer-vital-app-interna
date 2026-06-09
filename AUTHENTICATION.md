# 🔐 Renacer Vital - Authentication & Authorization Guide

## Overview

This document explains how authentication and authorization work in Renacer Vital.

## Architecture

### Components

1. **Supabase Auth** - Handles user registration, login, and JWT token generation
2. **Profiles Table** - Stores user metadata and role information
3. **Middleware** - Express middleware that validates tokens and enforces role-based access
4. **Row Level Security (RLS)** - Database-level policies that restrict data access

### Roles

The system has three user roles:

| Role | Permissions |
|------|-----------|
| **Admin** | Full access to all data, can manage users, create exercises/emotions |
| **Therapist** | Can only see assigned patients, create/edit SOAP notes, assign exercises |
| **Reception** | Can see all patients and schedule appointments, cannot edit clinical data |

## Authentication Flow

### 1. Registration (Admin only)

```
Admin → POST /api/auth/register → Supabase Auth creates user → Profile created → User ready to login
```

**Endpoint:**
```bash
POST /api/auth/register
Content-Type: application/json

{
  "email": "therapist@example.com",
  "password": "securePassword123",
  "first_name": "Juan",
  "last_name": "Pérez",
  "role": "therapist",
  "phone": "+34123456789",
  "specialization": "Psychology"
}
```

**Response:**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "uuid",
    "email": "therapist@example.com",
    "profile": {
      "id": "uuid",
      "role": "therapist",
      "first_name": "Juan",
      "last_name": "Pérez"
    }
  }
}
```

### 2. Login

```
User → POST /api/auth/login → Supabase Auth validates → JWT token returned → Token used for API calls
```

**Endpoint:**
```bash
POST /api/auth/login
Content-Type: application/json

{
  "email": "therapist@example.com",
  "password": "securePassword123"
}
```

**Response:**
```json
{
  "message": "Login successful",
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "refresh_token_here",
  "user": {
    "id": "user-uuid",
    "email": "therapist@example.com",
    "role": "therapist",
    "profile": {
      "first_name": "Juan",
      "last_name": "Pérez",
      "phone": "+34123456789",
      "specialization": "Psychology"
    }
  }
}
```

### 3. Using the Token

All protected endpoints require the JWT token in the Authorization header:

```bash
GET /api/profiles/me
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

## Authorization Rules

### Admin

```
✅ Can see all profiles
✅ Can see all patients
✅ Can see all sessions
✅ Can create/edit SOAP notes for any patient
✅ Can view all clinical files
✅ Can create users and manage roles
✅ Can manage exercises and emotions catalog
```

### Therapist

```
✅ Can see active profiles (teammates)
✅ Can only see patients assigned to them
✅ Can only see sessions with their patients
✅ Can create/edit SOAP notes only for their patients
✅ Can view clinical files for their patients
✅ Can create improvement feedback
✅ Can assign exercises to their patients
❌ Cannot create users
❌ Cannot edit other therapists' data
❌ Cannot access admin features
```

### Reception

```
✅ Can see all profiles
✅ Can see all patients
✅ Can see all sessions (for scheduling)
✅ Can create/edit appointments
❌ Cannot view SOAP notes
❌ Cannot edit patient medical information
❌ Cannot create clinical records
```

## Security Features

### 1. JWT Token Validation

Every protected request goes through token validation:

```typescript
// Token is extracted from Authorization header
// Token signature is verified against Supabase JWT secret
// User info is retrieved from token claims
// Profile role is fetched from database
```

### 2. Role-Based Access Control (RBAC)

Middleware checks user role before allowing access:

```typescript
// requireRole('therapist') middleware
// Only allows requests from users with 'therapist' role
// Returns 403 Forbidden for unauthorized roles
```

### 3. Row Level Security (RLS)

Database level policies ensure data cannot be accessed even with valid tokens:

```sql
-- Example: Therapists can only see their assigned patients
CREATE POLICY "therapists_view_assigned_patients" ON patients
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist' AND
        id IN (SELECT DISTINCT patient_id FROM sessions WHERE therapist_id = auth.uid())
    );
```

### 4. Token Expiration

- Access tokens expire after 7 days
- Refresh tokens can be used to get new access tokens
- Expired tokens return 401 Unauthorized

## Testing Authentication

### 1. Using cURL

**Login:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "therapist@example.com",
    "password": "securePassword123"
  }'
```

**Get current user:**
```bash
curl -X GET http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### 2. Using Postman

1. Login with credentials → Get access_token
2. Set up Postman Environment variable: `{{access_token}}`
3. Add Authorization header to requests: `Bearer {{access_token}}`

### 3. Using Thunder Client / REST Client (VS Code)

```http
### Login
POST http://localhost:3000/api/auth/login
Content-Type: application/json

{
  "email": "therapist@example.com",
  "password": "securePassword123"
}

### Get current user (use token from login response)
@access_token = eyJhbGciOiJIUzI1NiIs...

GET http://localhost:3000/api/auth/me
Authorization: Bearer @access_token
```

## API Endpoints

### Authentication

```
POST   /api/auth/register          - Register new user (admin only)
POST   /api/auth/login             - Login with email/password
GET    /api/auth/me                - Get current user info
POST   /api/auth/refresh           - Refresh access token
POST   /api/auth/logout            - Logout (client handles)
POST   /api/auth/change-password   - Change password
```

### Profiles

```
GET    /api/profiles               - Get all profiles (admin only)
GET    /api/profiles/role/:role    - Get users by role
GET    /api/profiles/:id           - Get specific profile
PUT    /api/profiles/:id           - Update profile
PATCH  /api/profiles/:id/active    - Activate/deactivate user (admin only)
```

## Environment Variables

Create `.env` file with:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anonymous-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_JWT_SECRET=your-jwt-secret

PORT=3000
FRONTEND_URL=http://localhost:3001
```

## Common Issues

### 1. "Invalid or expired token"

**Cause:** Token has expired or is malformed
**Solution:** Request new token using refresh token or login again

### 2. "Access denied. Required role: admin"

**Cause:** User doesn't have required role
**Solution:** Only admins can perform this action

### 3. "User profile not found"

**Cause:** Auth user exists but profile table entry missing
**Solution:** Contact admin to create profile entry

### 4. "User account is inactive"

**Cause:** User was deactivated by admin
**Solution:** Admin needs to activate user via `/api/profiles/:id/active`

## Next Steps

1. **Frontend Integration** - Implement login form and token storage
2. **Patient Routes** - Add patient CRUD endpoints with RLS enforcement
3. **Session Routes** - Add session management endpoints
4. **SOAP Notes** - Add SOAP note creation/editing endpoints
5. **Audit Logging** - Track who accessed what data and when

---

**Last Updated:** 2026-06-09
**Status:** ✅ Ready for Development
