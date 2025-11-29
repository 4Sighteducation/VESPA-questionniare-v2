# VESPA Activities V3 - Staff Dashboard

**Version**: 3.0  
**Framework**: Vue 3 + Vite  
**Database**: 100% Supabase (no Knack API calls except authentication)

---

## 🚀 **Quick Start**

### **1. Install Dependencies**

```bash
cd staff
npm install
```

### **2. Configure Environment**

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```env
VITE_SUPABASE_URL=https://qcdcdzfanrlvdcagmwmg.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here
VITE_ACCOUNT_API_URL=https://vespa-upload-api-07e11c285370.herokuapp.com
VITE_KNACK_APP_ID=your_knack_app_id
```

### **3. Run Development Server**

```bash
npm run dev
```

Opens at: http://localhost:3001

### **4. Build for Production**

```bash
npm run build
```

Output: `dist/` folder

---

## 📋 **Features**

### **Page 1: Student List**
- ✅ View all students with activity progress
- ✅ Real-time progress calculations
- ✅ Filter by year group, progress, search
- ✅ Sort by name or progress
- ✅ Toggle between Activities/Scores view
- ✅ Bulk select and assign activities
- ✅ Export to CSV
- ✅ Pagination (50 students per page)

### **Page 2: Student Workspace**
- ✅ View individual student's assigned activities
- ✅ Activities organized by VESPA category and level
- ✅ Drag-and-drop interface (coming soon)
- ✅ Assign new activities
- ✅ Remove activities
- ✅ View activity details with student responses
- ✅ Provide feedback on completed activities
- ✅ Mark activities as complete/incomplete (staff override)

### **Notification System**
- ✅ Unread feedback tracking
- ✅ Visual indicators for unread feedback
- ✅ Real-time updates via Supabase subscriptions
- ✅ Badge counts for staff notifications

---

## 🗄️ **Data Model**

### **Key Tables Used:**

1. **vespa_students** - Student registry
2. **vespa_staff** - Staff registry
3. **user_connections** - Staff-student relationships
4. **activities** - Activity catalog
5. **activity_responses** - THE MAGIC TABLE (assignments, progress, completions, feedback)
6. **activity_questions** - Questions per activity
7. **activity_history** - Audit trail

### **How Assignments Work:**

```javascript
// When staff assigns activity:
activity_responses {
  student_email: 'student@school.com',
  activity_id: 'uuid',
  status: 'assigned',           // Not completed yet
  selected_via: 'staff_assigned', // THIS marks it as prescribed!
  completed_at: null
}

// When student completes:
activity_responses {
  status: 'completed',
  completed_at: '2025-11-29T10:30:00Z',
  responses: { question_id: 'answer', ... }
}

// When staff gives feedback:
activity_responses {
  staff_feedback: 'Great work!',
  staff_feedback_by: 'teacher@school.com',
  staff_feedback_at: '2025-11-29T11:00:00Z',
  feedback_read_by_student: false  // Triggers notification!
}
```

---

## 🏗️ **Architecture**

### **Authentication Flow:**

```
User logs into Knack
    ↓
Get email from Knack.session.user
    ↓
Call /api/v3/accounts/auth/check
    ↓
Get schoolId and staff role
    ↓
Query Supabase with school context
    ↓
Display dashboard (no more Knack API calls!)
```

### **Data Loading (100% Supabase):**

```javascript
// Get students with activities
const { data: students } = await supabase
  .from('vespa_students')
  .select(`
    *,
    activity_responses (
      *,
      activities (*)
    )
  `)
  .eq('school_id', schoolId);

// Calculate progress client-side (instant!)
students.forEach(student => {
  const prescribed = student.activity_responses.filter(
    r => r.selected_via === 'questionnaire' || r.selected_via === 'staff_assigned'
  );
  const completed = prescribed.filter(r => r.completed_at);
  student.progress = (completed.length / prescribed.length) * 100;
});
```

---

## 📁 **Project Structure**

