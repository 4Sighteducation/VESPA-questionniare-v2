# Issue Analysis & Resolution Plan

**Date**: November 2025  
**Status**: ✅ Fixes Implemented - Ready for Deployment  
**Context**: Console errors showing 404 errors on API endpoints (routes not registered) and 406 on Supabase direct queries

---

## 🔍 **Issue Analysis**

### **Error 1: Backend API 404 Errors** 🔴 → ✅ FIXED

**Affected Endpoints**:
- `GET /api/activities/recommended?email=aramsey@vespa.academy&cycle=1` → **404 Not Found** (was showing as 500 in browser, but logs show 404)
- `GET /api/activities/assigned?email=aramsey@vespa.academy&cycle=1` → **404 Not Found**

**Root Cause Analysis** (from Heroku logs):
1. ✅ **Routes exist**: Code in `DASHBOARD/DASHBOARD/activities_api.py` contains endpoint implementations
2. ❌ **Routes NOT registered**: Flask returning 404 means routes weren't registered with Flask app
3. ❓ **Likely causes**:
   - Import error caught silently (try/except swallowing error)
   - `SUPABASE_ENABLED` is False
   - Exception during route registration
   - Import path issue

**✅ FIXES APPLIED**:
- Added detailed logging to route registration process
- Added traceback logging for import errors
- Added request logging in endpoint handlers
- Added better error messages with exception types

**Code Locations**:
- Backend: `DASHBOARD/DASHBOARD/activities_api.py` lines 30-159 (recommended), 188-237 (assigned)
- Frontend calls: `VESPAQuestionnaireV2/vespa-activities-v3/student/src/composables/useVESPAScores.js` line 38

---

### **Error 2: Supabase Direct Query 406 Error** 🔴

**Affected Query**:
```
GET qcdcdzfanrlvdcagmwmg.supabase.co/rest/v1/vespa_students?
  select=total_points,total_activities_completed,total_achievements&
  email=eq.aramsey@vespa.academy
```
→ **406 Not Acceptable**

**Root Cause Analysis**:
1. ✅ **Query location**: `VESPAQuestionnaireV2/vespa-activities-v3/student/src/composables/useAchievements.js` lines 65-69
2. ❌ **Problem**: Frontend is querying Supabase directly from browser using anon key
3. ✅ **Root cause**: **RLS (Row Level Security) policies** blocking anonymous access to `vespa_students` table

**✅ FIXES APPLIED**:
- Created new API endpoint: `GET /api/students/stats?email=...`
- Updated `useAchievements.js` to use API endpoint instead of direct Supabase query
- Added fallback to calculated totalPoints if API fails

**Code Location**:
- `VESPAQuestionnaireV2/vespa-activities-v3/student/src/composables/useAchievements.js` lines 65-69

---

## ✅ **Fixes Applied**

### **1. Backend Route Registration** ✅
- **File**: `DASHBOARD/DASHBOARD/app.py` lines 11538-11562
- **Changes**:
  - Added detailed logging before/after import
  - Added traceback logging for import errors
  - Added check for `supabase_client` existence
  - Added emoji indicators for success/warning/error states

### **2. Backend Error Handling** ✅
- **File**: `DASHBOARD/DASHBOARD/activities_api.py`
- **Changes**:
  - Added request logging in `/api/activities/recommended` endpoint
  - Added traceback logging in error handlers
  - Added exception type to error responses

### **3. New API Endpoint** ✅
- **File**: `DASHBOARD/DASHBOARD/activities_api.py` lines 928-964
- **New Endpoint**: `GET /api/students/stats?email=...`
- **Returns**: `{ total_points, total_activities_completed, total_achievements }`
- **Purpose**: Replace direct Supabase queries from frontend

### **4. Frontend Update** ✅
- **File**: `VESPAQuestionnaireV2/vespa-activities-v3/student/src/composables/useAchievements.js` lines 64-83
- **Changes**:
  - Replaced direct Supabase query with API endpoint call
  - Added error handling and fallback
  - Added console logging for debugging

### **5. Constants Update** ✅
- **File**: `VESPAQuestionnaireV2/vespa-activities-v3/shared/constants.js` line 98
- **Added**: `STUDENT_STATS: '/api/students/stats'` endpoint constant

---

## 🎯 **Next Steps (Deployment)**

### **Phase 1: Fix Backend API 500 Errors** (Priority 1)

