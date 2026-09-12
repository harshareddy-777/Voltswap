# Volt Swap

Flutter mobile app for a battery swapping system with Supabase backend and a map-first UI.

## Features Implemented

- **User Authentication**: Email/password signup with new fields:
  - Vehicle Number (alphanumeric - e.g., TS09AB1234)
  - Aadhar Number (12-digit unique ID)
- Separate admin login flow from the login page (no automatic role routing).
- **User Map Home**: Google Maps with:
  - User's current location marker (blue "My Location" pin)
  - Battery swap station markers (orange)
- Station details with slots and battery request logic.
- Request logic picks the highest `charge_percentage` from slots with `battery_present = true`.
- QR generation after request containing `station_id`, `slot_id`, `charge_percentage`.
- Profile tab with:
  - Account details (View/Edit)
  - Aadhar Number (Read-only)
  - Vehicle Number (Editable)
  - Swap history
  - Sign out
- Admin dashboard with:
  - Add stations
  - Toggle station status
  - Manage slot stock
  - Advanced Options page for admin features
- **Advanced Options** (Admin only):
  - "Deallocate All Batteries" feature with confirmation dialog
  - Clears all user battery allocations in one action
- No dummy stations; stations appear only when admin creates them.

## Project Structure

- `lib/screens`
- `lib/models`
- `lib/services`
- `lib/utils`

## Setup

1. Install dependencies:
   - `flutter pub get`
2. Update `lib/utils/app_config.dart`:
   - `supabaseUrl`
   - `supabaseAnonKey`
   - `adminEmail`
   - `adminPassword`
3. Add your Google Maps API key to Android/iOS app manifests.
4. Run:
   - `flutter run`

## Supabase SQL Schema

See `/master_schema.sql` for the complete production-ready schema or use the master SQL code below:

```sql
-- USERS TABLE (with new fields: vehicle_number, aadhar_number, admin battery allocation)
create table if not exists users (
  id uuid primary key,
  email text unique not null,
  name text not null,
  phone text,
  vehicle_number text,
  aadhar_number text,
  current_battery_slot_id integer,
  current_station_id text,
  assigned_battery_id integer,
  battery_status text default 'none',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- STATIONS TABLE
create table if not exists stations (
  station_id text primary key,
  latitude double precision not null,
  longitude double precision not null,
  status text default 'active',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- SLOTS TABLE (with id UUID for flexibility)
create table if not exists slots (
  id uuid primary key default uuid_generate_v4(),
  slot_id integer not null,
  station_id text not null references stations(station_id) on delete cascade,
  charge_percentage integer default 0,
  battery_present boolean default false,
  unique (station_id, slot_id),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- SWAP_REQUESTS TABLE
create table if not exists swap_requests (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references users(id) on delete cascade,
  station_id text not null references stations(station_id) on delete cascade,
  slot_id integer not null,
  status text default 'pending' check (status in ('pending', 'success', 'failed')),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);
```

## RLS Policies (Implemented)

- `users`: Users can view/update own profile only
- `swap_requests`: Users can view/create own swap requests only
- `stations`, `slots`: All authenticated users can read
- Admin operations: Use service role or authenticated endpoints

## ESP32 Future Support

The schema and services are ready for future API updates to `slots`:

- `charge_percentage`
- `battery_present`

You can later expose an authenticated HTTP endpoint to update `slots`, and UI will automatically reflect changes because station lists are streamed from Supabase.
