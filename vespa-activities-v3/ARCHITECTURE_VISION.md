# VESPA Platform - Future Architecture Vision

## 🎯 **Overall Goal**
Migrate from Knack-dependent system to fully independent Supabase platform while maintaining backwards compatibility.

---

## 🏗️ **Table Architecture**

### **Current State (Phase 1)**

```
┌─────────────────────────────────────────────────────────────┐
│                    LEGACY SYSTEM                            │
│  (Questionnaire & Reports - Knack-dependent)                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐         ┌──────────────┐                │
│  │  students    │────────>│ vespa_scores │                │
│  │  (legacy)    │         │ (UUID FK)    │                │
│  └──────────────┘         └──────────────┘                │
│         │                                                   │
│         └────────────────>┌────────────────────┐          │
│                           │ question_responses │          │
│                           │   (UUID FK)        │          │
│                           └────────────────────┘          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    NEW SYSTEM                               │
│  (Activities V3 - Email-based, Knack-independent)           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐      ┌────────────────────┐         │
│  │ vespa_students   │─────>│ activity_responses │         │
│  │ (canonical)      │      │  (EMAIL FK) ✅     │         │
│  └──────────────────┘      └────────────────────┘         │
│         │                                                   │
│         ├──────────────────>┌─────────────────────┐       │
│         │                   │ student_activities  │       │
│         │                   │   (EMAIL FK) ✅     │       │
│         │                   └─────────────────────┘       │
│         │                                                   │
│         └──────────────────>┌──────────────────────┐      │
│                             │ student_achievements │      │
│                             │   (EMAIL FK) ✅      │      │
│                             └──────────────────────┘      │
│                                                             │
│  ┌──────────────────┐      ┌─────────────────────┐       │
│  │ vespa_staff      │─────>│ staff_student_      │       │
│  │ (future)         │      │   connections       │       │
│  └──────────────────┘      └─────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 **Table Comparison**

| Feature | `students` (Legacy) | `vespa_students` (New) |
|---------|-------------------|---------------------|
| **Purpose** | Historical archive | Canonical registry |
| **Email Unique?** | ❌ No (duplicates exist) | ✅ Yes (enforced) |
| **Multi-year handling** | Multiple records per student | Single record, tracked history |
| **Foreign Key Pattern** | UUID (`student_id`) | VARCHAR (`student_email`) |
| **Year Rollover** | Creates new record | Updates existing record |
| **Knack ID Tracking** | Single field | Current + historical array |
| **Auth Ready** | No | Yes (Supabase auth fields) |
| **Used By** | Questionnaire, Reports | Activities (will expand) |

---

## 🔄 **Migration Phases**

### **Phase 1: Activities Launch (Current)** ✅
- **Status**: In progress
- **Auth**: Knack only
- **Tables**: 
  - Legacy `students` → Questionnaire/Reports
  - New `vespa_students` → Activities
- **Benefit**: Activities independent of legacy data issues

### **Phase 2: Gradual Supabase Auth** (Future - 3-6 months)
- **New users**: Created in `vespa_students` with Supabase auth
- **Existing users**: Knack auth, auto-sync to `vespa_students`
- **Vue apps**: Check Supabase auth first, fallback to Knack
- **Backend**: Handles dual auth methods

### **Phase 3: Questionnaire/Reports Migration** (Future - 6-12 months)
- **Migrate** `vespa_scores` from `student_id` → `student_email`
- **Migrate** `question_responses` from `student_id` → `student_email`
- **Use** `vespa_students` as source of truth
- **Bridge VIEW** allows gradual cutover

### **Phase 4: Complete Independence** (Future - 12+ months)
- **All systems** use `vespa_students`/`vespa_staff`
- **Knack auth** disabled, becomes read-only archive
- **Legacy `students` table** archived or dropped
- **100% Supabase platform** ✅

---

## 🎯 **Benefits of vespa_students Design**

### **1. Year Rollover Handling**
```sql
-- Student moves Year 12 → Year 13
-- Old system: Creates new record (duplicate email)
-- New system: Updates existing record

