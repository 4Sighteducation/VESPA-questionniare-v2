📦 PART 3: Data Migration Scripts
Migration 1: Activities (75 records)
# Python script: migrate_activities.py
import json
import os
from supabase import create_client, Client

# Load structured activities JSON
with open('structured_activities_with_thresholds.json', 'r') as f:
    activities_data = json.load(f)

supabase: Client = create_client(
    os.environ.get("SUPABASE_URL"),
    os.environ.get("SUPABASE_SERVICE_KEY")  # Use service key for migration
)

migrated_count = 0
errors = []

for activity in activities_data:
    try:
        # Parse content sections
        content = {
            "do": activity["sections"].get("do", {}),
            "think": activity["sections"].get("think", {}),
            "learn": activity["sections"].get("learn", {}),
            "reflect": activity["sections"].get("reflect", {})
        }
        
        # Create Supabase record
        data = {
            "knack_id": activity["id"],
            "name": activity["activity_name"],
            "slug": activity["activity_name"].lower().replace(" ", "-"),
            "vespa_category": activity["category"]["name"],
            "level": activity["level"],
            "difficulty": activity.get("difficulty", 0),
            "time_minutes": activity.get("time_minutes"),
            "score_threshold_min": activity.get("show_if_score_more_than"),
            "score_threshold_max": activity.get("show_if_score_less_than"),
            "content": content,
            "do_section_html": activity["raw_fields"].get("field_1289_raw", ""),
            "think_section_html": activity["raw_fields"].get("field_1288_raw", ""),
            "learn_section_html": activity["raw_fields"].get("field_1293_raw", ""),
            "reflect_section_html": activity["raw_fields"].get("field_1313_raw", ""),
            "color": activity.get("colour", ""),
            "display_order": activity.get("display_order"),
            "is_active": activity.get("active", True)
        }
        
        result = supabase.table("activities").insert(data).execute()
        migrated_count += 1
        print(f"✅ Migrated: {activity['activity_name']}")
        
    except Exception as e:
        errors.append({"activity": activity["activity_name"], "error": str(e)})
        print(f"❌ Error: {activity['activity_name']} - {e}")

print(f"\n📊 Migration Summary:")
print(f"Total activities: {len(activities_data)}")
print(f"Successfully migrated: {migrated_count}")
print(f"Errors: {len(errors)}")

if errors:
    print("\n❌ Failed migrations:")
    for err in errors:
        print(f"  - {err['activity']}: {err['error']}")

Migration 2: Questions (1,573 records)
# Python script: migrate_questions.py
import csv
import os
from supabase import create_client, Client

supabase: Client = create_client(
    os.environ.get("SUPABASE_URL"),
    os.environ.get("SUPABASE_SERVICE_KEY")
)

# First, fetch all activities to get UUID mappings
activities = supabase.table("activities").select("id, name, knack_id").execute()
activity_map = {a["name"]: a["id"] for a in activities.data}

migrated_count = 0
errors = []

