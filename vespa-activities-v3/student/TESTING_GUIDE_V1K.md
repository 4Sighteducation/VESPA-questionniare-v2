# 🧪 Quick Testing Guide - V1K

## 🎯 Test Accounts
- `cali@vespa.academy` (Cash Ali - Cycle 2, mixed scores: V3, E3, S6, P9, A4)
- `aramsey@vespa.academy` (Alena Ramsey)

---

## ⚡ Quick Tests (10 minutes)

### 1️⃣ Welcome Modal Test
```javascript
// In browser console:
localStorage.removeItem('vespa-welcome-modal-seen');
location.reload();
```
**Expected**: See welcome modal with scores + prescribed activities

### 2️⃣ Prescription Flow Test
**Option A - Continue**:
1. Click "Yes, Continue!"
2. ✅ Activities auto-assigned
3. ✅ Modal closes
4. ✅ Dashboard shows grouped activities

**Option B - Choose Own**:
1. Click "Select by Problem"
2. ✅ Problem selector modal opens
3. Click any problem
4. ✅ Activities modal shows
5. Select 2-3 activities
6. Click "Add to Dashboard"
7. ✅ Activities added

### 3️⃣ Points Test
1. Open any Level 2 activity
2. Complete it
3. ✅ See "+10 points" notification (slide from right)
4. ✅ Header total points increases

### 4️⃣ Removal Test
1. Click "Remove" on any activity
2. ✅ Activity disappears
3. Open staff dashboard
4. ✅ Status = 'removed', responses preserved

---

## 🐛 Troubleshooting

### CDN Not Loading?
Wait 2-3 mins after push, then:
```
https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/vespa-activities-v3/student/dist/student-activities1k.js?v=123
```

### Modal Not Showing?
```javascript
localStorage.clear();
location.reload();
```

### Points Not Updating?
Check Supabase `vespa_students.total_points`:
```sql
SELECT email, total_points, total_activities_completed 
FROM vespa_students 
WHERE email = 'cali@vespa.academy';
```

---

## ✅ Success Criteria

- [ ] Welcome modal shows with VESPA scores
- [ ] Prescribed activities display (8-10 activities)
- [ ] "Continue" assigns all activities
- [ ] Problem selector shows 35 problems
- [ ] Activities filter by problem_mappings correctly
- [ ] Points awarded on completion (10 or 15)
- [ ] Success notification appears
- [ ] Total points updates in real-time
- [ ] Activity removal works
- [ ] Staff can see removed activities

---

## 🚀 Ready to Test!

All features deployed and ready. Just copy KnackAppLoader into Knack and test!