UPDATE vespa_students
SET 
  current_knack_id = 'new_id_2026',
  historical_knack_ids = array_append(historical_knack_ids, 'new_id_2026'),
  current_year_group = 'Year 13',
  current_academic_year = '2025/2026',
  years_in_system = years_in_system + 1
WHERE email = 'student@school.com';
```

### **2. Multi-Year Tracking**
```sql
vespa_students:
  email: "student@school.com"
  years_in_system: 2
  current_academic_year: "2025/2026"
  previous_academic_years: ["2024/2025", "2025/2026"]
  historical_knack_ids: ["id_2024", "id_2025"]
```

### **3. VESPA Scores Caching**
```sql
-- Latest scores cached in vespa_students for instant access
latest_vespa_scores: {
  "cycle": 3,
  "vision": 7,
  "effort": 8,
  ...
}

-- Full history still in vespa_scores table
```

### **4. Future Auth Ready**
```sql
-- Phase 2: Add Supabase auth
supabase_user_id: "uuid-from-auth-users"
auth_provider: "supabase"  -- or "knack" during transition
```

---

## 🔗 **Linking Strategy**

### **Current (Phase 1):**
```javascript
// Vue app gets user from Knack
const userEmail = Knack.getUserAttributes().email;

// Backend creates/updates vespa_students record
await supabase.rpc('get_or_create_vespa_student', {
  student_email_param: userEmail,
  knack_attributes: Knack.getUserAttributes()
});

// All activities queries use email
const activities = await supabase
  .from('student_activities')
  .select('*')
  .eq('student_email', userEmail);
```

### **Future (Phase 3+):**
```javascript
// Vue app gets user from Supabase Auth
const user = await supabase.auth.getUser();
const userEmail = user.data.user.email;

// vespa_students already exists (created at signup)
const studentData = await supabase
  .from('vespa_students')
  .select('*')
  .eq('email', userEmail)
  .single();

// All systems use vespa_students
const scores = await supabase
  .from('vespa_scores')
  .select('*')
  .eq('student_email', userEmail);  // Changed from student_id
```

---

## 📊 **vespa_staff Table (Future)**

Companion table to `vespa_students` with matching structure:

```
vespa_staff:
  - email (UNIQUE)
  - current_knack_id
  - historical_knack_ids
  - supabase_user_id (for future auth)
  - primary_role
  - permissions JSONB
  - assigned_students_count
  - school_name
  - is_active
```

Links to students via:
```sql
staff_student_connections:
  staff_email → vespa_staff.email
  student_email → vespa_students.email
  staff_role (tutor/admin/etc)
```

---

## 🚀 **Immediate Implementation**

### **For Activities V3:**
1. ✅ Run `FUTURE_READY_SCHEMA.sql` (creates vespa_students)
2. ✅ Migration scripts use vespa_students
3. ✅ Vue apps reference vespa_students
4. ✅ Backend API uses vespa_students
5. ✅ Knack auth still works (Phase 1)

### **Later (When Ready):**
1. Create vespa_staff table
2. Migrate staff connections
3. Start Supabase auth for new users
4. Gradually migrate questionnaire/reports
5. Deprecate Knack auth

---

## 💡 **Key Design Decisions**

1. **Email as Primary Key**: Universal identifier across all systems
2. **Separate Tables**: Clean break from legacy issues
3. **Historical Tracking**: Arrays preserve all past Knack IDs
4. **Cached VESPA Scores**: Performance optimization
5. **Soft Deletes**: Audit trail preservation
6. **JSONB Fields**: Flexibility for future features
7. **Auth Provider Field**: Smooth auth migration path

---

## ✅ **Current Action**

**Run `FUTURE_READY_SCHEMA.sql` now!**

This creates:
- ✅ `vespa_students` table (clean, future-ready)
- ✅ All activity tables
- ✅ Helper functions for year rollovers
- ✅ RLS policies
- ✅ Migration bridge VIEW

Then we can:
- ✅ Run migration scripts
- ✅ Build Vue apps
- ✅ Launch Activities V3

**Future vespa_staff table is documented but not created yet** (Phase 2)

---

**Last Updated**: November 2025  
**Status**: Ready for Phase 1 implementation