with open('activityquestion.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    
    for row in reader:
        try:
            activity_name = row["Activity"]
            
            # Skip if no activity name or inactive
            if not activity_name or row["Active"] != "True":
                continue
            
            # Get activity UUID
            if activity_name not in activity_map:
                print(f"⚠️  Activity not found: {activity_name}")
                continue
            
            activity_id = activity_map[activity_name]
            
            # Parse dropdown options (CSV string → array)
            options_str = row["Dropdown/Checkbox options"]
            dropdown_options = [opt.strip() for opt in options_str.split(",")] if options_str else []
            
            data = {
                "activity_id": activity_id,
                "question_title": row["Question Title"],
                "text_above_question": row["Text Above Question"],
                "question_type": row["Type"],
                "dropdown_options": dropdown_options,
                "display_order": int(row["Order"]) if row["Order"] else 0,
                "is_active": row["Active"] == "True",
                "answer_required": row["Answer Required?"] == "Yes",
                "show_in_final_questions": row["Show in Final Questions Section"] == "Yes"
            }
            
            supabase.table("activity_questions").insert(data).execute()
            migrated_count += 1
            
            if migrated_count % 100 == 0:
                print(f"📝 Migrated {migrated_count} questions...")
                
        except Exception as e:
            errors.append({"row": row.get("Question Title", "Unknown"), "error": str(e)})

print(f"\n📊 Migration Summary:")
print(f"Total questions migrated: {migrated_count}")
print(f"Errors: {len(errors)}")

Migration 3: Historical Responses (6,060 records from Object_46)
# Python script: migrate_historical_responses.py
import os
import json
from datetime import datetime
from supabase import create_client, Client

supabase: Client = create_client(
    os.environ.get("SUPABASE_URL"),
    os.environ.get("SUPABASE_SERVICE_KEY")
)

# Fetch historical answers from Knack API
import requests

knack_app_id = '66e26296d863e5001c6f1e09'
knack_api_key = '0b19dcb0-9f43-11ef-8724-eb3bc75b770f'

headers = {
    'X-Knack-Application-Id': knack_app_id,
    'X-Knack-REST-API-Key': knack_api_key,
    'Content-Type': 'application/json'
}

# Fetch all Object_46 records where completion_date >= 2025-01-01
filters = {
    "match": "and",
    "rules": [
        {
            "field": "field_1870",  # completion_date
            "operator": "is after",
            "value": "01/01/2025"
        },
        {
            "field": "field_1301",  # student connection
            "operator": "is not blank"
        }
    ]
}

page = 1
rows_per_page = 1000
migrated_count = 0
errors = []

while True:
    params = {
        "filters": json.dumps(filters),
        "rows_per_page": rows_per_page,
        "page": page
    }
    
    response = requests.get(
        f"https://api.knack.com/v1/objects/object_46/records",
        headers=headers,
        params=params
    )
    
    if response.status_code != 200:
        print(f"❌ Knack API error: {response.text}")
        break
    
    data = response.json()
    records = data.get("records", [])
    
    if not records:
        break  # No more records
    
    for record in records:
        try:
            # Extract student email
            student_connection = record.get("field_1301_raw", [])
            if not student_connection or len(student_connection) == 0:
                continue
            
            student_email = student_connection[0].get("identifier", "")
            if not student_email:
                continue
            
            # Extract activity ID
            activity_connection = record.get("field_1302_raw", [])
            if not activity_connection or len(activity_connection) == 0:
                continue
            
            activity_knack_id = activity_connection[0].get("id", "")
            
            # Get activity UUID from Supabase
            activity_result = supabase.table("activities").select("id").eq("knack_id", activity_knack_id).execute()
            if not activity_result.data:
                print(f"⚠️  Activity not found for knack_id: {activity_knack_id}")
                continue
            
            activity_uuid = activity_result.data[0]["id"]
            
            # Parse responses JSON
            responses_json = {}
            try:
                raw_json = record.get("field_1300", "")
                if raw_json:
                    responses_json = json.loads(raw_json) if isinstance(raw_json, str) else raw_json
            except:
                pass
            
            # Create or ensure student exists
            supabase.table("students").upsert({
                "email": student_email,
                "knack_id": student_connection[0].get("id", "")
            }, on_conflict="email").execute()
            
            # Insert response
            response_data = {
                "knack_id": record["id"],
                "student_email": student_email,
                "activity_id": activity_uuid,
                "cycle_number": 1,  # Assume cycle 1 for historical data
                "responses": responses_json,
                "responses_text": record.get("field_2334", ""),
                "status": "completed",
                "completed_at": record.get("field_1870", None),
                "staff_feedback": record.get("field_1734", ""),
                "year_group": record.get("field_2331", ""),
                "student_group": record.get("field_2332", "")
            }
            
            supabase.table("activity_responses").insert(response_data).execute()
            migrated_count += 1
            
            if migrated_count % 100 == 0:
                print(f"📦 Migrated {migrated_count} responses...")
                
        except Exception as e:
            errors.append({"record_id": record.get("id", "Unknown"), "error": str(e)})
    
    page += 1

print(f"\n📊 Migration Summary:")
print(f"Total responses migrated: {migrated_count}")
print(f"Errors: {len(errors)}")

🎨 PART 4: Vue 3 App Architecture - Student Activities
Project Structure
vespa-activities-student/
├── src/
│   ├── components/
│   │   ├── ActivityDashboard.vue         # Main dashboard with recommended activities
│   │   ├── ActivityCard.vue              # Single activity card with progress
│   │   ├── ActivityModal.vue             # Full-screen activity experience
│   │   ├── CategoryFilter.vue            # Filter by VESPA category
│   │   ├── ProblemSelector.vue           # Self-selection by problem
│   │   ├── QuestionRenderer.vue          # Dynamic question rendering
│   │   ├── ProgressTracker.vue           # Visual progress indicators
│   │   ├── AchievementPanel.vue          # Achievements/badges display
│   │   ├── NotificationBell.vue          # Real-time notification dropdown
│   │   └── FeedbackPanel.vue             # Staff feedback display
│   ├── services/
│   │   ├── supabase.js                   # Supabase client setup
│   │   ├── activityService.js            # Activity CRUD operations
│   │   ├── responseService.js            # Response save/retrieve
│   │   ├── achievementService.js         # Achievement logic
│   │   ├── notificationService.js        # Real-time notifications
│   │   └── knackAuth.js                  # Knack user detection
│   ├── composables/
│   │   ├── useActivities.js              # Activity state management
│   │   ├── useProgress.js                # Progress calculations
│   │   ├── useVESPAScores.js             # Fetch scores from Supabase
│   │   ├── useNotifications.js           # Real-time notification subscription
│   │   └── useAchievements.js            # Achievement tracking
│   ├── utils/
│   │   ├── activityRecommendation.js     # Calculate recommended activities
│   │   ├── problemMapping.js             # Load problem→activity mappings
│   │   └── validators.js                 # Form validation
│   ├── App.vue                           # Main orchestrator (IIFE wrapped)
│   ├── main.js                           # Entry point
│   └── style.css                         # Global styles
├── public/
├── dist/                                 # Build output
├── package.json
├── vite.config.js
└── README.md
Key Component: ActivityDashboard.vue (Example)
<template>
  <div class="activity-dashboard">
    <!-- Notification Bell -->
    <NotificationBell :notifications="notifications" @mark-read="markNotificationRead" />
    
    <!-- Progress Overview -->
    <div class="progress-overview">
      <h2>Your Progress</h2>
      <ProgressTracker 
        :completed="completedCount" 
        :total="assignedCount" 
        :points="totalPoints"
      />
    </div>
    
    <!-- Recommended Activities -->
    <section class="recommended-section">
      <h3>📊 Recommended for Your Scores</h3>
      <p class="scores-summary">
        Vision: {{ vespaScores.vision }}/10 | Effort: {{ vespaScores.effort }}/10 | 
        Systems: {{ vespaScores.systems }}/10 | Practice: {{ vespaScores.practice }}/10 | 
        Attitude: {{ vespaScores.attitude }}/10
      </p>
      <div class="activity-grid">
        <ActivityCard 
          v-for="activity in recommendedActivities" 
          :key="activity.id"
          :activity="activity"
          :progress="getProgressForActivity(activity.id)"
          @start="startActivity"
          @continue="continueActivity"
          @view-feedback="viewFeedback"
        />
      </div>
    </section>
    
    <!-- Problem-Based Selection -->
    <section class="problem-section">
      <h3>🎯 Select by Problem</h3>
      <ProblemSelector 
        :category="selectedCategory"
        @select-activity="addActivityToDashboard"
      />
    </section>
    
    <!-- My Activities -->
    <section class="my-activities">
      <h3>📚 My Activities</h3>
      <CategoryFilter v-model="filterCategory" />
      <div class="activity-grid">
        <ActivityCard 
          v-for="activity in myActivities" 
          :key="activity.id"
          :activity="activity"
          :progress="getProgressForActivity(activity.id)"
          :is-assigned="true"
          @start="startActivity"
          @remove="removeActivity"
        />
      </div>
    </section>
    
    <!-- Achievements -->
    <section class="achievements-section">
      <h3>🏆 Your Achievements</h3>
      <AchievementPanel :achievements="achievements" />
    </section>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useActivities } from '@/composables/useActivities';
