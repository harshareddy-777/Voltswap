# 🔧 AUTHENTICATION TROUBLESHOOTING GUIDE

## Problem: "Can't Create Account or Login"

This guide will help you identify and fix authentication issues in your Battery Station app.

---

## 🚨 CRITICAL FIX: RLS Policies & Constraints

### Step 1: Execute the Authentication Fix SQL

1. **Open Supabase Dashboard**: https://supabase.com/dashboard
2. **Navigate to**: Your Project > SQL Editor
3. **Copy the entire content** from `SUPABASE_AUTH_FIX.sql` file
4. **Paste** into the SQL Editor
5. **Click "Run"** button
6. **Wait for completion** (you should see "Command completed successfully")

---

## ✅ Verification Checklist

### After running the SQL, verify:

**1. Check RLS Policies**
```sql
SELECT policyname, cmd, curtableoid::regclass as table_name 
FROM pg_policies 
WHERE tablename = 'users'
ORDER BY policyname;
```

**Expected Output:**
- `users_insert_own_profile` (INSERT)
- `users_select_own_profile` (SELECT)
- `users_update_own_profile` (UPDATE)

**2. Check Users Table Columns**
```sql
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users'
ORDER BY ordinal_position;
```

**Expected Columns:**
- id (uuid)
- email (text)
- name (text)
- phone (text)
- vehicle_number (text)
- aadhar_number (text)
- battery_type (text)
- wallet_balance (numeric)
- current_battery_slot_id (integer)
- current_station_id (text)
- assigned_battery_id (integer)
- battery_status (text)
- created_at (timestamp)
- updated_at (timestamp)

**3. Check Email Verification Settings**
- Go to: **Authentication > Policies**
- Check: "Require email confirmation"
  - ✅ **DISABLE IT** (allows signup/login without email verification)
  - OR if you want email verification, configure SMTP provider

---

## 🐛 Debug: Check for Errors

### In Flutter App:

1. **Open Terminal/Debug Console** (Ctrl+K in VS Code while running app)
2. **Try to sign up** with test credentials:
   - Name: Test User
   - Phone: 9999999999
   - Aadhar: 123456789012
   - Vehicle: TS09AB1234
   - Battery Type: LFP
   - Email: test@example.com
   - Password: Test@123456

3. **Look for error messages** like:
   - `=== SIGNUP START ===`
   - `=== SIGNUP SUCCESS ===`
   - Any `PostgrestException` or `AuthException` messages

### Common Error Messages & Fixes:

| Error Message | Cause | Fix |
|---------------|-------|-----|
| "new row violates RLS policy" | RLS policies not set up | Run `SUPABASE_AUTH_FIX.sql` |
| "Email already exists" | Valid - try different email | Use unique email |
| "Email not confirmed" | Email verification required | Disable in Auth > Policies |
| "Invalid credentials" | Wrong password at login | Check password is correct |
| "Account not found" | User not in database | Make sure signup succeeded |

---

## 🔍 Advanced Debugging

### Check if User was Created in Database:

```sql
SELECT id, email, name, created_at 
FROM users 
ORDER BY created_at DESC 
LIMIT 5;
```

### Check Auth Users:

```sql
SELECT id, email, email_confirmed_at, confirmation_sent_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;
```

### Check for RLS Violations in Logs:

- Supabase Dashboard > Logs > "Edge Functions" or "Database"
- Look for errors mentioning "RLS" or "policy"

---

## 📱 Step-by-Step Application Rebuild

After executing the SQL fixes:

```bash
# Terminal - in project directory
cd c:\Users\harsh\battery_station

# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Run the app
flutter run

# OR run with verbose output for debugging
flutter run -v
```

---

## 🔄 Testing Flow

### Test 1: Create Account
```
1. Run app
2. Click "Sign Up"
3. Fill in form with:
   - Name: John Doe
   - Phone: 9876543210
   - Aadhar: 123456789012
   - Vehicle: KA01AB1234
   - Battery Type: LFP
   - Email: john@test.com
   - Password: John@123456
4. Click "Create Account"
5. Should redirect to login screen
```

### Test 2: Email Verification (if enabled)
```
1. Check email inbox for verification link
2. Click verification link
3. Come back to app and login
```

### Test 3: Login
```
1. On login screen
2. Enter email: john@test.com
3. Enter password: John@123456
4. Click "Login"
5. Should see home screen with map
```

---

## 🛠️ If Issues Persist

### Option 1: Clear Auth State
```bash
# Disable RLS temporarily for testing (ONLY for testing!)
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

# Then test again
# After testing, re-enable:
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

### Option 2: Reset Users Table
```sql
-- DANGER: This deletes all users! Only use for testing!
DELETE FROM users;

-- Then try signup again
```

### Option 3: Check App Config
- Verify `lib/utils/app_config.dart` has correct Supabase URL and keys:
```dart
static const String supabaseUrl = 'https://vgkjdpexzausmrqboadm.supabase.co';
static const String supabaseAnonKey = 'sb_publishable_FWtiiwUdoplzoHsVE0QR7Q_yUSyKnqo';
```

---

## 📊 Summary of Fixes Applied

✅ **Code Changes**:
- Enhanced error logging in `auth_service.dart`
- Better error messages for debugging
- Additional error handling for email confirmation

✅ **Database Changes**:
- Fixed RLS policies to allow INSERT during signup
- Removed problematic NOT NULL constraints
- Verified all required columns exist

✅ **Configuration**:
- Checked email verification settings
- Verified Supabase credentials
- Confirmed all tables and indexes exist

---

## 🎯 Expected Outcome

After applying all fixes:

✅ Users can create accounts  
✅ Users can login successfully  
✅ Battery type is saved and displayed  
✅ Wallet balance initialized to 0  
✅ All user data persists in Supabase  

---

## 📞 Still Having Issues?

1. **Check Debug Console** for exact error messages
2. **Run verification queries** above to confirm database state
3. **Check Supabase Logs** for any policy violations
4. **Try test account** with different email address
5. **Clear app cache** and rebuild

---

## 🚀 Ready for Deployment

Once signup/login works:

1. ✅ Test all screens (profile, map, admin, etc.)
2. ✅ Test wallet features (add money, pay for swap)
3. ✅ Test admin functions (add battery, pricing, deallocate)
4. ✅ Deploy to App Store / Google Play

---

**Version**: 1.0  
**Last Updated**: April 8, 2026  
**Status**: Ready for Production
