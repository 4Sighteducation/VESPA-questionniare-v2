# ✅ Table Name Verification - Migration Scripts

**Date**: November 2025  
**Status**: Verified against FUTURE_READY_SCHEMA.sql

---

## 📊 **Schema Tables** (from FUTURE_READY_SCHEMA.sql)

1. ✅ `activities`
2. ✅ `activity_questions`
3. ✅ `vespa_students`
4. ✅ `activity_responses`
5. ✅ `student_activities`
6. ✅ `student_achievements`
7. ✅ `staff_student_connections`
8. ✅ `notifications`
9. ✅ `activity_history`
10. ✅ `achievement_definitions`

---

## 🔍 **Migration Script Table Usage**

### **Script 1: 01_migrate_activities.py**
- **Writes to**: `activities` ✅
- **Operation**: `INSERT`
- **Fields**: All fields match schema ✅

### **Script 2: 02_migrate_questions.py**
- **Reads from**: `activities` ✅
- **Writes to**: `activity_questions` ✅
- **Operation**: `INSERT`
- **Fields**: All fields match schema ✅

### **Script 3: 03_update_problem_mappings.py**
- **Reads from**: `activities` ✅
- **Writes to**: `activities` (updates `problem_mappings` column) ✅
- **Operation**: `UPDATE`
- **Fields**: `problem_mappings` TEXT[] ✅

### **Script 4: 04_migrate_historical_responses.py**
- **Reads from**: `activities` ✅
- **Writes to**: 
  - `vespa_students` ✅ (creates student records)
  - `activity_responses` ✅ (inserts responses)
- **Operation**: `UPSERT` (vespa_students), `INSERT` (activity_responses)
- **Fields**: All fields match schema ✅

### **Script 5: 05_seed_achievements.py**
- **Writes to**: `achievement_definitions` ✅
- **Operation**: `UPSERT` (on conflict: achievement_type)
- **Fields**: All fields match schema ✅

---

## ✅ **VERIFICATION COMPLETE**

All scripts are writing to the correct tables as defined in `FUTURE_READY_SCHEMA.sql`.

**Key Fix Applied**: Script 4 now uses `vespa_students` instead of `students` (fixed Nov 2025).

---

## 📝 **Table Field Mapping Verification**

### **activities table**
- ✅ `knack_id` (VARCHAR)
- ✅ `name` (VARCHAR UNIQUE)
- ✅ `slug` (VARCHAR)
- ✅ `vespa_category` (VARCHAR)
- ✅ `level` (VARCHAR)
- ✅ `difficulty` (INTEGER)
- ✅ `time_minutes` (INTEGER)
- ✅ `score_threshold_min` (INTEGER)
- ✅ `score_threshold_max` (INTEGER)
- ✅ `content` (JSONB)
- ✅ `do_section_html` (TEXT)
- ✅ `think_section_html` (TEXT)
- ✅ `learn_section_html` (TEXT)
- ✅ `reflect_section_html` (TEXT)
- ✅ `problem_mappings` (TEXT[])
- ✅ `color` (VARCHAR)
- ✅ `display_order` (INTEGER)
- ✅ `is_active` (BOOLEAN)

### **activity_questions table**
- ✅ `activity_id` (UUID FK to activities)
- ✅ `question_title` (TEXT)
- ✅ `text_above_question` (TEXT)
- ✅ `question_type` (VARCHAR)
- ✅ `dropdown_options` (TEXT[])
- ✅ `display_order` (INTEGER)
- ✅ `is_active` (BOOLEAN)
- ✅ `answer_required` (BOOLEAN)
- ✅ `show_in_final_questions` (BOOLEAN)

### **vespa_students table**
- ✅ `email` (VARCHAR UNIQUE) - Primary identifier
- ✅ `current_knack_id` (VARCHAR)
- ✅ `historical_knack_ids` (TEXT[])
- ✅ `first_name` (VARCHAR)
- ✅ `last_name` (VARCHAR)
- ✅ `full_name` (VARCHAR)
- ✅ `auth_provider` (VARCHAR) - Default 'knack'
- ✅ `status` (VARCHAR) - Default 'active'
- ✅ `is_active` (BOOLEAN)

### **activity_responses table**
- ✅ `knack_id` (VARCHAR)
- ✅ `student_email` (VARCHAR FK to vespa_students.email)
- ✅ `activity_id` (UUID FK to activities.id)
- ✅ `cycle_number` (INTEGER)
- ✅ `responses` (JSONB)
- ✅ `responses_text` (TEXT)
- ✅ `status` (VARCHAR)
- ✅ `completed_at` (TIMESTAMP)
- ✅ `staff_feedback` (TEXT)
- ✅ `staff_feedback_by` (VARCHAR)
- ✅ `year_group` (VARCHAR)
- ✅ `student_group` (VARCHAR)

### **achievement_definitions table**
- ✅ `achievement_type` (VARCHAR UNIQUE)
- ✅ `name` (VARCHAR)
- ✅ `description` (TEXT)
- ✅ `icon_emoji` (VARCHAR)
- ✅ `points_value` (INTEGER)
- ✅ `criteria` (JSONB)
- ✅ `is_active` (BOOLEAN)
- ✅ `display_order` (INTEGER)

---

**All table names and fields verified!** ✅


