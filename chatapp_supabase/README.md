# ChatApp — Supabase Version Setup Guide

## What You Need
- Flutter installed (`flutter doctor` passes)
- A Supabase account (free, no card needed)

---

## STEP 1 — Create Supabase Account

1. Go to **https://supabase.com**
2. Click **"Start your project"**
3. Sign up with **Google** or **Email** (no GitHub required)
4. Click **"New Project"**
5. Fill in:
   - Name: `chatapp`
   - Database Password: (choose a strong password, save it)
   - Region: Choose closest to you
6. Click **"Create new project"**
7. Wait ~2 minutes for it to set up

---

## STEP 2 — Run the Database Schema

1. In Supabase dashboard, click **"SQL Editor"** (left sidebar)
2. Click **"New query"**
3. Open the file `supabase_schema.sql` from this project
4. Copy ALL the contents
5. Paste into the SQL editor
6. Click **"Run"** (or press Ctrl+Enter)
7. You should see: `Success. No rows returned`

---

## STEP 3 — Create Storage Buckets

1. In Supabase, click **"Storage"** (left sidebar)
2. Click **"New bucket"**
3. Create bucket 1:
   - Name: `chat-files`
   - Toggle **Public bucket** → ON
   - Click Save
4. Click **"New bucket"** again
5. Create bucket 2:
   - Name: `avatars`
   - Toggle **Public bucket** → ON
   - Click Save

---

## STEP 4 — Get Your API Keys

1. In Supabase, click **"Settings"** (gear icon, left sidebar)
2. Click **"API"**
3. Copy these two values:

```
Project URL:   https://xxxxxxxxxx.supabase.co
anon public:   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## STEP 5 — Add Keys to Flutter App

Open this file:
```
flutter_app/lib/utils/supabase_config.dart
```

Replace with your actual values:
```dart
const String supabaseUrl = 'https://xxxxxxxxxx.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

---

## STEP 6 — Run the Flutter App

```bash
# Go to flutter app folder
cd flutter_app

# Install dependencies
flutter pub get

# Check devices
flutter devices

# Run the app
flutter run
```

---

## STEP 7 — Test the App

1. **Sign Up** — enter name, email, password
2. Open app on a second device or emulator → Sign Up with different email
3. Tap **+** button → search the other user → start chat
4. Send messages, images, files!

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `supabaseUrl` error | Check you copied the full URL including `https://` |
| Sign up fails | Check Supabase → Authentication → Settings → Enable email signups |
| Messages not loading | Make sure you ran the full SQL schema |
| File upload fails | Check Storage buckets exist and are set to Public |
| `flutter pub get` fails | Check internet; run `flutter clean` then try again |

---

## Enable Email Confirmations OFF (for testing)

By default Supabase requires email confirmation. To disable for testing:

1. Supabase → **Authentication** → **Settings**
2. Under **Email Auth** → Toggle **"Confirm email"** → OFF
3. Save

Now users can sign up and log in instantly without email verification.
