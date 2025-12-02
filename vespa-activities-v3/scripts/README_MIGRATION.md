# Activity Migration Script

## 📋 What This Does

Migrates **ALL** student activity data from Knack to Supabase:

- **Object_126** (Activity Progress) → activity_responses 
- **Object_46** (Activity Answers) → merged with progress data
- **Object_10** (VESPA Results) → used for cycle numbers and prescription logic

## 🎯 Key Features

✅ **Merges two Knack objects** into one Supabase table  
✅ **Determines prescribed vs student_choice** using threshold logic  
✅ **Handles duplicates** with upsert (safe to re-run)  
✅ **Includes VESPA ACADEMY** and all schools  
✅ **Preserves all historical data**

## ⚡ Quick Start

### 1. Install Dependencies

```bash
cd vespa-activities-v3/scripts
npm install @supabase/supabase-js
```

### 2. Set Environment Variable

Get your **Supabase Service Role key** from:
- https://supabase.com/dashboard/project/qcdcdzfanrlvdcagmwmg/settings/api
- Copy the `service_role` key (NOT the anon key!)

**On Windows (PowerShell):**
```powershell
$env:SUPABASE_SERVICE_KEY="your-service-key-here"
node migrate-activities-complete.js
```

**On Mac/Linux:**
```bash
export SUPABASE_SERVICE_KEY="your-service-key-here"
node migrate-activities-complete.js
```

### 3. Run Migration

```bash
node migrate-activities-complete.js
```

Expected output:
```
🚀 VESPA Activities Migration - Starting...
📖 Step 1: Loading activity thresholds...
✅ Loaded 400+ activity threshold mappings
📖 Step 2: Loading activities from Supabase...
✅ Loaded 500+ activities
... (continues)
✅ Successfully migrated: 1,095 records
✅ VESPA ACADEMY responses: 29+
🎉 Migration complete!
```

## 📊 What Gets Migrated

### From Object_126 (Activity Progress):
| Field | Maps To | Notes |
|-------|---------|-------|
| field_3536 | student_email | Resolved via Object_6 |
| field_3537 | activity_id | Mapped to Supabase UUID |
| field_3538 | cycle_number | Or from Object_10 |
| field_3539 | started_at | Date parsed |
| field_3541 | completed_at | Date parsed |
| field_3542 | time_spent_minutes | Integer |
| field_3543 | status | not_started/in_progress/completed |
| field_3549 | word_count | Integer |

### From Object_46 (Activity Answers):
| Field | Maps To | Notes |
|-------|---------|-------|
| field_1300 | responses | JSON of answers |
| field_2334 | responses_text | Plain text version |
| field_1734 | staff_feedback | Feedback text |
| field_3648 | feedback_read_by_student | Boolean |
| field_3649 | staff_feedback_at | Date |
| field_3650 | feedback_read_at | Date |

### Calculated Fields:
| Field | Logic |
|-------|-------|
| selected_via | 'questionnaire' if activity score falls within thresholds, else 'student_choice' |
| academic_year | Derived from dates (currently hardcoded 2025/2026) |

## 🔍 Verification

After running, check Supabase:

```sql
-- Check total records
SELECT COUNT(*) FROM activity_responses;

-- Check VESPA ACADEMY specifically
SELECT 
  student_email,
  COUNT(*) as activities
FROM activity_responses
WHERE student_email LIKE '%@vespa.academy'
GROUP BY student_email
ORDER BY activities DESC;

-- Check Alena specifically
SELECT * FROM activity_responses
WHERE student_email = 'aramsey@vespa.academy';
```

## ⚠️ Important Notes

- **Safe to re-run**: Uses UPSERT, won't create duplicates
- **Rate limited**: Adds delays to avoid API throttling
- **Service key required**: Uses elevated permissions to bypass RLS
- **Object_6 lookups**: Makes API calls to resolve student emails (slower)

## 🐛 Troubleshooting

### "No student email found"
- Student record doesn't have field_91 populated
- Check in Knack Builder

### "Activity not in Supabase"
- Activity hasn't been migrated yet
- Run activities migration first

### "Rate limit exceeded"
- Increase delays in script
- Run in batches

## 📝 TODO After Migration

1. ✅ Update RPC functions to include activity counts
2. ✅ Test staff dashboard shows correct progress
3. ✅ Verify prescribed activities display correctly
4. ✅ Check student dashboard shows their work
5. ⏳ Populate activity thresholds (run populate-activity-thresholds.js)

---

**Last Updated**: November 30, 2025  
**Status**: Ready to run ✅



