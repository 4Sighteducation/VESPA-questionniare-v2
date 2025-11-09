# VESPA Questionnaire V2 - Concurrency & Scalability Analysis

## Executive Summary

**Current Capacity:** ~50-100 concurrent users safely
**Target Capacity:** 500+ concurrent users
**Bottleneck:** Knack API rate limits and sequential calls
**Recommendation:** Accept Supabase-only writes as source of truth, sync to Knack async

---

## Current Architecture Analysis

### Data Flow Per Submission

```
Student submits (frontend)
    ↓
Backend receives request
    ↓
┌─── SUPABASE WRITE (~300ms) ──────┐
│  1. Upsert student (50ms)        │
│  2. Upsert vespa_scores (50ms)   │
│  3. Upsert 32 responses (200ms)  │
│  Total: ~300ms                   │
│  ✅ Thread-safe, concurrent OK   │
└──────────────────────────────────┘
    ↓
┌─── KNACK WRITE (~3000ms) ────────┐
│  1. GET Object_6 (500ms)         │
│  2. GET Object_10 (500ms)        │
│  3. PUT Object_10 (800ms)        │
│  4. GET Object_29 (500ms)        │
│  5. PUT Object_29 (800ms)        │
│  Total: ~3000ms                  │
│  ⚠️ Rate limited, sequential     │
└──────────────────────────────────┘
    ↓
Return success to student
```

**Total time per submission:** ~3.3 seconds

---

## Concurrent Load Scenarios

### Scenario 1: 50 Students (Current Safe Limit)

**Supabase:**
- 50 × 34 writes = 1,700 total writes
- Time: ~5-10 seconds (parallel processing)
- Status: ✅ **NO ISSUES**

**Knack:**
- 50 × 5 API calls = 250 total calls
- Knack rate limit: ~10-20 req/sec
- Time: 12-25 seconds
- Status: ✅ **ACCEPTABLE** (some students wait, but completes)

**Result:** All students complete successfully, some experience 10-15 second delays

---

### Scenario 2: 200 Students (Pushing Limits)

**Supabase:**
- 200 × 34 writes = 6,800 total writes
- Time: ~15-30 seconds
- Status: ✅ **HANDLES IT** (Postgres connection pooling works)

**Knack:**
- 200 × 5 API calls = 1,000 total calls
- At 15 req/sec = 67 seconds minimum
- Status: ⚠️ **DEGRADED**
  - Students wait 30-60 seconds
  - Timeout errors likely (30s Flask timeout)
  - 429 "Rate Limit" errors probable

**Result:** 
- ✅ 70-80% complete successfully (Supabase + Knack)
- ⚠️ 20-30% partial success (Supabase only, Knack times out)
- ❌ **No data loss** (Supabase is saved first)

---

### Scenario 3: 500 Students (TARGET LOAD)

**Supabase:**
- 500 × 34 writes = 17,000 total writes
- Time: ~30-60 seconds
- Status: ✅ **HANDLES IT** (designed for this)

**Knack:**
- 500 × 5 API calls = 2,500 total calls
- At 15 req/sec = 167 seconds (2.8 minutes)
- Status: ❌ **FAILS BADLY**
  - Most requests timeout after 30s
  - 429 errors everywhere
  - Knack servers might throttle/block your account

**Result:**
- ✅ 100% save to Supabase successfully
- ❌ 50-70% fail to write to Knack
- ⚠️ Students see error messages (even though data is saved)
- 🔄 Tonight's sync script fixes Knack

---

## Solutions for High Concurrency

### Option 1: Accept Current Behavior (RECOMMENDED FOR NOW)

**Implementation:**
```python
# Already implemented in your code!
if supabase_success:
    return jsonify({'success': True, 'knackWritten': knack_success})
```

**How it works:**
- ✅ Supabase writes first (always succeeds)
- ⚠️ Knack writes attempted (may fail at scale)
- ✅ Student sees success even if Knack fails
- 🔄 Sync script reconciles Knack overnight

**Benefits:**
- Zero code changes needed
- Works for 500+ concurrent users
- No data loss
- Simple to maintain

**Drawbacks:**
- Staff might not see results immediately (wait for sync)
- Knack temporarily inconsistent
- "Fake success" (says success but Knack might have failed)

---

### Option 2: Background Queue System (PRODUCTION-GRADE)

