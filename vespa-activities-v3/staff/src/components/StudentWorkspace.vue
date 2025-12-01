<template>
  <div class="student-workspace">
    <!-- Compact Header -->
    <div class="workspace-header-compact">
      <button class="btn btn-secondary" @click="$emit('back')">
        <i class="fas fa-arrow-left"></i> Back to List
      </button>
      
      <div class="student-info-compact">
        <h3>{{ student.full_name }}</h3>
        <span>{{ assignedActivities.length }} activities assigned</span>
      </div>
      
      <div class="header-actions">
        <input
          type="search"
          v-model="searchTerm"
          placeholder="Search activities..."
          class="search-input-compact"
        />
        <button class="btn btn-primary" @click="showAssignModal = true">
          <i class="fas fa-plus"></i> Assign
        </button>
        <button class="btn btn-secondary" @click="$emit('refresh')">
          <i class="fas fa-sync"></i>
        </button>
      </div>
    </div>

    <!-- Main Workspace Content -->
    <div class="workspace-content">
      <!-- Student Activities Section (Top - Fixed Height) -->
      <div class="student-section">
        <div class="section-header-compact">
          <h4>
            <i class="fas fa-clipboard-check"></i>
            Student Activities ({{ assignedActivities.length }})
          </h4>
          <div class="legend-compact">
            <span class="legend-item">
              <span class="source-circle questionnaire"></span>
              Questionnaire
            </span>
            <span class="legend-item">
              <span class="source-circle student"></span>
              Student
            </span>
            <span class="legend-item">
              <span class="source-circle staff"></span>
              Staff
            </span>
            <span class="legend-item">
              <span class="source-circle feedback"></span>
              Feedback
            </span>
          </div>
        </div>
        
        <!-- Activities by Category (5 Columns) -->
        <div class="activities-by-category student">
          <div
            v-for="cat in categories"
            :key="cat"
            class="category-section"
            :class="cat.toLowerCase()"
          >
            <div class="category-main-header" :class="cat.toLowerCase()">
              <span class="cat-icon">{{ getCategoryIcon(cat) }}</span>
              <span>{{ cat }}</span>
              <span class="count">{{ getCategoryActivities(cat, true).length }}</span>
            </div>
            
            <!-- Level 2 & 3 Columns -->
            <div class="level-columns">
              <div class="level-column">
                <div class="level-header">Level 2</div>
                <div 
                  class="column-activities-compact level-2-activities"
                  @drop="onDrop($event, cat, 2, true)"
                  @dragover.prevent
                  @dragenter="$event.currentTarget.classList.add('drag-over')"
                  @dragleave="$event.currentTarget.classList.remove('drag-over')"
                >
                  <ActivityCardCompact
                    v-for="activity in getCategoryActivities(cat, true).filter(a => a.activities?.level === 'Level 2')"
                    :key="activity.id"
                    :activity="activity"
                    :is-assigned="true"
                    :draggable="true"
                    @dragstart="onDragStart($event, activity)"
                    @click="viewActivityDetail(activity)"
                    @remove="removeActivity(activity)"
                  />
                  <div v-if="getCategoryActivities(cat, true).filter(a => a.activities?.level === 'Level 2').length === 0" class="empty-level">
                    No Level 2
                  </div>
                </div>
              </div>
              
              <div class="level-column">
                <div class="level-header">Level 3</div>
                <div 
                  class="column-activities-compact level-3-activities"
                  @drop="onDrop($event, cat, 3, true)"
                  @dragover.prevent
                  @dragenter="$event.currentTarget.classList.add('drag-over')"
                  @dragleave="$event.currentTarget.classList.remove('drag-over')"
                >
                  <ActivityCardCompact
                    v-for="activity in getCategoryActivities(cat, true).filter(a => a.activities?.level === 'Level 3')"
                    :key="activity.id"
                    :activity="activity"
                    :is-assigned="true"
                    :draggable="true"
                    @dragstart="onDragStart($event, activity)"
                    @click="viewActivityDetail(activity)"
                    @remove="removeActivity(activity)"
                  />
                  <div v-if="getCategoryActivities(cat, true).filter(a => a.activities?.level === 'Level 3').length === 0" class="empty-level">
                    No Level 3
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Divider -->
      <div class="section-divider"></div>

      <!-- All Activities Section (Bottom - Scrollable) -->
      <div class="all-section">
        <div class="section-header-compact">
          <h4>
            <i class="fas fa-book"></i>
            All Activities ({{ availableActivities.length }})
          </h4>
        </div>
        
        <!-- Available Activities by Category -->
        <div class="activities-by-category all">
          <div
            v-for="cat in categories"
            :key="cat"
            class="category-section"
            :class="cat.toLowerCase()"
          >
            <div class="category-main-header" :class="cat.toLowerCase()">
              <span class="cat-icon">{{ getCategoryIcon(cat) }}</span>
              <span>{{ cat }}</span>
              <span class="count">{{ getCategoryActivities(cat, false).length }}</span>
            </div>
            
            <!-- Level 2 & 3 Columns -->
            <div class="level-columns">
              <div class="level-column">
                <div class="level-header">Level 2</div>
                <div 
                  class="column-activities-compact level-2-activities"
                  @drop="onDrop($event, cat, 2, false)"
                  @dragover.prevent
                  @dragenter="$event.currentTarget.classList.add('drag-over')"
                  @dragleave="$event.currentTarget.classList.remove('drag-over')"
                >
                  <ActivityCardCompact
                    v-for="activity in getCategoryActivities(cat, false).filter(a => a.level === 'Level 2')"
                    :key="activity.id"
                    :activity="activity"
                    :is-assigned="false"
                    :draggable="true"
                    @dragstart="onDragStart($event, activity)"
                    @click="quickAddActivity(activity)"
                  />
                </div>
              </div>
              
              <div class="level-column">
                <div class="level-header">Level 3</div>
                <div 
                  class="column-activities-compact level-3-activities"
                  @drop="onDrop($event, cat, 3, false)"
                  @dragover.prevent
                  @dragenter="$event.currentTarget.classList.add('drag-over')"
                  @dragleave="$event.currentTarget.classList.remove('drag-over')"
                >
                  <ActivityCardCompact
                    v-for="activity in getCategoryActivities(cat, false).filter(a => a.level === 'Level 3')"
                    :key="activity.id"
                    :activity="activity"
                    :is-assigned="false"
                    :draggable="true"
                    @dragstart="onDragStart($event, activity)"
                    @click="quickAddActivity(activity)"
                  />
                </div>
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
import { ref, computed, onMounted } from 'vue';
import ActivityCardCompact from './ActivityCardCompact.vue';
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
const { 
  allActivities,
  loadAllActivities,
  assignActivity,
  removeActivity: removeActivityAPI 
} = useActivities();
const { getStaffEmail } = useAuth();

