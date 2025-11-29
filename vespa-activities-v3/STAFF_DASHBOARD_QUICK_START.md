# VESPA Staff Dashboard V3 - Quick Start Guide

**Get up and running in 10 minutes!** ⏱️

---

## 🚀 **STEP 1: Setup (5 minutes)**

### **1.1 Install Dependencies**

```bash
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2\vespa-activities-v3\staff"

npm install
```

### **1.2 Create Environment File**

Create `staff/.env`:

```env
VITE_SUPABASE_URL=https://qcdcdzfanrlvdcagmwmg.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjZGNkemZhbnJsdmRjYWdtd21nIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTk4MDI0MDAsImV4cCI6MjAxNTM3ODQwMH0.YOUR_KEY_HERE
VITE_ACCOUNT_API_URL=https://vespa-upload-api-07e11c285370.herokuapp.com
VITE_KNACK_APP_ID=6001af8f39b1a60013da7c87
```

**Replace** `YOUR_KEY_HERE` with your actual Supabase anon key!

---

## ⚡ **STEP 2: Test Locally (3 minutes)**

```bash
npm run dev
```

**Opens at**: http://localhost:3001

**Test:**
1. ✅ Page loads without errors
2. ✅ Mock login works (or real Knack login)
3. ✅ Students appear in list
4. ✅ Can click "VIEW" to see student workspace
5. ✅ Can assign activities
6. ✅ Can give feedback

---

## 🌐 **STEP 3: Deploy to Production (2 minutes)**

### **Option A: Build and Deploy to CDN**

```bash
# Build for production
npm run build

# Upload dist/ folder to GitHub
# Then access via jsdelivr CDN:
# https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/staff/dist/
```

### **Option B: Deploy to Netlify (Easiest!)**

1. Connect GitHub repo to Netlify
2. Set build command: `npm run build`
3. Set publish directory: `dist`
4. Add environment variables in Netlify dashboard
5. Deploy! ✅

---

## 🔗 **STEP 4: Integrate with Knack**

### **Method: Load in Knack Page**

Add to your Knack scene (scene_1258 or wherever staff dashboard lives):

```html
<!-- Add this to Page HTML or JavaScript section -->
<div id="vespa-staff-dashboard-v3"></div>

<script type="module">
  // Wait for page to load
  $(document).on('knack-scene-render.scene_1258', function() {
    
    // Load Vue 3
    const vueScript = document.createElement('script');
    vueScript.src = 'https://unpkg.com/vue@3.4.21/dist/vue.global.prod.js';
    document.head.appendChild(vueScript);
    
    // Load built app after Vue loads
    vueScript.onload = () => {
      // Load app CSS
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = 'YOUR_CDN_URL/staff/dist/assets/index.css';
      document.head.appendChild(link);
      
      // Load app JS
      const script = document.createElement('script');
      script.type = 'module';
      script.src = 'YOUR_CDN_URL/staff/dist/assets/index.js';
      document.body.appendChild(script);
    };
  });
</script>
```

**Replace `YOUR_CDN_URL`** with your actual deployment URL!

---

## 🧪 **TESTING CHECKLIST**

### **Authentication:**
- [ ] Super user can access dashboard
- [ ] Staff admin can access dashboard
- [ ] Tutor can access dashboard
- [ ] Students cannot access staff dashboard
- [ ] Proper school context retrieved

### **Student List (Page 1):**
- [ ] All students load within 1 second
- [ ] Progress percentages show correctly
- [ ] Can search by name/email
- [ ] Can filter by year group
- [ ] Can filter by progress status
- [ ] Toggle Activities/Scores view works
- [ ] Can select multiple students
- [ ] Export CSV works
- [ ] Pagination works (if >50 students)

### **Student Workspace (Page 2):**
- [ ] Click VIEW opens student workspace
- [ ] All assigned activities show
- [ ] Activities grouped by category correctly
- [ ] Can assign new activities
- [ ] Can remove activities
- [ ] Click activity opens detail modal
- [ ] Back button returns to list

### **Activity Detail Modal:**
- [ ] Student responses display correctly
- [ ] Activity content shows properly
- [ ] Can write/edit feedback
- [ ] Can save feedback
- [ ] Can mark complete/incomplete
- [ ] Feedback indicators work (unread badge)

### **Bulk Operations:**
- [ ] Select multiple students
- [ ] Bulk assign modal opens
- [ ] Can select multiple activities
- [ ] Bulk assignment succeeds
- [ ] All students get activities

### **Notifications:**
- [ ] Unread feedback shows red badge
- [ ] Badge count is accurate
- [ ] Real-time updates work (optional)

---

## 📊 **SAMPLE QUERIES (For Debugging)**

### **Check Student Data:**

