--========================================================
-- COMPREHENSIVE AUTH/SIGNUP FIX FOR SUPABASE
-- Execute this entire script in Supabase SQL Editor
--========================================================

-- STEP 1: Drop problematic constraints that may block signups
--========================================================
ALTER TABLE users DROP CONSTRAINT IF EXISTS email_not_null;
ALTER TABLE users DROP CONSTRAINT IF EXISTS name_not_null;


-- STEP 2: Fix RLS Policies for Authentication
--========================================================

-- Allow authenticated users to INSERT their own profile during signup
DROP POLICY IF EXISTS users_insert_own_profile ON users;
CREATE POLICY users_insert_own_profile ON users
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Allow authenticated users to SELECT their own profile
DROP POLICY IF EXISTS users_select_own_profile ON users;
CREATE POLICY users_select_own_profile ON users
  FOR SELECT
  USING (auth.uid() = id);

-- Allow authenticated users to UPDATE their own profile
DROP POLICY IF EXISTS users_update_own_profile ON users;
CREATE POLICY users_update_own_profile ON users
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);


-- STEP 3: Verify users table structure
--========================================================
-- The users table should already have these columns from master schema
-- If any are missing, they will be added here:

ALTER TABLE users ADD COLUMN IF NOT EXISTS vehicle_number TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS aadhar_number TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS battery_type TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS wallet_balance NUMERIC DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT;


-- STEP 4: Add battery type constraint
--========================================================
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_battery_type_check;
ALTER TABLE users ADD CONSTRAINT users_battery_type_check 
CHECK (battery_type IS NULL OR battery_type IN ('LFP', 'NMC', 'NMA'));


-- STEP 5: Verify indexes exist
--========================================================
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_id ON users(id);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);


-- STEP 6: Test data - CREATE TEST USER (Optional - for testing)
--========================================================
-- Only run this if you want to create a test account for debugging
-- Otherwise, skip this section

-- INSERT INTO auth.users (id, email, email_confirmed_at, encrypted_password, raw_app_meta_data, raw_user_meta_data, aud, role)
-- VALUES (
--   'test-user-id-12345',
--   'test@voltswap.com',
--   now(),
--   crypt('Test@123456', gen_salt('bf')),
--   '{"provider":"email","providers":["email"]}',
--   '{}',
--   'authenticated',
--   'authenticated'
-- );


-- STEP 7: Verify RLS is enabled
--========================================================
-- This should already be enabled from master schema
ALTER TABLE users ENABLE ROW LEVEL SECURITY;


--========================================================
-- VERIFICATION QUERIES (Run these to check status)
--========================================================

-- Check if policies exist and are correct:
-- SELECT policyname, cmd, curtableoid::regclass as table_name 
-- FROM pg_policies 
-- WHERE tablename = 'users';

-- Check users table structure:
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'users';

-- Check for any rows in users table:
-- SELECT COUNT(*) FROM users;