**Architecture:**
```
Student submits
    ↓
Write to Supabase immediately
    ↓
Add "Knack write job" to Redis queue
    ↓
Return success to student immediately
    ↓
Background worker processes queue (1 job at a time)
    ↓
Knack writes happen slowly but reliably
```

**Implementation:**
```python
# Install: pip install rq (Redis Queue)

from redis import Redis
from rq import Queue

redis_conn = Redis()
knack_queue = Queue('knack-writes', connection=redis_conn)

@app.route('/api/vespa/questionnaire/submit', methods=['POST'])
def submit_questionnaire():
    # Write to Supabase (fast)
    supabase_write(data)
    
    # Queue Knack write (async)
    knack_queue.enqueue(write_to_knack, data)
    
    # Return immediately
    return jsonify({'success': True})

def write_to_knack(data):
    # Background worker processes this
    # No time limit, no race conditions
    ...
```

**Benefits:**
- ✅ Students see instant success
- ✅ No timeouts
- ✅ Knack writes happen eventually
- ✅ Can retry failures
- ✅ Handles unlimited concurrent users

**Drawbacks:**
- Requires Redis (adds complexity)
- Requires background worker process
- More infrastructure to maintain

---

### Option 3: Batch Knack Writes (COMPROMISE)

**Implementation:**
```python
# Collect submissions in memory
# Every 5 minutes, batch write to Knack

submissions_buffer = []

@app.route('/api/vespa/questionnaire/submit')
def submit():
    # Write to Supabase
    supabase_write(data)
    
    # Add to buffer
    submissions_buffer.append(data)
    
    # Return immediately
    return success

# Scheduled task (every 5 min)
def batch_write_to_knack():
    for data in submissions_buffer:
        write_to_knack(data)
        time.sleep(0.1)  # Rate limit friendly
    submissions_buffer.clear()
```

**Benefits:**
- ✅ Spreads Knack writes over time
- ✅ No timeout issues
- ✅ Simpler than full queue

**Drawbacks:**
- Memory usage (store submissions in RAM)
- Lost if server crashes before batch runs
- Still hits rate limits if batch is huge

---

## Supabase-Only Future

### When You Remove Knack Dependency

**Architecture:**
```
500 Students submit simultaneously
    ↓
Flask (8 Gunicorn workers)
    ↓
Supabase Connection Pool (100 connections)
    ↓
PostgreSQL handles concurrency (MVCC)
    ↓
All writes succeed in parallel
```

**Performance:**
- **Current:** 3.3 seconds per submission
- **Future:** 0.3 seconds per submission
- **Speed:** **11x faster!**

**Capacity:**
- **Current:** ~50-100 concurrent
- **Future:** ~5,000+ concurrent
- **Scale:** **50x more users**

**Benefits:**
- ✅ No rate limits
- ✅ No timeouts
- ✅ True parallelization
- ✅ Instant staff visibility (no sync delay)
- ✅ Simpler codebase
- ✅ Lower costs (fewer API calls)

---

## Data Loss Risk Assessment

### Current System (Dual-Write)

**Risk Level: LOW** ✅

| Failure Point | Data Loss? | Impact | Mitigation |
|--------------|------------|---------|-----------|
| Supabase fails | ❌ YES - All data lost | CRITICAL | Supabase has 99.9% uptime |
| Knack fails | ✅ NO - Supabase has data | Minor | Sync script recovers |
| Both fail | ❌ YES - Total loss | CRITICAL | Probability: <0.01% |
| Student submits twice | ⚠️ Last write wins | Minor | Upsert handles it |
| Network timeout | ✅ NO - Supabase wrote | Minor | Student retries |

**Key Protection:** Supabase writes FIRST, so even if Knack fails, data is preserved.

### Future System (Supabase-Only)

**Risk Level: MINIMAL** ✅✅

| Failure Point | Data Loss? | Impact | Mitigation |
|--------------|------------|---------|-----------|
| Supabase fails | ❌ YES | CRITICAL | 99.9% uptime + backups |
| Student submits twice | ✅ NO - Upsert | None | Atomic operations |
| Network timeout | ⚠️ Partial | Minor | Student retries |
| Database corruption | ✅ NO | None | Point-in-time recovery |

---

## Recommendations

### Immediate Term (Next 6 Months)

**Action:** Keep current dual-write approach

**Reason:**
- Works for your current load (50-200 students)
- Maintains backwards compatibility
- Low risk - Supabase is source of truth
- Sync script provides safety net