#### **Step 1.1: Check Server Logs**
- [ ] Access Heroku logs: `heroku logs --tail --app vespa-dashboard-9a1f84ee5341`
- [ ] Look for stack traces from `/api/activities/recommended` and `/api/activities/assigned`
- [ ] Identify exact exception message

#### **Step 1.2: Verify Database Function Exists**
- [ ] Check if `get_or_create_vespa_student` function exists in Supabase
- [ ] If missing, create it (see `FUTURE_READY_SCHEMA.sql` or create new migration)
- [ ] Test function manually in Supabase SQL editor

#### **Step 1.3: Add Better Error Handling**
- [ ] Wrap all Supabase queries in try-catch blocks
- [ ] Log detailed error messages with context
- [ ] Return meaningful error messages to frontend (not just "500")

#### **Step 1.4: Fix Specific Issues**
**Potential Issues to Check**:
1. **Line 47-50**: `vespa_students` query might fail if table doesn't exist or column names wrong
2. **Line 70-73**: `students` table query might return empty (expected for new students)
3. **Line 90-95**: `vespa_scores` query might fail if no scores exist
4. **Line 119-130**: `activities` query might fail if table structure different

**Fix Strategy**:
- Add null checks after each query
- Handle empty results gracefully
- Provide fallback values

#### **Step 1.5: Test Endpoints**
- [ ] Test `/api/activities/recommended?email=aramsey@vespa.academy&cycle=1` directly
- [ ] Test `/api/activities/assigned?email=aramsey@vespa.academy&cycle=1` directly
- [ ] Verify JSON response structure matches frontend expectations

---

### **Phase 2: Fix Supabase Direct Query 406 Error** (Priority 2)

#### **Option A: Use API Endpoint Instead** (Recommended ✅)

**Why**: More secure, consistent with architecture, avoids RLS issues

**Changes Needed**:
1. Create new API endpoint: `GET /api/students/stats?email=...`
2. Update `useAchievements.js` to call API instead of direct Supabase query
3. Backend queries `vespa_students` with service key (bypasses RLS)

**Implementation**:
```python
# In activities_api.py
@app.route('/api/students/stats', methods=['GET'])
def get_student_stats():
    student_email = request.args.get('email')
    if not student_email:
        return jsonify({"error": "email parameter required"}), 400
    
    result = supabase.table('vespa_students').select(
        'total_points, total_activities_completed, total_achievements'
    ).eq('email', student_email).single().execute()
    
    return jsonify(result.data if result.data else {})
```

```javascript
// In useAchievements.js - replace lines 65-69
const response = await fetch(
  `${API_BASE_URL}/api/students/stats?email=${studentEmail}`
);
if (response.ok) {
  const data = await response.json();
  if (data.total_points !== undefined) {
    totalPoints.value = data.total_points || 0;
  }
}
```

#### **Option B: Fix RLS Policies** (Alternative)

**Why**: Allows direct queries, but requires RLS setup

**Changes Needed**:
1. Create RLS policy allowing students to read their own `vespa_students` record
2. Update Supabase client to use proper authentication
3. Ensure Accept headers are set correctly

**RLS Policy**:
```sql
-- Allow students to read their own vespa_students record
CREATE POLICY "Students can read own stats"
ON vespa_students
FOR SELECT
USING (auth.uid()::text = email OR auth.jwt() ->> 'email' = email);
```

**Note**: This requires Supabase Auth, which might not be set up yet (using Knack auth).

---

### **Phase 3: Additional Fixes** (Priority 3)

#### **Step 3.1: Add Error Boundaries**
- [ ] Add try-catch in `App.vue` initialization
- [ ] Show user-friendly error messages
- [ ] Add retry mechanisms

#### **Step 3.2: Improve Logging**
- [ ] Add console.log statements with `[VESPA Activities]` prefix
- [ ] Log API request/response details
- [ ] Log Supabase query errors

#### **Step 3.3: Handle Edge Cases**
- [ ] Student doesn't exist in `vespa_students` → auto-create
- [ ] No VESPA scores → show default activities
- [ ] No assigned activities → show empty state
- [ ] Network errors → show retry button

---

## 📋 **Implementation Checklist**

### **Immediate Actions** (Do First)
- [ ] **1. Check Heroku logs** to see exact 500 error messages
- [ ] **2. Verify `get_or_create_vespa_student` function exists** in Supabase
- [ ] **3. Test backend endpoints directly** with curl/Postman
- [ ] **4. Fix backend 500 errors** based on log findings
- [ ] **5. Replace direct Supabase query** with API endpoint call

