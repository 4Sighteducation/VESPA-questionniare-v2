<template>
  <div class="student-workspace">
    <!-- Header -->
    <div class="workspace-header">
      <button class="btn btn-secondary" @click="$emit('back')">
        <i class="fas fa-arrow-left"></i> Back to List
      </button>
      
      <div class="student-info">
        <h2 class="student-name">{{ student.full_name }}</h2>
        <div class="student-meta">
          <span class="meta-badge">
            <i class="fas fa-envelope"></i> {{ student.email }}
          </span>
          <span v-if="student.current_year_group" class="meta-badge">
            <i class="fas fa-graduation-cap"></i> {{ student.current_year_group }}
          </span>
          <span v-if="student.student_group" class="meta-badge">
            <i class="fas fa-users"></i> {{ student.student_group }}
          </span>
          <span class="meta-badge progress-badge">
            <i class="fas fa-chart-line"></i> {{ student.progress }}% Complete
          </span>
        </div>
      </div>
      
      <div class="header-actions">
        <input
          type="search"
          v-model="searchTerm"
          placeholder="Search activities..."
          class="search-input-compact"
        />
        <button class="btn btn-primary" @click="showAssignModal = true">
          <i class="fas fa-plus"></i> Assign Activities
        </button>
        <button class="btn btn-secondary" @click="$emit('refresh')">
          <i class="fas fa-sync"></i> Refresh
        </button>
      </div>
    </div>

    <!-- Student Activities Section -->
    <div class="workspace-content">
      <div class="section-header">
        <h3>
          <i class="fas fa-clipboard-check"></i>
          Assigned Activities ({{ assignedActivities.length }})
        </h3>
        <div class="legend">
          <span class="legend-item">
            <span class="source-dot questionnaire"></span>
            Questionnaire
          </span>
          <span class="legend-item">
            <span class="source-dot staff"></span>
            Staff Assigned
          </span>
          <span class="legend-item">
            <span class="source-dot student"></span>
            Student Choice
          </span>
          <span class="legend-item">
            <span class="source-dot feedback"></span>
            Unread Feedback
          </span>
        </div>
      </div>

      <!-- Activities by Category -->
      <div class="activities-by-category">
        <div
          v-for="cat in categories"
          :key="cat"
          class="category-column"
        >
          <div class="category-header" :class="cat.toLowerCase()">
            <span class="category-icon">{{ getCategoryIcon(cat) }}</span>
            <span class="category-name">{{ cat }}</span>
            <span class="activity-count">
              {{ getCategoryActivities(cat, true).filter(a => a.completed_at).length }}/{{ getCategoryActivities(cat, true).length }}
            </span>
          </div>

          <div class="category-activities">
            <!-- Level 2 Activities -->
            <div class="level-section">
              <div class="level-label">Level 2</div>
              <ActivityCard
                v-for="activity in getCategoryActivities(cat, true).filter(a => a.activities.level === 'Level 2')"
                :key="activity.id"
                :activity="activity"
                :student="student"
                :is-assigned="true"
                @click="viewActivityDetail(activity)"
                @remove="removeActivity(activity)"
              />
              <div v-if="getCategoryActivities(cat, true).filter(a => a.activities.level === 'Level 2').length === 0" class="empty-level">
                No Level 2 activities
              </div>
            </div>

            <!-- Level 3 Activities -->
            <div class="level-section">
              <div class="level-label">Level 3</div>
              <ActivityCard
                v-for="activity in getCategoryActivities(cat, true).filter(a => a.activities.level === 'Level 3')"
                :key="activity.id"
                :activity="activity"
                :student="student"
                :is-assigned="true"
                @click="viewActivityDetail(activity)"
                @remove="removeActivity(activity)"
              />
              <div v-if="getCategoryActivities(cat, true).filter(a => a.activities.level === 'Level 3').length === 0" class="empty-level">
                No Level 3 activities
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Assign Activities Modal -->
    <AssignModal
      v-if="showAssignModal"
      :student="student"
      :staff-context="staffContext"
      @close="showAssignModal = false"
      @assigned="handleAssigned"
    />

    <!-- Activity Detail Modal -->
    <ActivityDetailModal
      v-if="selectedActivity"
      :activity="selectedActivity"
      :student="student"
      :staff-context="staffContext"
      @close="selectedActivity = null"
      @feedback-saved="handleFeedbackSaved"
      @status-changed="handleStatusChanged"
    />
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import ActivityCard from './ActivityCard.vue';
import AssignModal from './AssignModal.vue';
import ActivityDetailModal from './ActivityDetailModal.vue';
import { useActivities } from '../composables/useActivities';
import { useAuth } from '../composables/useAuth';

// Props
const props = defineProps({
  student: {
    type: Object,
    required: true
  },
  staffContext: {
    type: Object,
    required: true
  }
});

// Emits
const emit = defineEmits(['back', 'refresh']);

// Composables
const { removeActivity: removeActivityAPI } = useActivities();
const { getStaffEmail } = useAuth();

// State
const searchTerm = ref('');
const showAssignModal = ref(false);
const selectedActivity = ref(null);

// Constants
const categories = ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude'];

// Computed
const assignedActivities = computed(() => {
  return props.student.activity_responses?.filter(r => r.status !== 'removed') || [];
});

const filteredAssignedActivities = computed(() => {
  if (!searchTerm.value) return assignedActivities.value;
  
  const term = searchTerm.value.toLowerCase();
  return assignedActivities.value.filter(a =>
    a.activities?.name?.toLowerCase().includes(term)
  );
});

