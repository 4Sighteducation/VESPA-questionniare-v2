# Current Supabase Schema Analysis

**Database**: `qcdcdzfanrlvdcagmwmg.supabase.co` (vespa-dashboard)  
**Generated**: November 2025  
**Source**: Schema export from Supabase

---

## 📊 **Key Student-Related Tables**

Based on your schema export and the `vespa_students` structure you shared:

### **1. students (Legacy/Dashboard Table)**

**Purpose**: Original dashboard table, populated by daily Knack sync  
**Usage**: Dashboard analytics, historical data, questionnaire responses

```
Estimated rows: 20,000+ (all historical students)
Key fields:
- id (UUID) - primary key
- knack_id - links to Knack
- email - student email
- name - full name
- establishment_id - school
- year_group, course, faculty, group
- academic_year
- status
- created_at, updated_at
```

**Foreign Keys:**
- `establishment_id` → `establishments.id`
- Referenced by: `vespa_scores`, `student_comments`, `student_enrollments`, `student_responses`, `student_goals`, `staff_coaching_notes`

---

### **2. vespa_students (Activities V3 Table)**

**Purpose**: Canonical student registry for Activities V3, auto-created on first use  
**Usage**: Activity system only

```
Current rows: 1,806 (students who used activities since migration)
Key fields:
- id (UUID) - primary key
- email (VARCHAR) - UNIQUE, primary identifier
- current_knack_id - current Knack ID
- historical_knack_ids[] - array for year rollovers
- supabase_user_id - NULL (for future Supabase Auth)
- auth_provider - 'knack' (default)
- first_name, last_name, full_name
- school_name, trust_name
- current_year_group, current_academic_year
- current_level, current_cycle
- latest_vespa_scores (JSONB)
- total_points, total_activities_completed, total_achievements
- current_streak_days, longest_streak_days
- status, is_active
- last_activity_at
- years_in_system
- previous_academic_years[]
- preferences (JSONB)
- last_synced_from_knack
- knack_user_attributes (JSONB)
- created_at, updated_at
```

**Foreign Keys:**
- None currently (standalone table)
- Referenced by: `activity_responses` (via email)

---

### **3. vespa_scores (Dashboard/Questionnaire Table)**

**Purpose**: Stores VESPA questionnaire results (Vision, Effort, Systems, Practice, Attitude)  
**Usage**: Both dashboard analytics AND questionnaire V2

```
Estimated rows: 30,000-50,000 (multiple cycles per student)
Key fields:
- id (UUID) - primary key
- student_id (UUID) - FK to students.id ⚠️ Links to LEGACY table
- student_email (VARCHAR) - email (added for Activities V3)
- cycle (INTEGER) - 1, 2, or 3
- academic_year (VARCHAR) - e.g., "2025/2026"
- vision, effort, systems, practice, attitude (NUMERIC scores)
- overall (NUMERIC) - calculated overall score
- level (VARCHAR) - e.g., "Level 2"
- completion_date (TIMESTAMP)
- created_at, updated_at
```

**Foreign Keys:**
- `student_id` → `students.id` (legacy table!)
- Also has `student_email` for newer queries

---

### **4. activity_responses (Activities V3 Table)**

**Purpose**: Student responses to activities  
**Usage**: Activities V3 only

```
Current rows: 6,031 (since Activities V3 migration)
Key fields:
- id (UUID) - primary key
- student_email (VARCHAR) - ⚠️ EMAIL not UUID!
- activity_id (UUID) - FK to activities.id
- cycle_number (INTEGER)
- response_data (JSONB) - answers to questions
- status (VARCHAR) - 'in_progress', 'completed'
- started_at, completed_at
- time_minutes (INTEGER)
- word_count (INTEGER)
- staff_feedback (TEXT)
- created_at, updated_at
```

**Foreign Keys:**
- `activity_id` → `activities.id`
- `student_email` → ⚠️ NOT a formal FK (just a string)

---

### **5. question_responses (Questionnaire V2 Table)**

**Purpose**: Stores individual question responses from questionnaire  
**Usage**: Questionnaire V2, feeds into vespa_scores

```
Estimated rows: 500,000+ (many questions per student per cycle)
Key fields:
- id (UUID) - primary key
- student_id (UUID) - FK to students.id ⚠️ Legacy link
- student_email (VARCHAR)
- question_id (VARCHAR)
- response_value (INTEGER) - 1-5 scale
- cycle (INTEGER)
- academic_year (VARCHAR)
- submitted_at (TIMESTAMP)
```

**Foreign Keys:**
- `student_id` → `students.id` (legacy table!)

---

## 🔗 **Table Relationships**

