# Quick Start - Build & Deploy in 10 Minutes

## What We've Built

✅ **Frontend:** Complete Vue 3 questionnaire app  
✅ **Backend:** Python Flask API endpoints  
✅ **Database:** Schema ready in Supabase  
✅ **Integration:** KnackAppLoader config ready  
✅ **Validation:** Full eligibility checking built-in  

---

## Next Steps (You Do These)

### 1. Install & Build (2 minutes)

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2"

npm install

npm run build
```

**Expected:** Creates `dist/` folder with `questionnaire.js` and `questionnaire.css`

---

### 2. Add Backend to Dashboard (5 minutes)

**Open:** `C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\DASHBOARD\DASHBOARD\app.py`

**Find:** The end of the file (before `if __name__ == '__main__':`)

**Copy-Paste:** Entire contents of `backend_endpoints.py` 

**Save** the file.

---

### 3. Push to GitHub (1 minute)

```bash
# Still in VESPAQuestionnaireV2 directory

git add .
git commit -m "VESPA Questionnaire V2 - Initial release"
git push -u origin main
```

**Verify:** Go to https://github.com/4Sighteducation/VESPA-questionniare-v2 and check `dist/` folder exists.

---

### 4. Deploy Backend to Heroku (2 minutes)

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\DASHBOARD\DASHBOARD"

git add app.py
git commit -m "Add Questionnaire V2 API endpoints"
git push heroku main
```

**Test:** Open https://vespa-dashboard-9a1f84ee5341.herokuapp.com/api/vespa/questionnaire/validate?email=YOUR_EMAIL

Should return JSON (not error page).

---

### 5. Update KnackAppLoader (5 minutes)

**Open:** `C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\Homepage\KnackAppLoader(copy).js`

**Find:** Line ~1434 (after `curriculumResources` config)

**Add:** The `questionnaireV2` config from `knackAppLoader_integration.js`

**Upload:** Copy entire KnackAppLoader to Knack Builder → JavaScript section.

---

### 6. Test in Knack (5 minutes)

**Navigate to:** `https://vespaacademy.knack.com/vespa-academy#vespaquestionniare/`

**Expected Flow:**
1. Loading spinner
2. Instructions screen (if eligible) OR error message
3. Click "Start Questionnaire"
4. 32 questions with progress bar
5. Submit → Success → Redirect to report

**Check Data:**

**Supabase:**
```sql
SELECT * FROM vespa_scores ORDER BY created_at DESC LIMIT 5;
SELECT * FROM question_responses ORDER BY created_at DESC LIMIT 10;
```

**Knack:**
- Object_10: Check your record has updated scores
- Object_29: Check responses are saved

---

## If Something Goes Wrong

### Build Fails
```bash
# Check Node version (should be 18+)
node --version

# Reinstall
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Backend Errors
- Check Heroku logs: `heroku logs --tail -a vespa-dashboard-9a1f84ee5341`
- Look for `[Questionnaire V2]` entries
- Check environment variables are set (SUPABASE_URL, SUPABASE_KEY)

### Frontend Doesn't Load
- Check browser console for errors
- Verify CDN URLs load (paste in browser)
- Wait 10 minutes for JSDelivr cache
- Check KnackAppLoader has correct scriptUrl

### Data Not Saving
- Check browser network tab for API errors
- Check backend logs
- Verify Supabase connection
- Check Knack API credentials

---

## Quick Test Checklist

- [ ] Navigate to #vespaquestionniare/
- [ ] See loading screen
- [ ] See instructions (with your name)
- [ ] Click start
- [ ] See question 1 with Likert scale
- [ ] Select response - "Next" button enables
- [ ] Navigate through all 32 questions
- [ ] Progress bar updates correctly
- [ ] Submit button appears on question 32
- [ ] Click submit - see "Saving..." spinner
- [ ] See success message with scores
- [ ] Click "View Report"
- [ ] Redirects to #vespa-results
- [ ] Report shows correct scores (no zeros!)

**If all ✅ then deployment successful!**

---

## What Happens Next

Once deployed and tested:

1. **Keep old questionnaire as backup**
   - Scene_358 (#add-q) stays active
   - If V2 has issues, students can use old one

2. **Monitor for 1 week**
   - Check submissions daily
   - Watch for errors
   - Verify existing report works

3. **Update navigation**
   - Point GeneralHeader to new questionnaire
   - Disable questionnaireValidator (optional)

4. **Full rollout**
   - All students use V2
   - KSense code no longer loaded
   - Independent from third-party!

---

## Need Help?

Check these files:
- `README.md` - Full technical documentation
- `DEPLOYMENT_GUIDE.md` - Detailed deployment steps
- `backend_endpoints.py` - Backend code with comments
- `src/App.vue` - Frontend logic and state machine

**You're all set! Start with Step 1 above.** 🚀

