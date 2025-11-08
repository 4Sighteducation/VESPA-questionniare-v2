# VESPA Questionnaire V2 - Deployment Guide

Complete step-by-step guide to deploy and test the new questionnaire system.

## Pre-Deployment Checklist

### ✅ Database (Completed)
- [x] Supabase schema updated (`quick_fix_students.sql` run)
- [x] `students.academic_year` is nullable
- [x] Multi-year constraints in place
- [x] Helper functions created

### ⏳ Backend (To Do)
- [ ] Copy `backend_endpoints.py` content into `DASHBOARD/DASHBOARD/app.py`
- [ ] Test endpoints work locally
- [ ] Deploy to Heroku

### ⏳ Frontend (To Do)
- [ ] Install npm packages
- [ ] Build Vue app
- [ ] Push to GitHub
- [ ] Verify CDN files load

### ⏳ Integration (To Do)
- [ ] Update KnackAppLoader
- [ ] Test in Knack app
- [ ] (Optional) Update questionnaireValidator redirect
- [ ] (Optional) Update GeneralHeader navigation

---

## Step-by-Step Deployment

### STEP 1: Install Dependencies & Build

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2"

# Install packages
npm install

# Build for production
npm run build
```

**Expected Output:**
- `dist/questionnaire.js` (your Vue app)
- `dist/questionnaire.css` (styles)
- `dist/assets/` (any other assets)

### STEP 2: Test Locally (Optional but Recommended)

```bash
# Run dev server
npm run dev
```

Open: `http://localhost:5173`

**Note:** In dev mode, Knack won't be available, so it will use test mode. You'll see console warnings but can test the UI flow.

### STEP 3: Add Backend Endpoints

**File:** `C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\DASHBOARD\DASHBOARD\app.py`

**Action:** Copy ALL content from `backend_endpoints.py` and paste at the END of `app.py` (before the `if __name__ == '__main__'` block).

**What it adds:**
- `GET /api/vespa/questionnaire/validate` - Check eligibility
- `POST /api/vespa/questionnaire/submit` - Save responses
- `GET /api/vespa/questionnaire/status` - Get student status
- Helper functions for VESPA calculation

### STEP 4: Test Backend Locally

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\DASHBOARD\DASHBOARD"

# Run Flask locally
python app.py
```

**Test the validate endpoint:**
```bash
curl "http://localhost:5000/api/vespa/questionnaire/validate?email=YOUR_EMAIL"
```

Should return JSON with `allowed: true/false` and cycle info.

### STEP 5: Deploy Backend to Heroku

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\DASHBOARD\DASHBOARD"

# If you have changes
git add app.py
git commit -m "Add Questionnaire V2 API endpoints"
git push heroku main

# Or push to GitHub first then deploy
```

**Verify:**
```bash
curl "https://vespa-dashboard-9a1f84ee5341.herokuapp.com/api/vespa/questionnaire/validate?email=YOUR_EMAIL"
```

### STEP 6: Push Frontend to GitHub

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2"

# Add all files
git add .

# Commit
git commit -m "Initial commit - VESPA Questionnaire V2"

# Push to GitHub
git push -u origin main
```

**IMPORTANT:** Make sure GitHub repo is public or accessible via CDN.

**Verify CDN Access** (wait 5-10 minutes for JSDelivr cache):
- JS: https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/dist/questionnaire.js
- CSS: https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/dist/questionnaire.css

### STEP 7: Update KnackAppLoader

**File:** `C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\Homepage\KnackAppLoader(copy).js`

**Location:** Around line 1434 (after `curriculumResources` config)

**Action:** Copy the config from `knackAppLoader_integration.js` and paste into the `APPS` object.

**Result:**
```javascript
const APPS = {
    // ... existing apps ...
    'curriculumResources': { ... },
    
    // ADD THIS:
    'questionnaireV2': {
        scenes: ['scene_1282'],
        views: ['view_3247'],
        scriptUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/dist/questionnaire.js',
        cssUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/dist/questionnaire.css',
        configBuilder: (baseConfig, sceneKey, viewKey) => ({
            ...baseConfig,
            appType: 'questionnaireV2',
            sceneKey: sceneKey,
            viewKey: viewKey,
            elementSelector: '#view_3247',
            apiUrl: 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'
        }),
        configGlobalVar: 'QUESTIONNAIRE_V2_CONFIG',
        initializerFunctionName: 'initializeQuestionnaireV2'
    }
};
```

**Then:** Copy this updated KnackAppLoader(copy).js to Knack Builder → JavaScript section.

### STEP 8: Initial Testing

**Test URL:** `https://vespaacademy.knack.com/vespa-academy#vespaquestionniare/`