// Methods
const getCategoryIcon = (category) => {
  const icons = {
    'Vision': '👁️',
    'Effort': '💪',
    'Systems': '⚙️',
    'Practice': '🎯',
    'Attitude': '❤️'
  };
  return icons[category] || category[0];
};

const getCategoryActivities = (category, assigned = true) => {
  const activities = assigned ? filteredAssignedActivities.value : [];
  return activities.filter(a => a.activities?.vespa_category === category);
};

const viewActivityDetail = (activity) => {
  console.log('🖱️ Activity card clicked:', activity.activities?.name);
  selectedActivity.value = activity;
};

const removeActivity = async (activity) => {
  if (!confirm(`Remove "${activity.activities.name}" from ${props.student.full_name}?`)) {
    return;
  }

  try {
    await removeActivityAPI(
      activity.student_email,
      activity.activity_id,
      activity.cycle_number,
      getStaffEmail()
    );

    emit('refresh');

  } catch (error) {
    console.error('Failed to remove activity:', error);
    alert('Failed to remove activity. Please try again.');
  }
};

const handleAssigned = () => {
  showAssignModal.value = false;
  emit('refresh');
};

const handleFeedbackSaved = () => {
  selectedActivity.value = null;
  emit('refresh');
};

const handleStatusChanged = () => {
  selectedActivity.value = null;
  emit('refresh');
};
</script>

<style scoped>
.student-workspace {
  min-height: 100vh;
  background: #f8f9fa;
  padding: 20px;
}

.workspace-header {
  background: white;
  border-radius: 12px;
  padding: 20px 24px;
  margin-bottom: 24px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  display: flex;
  align-items: center;
  gap: 20px;
}

.student-info {
  flex: 1;
}

.student-name {
  font-size: 24px;
  font-weight: 600;
  color: #23356f;
  margin: 0 0 8px 0;
}

.student-meta {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.meta-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 12px;
  background: #f8f9fa;
  border-radius: 16px;
  font-size: 13px;
  color: #495057;
}

.meta-badge i {
  color: #079baa;
}

.progress-badge {
  background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
  color: #15803d;
  font-weight: 600;
}

.header-actions {
  display: flex;
  gap: 12px;
  align-items: center;
}

.search-input-compact {
  padding: 8px 12px;
  border: 1px solid #dee2e6;
  border-radius: 6px;
  font-size: 14px;
  width: 200px;
}

.workspace-content {
  background: white;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding-bottom: 16px;
  border-bottom: 2px solid #f1f5f9;
}

.section-header h3 {
  font-size: 18px;
  font-weight: 600;
  color: #23356f;
  margin: 0;
  display: flex;
  align-items: center;
  gap: 10px;
}

.legend {
  display: flex;
  gap: 16px;
  font-size: 12px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 6px;
  color: #6c757d;
}

.source-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  border: 2px solid white;
  box-shadow: 0 1px 3px rgba(0,0,0,0.2);
}

.source-dot.questionnaire {
  background: #1e7e34;
}

.source-dot.staff {
  background: #6f42c1;
}

.source-dot.student {
  background: #007bff;
}

.source-dot.feedback {
  background: #dc3545;
}

.activities-by-category {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 16px;
}

.category-column {
  background: #f8f9fa;
  border-radius: 8px;
  overflow: hidden;
}

.category-header {
  padding: 12px;
  color: white;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: space-between;
}

.category-header.vision {
  background: linear-gradient(135deg, #ff8f00 0%, #f57c00 100%);
}

.category-header.effort {
  background: linear-gradient(135deg, #86b4f0 0%, #5e9de8 100%);
}

.category-header.systems {
  background: linear-gradient(135deg, #84cc16 0%, #65a30d 100%);
}

.category-header.practice {
  background: linear-gradient(135deg, #7f31a4 0%, #6b2589 100%);
}

.category-header.attitude {
  background: linear-gradient(135deg, #f032e6 0%, #d91ad9 100%);
}

.category-icon {
  width: 28px;
  height: 28px;
  background: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
}

.activity-count {
  padding: 2px 8px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 12px;
  font-size: 12px;
}

.category-activities {
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-height: 200px;
  max-height: 600px;
  overflow-y: auto;
}

.level-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.level-label {
  font-size: 11px;
  font-weight: 600;
  color: #6c757d;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  padding: 4px 8px;
  background: white;
  border-radius: 4px;
}

.empty-level {
  padding: 16px;
  text-align: center;
  color: #94a3b8;
  font-size: 13px;
  font-style: italic;
  background: white;
  border-radius: 6px;
  border: 1px dashed #cbd5e1;
}

/* Scrollbar styling */
.category-activities::-webkit-scrollbar {
  width: 6px;
}

.category-activities::-webkit-scrollbar-track {
  background: #f1f5f9;
}

.category-activities::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 3px;
}

.category-activities::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

/* Responsive */
@media (max-width: 1400px) {
  .activities-by-category {
    grid-template-columns: repeat(3, 1fr);
  }
}

@media (max-width: 900px) {
  .activities-by-category {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 600px) {
  .activities-by-category {
    grid-template-columns: 1fr;
  }
  
  .workspace-header {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .header-actions {
    width: 100%;
    flex-direction: column;
  }
  
  .search-input-compact {
    width: 100%;
  }
}
</style>