import { useProgress } from '@/composables/useProgress';
import { useVESPAScores } from '@/composables/useVESPAScores';
import { useNotifications } from '@/composables/useNotifications';
import { useAchievements } from '@/composables/useAchievements';

const config = window.STUDENT_ACTIVITIES_V3_CONFIG;
const studentEmail = window.Knack?.getUserAttributes()?.email;

// Composables
const { 
  activities, 
  myActivities, 
  recommendedActivities,
  fetchActivities,
  addActivity,
  removeActivity 
} = useActivities(studentEmail);

const { 
  completedCount, 
  assignedCount, 
  getProgressForActivity 
} = useProgress(studentEmail);

const { vespaScores, fetchVESPAScores } = useVESPAScores(studentEmail);
const { notifications, markRead } = useNotifications(studentEmail);
const { achievements, totalPoints, checkNewAchievements } = useAchievements(studentEmail);

// State
const selectedCategory = ref('all');
const filterCategory = ref('all');

// Methods
const startActivity = (activity) => {
  // Open ActivityModal
};

const continueActivity = (activity) => {
  // Resume in ActivityModal
};

const viewFeedback = (activityId) => {
  // Show FeedbackPanel
};

const addActivityToDashboard = async (activity) => {
  await addActivity(activity.id, 'student_choice');
  await checkNewAchievements(); // Check if this triggers an achievement
};

const markNotificationRead = async (notificationId) => {
  await markRead(notificationId);
};

// Initialize
onMounted(async () => {
  await fetchVESPAScores();
  await fetchActivities();
});
</script>

<style scoped>
/* Theme colors matching VESPA palette */
.activity-dashboard {
  max-width: 1400px;
  margin: 0 auto;
  padding: 20px;
  background: linear-gradient(135deg, #f5f9fc 0%, #e8f4f8 100%);
}

.activity-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
  margin-top: 20px;
}