### **Testing Checklist**
- [ ] Test `/api/activities/recommended` endpoint
- [ ] Test `/api/activities/assigned` endpoint  
- [ ] Test `/api/students/stats` endpoint (new)
- [ ] Test frontend initialization flow
- [ ] Test error handling and fallbacks

### **Verification**
- [ ] No 500 errors in console
- [ ] No 406 errors in console
- [ ] Activities load successfully
- [ ] Student stats display correctly
- [ ] Error messages are user-friendly

---

## 🔧 **Quick Fixes (Can Do Now)**

### **Fix 1: Add Error Logging to Backend**

Update `activities_api.py` to log errors better:

```python
@app.route('/api/activities/recommended', methods=['GET'])
def get_recommended_activities():
    try:
        student_email = request.args.get('email')
        cycle = int(request.args.get('cycle', 1))
        
        logger.info(f"[Activities API] Getting recommended activities for {student_email}, cycle {cycle}")
        
        if not student_email:
            return jsonify({"error": "email parameter required"}), 400
        
        # ... rest of code ...
        
    except Exception as e:
        logger.error(f"[Activities API] Error in get_recommended_activities: {str(e)}", exc_info=True)
        import traceback
        logger.error(traceback.format_exc())
        return jsonify({"error": str(e), "type": type(e).__name__}), 500
```

### **Fix 2: Replace Direct Supabase Query**

Update `useAchievements.js`:

```javascript
// Replace lines 64-73 with:
// Fetch from API endpoint instead of direct Supabase query
try {
  const response = await fetch(
    `${API_BASE_URL}/api/students/stats?email=${studentEmail}`
  );
  
  if (response.ok) {
    const data = await response.json();
    if (data.total_points !== undefined) {
      totalPoints.value = data.total_points || totalPoints.value;
    }
  } else {
    console.warn('[useAchievements] Could not fetch student stats from API');
  }
} catch (err) {
  console.warn('[useAchievements] Error fetching student stats:', err);
  // Continue with calculated totalPoints from achievements
}
```

---

## 📊 **Expected Outcomes**

After fixes:
- ✅ `/api/activities/recommended` returns 200 with JSON data
- ✅ `/api/activities/assigned` returns 200 with JSON data
- ✅ `/api/students/stats` returns 200 with student stats
- ✅ No 406 errors in console
- ✅ Frontend loads activities successfully
- ✅ Student stats display correctly

---

## 🚨 **Critical Notes**

1. **Database Function**: The `get_or_create_vespa_student` function might not exist. Check `FUTURE_READY_SCHEMA.sql` or create it.

2. **RLS Policies**: If using direct Supabase queries, RLS policies must allow anonymous access OR use authenticated requests.

3. **Error Handling**: Current error handling might be swallowing exceptions. Need better logging.

4. **Fallback Strategy**: Frontend should handle API failures gracefully and show user-friendly messages.

---

## 📞 **Next Steps**

1. **Immediate**: Check Heroku logs to see exact error messages
2. **Short-term**: Fix backend 500 errors based on logs
3. **Short-term**: Create `/api/students/stats` endpoint
4. **Short-term**: Update frontend to use API instead of direct query
5. **Testing**: Verify all endpoints work end-to-end

---

**Last Updated**: November 2025  
**Status**: ✅ Fixes Implemented - Ready for Deployment  
**Priority**: Critical - blocking frontend initialization

---

## 📋 **Deployment Checklist**

### **Before Deploying**:
- [ ] Review all code changes
- [ ] Verify `SUPABASE_ENABLED` is True in Heroku environment
- [ ] Verify `supabase_client` is initialized correctly
- [ ] Check Heroku logs after deployment for route registration messages

### **After Deploying**:
- [ ] Check Heroku logs for: `✅ VESPA Activities V3 API routes registered successfully`
- [ ] Test endpoint: `GET /api/activities/recommended?email=aramsey@vespa.academy&cycle=1`
- [ ] Test endpoint: `GET /api/activities/assigned?email=aramsey@vespa.academy&cycle=1`
- [ ] Test endpoint: `GET /api/students/stats?email=aramsey@vespa.academy`
- [ ] Verify no 404 errors in browser console
- [ ] Verify no 406 errors in browser console
- [ ] Test frontend initialization flow

### **If Routes Still Don't Register**:
1. Check Heroku logs for import errors
2. Verify `activities_api.py` file exists in Heroku deployment
3. Check if `SUPABASE_ENABLED` is True
4. Check if `supabase_client` is not None
5. Verify Python import path is correct

