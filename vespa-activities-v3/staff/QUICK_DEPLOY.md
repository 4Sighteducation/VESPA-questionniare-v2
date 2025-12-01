# ⚡ Quick Deployment Reference - Version 1u

## 1️⃣ Build

```powershell
cd "C:\Users\tonyd\OneDrive - 4Sight Education Ltd\Apps\VESPAQuestionnaireV2\vespa-activities-v3\staff"
npm run build
```

**Verify**: `dist/activity-dashboard-1u.js` and `dist/activity-dashboard-1u.css` exist

---

## 2️⃣ Git Commit & Push

```powershell
cd ..
git add -A
git commit -m "v1u: Font Awesome, compact grids, drag-drop, clickable modals"
git push origin main
```

**Wait**: 2-5 minutes for jsDelivr CDN to update

---

## 3️⃣ Update KnackAppLoader

**File**: `Homepage/KnackAppLoader(copy).js`

**Find** (around line 1533):
```javascript
cssUrl: '...activity-dashboard-1t.css',
jsUrl: '...activity-dashboard-1t.js',
```

**Replace with**:
```javascript
cssUrl: '...activity-dashboard-1u.css',
jsUrl: '...activity-dashboard-1u.js',
```

---

## 4️⃣ Update Knack

1. Go to: https://vespaacademy.knack.com/builder/settings/code
2. Replace JavaScript with updated `KnackAppLoader(copy).js` content
3. Click **Save**

---

## 5️⃣ Test

1. Go to: https://vespaacademy.knack.com/vespa-academy#activity-dashboard/
2. **Hard Refresh**: Ctrl+Shift+R
3. Login as staff

**Quick Test**:
- [ ] Icons show (not squares)
- [ ] Compact grids in assign modals
- [ ] Drag-and-drop works
- [ ] Activity modals open on click

---

## 🚨 If Something Breaks

**Rollback to 1t**:
```javascript
// In KnackAppLoader, change back to:
activity-dashboard-1t.css
activity-dashboard-1t.js
```

**Or** wait 10 minutes and try again (CDN propagation).

---

## ✅ Success!

You'll know it worked when:
1. ✨ Font Awesome icons everywhere
2. 📦 15-20 activities visible in assign modal
3. 🖱️ Drag-and-drop between sections works
4. 🎯 Click activity → modal shows responses
5. ⚡ Everything loads fast (<1 second)