.progress-overview {
  background: white;
  border-radius: 12px;
  padding: 24px;
  margin-bottom: 30px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

/* Category colors */
.category-vision { color: #ff8f00; }
.category-effort { color: #5899a8; }
.category-systems { color: #7bd8d0; }
.category-practice { color: #8b72be; }
.category-attitude { color: #ff769c; }
</style>



🎯 PART 5: Backend API Endpoints (Flask)
Complete API Specificatio

# app.py additions for activities

from flask import Flask, request, jsonify
from supabase import create_client, Client
import os
from datetime import datetime

app = Flask(__name__)

# Initialize Supabase
supabase: Client = create_client(
    os.environ.get("SUPABASE_URL"),
    os.environ.get("SUPABASE_SERVICE_KEY")
)

# ==========================================
# STUDENT ENDPOINTS
# ==========================================

@app.route('/api/activities/recommended', methods=['GET'])
def get_recommended_activities():
    """
    Calculate recommended activities based on VESPA scores
    Query params: email, cycle
    """
    student_email = request.args.get('email')
    cycle = request.args.get('cycle', 1)
    
    # Fetch VESPA scores from Supabase
    scores_result = supabase.table('vespa_scores').select('*').eq('student_email', student_email).eq('cycle_number', cycle).execute()
    
    if not scores_result.data:
        return jsonify({"error": "No VESPA scores found"}), 404
    
    scores = scores_result.data[0]
    level = scores.get('level', 'Level 2')
    
    # Fetch student record to get current cycle
    student = supabase.table('students').select('*').eq('email', student_email).execute()
    
    # Calculate which activities to recommend based on scores
    recommended = []
    
    for category in ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude']:
        score_key = category.lower()
        score = scores.get(score_key, 5)
        
        # Fetch activities matching: category, level, score thresholds
        activities_result = supabase.table('activities').select('*')\
            .eq('vespa_category', category)\
            .eq('level', level)\
            .eq('is_active', True)\
            .or_(f'score_threshold_min.lte.{score},score_threshold_min.is.null')\
            .or_(f'score_threshold_max.gte.{score},score_threshold_max.is.null')\
            .order('display_order')\
            .limit(3)\
            .execute()
        
        recommended.extend(activities_result.data)
    
    return jsonify({
        "recommended": recommended,
        "vespaScores": scores,
        "level": level,
        "cycle": cycle
    })


@app.route('/api/activities/by-problem', methods=['GET'])
def get_activities_by_problem():
    """
    Get activities mapped to specific problems
    Query params: problem_id
    """
    problem_id = request.args.get('problem_id')
    
    # Fetch activities that have this problem_id in their problem_mappings array
    activities_result = supabase.table('activities').select('*')\
        .contains('problem_mappings', [problem_id])\
        .eq('is_active', True)\
        .execute()
    
    return jsonify({"activities": activities_result.data})


@app.route('/api/activities/assigned', methods=['GET'])
def get_assigned_activities():
    """
    Get student's assigned/prescribed activities
    Query params: email, cycle
    """
    student_email = request.args.get('email')
    cycle = request.args.get('cycle', 1)
    
    # Fetch student's activities
    assigned_result = supabase.table('student_activities').select('''
        *,
        activities:activity_id (
            id, name, vespa_category, level, time_minutes, color, content
        )
    ''')\
        .eq('student_email', student_email)\
        .eq('cycle_number', cycle)\
        .neq('status', 'removed')\
        .execute()
    
    # Also fetch progress for each
    responses_result = supabase.table('activity_responses').select('*')\
        .eq('student_email', student_email)\
        .eq('cycle_number', cycle)\
        .execute()
    
    # Merge progress into activities
    progress_map = {r['activity_id']: r for r in responses_result.data}
    
    for assignment in assigned_result.data:
        activity_id = assignment['activity_id']
        assignment['progress'] = progress_map.get(activity_id, {})
    
    return jsonify({"assignments": assigned_result.data})


@app.route('/api/activities/questions', methods=['GET'])
def get_activity_questions():
    """
    Get all questions for an activity
    Query params: activity_id
    """
    activity_id = request.args.get('activity_id')
    
    questions_result = supabase.table('activity_questions').select('*')\
        .eq('activity_id', activity_id)\
        .eq('is_active', True)\
        .order('display_order')\
        .execute()
    
    return jsonify({"questions": questions_result.data})


@app.route('/api/activities/start', methods=['POST'])
def start_activity():
    """
    Start an activity (create initial response record)
    """
    data = request.json
    student_email = data['studentEmail']
    activity_id = data['activityId']
    cycle = data.get('cycle', 1)
    selected_via = data.get('selectedVia', 'student_choice')
    
    # Create response record
    response_data = {
        "student_email": student_email,
        "activity_id": activity_id,
        "cycle_number": cycle,
        "status": "in_progress",
        "selected_via": selected_via,
        "responses": {}
    }
    
    result = supabase.table('activity_responses').upsert(
        response_data,
        on_conflict='student_email,activity_id,cycle_number'
    ).execute()
    
    # Update student_activities if not already there
    supabase.table('student_activities').upsert({
        "student_email": student_email,
        "activity_id": activity_id,
        "cycle_number": cycle,
        "assigned_by": selected_via,
        "status": "started"
    }, on_conflict='student_email,activity_id,cycle_number').execute()
    
    # Log history
    supabase.table('activity_history').insert({
        "student_email": student_email,
        "activity_id": activity_id,
        "action": "started",
        "triggered_by": "student",
        "cycle_number": cycle
    }).execute()
    
    return jsonify({"success": True, "response": result.data})


@app.route('/api/activities/save', methods=['POST'])
def save_activity_progress():
    """
    Auto-save activity progress (called every 30 seconds)
    """
    data = request.json
    student_email = data['studentEmail']
    activity_id = data['activityId']
    cycle = data.get('cycle', 1)
    responses = data.get('responses', {})
    time_minutes = data.get('timeMinutes', 0)
    
    # Update responses
    update_data = {
        "responses": responses,
        "time_spent_minutes": time_minutes,
        "updated_at": datetime.utcnow().isoformat()
    }
    
    result = supabase.table('activity_responses').update(update_data)\
        .eq('student_email', student_email)\
        .eq('activity_id', activity_id)\
        .eq('cycle_number', cycle)\
        .execute()
    
    return jsonify({"success": True, "saved": True})


@app.route('/api/activities/complete', methods=['POST'])
def complete_activity():
    """
    Complete an activity (final submission)
    """
    data = request.json
    student_email = data['studentEmail']
    activity_id = data['activityId']
    cycle = data.get('cycle', 1)
    responses = data['responses']
    reflection = data.get('reflection', '')
    time_minutes = data.get('timeMinutes', 0)
    word_count = data.get('wordCount', 0)
    
    # Update response to completed
    update_data = {
        "status": "completed",
        "responses": responses,
        "responses_text": reflection,
        "time_spent_minutes": time_minutes,
        "word_count": word_count,
        "completed_at": datetime.utcnow().isoformat()
    }
    
    result = supabase.table('activity_responses').update(update_data)\
        .eq('student_email', student_email)\
        .eq('activity_id', activity_id)\
        .eq('cycle_number', cycle)\
        .execute()
    
    # Update student_activities
    supabase.table('student_activities').update({"status": "completed"})\
        .eq('student_email', student_email)\
        .eq('activity_id', activity_id)\
        .eq('cycle_number', cycle)\
        .execute()
    
    # Update student totals
    supabase.rpc('increment_student_completed_count', {
        'student_email_param': student_email
    }).execute()
    
    # Log history
    supabase.table('activity_history').insert({
        "student_email": student_email,
        "activity_id": activity_id,
        "action": "completed",
        "triggered_by": "student",
        "cycle_number": cycle,
        "metadata": {
            "time_minutes": time_minutes,
            "word_count": word_count
        }
    }).execute()
    
    # Check for new achievements
    achievements_earned = check_and_award_achievements(student_email)
    
    # Send notification to staff if feedback exists
    if achievements_earned:
        create_notification(
            student_email,
            'achievement_earned',
            f"🏆 New Achievement Unlocked!",
            f"You earned: {', '.join([a['achievement_name'] for a in achievements_earned])}"
        )
    
    return jsonify({
        "success": True,
        "completed": True,
        "newAchievements": achievements_earned
    })


# ==========================================
# STAFF ENDPOINTS
# ==========================================

@app.route('/api/staff/students', methods=['GET'])
def get_staff_students():
    """
    Get all students connected to a staff member
    Query params: staff_email, role
    """
    staff_email = request.args.get('staff_email')
    role = request.args.get('role', 'tutor')
    
    # Fetch connections
    connections = supabase.table('staff_student_connections').select('''
        *,
        students:student_email (*)
    ''')\
        .eq('staff_email', staff_email)\
        .eq('staff_role', role)\
        .execute()
    
    students = []
    for conn in connections.data:
        student = conn['students']
        
        # Get activity stats
        stats = supabase.table('activity_responses').select('status', count='exact')\
            .eq('student_email', student['email'])\
            .execute()
        
        student['activity_stats'] = {
            'total': stats.count,
            'completed': len([r for r in stats.data if r['status'] == 'completed'])
        }
        
        students.append(student)
    
    return jsonify({"students": students})


@app.route('/api/staff/student-activities', methods=['GET'])
def get_student_activities_for_staff():
    """
    Get detailed activity breakdown for a student
    Query params: student_email, cycle
    """
    student_email = request.args.get('student_email')
    cycle = request.args.get('cycle', 1)
    
    # Fetch all responses with activity details
    responses = supabase.table('activity_responses').select('''
        *,
        activities:activity_id (
            id, name, vespa_category, level
        )
    ''')\
        .eq('student_email', student_email)\
        .eq('cycle_number', cycle)\
        .order('updated_at', desc=True)\
        .execute()
    
    # Group by category
    by_category = {}
    for response in responses.data:
        category = response['activities']['vespa_category']
        if category not in by_category:
            by_category[category] = []
        by_category[category].append(response)
    
    return jsonify({
        "responses": responses.data,
        "byCategory": by_category
    })


@app.route('/api/staff/assign-activity', methods=['POST'])
def assign_activity_to_student():
    """
    Staff assigns activity to student
    """
    data = request.json
    staff_email = data['staffEmail']
    student_email = data['studentEmail']
    activity_ids = data['activityIds']  # Can assign multiple
    cycle = data.get('cycle', 1)
    reason = data.get('reason', 'Staff recommendation')
    
    assigned = []
    
    for activity_id in activity_ids:
        # Insert into student_activities
        assignment = {
            "student_email": student_email,
            "activity_id": activity_id,
            "cycle_number": cycle,
            "assigned_by": staff_email,
            "assigned_reason": reason,
            "status": "assigned"
        }
        
        result = supabase.table('student_activities').upsert(
            assignment,
            on_conflict='student_email,activity_id,cycle_number'
        ).execute()
        
        assigned.append(result.data[0])
        
        # Log history
        supabase.table('activity_history').insert({
            "student_email": student_email,
            "activity_id": activity_id,
            "action": "assigned",
            "triggered_by": "staff",
            "triggered_by_email": staff_email,
            "cycle_number": cycle
        }).execute()
        
        # Create notification for student
        activity_name = get_activity_name(activity_id)
        create_notification(
            student_email,
            'activity_assigned',
            '📚 New Activity Assigned',
            f"Your tutor assigned you: {activity_name}",
            action_url=f"#vespa-activities?activity={activity_id}&action=view"
        )
    
    return jsonify({
        "success": True,
        "assigned": assigned
    })


@app.route('/api/staff/feedback', methods=['POST'])
def give_feedback():
    """
    Staff provides feedback on student's activity
    """
    data = request.json
    staff_email = data['staffEmail']
    response_id = data['responseId']
    feedback_text = data['feedbackText']
    
    # Update activity_responses
    result = supabase.table('activity_responses').update({
        "staff_feedback": feedback_text,
        "staff_feedback_by": staff_email,
        "staff_feedback_at": datetime.utcnow().isoformat(),
        "feedback_read_by_student": False
    }).eq('id', response_id).execute()
    
    # Get student email for notification
    response_data = result.data[0]
    student_email = response_data['student_email']
    activity_id = response_data['activity_id']
    
    # Create notification
    activity_name = get_activity_name(activity_id)
    create_notification(
        student_email,
        'feedback_received',
        '💬 New Feedback on Your Activity',
        f"Your tutor left feedback on: {activity_name}",
        action_url=f"#vespa-activities?activity={activity_id}&action=view-feedback"
    )
    
    return jsonify({"success": True, "feedback_sent": True})


@app.route('/api/staff/remove-activity', methods=['POST'])
def remove_activity_from_student():
    """
    Staff removes activity from student's dashboard
    """
    data = request.json
    staff_email = data['staffEmail']
    student_email = data['studentEmail']
    activity_id = data['activityId']
    cycle = data.get('cycle', 1)
    
    # Update to removed status
    supabase.table('student_activities').update({
        "status": "removed",
        "removed_at": datetime.utcnow().isoformat()
    })\
        .eq('student_email', student_email)\
        .eq('activity_id', activity_id)\
        .eq('cycle_number', cycle)\
        .execute()
    
    # Log history
    supabase.table('activity_history').insert({
        "student_email": student_email,
        "activity_id": activity_id,
        "action": "removed",
        "triggered_by": "staff",
        "triggered_by_email": staff_email,
        "cycle_number": cycle
    }).execute()
    
    return jsonify({"success": True})


@app.route('/api/staff/award-achievement', methods=['POST'])
def award_achievement():
    """
    Staff manually awards achievement (certificate)
    """
    data = request.json
    staff_email = data['staffEmail']
    student_email = data['studentEmail']
    achievement_type = data.get('achievementType', 'custom')
    achievement_name = data['achievementName']
    description = data.get('description', '')
    points = data.get('points', 50)
    icon = data.get('icon', '🏅')
    
    # Create achievement
    achievement = {
        "student_email": student_email,
        "achievement_type": achievement_type,
        "achievement_name": achievement_name,
        "achievement_description": description,
        "points_value": points,
        "icon_emoji": icon,
        "issued_by_staff": staff_email,
        "date_earned": datetime.utcnow().isoformat()
    }
    
    result = supabase.table('student_achievements').insert(achievement).execute()
    
    # Update student points
    supabase.rpc('add_student_points', {
        'student_email_param': student_email,
        'points_param': points
    }).execute()
    
    # Notify student
    create_notification(
        student_email,
        'achievement_earned',
        f'🎉 Achievement: {achievement_name}',
        description or f"Your tutor awarded you {points} points!",
        related_achievement_id=result.data[0]['id']
    )
    
    return jsonify({"success": True, "achievement": result.data[0]})


# ==========================================
# NOTIFICATION ENDPOINTS
# ==========================================

@app.route('/api/notifications', methods=['GET'])
def get_notifications():
    """
    Get notifications for a user
    Query params: email, unread_only
    """
    email = request.args.get('email')
    unread_only = request.args.get('unread_only', 'false') == 'true'
    
    query = supabase.table('notifications').select('*').eq('recipient_email', email)
    
    if unread_only:
        query = query.eq('is_read', False)
    
    result = query.order('created_at', desc=True).limit(50).execute()
    
    return jsonify({"notifications": result.data})


@app.route('/api/notifications/mark-read', methods=['POST'])
def mark_notification_read():
    """
    Mark notification as read
    """
    data = request.json
    notification_id = data['notificationId']
    
    supabase.table('notifications').update({
        "is_read": True,
        "read_at": datetime.utcnow().isoformat()
    }).eq('id', notification_id).execute()
    
    return jsonify({"success": True})


@app.route('/api/achievements/check', methods=['GET'])
def check_achievements():
    """
    Check if student has earned any new achievements
    Query params: email
    """
    student_email = request.args.get('email')
    
    new_achievements = check_and_award_achievements(student_email)
    
    return jsonify({"newAchievements": new_achievements})


# ==========================================
# HELPER FUNCTIONS
# ==========================================

def create_notification(recipient_email, notification_type, title, message, 
                       action_url=None, related_activity_id=None, 
                       related_response_id=None, related_achievement_id=None,
                       priority='normal'):
    """Helper to create notifications"""
    notification = {
        "recipient_email": recipient_email,
        "recipient_type": "student" if "student" in notification_type else "staff",
        "notification_type": notification_type,
        "title": title,
        "message": message,
        "action_url": action_url,
        "related_activity_id": related_activity_id,
        "related_response_id": related_response_id,
        "related_achievement_id": related_achievement_id,
        "priority": priority,
        "is_read": False
    }
    
    supabase.table('notifications').insert(notification).execute()


def check_and_award_achievements(student_email):
    """Check all achievement criteria and award if met"""
    # Fetch achievement definitions
    achievement_defs = supabase.table('achievement_definitions').select('*')\
        .eq('is_active', True)\
        .execute()
    
    # Fetch student stats
    responses = supabase.table('activity_responses').select('*')\
        .eq('student_email', student_email)\
        .eq('status', 'completed')\
        .execute()
    
    new_achievements = []
    
    for achievement_def in achievement_defs.data:
        criteria = achievement_def['criteria']
        
        # Check if already earned
        existing = supabase.table('student_achievements').select('id')\
            .eq('student_email', student_email)\
            .eq('achievement_type', achievement_def['achievement_type'])\
            .execute()
        
        if existing.data:
            continue  # Already has this achievement
        
        # Evaluate criteria
        if evaluate_achievement_criteria(responses.data, criteria):
            # Award it!
            achievement = {
                "student_email": student_email,
                "achievement_type": achievement_def['achievement_type'],
                "achievement_name": achievement_def['name'],
                "achievement_description": achievement_def['description'],
                "points_value": achievement_def['points_value'],
                "icon_emoji": achievement_def['icon_emoji'],
                "criteria_met": criteria
            }
            
            result = supabase.table('student_achievements').insert(achievement).execute()
            new_achievements.append(result.data[0])
            
            # Update student points
            supabase.rpc('add_student_points', {
                'student_email_param': student_email,
                'points_param': achievement_def['points_value']
            }).execute()
    
    return new_achievements


def evaluate_achievement_criteria(responses, criteria):
    """Evaluate if achievement criteria is met"""
    criteria_type = criteria.get('type')
    
    if criteria_type == 'activities_completed':
        count_required = criteria['count']
        category = criteria.get('category')
        
        if category:
            # Count completions in specific category
            # Would need to join with activities table
            pass
        else:
            # Count all completions
            return len(responses) >= count_required
    
    elif criteria_type == 'streak':
        # Check consecutive days
        pass
    
    elif criteria_type == 'category_master':
        # Check if completed X% of category
        pass
    
    return False


def get_activity_name(activity_id):
    """Helper to get activity name"""
    result = supabase.table('activities').select('name').eq('id', activity_id).single().execute()
    return result.data['name'] if result.data else "Unknown Activity"




⚡ PART 6: Real-Time Notifications (Supabase Realtime)
Frontend Setup (useNotifications.js)
// composables/useNotifications.js
import { ref, onMounted, onUnmounted } from 'vue';
import { supabase } from '@/services/supabase';

export function useNotifications(userEmail) {
    const notifications = ref([]);
    const unreadCount = ref(0);
    let subscription = null;
    
    const fetchNotifications = async () => {
        const { data, error } = await supabase
            .from('notifications')
            .select('*')
            .eq('recipient_email', userEmail)
            .order('created_at', { ascending: false })
            .limit(20);
        
        if (data) {
            notifications.value = data;
            unreadCount.value = data.filter(n => !n.is_read).length;
        }
    };
    
    const markRead = async (notificationId) => {
        await supabase
            .from('notifications')
            .update({ is_read: true, read_at: new Date().toISOString() })
            .eq('id', notificationId);
        
        // Update local state
        const notification = notifications.value.find(n => n.id === notificationId);
        if (notification) {
            notification.is_read = true;
            unreadCount.value--;
        }
    };
    
    const subscribeToRealtime = () => {
        subscription = supabase
            .channel(`notifications:${userEmail}`)
            .on(
                'postgres_changes',
                {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'notifications',
                    filter: `recipient_email=eq.${userEmail}`
                },
                (payload) => {
                    console.log('New notification received:', payload.new);
                    notifications.value.unshift(payload.new);
                    unreadCount.value++;
                    
                    // Show toast notification
                    showToast(payload.new.title, payload.new.message);
                }
            )
            .subscribe();
    };
    
    const showToast = (title, message) => {
        // Simple toast notification
        const toast = document.createElement('div');
        toast.className = 'vespa-toast-notification';
        toast.innerHTML = `
            <div class="toast-header">${title}</div>
            <div class="toast-body">${message}</div>
        `;
        document.body.appendChild(toast);
        
        setTimeout(() => toast.remove(), 5000);
    };
    
    onMounted(async () => {
        await fetchNotifications();
        subscribeToRealtime();
    });
    
    onUnmounted(() => {
        if (subscription) {
            subscription.unsubscribe();
        }
    });
    
    return {
        notifications,
        unreadCount,
        markRead,
        fetchNotifications
    };
}

🎮 PART 7: Enhanced Gamification System
Achievement Types
const ACHIEVEMENT_TYPES = {
    // Milestone achievements
    FIRST_ACTIVITY: {
        name: "First Steps 🚶",
        description: "Completed your first VESPA activity",
        points: 10,
        criteria: { type: 'activities_completed', count: 1 }
    },
    FIVE_COMPLETE: {
        name: "Rising Star ⭐",
        description: "Completed 5 activities",
        points: 25,
        criteria: { type: 'activities_completed', count: 5 }
    },
    TEN_COMPLETE: {
        name: "Dedicated Learner 📚",
        description: "Completed 10 activities",
        points: 50,
        criteria: { type: 'activities_completed', count: 10 }
    },
    TWENTY_COMPLETE: {
        name: "VESPA Champion 🏆",
        description: "Completed 20 activities",
        points: 100,
        criteria: { type: 'activities_completed', count: 20 }
    },
    
    // Category mastery achievements
    VISION_MASTER: {
        name: "Vision Master 🔭",
        description: "Completed 80% of Vision activities",
        points: 75,
        criteria: { type: 'category_master', category: 'Vision', percentage: 80 }
    },
    EFFORT_MASTER: {
        name: "Effort Master 💪",
        description: "Completed 80% of Effort activities",
        points: 75,
        criteria: { type: 'category_master', category: 'Effort', percentage: 80 }
    },
    // ... etc for all categories
    
    // Streak achievements
    WEEK_STREAK: {
        name: "Weekly Warrior 🔥",
        description: "Completed activities 7 days in a row",
        points: 50,
        criteria: { type: 'streak', days: 7 }
    },
    MONTH_STREAK: {
        name: "Unstoppable 🚀",
        description: "Completed activities 30 days in a row",
        points: 150,
        criteria: { type: 'streak', days: 30 }
    },
    
    // Perfect score achievements
    PERFECT_REFLECTION: {
        name: "Thoughtful Scholar 💭",
        description: "Wrote reflection with 500+ words",
        points: 25,
        criteria: { type: 'word_count', min: 500 }
    },
    
    // Speed achievements
    QUICK_COMPLETION: {
        name: "Efficient Worker ⚡",
        description: "Completed activity in under recommended time",
        points: 20,
        criteria: { type: 'time_bonus', under_recommended: true }
    }
};


📱 PART 8: KnackAppLoader Configuration
Updated KnackAppLoader(copy).js - Add these entries:
'studentActivitiesV3': {
    scenes: ['scene_1288'],
    views: ['view_3262'],
    scriptUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/student/dist/student-activities1a.js',
    cssUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/student/dist/student-activities1a.css',
    configBuilder: (baseConfig, sceneKey, viewKey) => ({
        ...baseConfig,
        appType: 'studentActivitiesV3',
        sceneKey: sceneKey,
        viewKey: viewKey,
        debugMode: true,
        elementSelector: '#view_3262',
        renderMode: 'replace',
        hideOriginalView: true,
        apiUrl: 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com',
        supabaseUrl: process.env.SUPABASE_URL,  // Will be replaced during build
        supabaseAnonKey: process.env.SUPABASE_ANON_KEY,
        problemMappingsUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/shared/vespa-problem-activity-mappings1a.json'
    }),
    configGlobalVar: 'STUDENT_ACTIVITIES_V3_CONFIG',
    initializerFunctionName: 'initializeStudentActivitiesV3'
},

'staffActivitiesOverviewV3': {
    scenes: ['scene_1286'],  // CONFIRMED: scene_1286, not scene_1290
    views: ['view_3258'],
    scriptUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/staff/dist/staff-overview1a.js',
    cssUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v3@main/staff/dist/staff-overview1a.css',
    configBuilder: (baseConfig, sceneKey, viewKey) => ({
        ...baseConfig,
        appType: 'staffActivitiesOverviewV3',
        sceneKey: sceneKey,
        viewKey: viewKey,
        debugMode: true,
        elementSelector: '#view_3258',
        renderMode: 'replace',
        hideOriginalView: true,
        apiUrl: 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'
    }),
    configGlobalVar: 'STAFF_ACTIVITIES_OVERVIEW_V3_CONFIG',
    initializerFunctionName: 'initializeStaffActivitiesOverviewV3'
}