```
┌─────────────────────────┐
│  students (LEGACY)      │ ← Daily Knack sync
│  20,000+ records        │
└─────────────────────────┘
          │ (student_id FK)
          ├──→ vespa_scores
          ├──→ question_responses
          ├──→ student_comments
          ├──→ student_enrollments
          └──→ student_responses

┌─────────────────────────┐
│  vespa_students (V3)    │ ← On-demand creation
│  1,806 records          │
└─────────────────────────┘
          │ (email string)
          └──→ activity_responses

┌─────────────────────────┐
│  vespa_scores           │
│  Links to BOTH!         │
│  - student_id (UUID)    │ ← Links to students
│  - student_email (str)  │ ← Links to vespa_students
└─────────────────────────┘
```

---

## ⚠️ **Current Architecture Problems**

### **Problem 1: Two Student Tables**

- `students` (20,000+) - Legacy, UUID-based
- `vespa_students` (1,806) - New, email-based
- **NO CONNECTION** between them!

### **Problem 2: Mixed Foreign Key Types**

- Old system: UUID foreign keys (`student_id`)
- New system: Email string references (`student_email`)
- Inconsistent, harder to maintain

### **Problem 3: Data Duplication**

- Student info in both tables
- Syncing issues (update one, forget the other)
- No single source of truth

### **Problem 4: Unclear Boundaries**

- Dashboard reads from `students`
- Questionnaire V2 reads/writes to `students` + `vespa_scores`
- Activities V3 reads from `vespa_students` + writes to `activity_responses`
- **Confusion about which table to use when**

---

## 🎯 **Recommended Hybrid Schema Changes**

### **Phase 1: Add Linking (This Migration)**

```sql
-- Add account_id to vespa_students (linking to vespa_accounts)
ALTER TABLE vespa_students ADD COLUMN account_id UUID;

-- Create vespa_accounts (new parent table)
-- Migrate existing vespa_students → vespa_accounts
-- Link them

-- Create vespa_staff + user_roles + user_connections
```

### **Phase 2: Bridge the Gap (Feb-June 2026)**

```sql
-- Add email to students table (if missing)
-- Create view to unify both tables:
CREATE VIEW unified_students AS
SELECT 
  COALESCE(vs.id, s.id) as id,
  COALESCE(vs.email, s.email) as email,
  COALESCE(vs.full_name, s.name) as name,
  vs.id as vespa_student_id,
  s.id as legacy_student_id,
  ...
FROM students s
FULL OUTER JOIN vespa_students vs ON s.email = vs.email;
```

### **Phase 3: Full Migration (July 2026)**

- Migrate all active students from `students` → `vespa_accounts` + `vespa_students`
- Update all foreign keys to use `vespa_accounts.id`
- Archive or drop `students` table
- Single source of truth achieved

---

## 📋 **Key Tables for Staff Migration**

Based on your existing structure:

### **Staff-Related Tables (To Query from Knack)**

```
staff_admins
- email
- establishment_id
- knack_id

super_users
- email
- knack_id

(Knack Objects to Query)
- object_5 (Staff Admin)
- object_7 (Tutor)
- object_18 (Head of Year)
- object_78 (Subject Teacher)
```

---

## 🎯 **Decision Points**

### **Question 1: Student Migration Strategy**

**Option A: Keep Separate (Recommended for Now)**
- Dashboard uses `students` table (20,000+)
- Activities V3 uses `vespa_students` (grows organically)
- Bridge them via `legacy_students_bridge` view (already exists!)
- Unify in July 2026

**Option B: Full Migration Now**
- Migrate all 20,000+ students to `vespa_accounts` + `vespa_students`
- Update all FK references
- Big bang migration (risky!)

### **Question 2: Staff Migration**

**Recommendation: Full Staff Migration NOW**
- Only ~200-500 staff
- Manageable migration
- Enables Activities V3 staff features
- No daily sync issues (staff change rarely)

---

## ✅ **Next Steps**

1. **Run investigative SQL** (you're doing now)
2. **Confirm:** Keep students separate for now?
3. **Run:** `ADDITIVE_HYBRID_MIGRATION.sql` (creates vespa_accounts, links vespa_students)
4. **Create:** Staff migration script (06_migrate_staff_accounts.py)
5. **Migrate:** All staff from Knack → Supabase
6. **Test:** Activities V3 with new structure
7. **Plan:** July 2026 full unification

---

**This analysis based on:**
- Schema export CSV
- vespa_students structure (51 columns)
- Views: `legacy_students_bridge`, `student_questionnaire_status`, etc.
- Understanding of daily dashboard sync

**Waiting for investigative SQL results to confirm row counts and relationships!**