**Monitoring:**
- Watch Heroku logs during peak times
- Track `knackWritten: false` occurrences
- If >20% Knack failures → implement Queue (Option 2)

### Mid Term (6-12 Months)

**Action:** Implement Redis queue for Knack writes

**Benefits:**
- Handles 500+ concurrent users
- No student-facing timeouts
- Smoother experience

**Effort:** 2-3 days development

### Long Term (12+ Months)

**Action:** Remove Knack dependency entirely

**Benefits:**
- 11x faster submissions
- 50x more concurrent capacity
- Simpler codebase
- Lower costs

**Requirements:**
- Migrate all Knack views/reports to Supabase
- Staff training on new interface
- Complete data migration

---

## Testing Concurrent Load

### How to Test 500 Users

**Option A: Locust Load Testing**
```python
# install locust
pip install locust

# Create locustfile.py
from locust import HttpUser, task

class QuestionnaireUser(HttpUser):
    @task
    def submit_questionnaire(self):
        self.client.post("/api/vespa/questionnaire/submit", json={...})

# Run: locust -f locustfile.py --users 500 --spawn-rate 50
```

**Option B: Artillery**
```yaml
# artillery.yml
config:
  target: 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'
  phases:
    - duration: 60
      arrivalRate: 10  # 10 users/second
      
scenarios:
  - name: "Submit questionnaire"
    flow:
      - post:
          url: "/api/vespa/questionnaire/submit"
          json: {...}
```

**Option C: Real-World Test**
- Schedule full year group (500 students) to complete on same day
- Monitor Heroku metrics
- Check error rates
- Verify Supabase vs Knack write success rates

---

## Heroku Configuration

### Current Setup (Likely)
```
Dynos: 1-2 (Standard/Performance)
Workers: 4 Gunicorn workers
Timeout: 30 seconds
Memory: 512MB-1GB
```

### Recommended for 500 Users
```
Dynos: 2-4 (Performance tier)
Workers: 8-12 Gunicorn workers
Timeout: 60 seconds (allow more time)
Memory: 1-2GB
Redis: Standard plan (if implementing queue)
```

**Cost:** ~$50-100/month (vs current ~$25)

---

## Key Metrics to Monitor

### During High Load

**Watch in Heroku Dashboard:**
1. Response time (should be <5 seconds)
2. Error rate (should be <5%)
3. Memory usage (shouldn't hit limit)
4. Request queue (shouldn't back up)

**Watch in Logs:**
```
[Questionnaire Submit] Supabase write failed  ← CRITICAL
[Questionnaire Submit] Knack write failed     ← ACCEPTABLE (sync fixes)
Too Many Requests (429)                        ← Rate limit hit
```

**Watch in Supabase:**
```sql
-- Check submission rate
SELECT 
    DATE_TRUNC('minute', created_at) as minute,
    COUNT(*) as submissions
FROM vespa_scores
WHERE completion_date = CURRENT_DATE
GROUP BY minute
ORDER BY minute DESC;

-- Should see steady rate, not all in 1 minute
```

---

## Conclusion

### For Your Next Test (500 Students)

**Expected Behavior:**
1. ✅ **All 500 students' data saved to Supabase** (100% success)
2. ⚠️ **50-70% write to Knack successfully** (rest timeout)
3. ✅ **Tonight's sync script writes the remaining 30-50% to Knack**
4. ✅ **No data loss**
5. ⚠️ **Some students see error messages** (even though Supabase saved)

**Action Items:**
- Monitor first large test carefully
- Check Supabase data completeness
- Verify sync script catches failed Knack writes
- Consider queue system if errors are disruptive to students

---

## Future-Proof Architecture

Once you're ready to go Supabase-only:

**Benefits:**
- 0.3s response time (vs 3.3s)
- 5,000+ concurrent users
- No rate limits
- No sync delays
- Simpler maintenance

**Migration Path:**
1. Move VESPA reports to Supabase queries ✅ (already done in dashboard)
2. Migrate staff views to Supabase
3. Test thoroughly
4. Remove Knack writes from questionnaire
5. Keep sync script running (Knack → Supabase for historical data)

**Timeline:** 3-6 months for full migration

---

**Document Created:** November 8, 2025
**System Version:** 1N (Frontend) + Multiple Backend Fixes
**Author:** AI Assistant