```
staff/
├── src/
│   ├── components/
│   │   ├── StudentListView.vue        - Page 1: Student table
│   │   ├── StudentWorkspace.vue       - Page 2: Individual student
│   │   ├── ActivityCard.vue           - Activity display card
│   │   ├── AssignModal.vue            - Single student assignment
│   │   ├── BulkAssignModal.vue        - Multi-student assignment
│   │   ├── ActivityDetailModal.vue    - View/edit activity
│   │   └── ActivityPreviewModal.vue   - Preview before assign
│   ├── composables/
│   │   ├── useAuth.js                 - Authentication
│   │   ├── useStudents.js             - Student data management
│   │   ├── useActivities.js           - Activity operations
│   │   ├── useFeedback.js             - Feedback system
│   │   └── useNotifications.js        - Real-time notifications
│   ├── App.vue                        - Main app component
│   ├── main.js                        - Entry point
│   └── style.css                      - Global styles
├── index.html
├── package.json
├── vite.config.js
└── .env                               - Environment config (gitignored)
```

---

## 🎨 **Design System**

### **Colors:**

- **Primary**: #079baa (VESPA Teal)
- **Vision**: #f97316 (Orange)
- **Effort**: #3b82f6 (Blue)
- **Systems**: #10b981 (Green)
- **Practice**: #8b5cf6 (Purple)
- **Attitude**: #ec4899 (Pink)

### **Typography:**

- **Headings**: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto
- **Body**: 14px, line-height 1.6
- **Small**: 12px for metadata

### **Spacing:**

- **Small**: 8px
- **Medium**: 16px
- **Large**: 24px

---

## 🔧 **Key Features Explained**

### **Prescribed vs Additional Activities**

**Prescribed activities** are counted in progress bar:
- `selected_via = 'questionnaire'` (from VESPA report)
- `selected_via = 'staff_assigned'` (assigned by staff)

**Additional activities** (student choice) don't affect progress:
- `selected_via = 'student_choice'`

### **Real-time Updates**

Staff dashboard subscribes to changes:

```javascript
supabase
  .channel('feedback-updates')
  .on('postgres_changes', { table: 'activity_responses' }, (payload) => {
    // Update UI when student reads feedback
    if (payload.new.feedback_read_by_student) {
      updateNotificationBadge();
    }
  })
  .subscribe();
```

### **Performance Optimizations**

1. **Single Query Load**: One Supabase query gets students + activities + progress
2. **Client-side Calculations**: Progress, category breakdowns calculated in browser
3. **Pagination**: Only render 50 students at a time
4. **Caching**: Activity catalog cached after first load
5. **Indexed Queries**: All common queries use indexed columns

---

## 🚨 **Troubleshooting**

### **Issue: Students not loading**

**Check:**
1. Supabase credentials in `.env`
2. RLS policies allow staff to read vespa_students
3. user_connections table has staff-student links
4. Console for error messages

**Fix:**
```sql
-- Verify staff has connections
SELECT * FROM user_connections 
WHERE staff_account_id = (
  SELECT account_id FROM vespa_staff WHERE email = 'your@email.com'
);
```

### **Issue: Activities not showing**

**Check:**
1. `activities` table has data
2. `activity_responses` table has records
3. Foreign keys are correct

**Fix:**
```sql
-- Check activity responses for student
SELECT * FROM activity_responses 
WHERE student_email = 'student@school.com';
```

### **Issue: Feedback not saving**

**Check:**
1. Response ID is correct
2. Staff has permission
3. Check browser console for errors

---

## 🎯 **Next Steps**

After initial deployment:

1. **Add drag-and-drop** for activity assignment
2. **Email notifications** when feedback is given
3. **Activity recommendations** based on VESPA scores
4. **Bulk feedback** for multiple students
5. **Activity completion tracking** with time analytics
6. **Mobile responsive** improvements

---

## 📚 **Documentation**

- [Complete Schema](../ACTIVITIES_V3_SCHEMA_COMPLETE.md)
- [Account System Integration](../../vespa-upload-api/ACCOUNT_SYSTEM_HANDOVER_FOR_DASHBOARDS.md)
- [Architecture Vision](../ARCHITECTURE_VISION.md)

---

**Built with ❤️ for VESPA by 4Sight Education**