// State
const searchTerm = ref('');
const showAssignModal = ref('');
const selectedActivity = ref(null);
const draggedActivity = ref(null);

// Constants
const categories = ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude'];

// Load all activities on mount
onMounted(async () => {
  await loadAllActivities();
});

// Computed
const assignedActivities = computed(() => {
  return props.student.activity_responses?.filter(r => r.status !== 'removed') || [];
});

const assignedActivityIds = computed(() => {
  return new Set(assignedActivities.value.map(a => a.activity_id));
});

const availableActivities = computed(() => {
  let available = allActivities.value.filter(a => !assignedActivityIds.value.has(a.id));
  
  if (searchTerm.value) {
    const term = searchTerm.value.toLowerCase();
    available = available.filter(a =>
      a.name.toLowerCase().includes(term)
    );
  }
  
  return available;
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
  if (assigned) {
    return filteredAssignedActivities.value.filter(a => 
      a.activities?.vespa_category === category
    );
  } else {
    return availableActivities.value.filter(a => 
      a.vespa_category === category
    );
  }
};

// Drag and Drop Handlers
const onDragStart = (event, activity) => {
  draggedActivity.value = activity;
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('text/plain', activity.id);
  event.currentTarget.classList.add('dragging');
};

const onDrop = async (event, category, level, isStudentSection) => {
  event.preventDefault();
  event.currentTarget.classList.remove('drag-over');
  
  if (!draggedActivity.value) return;
  
  const activity = draggedActivity.value;
  
  // If dropping in student section and activity is not assigned yet
  if (isStudentSection && !activity.activity_id) {
    await quickAddActivity(activity);
  }
  
  // If dropping in available section and activity is assigned
  if (!isStudentSection && activity.activity_id) {
    await removeActivity(activity);
  }
  
  draggedActivity.value = null;
};

const viewActivityDetail = (activity) => {
  console.log('🖱️ Activity card clicked:', activity.activities?.name);
  selectedActivity.value = activity;
};

const quickAddActivity = async (activity) => {
  try {
    const activityId = activity.id || activity.activity_id;
    await assignActivity(
      props.student.email,
      activityId,
      getStaffEmail(),
      props.student.current_cycle || 1,
      props.staffContext.schoolId
    );

    emit('refresh');
    console.log('✅ Activity added:', activityId);
  } catch (error) {
    console.error('Failed to add activity:', error);
    alert('Failed to add activity. Please try again.');
  }
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
/* Radical Workspace Design - Based on v2 Staff 8b */
.student-workspace {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: #f8f9fa;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Compact Header */
.workspace-header-compact {
  background: white !important;
  padding: 15px 20px !important;
  margin: 120px 20px 20px 20px !important;
  border-radius: 8px !important;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1) !important;
  display: flex !important;
  align-items: center !important;
  justify-content: space-between !important;
  border: 1px solid #dee2e6 !important;
  position: relative !important;
  z-index: 999998 !important;
  visibility: visible !important;
  opacity: 1 !important;
}

.student-info-compact {
  flex: 1;
  text-align: center;
}

.student-info-compact h3 {
  margin: 0;
  font-size: 18px;
  color: #212529;
}

.student-info-compact span {
  color: #6c757d;
  font-size: 14px;
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

/* Main Content Area */
.workspace-content {
  margin-top: 0;
  padding: 0 16px;
  height: calc(100vh - 220px);
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow: hidden;
}

/* Student Section - Fixed Height */
.student-section {
  flex-shrink: 0;
  height: 280px;
  overflow: visible;
}

/* All Activities Section - Flex */
.all-section {
  flex: 1;
  overflow-y: auto;
  min-height: 300px;
}

.section-header-compact {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
  padding: 8px 12px;
  background: white;
  border-radius: 6px;
}

.section-header-compact h4 {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: #23356f;
  display: flex;
  align-items: center;
  gap: 8px;
}

.legend-compact {
  display: inline-flex;
  gap: 15px;
  font-size: 10px;
  align-items: center;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 4px;
  color: #6c757d;
}

.source-circle {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  border: 2px solid white;
  box-shadow: 0 1px 3px rgba(0,0,0,0.2);
}

.source-circle.questionnaire { background: #1e7e34; }
.source-circle.staff { background: #6f42c1; }
.source-circle.student { background: #007bff; }
.source-circle.feedback { background: #dc3545; }

/* Activities by Category Grid */
.activities-by-category {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 12px;
}

/* Category Sections */
.category-section {
  display: flex;
  flex-direction: column;
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

/* Category Headers */
.category-main-header {
  padding: 8px;
  background: white;
  border-bottom: 3px solid;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 12px;
  font-weight: 600;
  color: white;
}

.category-main-header.vision {
  background: linear-gradient(135deg, #ff8f00, #f57c00);
  border-bottom-color: #ff8f00;
}

.category-main-header.effort {
  background: linear-gradient(135deg, #86b4f0, #5e9de8);
  border-bottom-color: #86b4f0;
}

.category-main-header.systems {
  background: linear-gradient(135deg, #84cc16, #65a30d);
  border-bottom-color: #84cc16;
}

.category-main-header.practice {
  background: linear-gradient(135deg, #7f31a4, #6b2589);
  border-bottom-color: #7f31a4;
}

.category-main-header.attitude {
  background: linear-gradient(135deg, #f032e6, #d91ad9);
  border-bottom-color: #f032e6;
}

.cat-icon {
  font-size: 16px;
}

.count {
  padding: 2px 6px;
  background: rgba(255,255,255,0.2);
  border-radius: 10px;
  font-size: 11px;
}

/* Level Columns */
.level-columns {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0;
  flex: 1;
}

.level-column {
  border-right: 1px solid #e0e0e0;
  display: flex;
  flex-direction: column;
}

.level-column:last-child {
  border-right: none;
}

.level-header {
  background: #f8f9fa;
  padding: 4px 8px;
  font-weight: 600;
  font-size: 11px;
  color: #495057;
  text-align: center;
  border-bottom: 1px solid #e0e0e0;
}

/* Column Activities Container */
.column-activities-compact {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-height: 100px;
}

.student-section .column-activities-compact {
  height: 160px;
  max-height: 160px;
}

.all-section .column-activities-compact {
  min-height: 200px;
}

.column-activities-compact.drag-over {
  background: #e0f2fe;
  border: 2px dashed #079baa;
  border-radius: 4px;
}

.empty-level {
  padding: 16px;
  text-align: center;
  color: #94a3b8;
  font-size: 11px;
  font-style: italic;
}

.section-divider {
  height: 2px;
  background: #d0d5db;
  margin: 8px 0;
}

/* Scrollbar Styling */
.column-activities-compact::-webkit-scrollbar {
  width: 4px;
}

.column-activities-compact::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 2px;
}

.column-activities-compact::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 2px;
}

.column-activities-compact::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

/* Dragging State */
:deep(.dragging) {
  opacity: 0.5;
  transform: rotate(2deg);
}

/* Responsive Adjustments */
@media (max-width: 1400px) {
  .activities-by-category {
    grid-template-columns: repeat(5, 1fr);
    gap: 8px;
  }
}

@media (max-width: 1200px) {
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
  
  .workspace-header-compact {
    flex-direction: column;
    gap: 12px;
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

/* Buttons */
.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.btn-primary {
  background: linear-gradient(135deg, #079baa 0%, #057a87 100%);
  color: white;
}

.btn-primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(7, 155, 170, 0.3);
}

.btn-secondary {
  background: white;
  color: #079baa;
  border: 1px solid #079baa;
}

.btn-secondary:hover {
  background: #f0f9ff;
}
</style>