**Expected Flow:**
1. ✅ Page loads scene_1282
2. ✅ Spinner shows "Checking your questionnaire access..."
3. ✅ Either:
   - Instructions screen (if eligible)
   - Error message (if not eligible)
4. ✅ Click "Start Questionnaire"
5. ✅ See 32 questions with Likert scale
6. ✅ Submit
7. ✅ Success message
8. ✅ Redirect to #vespa-results (existing report)

**Check Data:**
- **Supabase:** `question_responses` and `vespa_scores` tables
- **Knack:** Object_29 and Object_10 (should have new data)

### STEP 9: Update Navigation (Optional)

**Option A: Keep Validator, Redirect to V2**

Edit `questionnaireValidator.js` line 769:
```javascript
// OLD:
const questionnaireUrl = `#add-q/questionnaireqs/${validationResult.userRecord.id}`;

// NEW:
const questionnaireUrl = `#vespaquestionniare/`;
```

**Option B: Direct Navigation (Recommended)**

Edit `GeneralHeader.js` line 678:
```javascript
// OLD:
{ label: 'VESPA Questionnaire', icon: 'fa-question-circle', href: '#add-q', scene: 'scene_358' },

// NEW:
{ label: 'VESPA Questionnaire', icon: 'fa-question-circle', href: '#vespaquestionniare/', scene: 'scene_1282' },
```

**Option C: Both**
- Update GeneralHeader to point to new questionnaire
- Keep validator as it is (won't interfere since it only intercepts #add-q)

---

## Troubleshooting

### Issue: "Failed to load script from CDN"
**Solution:** 
- Check GitHub repo is public
- Wait 10 minutes for JSDelivr cache
- Or use direct GitHub raw URL temporarily:
  `https://raw.githubusercontent.com/4Sighteducation/VESPA-questionniare-v2/main/dist/questionnaire.js`

### Issue: "CORS error from API"
**Solution:** 
- Verify backend is deployed to Heroku
- Check CORS settings in app.py allow vespaacademy.knack.com

### Issue: "Knack not defined"
**Solution:**
- Make sure you're testing in Knack app, not standalone
- Check browser console for errors

### Issue: "Student record not found in Supabase"
**Solution:**
- Run sync script: `python sync_knack_to_supabase.py`
- Or student needs to be enrolled first

### Issue: Data not writing to Knack
**Solution:**
- Check Object_29 exists and is connected to Object_10 via field_792
- Check console logs in backend for Knack API errors

---

## Monitoring & Maintenance

### Check Submissions
```sql
-- In Supabase SQL Editor

-- Recent questionnaire submissions
SELECT 
  s.email,
  s.name,
  vs.cycle,
  vs.completion_date,
  vs.academic_year,
  vs.vision, vs.effort, vs.systems, vs.practice, vs.attitude, vs.overall
FROM vespa_scores vs
JOIN students s ON vs.student_id = s.id
ORDER BY vs.created_at DESC
LIMIT 20;

-- Count by cycle
SELECT 
  cycle,
  academic_year,
  COUNT(*) as submissions
FROM vespa_scores
WHERE completion_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY cycle, academic_year
ORDER BY cycle;
```

### Check Heroku Logs
```bash
heroku logs --tail -a vespa-dashboard-9a1f84ee5341
```

Look for `[Questionnaire V2]` log entries.

---

## Rollback Plan

If issues arise:

1. **Disable in KnackAppLoader:**
   - Comment out the `questionnaireV2` config
   - Re-upload KnackAppLoader to Knack
   - Students automatically revert to old #add-q

2. **Restore questionnaireValidator:**
   - Undo any changes to line 769
   - Keep pointing to #add-q

3. **Restore GeneralHeader:**
   - Undo changes to navigation
   - Keep pointing to scene_358

**No data loss** - All new submissions are in Supabase, old questionnaire still functional in Knack.

---

## Next Steps After Successful Deployment

1. **Monitor for 1 week:**
   - Check submissions daily
   - Verify dual-write working
   - Watch for errors in logs

2. **Gradual Rollout:**
   - Week 1: Test with your account only
   - Week 2: Enable for one pilot school
   - Week 3: Enable for all students

3. **Phase 2 - Report Replacement:**
   - Build Vue report viewer (scene_43 replacement)
   - Keep using existing report for now

4. **Phase 3 - Staff Portal:**
   - Build staff coaching report view (scene_1095 replacement)

---

## Success Metrics

- ✅ Students can complete questionnaire without errors
- ✅ Data appears in both Supabase AND Knack
- ✅ Existing report (#vespa-results) shows correct scores
- ✅ No zeros appearing in reports
- ✅ Dashboard shows new data immediately (no sync delay)

**Once these are met, you're fully independent of KSense!** 🎉

