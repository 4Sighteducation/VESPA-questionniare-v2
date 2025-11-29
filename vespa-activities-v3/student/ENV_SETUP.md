# Environment Variables Setup

## Yes, you need a NEW .env file in the student app directory

The Vue app needs its own `.env` file because:
1. **Vite requires `VITE_` prefix** for environment variables
2. **Frontend uses ANON key** (public), not service key
3. **Different location** - Vue app is separate from Flask backend

## Location

Create a `.env` file here:
```
VESPAQuestionnaireV2/vespa-activities-v3/student/.env
```

## Required Variables

Copy these values from your backend `.env` file (`DASHBOARD/DASHBOARD/.env`):

```env
# Use the SAME Supabase URL as your backend
VITE_SUPABASE_URL=<copy SUPABASE_URL from backend .env>

# Use the ANON/PUBLIC key (NOT the service key!)
# Get this from: Supabase Dashboard > Project Settings > API > anon/public key
VITE_SUPABASE_ANON_KEY=<your-anon-public-key>

# Optional - defaults to Heroku URL if not set
VITE_API_URL=https://vespa-dashboard-9a1f84ee5341.herokuapp.com
```

## Important Notes

1. **VITE_SUPABASE_URL**: Copy directly from your backend `.env` file's `SUPABASE_URL`
2. **VITE_SUPABASE_ANON_KEY**: This is DIFFERENT from `SUPABASE_KEY` or `SUPABASE_SERVICE_KEY`
   - Backend uses: `SUPABASE_KEY` (service key - full access)
   - Frontend uses: `VITE_SUPABASE_ANON_KEY` (anon/public key - limited access)
   - Get it from Supabase Dashboard: Project Settings > API > "anon" "public" key
3. **VITE_API_URL**: Optional - the Vue app defaults to the Heroku URL if not set

## How to Get the ANON Key

1. Go to https://app.supabase.com
2. Select your project
3. Go to **Settings** > **API**
4. Under **Project API keys**, find the **"anon" "public"** key
5. Copy that key (NOT the "service_role" key)

## Security

- ✅ `.env` files are gitignored (won't be committed)
- ✅ Frontend uses ANON key (read-only, RLS protected)
- ✅ Backend uses SERVICE key (full access, server-side only)

## Example .env File

```env
VITE_SUPABASE_URL=https://abcdefghijklmnop.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiY2RlZmdoaWprbG1ub3AiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTYxNjIzOTAyMiwiZXhwIjoxOTMxODE1MDIyfQ.example-signature
VITE_API_URL=https://vespa-dashboard-9a1f84ee5341.herokuapp.com
```

## After Creating .env

1. Restart your dev server if running: `npm run dev`
2. Rebuild if needed: `npm run build`
3. The variables will be embedded at build time

