# VESPA Questionnaire V2

Modern Vue 3 questionnaire system with Supabase integration and Knack backwards compatibility.

## Overview

This is a complete replacement for the KSense-managed questionnaire, providing:
- ✅ Full control over questionnaire logic
- ✅ Direct writes to Supabase (no sync delays)
- ✅ Backwards compatibility (dual-write to Knack)
- ✅ Beautiful mobile-responsive UI
- ✅ Integrated eligibility checking
- ✅ Academic year locking for multi-year students

## Architecture

### Flow
```
Student navigates to #vespaquestionniare/
    ↓
Vue app loads in scene_1282/view_3247
    ↓
Check eligibility (cycle dates, completed cycles)
    ↓
Show instructions OR error message
    ↓
Student completes 32 questions (29 VESPA + 3 outcome)
    ↓
Submit to backend API
    ↓
Backend calculates VESPA scores
    ↓
Writes to Supabase + Knack (dual-write)
    ↓
Success → Redirect to #vespa-results
```

### Tech Stack
- **Frontend**: Vue 3 + Vite
- **Backend**: Python Flask (existing Dashboard app)
- **Database**: Supabase (primary) + Knack (legacy)
- **Hosting**: GitHub → JSDelivr CDN
- **Deployment**: Vercel

## Project Structure

```
vespa-questionnaire-v2/
├── src/
│   ├── components/
│   │   ├── LoadingCheck.vue         # Loading spinner states
│   │   ├── InstructionsScreen.vue   # Welcome and instructions
│   │   ├── NotAvailable.vue         # Error/not eligible messages
│   │   ├── ProgressIndicator.vue    # Progress bar at top
│   │   ├── QuestionCard.vue         # Single question with Likert scale
│   │   └── SuccessMessage.vue       # Post-submission success
│   ├── services/
│   │   ├── api.js                   # Backend API calls
│   │   ├── knackAuth.js             # Knack user authentication
│   │   └── vespaCalculator.js       # VESPA score calculation
│   ├── data/
│   │   └── questions.js             # All 32 questions with mappings
│   ├── App.vue                      # Main orchestrator
│   ├── main.js                      # Entry point
│   └── style.css                    # Global styles
├── public/
├── dist/                            # Build output (for CDN)
├── package.json
├── vite.config.js
└── README.md
```

## Questions Data