```sql
-- Get a student with all activities
SELECT 
  vs.*,
  (
    SELECT json_agg(ar.*) 
    FROM activity_responses ar 
    WHERE ar.student_email = vs.email
  ) as activities
FROM vespa_students vs
WHERE vs.email = 'student@school.com';
```

### **Check Staff Connections:**

```sql
-- See which students a staff member can access
SELECT 
  vs.full_name,
  vs.email,
  uc.connection_type
FROM user_connections uc
JOIN vespa_accounts staff_acc ON staff_acc.id = uc.staff_account_id
JOIN vespa_accounts student_acc ON student_acc.id = uc.student_account_id
JOIN vespa_students vs ON vs.account_id = student_acc.id
WHERE staff_acc.email = 'staff@school.com';
```

### **Check Activity Assignments:**

```sql
-- See all assignments for a student
SELECT 
  ar.status,
  ar.selected_via,
  ar.completed_at,
  a.name as activity_name,
  a.vespa_category
FROM activity_responses ar
JOIN activities a ON a.id = ar.activity_id
WHERE ar.student_email = 'student@school.com'
  AND ar.status != 'removed'
ORDER BY a.vespa_category, a.level;
```

---

## 🚨 **TROUBLESHOOTING**

### **Problem: "No students showing"**

**Solution:**
1. Check browser console for errors
2. Verify Supabase credentials in `.env`
3. Check RLS policies:
```sql
SELECT * FROM vespa_students LIMIT 1; -- Should return data
```
4. Verify staff has user_connections
5. Check Account API is responding

### **Problem: "Activities not loading"**

**Solution:**
1. Check activities table has data:
```sql
SELECT COUNT(*) FROM activities WHERE is_active = true;
```
2. Check browser Network tab for failed requests
3. Verify Supabase anon key has SELECT permission

### **Problem: "Can't save feedback"**

**Solution:**
1. Check response ID is valid
2. Verify activity was completed by student
3. Check Supabase permissions (service role vs anon)
4. Look for error in browser console

### **Problem: "Progress shows 0% but student completed activities"**

**Solution:**
Check `selected_via` field:
```sql
SELECT selected_via, COUNT(*) 
FROM activity_responses 
WHERE student_email = 'student@school.com'
GROUP BY selected_via;
```

Only `questionnaire` and `staff_assigned` count toward prescribed progress!

---

## 📈 **PERFORMANCE TIPS**

### **If Dashboard is Slow:**

1. **Check Network Tab**: Is Supabase responding quickly?
2. **Check Query**: Are you fetching too much data?
3. **Use Pagination**: Don't load all 500+ students at once
4. **Cache Activities**: Activity catalog only loads once

### **Optimize Queries:**

```javascript
// BAD: Fetches everything
const { data } = await supabase
  .from('vespa_students')
  .select('*');

// GOOD: Fetches only what you need
const { data } = await supabase
  .from('vespa_students')
  .select('id, email, full_name, current_year_group')
  .limit(50);
```

---

## 🎓 **TRAINING GUIDE FOR STAFF**

### **How to Use the New Dashboard:**

1. **View Student Progress:**
   - See all your students at a glance
   - Progress bars show curriculum completion
   - Colors indicate VESPA category progress

2. **Assign Activities:**
   - Click student's VIEW button
   - Click "Assign Activities"
   - Select activities from catalog
   - Click "Assign"

3. **Give Feedback:**
   - Click on completed activity (green card)
   - Read student's responses
   - Write feedback in text box
   - Click "Save Feedback"
   - Student gets notification! 🔔

4. **Track Feedback:**
   - Red badge = unread feedback
   - Green checkmark = student read it
   - Real-time updates

5. **Bulk Operations:**
   - Select multiple students (checkboxes)
   - Click "Assign Activities"
   - Choose activities
   - Applies to all selected students

---

## ✅ **SUCCESS CRITERIA**

Dashboard is working correctly if:

- ✅ Loads in <1 second
- ✅ Progress updates immediately after student completes activity
- ✅ Can assign activities to students
- ✅ Can save feedback that students see
- ✅ Feedback notifications work
- ✅ No console errors
- ✅ Mobile responsive
- ✅ Works in all major browsers

---

## 🎯 **GO LIVE!**

Once you've tested everything:

1. Announce to staff: "New dashboard is live!"
2. Send quick training guide
3. Monitor for first week
4. Gather feedback
5. Iterate and improve

**You're ready to go! 🚀**

---

**Need help?** Reference the complete documentation:
- [Schema Documentation](./ACTIVITIES_V3_SCHEMA_COMPLETE.md)
- [Implementation Guide](./STAFF_DASHBOARD_V3_IMPLEMENTATION.md)
- [Account System Integration](../vespa-upload-api/ACCOUNT_SYSTEM_HANDOVER_FOR_DASHBOARDS.md)

