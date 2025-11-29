# VESPA Activities V3 - Handover Document
**Date:** November 11, 2025  
**Status:** Frontend Loading, Backend API Errors

---

## Current Status

### ✅ What's Working
1. **Frontend Build & Loading**
   - Vue 3 student app builds successfully
   - App loads correctly in Knack via KnackAppLoader
   - Version `1d` deployed to GitHub and CDN
   - Supabase ANON key properly embedded in build
   - App initializes and mounts successfully

2. **KnackAppLoader Integration**
   - Configuration updated to use version `1d`
   - CSS and JS files loading from CDN correctly
   - Initializer function called successfully

3. **Environment Variables**
   - `.env` file configured with `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_API_URL`
   - `vite.config.js` fixed to use `path.resolve(__dirname)` for correct `.env` loading
   - Build process correctly embeds environment variables

### ❌ What's Broken

1. **Backend API Endpoints - 500 Errors**
   - `/api/activities/recommended` - Returns 500 Internal Server Error
   - `/api/activities/assigned` - Returns 500 Internal Server Error
   - Error message: "404 Not Found: The requested URL was not found on the server"
   - **Root Cause:** Likely `desc=True` syntax issue in Supabase Python client queries

2. **Supabase Direct Queries - 406 Errors**
   - Direct queries to `vespa_students` table return 406 Not Acceptable
   - Likely RLS (Row Level Security) policy issue
   - Frontend trying to query: `vespa_students?select=total_points,total_activities_completed,total_achievements&email=eq.aramsey@vespa.academy`

---

## Recent Changes Made

### Frontend (Vue 3 Student App)
- **Location:** `VESPAQuestionnaireV2/vespa-activities-v3/student/`
- **Build Version:** `1d` (student-activities1d.js, student-activities1d.css)
- **Fixed Issues:**
  - Fixed `loadEnv` to use `path.resolve(__dirname)` instead of `process.cwd()`
  - Added real Supabase ANON key to `.env` file
  - Updated fallback ANON key in `vite.config.js` to real value
  - Incremented version from `1c` to `1d` for CDN cache busting

### Backend (Flask API)
- **Location:** `DASHBOARD/DASHBOARD/activities_api.py`
- **Fixed Issues:**
  - Removed all `desc=True` syntax from Supabase queries
  - Replaced with Python-based sorting (query ascending, sort descending in Python)
  - Fixed 4 endpoints: `get_recommended_activities`, `get_assigned_activities`, `get_my_activities`, `get_notifications`
- **Status:** Changes committed and pushed, waiting for Heroku deployment

### KnackAppLoader
- **Location:** `Homepage/KnackAppLoader(copy).js`
- **Updated:** CDN URLs to use version `1d`
- **Configuration:** `studentActivitiesV3` app configured for `scene_1288` / `view_3262`

---

## File Locations

### Frontend
```
VESPAQuestionnaireV2/vespa-activities-v3/student/
├── src/
│   ├── App.vue                    # Main Vue component
│   ├── main.js                    # Entry point with initializeStudentActivitiesV3
│   ├── composables/
│   │   ├── useActivities.js      # Activity fetching logic
│   │   ├── useVESPAScores.js      # VESPA scores fetching
│   │   ├── useNotifications.js   # Notifications
│   │   └── useAchievements.js     # Achievements
│   └── components/                # Vue components
├── shared/
│   ├── supabaseClient.js          # Supabase client config
│   └── constants.js                # Constants and config
├── vite.config.js                 # Build configuration
└── .env                           # Environment variables (gitignored)
```

### Backend
```
DASHBOARD/DASHBOARD/
├── activities_api.py              # All activities API endpoints
└── app.py                         # Main Flask app (registers activities routes)
```

### Configuration
```
Homepage/KnackAppLoader(copy).js   # Knack app loader configuration
```

---

## Current Errors

### Backend API Errors (500)
**Error Message:** "404 Not Found: The requested URL was not found on the server"  
**Status Code:** 500 (not 404 - Flask catching exception)

**Affected Endpoints:**
- `GET /api/activities/recommended?email=aramsey@vespa.academy&cycle=1`
- `GET /api/activities/assigned?email=aramsey@vespa.academy&cycle=1`

**Likely Cause:** 
- `desc=True` syntax may not be supported in Supabase Python client version on Heroku
- **Fix Applied:** Removed all `desc=True`, replaced with Python sorting
- **Status:** Fixed in code, waiting for Heroku deployment

### Supabase Direct Query Errors (406)
**Error:** `GET /rest/v1/vespa_students?... 406 (Not Acceptable)`

**Likely Cause:**
- Row Level Security (RLS) policies blocking anonymous access
- Frontend trying to query `vespa_students` table directly

**Solution Needed:**
- Either add RLS policies allowing anonymous read access
- Or route these queries through backend API endpoints

---

## Next Steps

### Immediate (Critical)
1. **Wait for Heroku Deployment**
   - Backend changes pushed, Heroku should auto-deploy
   - Check deployment: `heroku releases --app vespa-dashboard`
   - Verify routes registered: Check logs for "VESPA Activities V3 API routes registered successfully"

2. **Test Backend API Endpoints**
   - After deployment, test: `https://vespa-dashboard-9a1f84ee5341.herokuapp.com/api/activities/recommended?email=aramsey@vespa.academy&cycle=1`
   - Should return JSON instead of 500 error

3. **Fix Supabase RLS Policies**
   - Review RLS policies on `vespa_students` table
   - Either allow anonymous read access OR route queries through backend API
   - Frontend should use API endpoints, not direct Supabase queries