32 total questions:
- **29 VESPA questions** (q1-q28 + q29) → Calculate 5 VESPA scores (1-10 scale)
- **3 Outcome questions** (q30-q32) → Track confidence/preparedness (don't affect scores)

Each question maps to multiple Knack fields:
- `current`: field_794-field_821, field_2317, field_1816-1818
- `cycle1`: field_1953-1956, etc.
- `cycle2`: field_1955, field_1957, etc.
- `cycle3`: field_1956, field_1958, etc.

## VESPA Score Calculation

Statement scores (1-5) → Category averages → VESPA scores (1-10)

Thresholds from `reverse_vespa_calculator.py`:
- **VISION**: 5 questions → Average → Map to VESPA 1-10
- **EFFORT**: 4 questions → Average → Map to VESPA 1-10
- **SYSTEMS**: 5 questions → Average → Map to VESPA 1-10
- **PRACTICE**: 6 questions → Average → Map to VESPA 1-10
- **ATTITUDE**: 9 questions → Average → Map to VESPA 1-10
- **OVERALL**: Mean of all 5 VESPA scores

## Academic Year Locking

Critical innovation to handle multi-year students:

1. When student completes **Cycle 1** → Calculate and lock academic year
   - UK: Based on Aug 1 cutoff → "2025/2026"
   - AUS: Based on calendar year → "2025/2025"
   - Stored with Cycle 1 in Supabase

2. When student completes **Cycle 2 or 3** → Use locked academic year from Cycle 1
   - Query: `get_student_academic_year(student_id)`
   - Returns the Cycle 1 academic year
   - All cycles in same year share this value

3. Edge case handled: Cycle 3 in next calendar year stays in same academic year

## Backend API Endpoints

### GET /api/vespa/questionnaire/validate
Check if student can take questionnaire.

**Query Params:**
- `email`: Student email
- `accountId`: Knack account ID

**Returns:**
```json
{
  "allowed": true/false,
  "cycle": 1/2/3,
  "reason": "cycle_1_active" | "before_start" | "all_completed",
  "message": "Human readable message",
  "academicYear": "2025/2026",
  "nextStartDate": "2025-03-15",
  "userRecord": { ... }
}
```

### POST /api/vespa/questionnaire/submit
Submit completed questionnaire.

**Body:**
```json
{
  "studentEmail": "student@school.com",
  "studentName": "John Doe",
  "cycle": 1,
  "responses": { "q1": 4, "q2": 5, ... },
  "vespaScores": { "VISION": 7, "EFFORT": 8, ... },
  "categoryAverages": { "VISION": 4.2, ... },
  "knackRecordId": "abc123",
  "academicYear": "2025/2026"
}
```

**Process:**
1. Write to Supabase `question_responses` (32+ rows)
2. Write to Supabase `vespa_scores` (1 row)
3. Dual-write to Knack Object_29 (all fields)
4. Dual-write to Knack Object_10 (all fields + update field_146)

**Returns:**
```json
{
  "success": true,
  "supabaseWritten": true,
  "knackWritten": true,
  "scores": { ... }
}
```

## Development

```bash
# Install dependencies
npm install

# Run dev server
npm run dev

# Build for production
npm run build
```

## Deployment

### IMPORTANT: CDN Cache Busting Strategy

JSDelivr CDN caches files aggressively. After each code change, you MUST increment the version suffix:

**Version Pattern:** `questionnaire1a.js` → `questionnaire1b.js` → `questionnaire1c.js` → etc.

### 1. Build with New Version
```bash
# Edit vite.config.js - change version:
# entryFileNames: 'questionnaire1a.js'  →  'questionnaire1b.js'
# (in assetFileNames too for CSS)

npm run build
```

### 2. Push to GitHub
```bash
git add .
git commit -m "Version 1b - [describe changes]"
git push origin main
```

### 3. Update KnackAppLoader
```javascript
// Change in KnackAppLoader(copy).js:
scriptUrl: '...questionnaire1a.js'  →  '...questionnaire1b.js'
cssUrl: '...questionnaire1a.css'  →  '...questionnaire1b.css'
```

### 4. Upload to Knack Builder
Copy entire KnackAppLoader(copy).js to Knack Builder → JavaScript

### 5. Test
Navigate to `#vespaquestionniare/` and hard refresh (Ctrl+Shift+R)

**Current Version:** 1L

**Version History:**
- 1L: UI polish - fixed progress bar overlap, smooth transitions, removed scrollbar
- 1a: Initial release with mount fix

## Database Schema

### Supabase Tables (Write)
- `students` - Student records
- `vespa_scores` - VESPA scores (1-10 scale)
- `question_responses` - Individual responses (1-5 scale)

### Knack Objects (Dual-Write for Compatibility)
- `object_10` - VESPA Results (fields 147-172, 146)
- `object_29` - Question responses (fields 794-821, 2317, 1816-1818, historical fields)

## Testing

1. Navigate to `#vespaquestionniare/` in Knack app
2. Should load in scene_1282
3. Check eligibility validation
4. Complete questionnaire
5. Verify data in both Supabase and Knack
6. Check existing report still works (#vespa-results)

## Rollback Plan

If issues arise:
1. Disable in KnackAppLoader (set enabled: false)
2. Students revert to old questionnaire at #add-q
3. No data loss - existing questionnaire still functional

## Notes

- Replaces KSense `index2.4.0.js` completely for questionnaire
- Does NOT replace report generation yet (Phase 2)
- Existing report (scene_43) continues to work via dual-write
- Clean separation of concerns for future migrations