### Short Term
1. **Verify All API Endpoints**
   - Test all 15 endpoints listed in `ACTIVITY_PLA1.md`
   - Check error handling and logging

2. **Fix Frontend Direct Supabase Queries**
   - Replace direct `vespa_students` queries with API calls
   - Use `/api/activities/*` endpoints instead

3. **Test Full Flow**
   - Student can view recommended activities
   - Student can start/complete activities
   - Achievements are awarded
   - Notifications work

### Medium Term
1. **Build Staff App**
   - Mirror student app structure
   - Implement staff monitoring endpoints
   - Build Vue 3 staff app

2. **Performance Optimization**
   - Cache frequently accessed data
   - Optimize database queries
   - Add pagination where needed

---

## Important Notes

### Security
- **Supabase ANON Key:** Publicly exposed in frontend build (by design, safe)
- **Security Model:** Row Level Security (RLS) policies protect data
- **SERVICE Key:** Never exposed, backend only

### Environment Variables
- **Frontend:** `.env` file in `student/` directory (gitignored)
- **Backend:** Heroku config vars (not in codebase)
- **Build Process:** Vite embeds env vars at build time into JS bundle

### Version Management
- **Frontend:** Increment version in `vite.config.js` (currently `1d`)
- **CDN Cache Busting:** Update version number in:
  - `vite.config.js` (build output filenames)
  - `KnackAppLoader(copy).js` (CDN URLs)

### Deployment Process
1. Update `.env` file with new values (if needed)
2. Run `npm run build` in `student/` directory
3. Commit and push build files to GitHub
4. Update `KnackAppLoader(copy).js` with new version number
5. Copy `KnackAppLoader(copy).js` to Knack Builder

### Backend Deployment
- **Auto-deploy:** Heroku auto-deploys on git push to `main`
- **Manual:** `git push heroku main` (if needed)
- **Check Logs:** `heroku logs --tail --app vespa-dashboard`

---

## Known Issues

1. **Backend API 500 Errors**
   - Status: Fixed in code, waiting for deployment
   - Fix: Removed `desc=True` syntax, using Python sorting

2. **Supabase 406 Errors**
   - Status: Needs RLS policy fix or API routing
   - Impact: Frontend can't query `vespa_students` directly

3. **Frontend Direct Queries**
   - Status: Should use API endpoints instead
   - Location: Check `useAchievements.js` and other composables

---

## Testing Checklist

- [ ] Backend API endpoints return 200 (not 500)
- [ ] Student can see recommended activities
- [ ] Student can see assigned activities
- [ ] Student can start an activity
- [ ] Student can save progress
- [ ] Student can complete an activity
- [ ] Achievements are awarded correctly
- [ ] Notifications appear
- [ ] VESPA scores display correctly
- [ ] No console errors in browser

---

## Key Contacts & Resources

- **GitHub Repo:** `4Sighteducation/VESPA-questionniare-v2`
- **Heroku App:** `vespa-dashboard`
- **Supabase Project:** `qcdcdzfanrlvdcagmwmg.supabase.co`
- **API Base URL:** `https://vespa-dashboard-9a1f84ee5341.herokuapp.com`
- **CDN:** JSDelivr via GitHub (`cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/...`)

---

## Architecture Notes

### Frontend Architecture
- **Framework:** Vue 3 (Composition API)
- **Build Tool:** Vite
- **Format:** IIFE (Immediately Invoked Function Expression) to prevent DOM conflicts
- **Integration:** Loaded dynamically via KnackAppLoader

### Backend Architecture
- **Framework:** Flask (Python)
- **Database:** Supabase (PostgreSQL)
- **API Style:** RESTful
- **Error Handling:** Try-except blocks with logging

### Data Flow
1. Frontend loads from CDN
2. Frontend calls Flask API endpoints (`/api/activities/*`)
3. Flask queries Supabase using SERVICE key
4. Flask returns JSON to frontend
5. Frontend also queries Supabase directly (ANON key) for some data (needs RLS fix)

---

## Troubleshooting

### If Backend Still Returns 500:
1. Check Heroku logs: `heroku logs --tail --app vespa-dashboard`
2. Verify routes registered: Look for "VESPA Activities V3 API routes registered successfully"
3. Check Supabase connection: Look for "Supabase client initialized"
4. Test endpoint directly: `curl https://vespa-dashboard-9a1f84ee5341.herokuapp.com/api/activities/recommended?email=test@vespa.academy&cycle=1`

### If Frontend Not Loading:
1. Check browser console for CDN errors
2. Verify version number matches in `KnackAppLoader` and `vite.config.js`
3. Hard refresh browser (Ctrl+Shift+R)
4. Check CDN URL is correct: `https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/vespa-activities-v3/student/dist/student-activities1d.js`

### If Supabase Queries Fail:
1. Check RLS policies in Supabase dashboard
2. Verify ANON key is correct (not placeholder)
3. Check if queries should go through API instead

---

## Code Changes Summary

### activities_api.py
- **Lines Changed:** ~50 lines
- **Changes:** Removed `desc=True` from 4 query locations
- **Impact:** Queries now use ascending order, sorted in Python

### vite.config.js
- **Lines Changed:** ~20 lines
- **Changes:** Fixed `loadEnv` path, updated version to `1d`
- **Impact:** Environment variables now load correctly

### KnackAppLoader(copy).js
- **Lines Changed:** 2 lines
- **Changes:** Updated CDN URLs to version `1d`
- **Impact:** Loads correct build version

---

**Last Updated:** November 11, 2025  
**Next Review:** After Heroku deployment completes

