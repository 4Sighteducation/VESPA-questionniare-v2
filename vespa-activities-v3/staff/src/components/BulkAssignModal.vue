<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal">
      <div class="modal-header">
        <h3 class="modal-title">
          <i class="fas fa-users"></i>
          Bulk Assign Activities to {{ selectedStudents.length }} Student{{ selectedStudents.length !== 1 ? 's' : '' }}
        </h3>
        <button class="modal-close" @click="$emit('close')">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="modal-body">
        <!-- Student List -->
        <div class="selected-students-list">
          <h4>Selected Students:</h4>
          <div class="student-chips">
            <span
              v-for="studentId in selectedStudents"
              :key="studentId"
              class="student-chip"
            >
              {{ getStudentName(studentId) }}
            </span>
          </div>
        </div>

        <!-- Activity Filters -->
        <div class="activity-filters">
          <input
            type="search"
            v-model="searchTerm"
            placeholder="Search activities..."
            class="search-input"
          />
          
          <select v-model="filterCategory" class="filter-select">
            <option value="all">All Categories</option>
            <option v-for="cat in categories" :key="cat" :value="cat">{{ cat }}</option>
          </select>
          
          <select v-model="filterLevel" class="filter-select">
            <option value="all">All Levels</option>
            <option value="Level 2">Level 2</option>
            <option value="Level 3">Level 3</option>
          </select>
        </div>

        <!-- Selection Summary -->
        <div v-if="selectedActivities.size > 0" class="selection-summary">
          <span>
            <i class="fas fa-check-circle"></i>
            {{ selectedActivities.size }} activity(ies) selected
          </span>
          <button class="btn btn-sm btn-secondary" @click="clearSelection">
            Clear Selection
          </button>
        </div>

        <!-- Loading -->
        <div v-if="isLoadingActivities" class="loading-state">
          <div class="spinner"></div>
          <p>Loading activities...</p>
        </div>

        <!-- Activities List -->
        <div v-else class="activities-grid">
          <div
            v-for="activity in filteredActivities"
            :key="activity.id"
            :class="['activity-item', { 'selected': selectedActivities.has(activity.id) }]"
            @click="toggleActivity(activity.id)"
          >
            <input
              type="checkbox"
              :checked="selectedActivities.has(activity.id)"
              @click.stop
              @change="toggleActivity(activity.id)"
            />
            
            <div class="activity-info">
              <h4 class="activity-name">{{ activity.name }}</h4>
              <div class="activity-badges">
                <span :class="['category-badge', activity.vespa_category.toLowerCase()]">
                  {{ activity.vespa_category }}
                </span>
                <span class="level-badge">{{ activity.level }}</span>
                <span v-if="activity.time_minutes" class="time-badge">
                  <i class="fas fa-clock"></i> {{ activity.time_minutes }}m
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Empty State -->
        <div v-if="!isLoadingActivities && filteredActivities.length === 0" class="empty-state">
          <i class="fas fa-search empty-icon"></i>
          <p>No activities found matching your filters</p>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" @click="$emit('close')">
          Cancel
        </button>
        <button
          class="btn btn-primary"
          @click="confirmBulkAssignment"
          :disabled="selectedActivities.size === 0 || isAssigning"
        >
          <i class="fas fa-check"></i>
          {{ isAssigning ? 'Assigning...' : `Assign to ${selectedStudents.length} Students` }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useActivities } from '../composables/useActivities';
import { useAuth } from '../composables/useAuth';

const props = defineProps({
  selectedStudents: {
    type: Array,
    required: true
  },
  students: {
    type: Array,
    required: true
  },
  staffContext: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'assigned']);

// Composables
const { allActivities, isLoadingActivities, loadAllActivities, bulkAssignActivities } = useActivities();
const { getStaffEmail } = useAuth();

// State
const searchTerm = ref('');
const filterCategory = ref('all');
const filterLevel = ref('all');
const selectedActivities = ref(new Set());
const isAssigning = ref(false);

// Constants
const categories = ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude'];

// Computed
const filteredActivities = computed(() => {
  let filtered = allActivities.value;

  if (searchTerm.value) {
    const term = searchTerm.value.toLowerCase();
    filtered = filtered.filter(a =>
      a.name.toLowerCase().includes(term) ||
      a.curriculum_tags?.some(tag => tag.toLowerCase().includes(term))
    );
  }

  if (filterCategory.value !== 'all') {
    filtered = filtered.filter(a => a.vespa_category === filterCategory.value);
  }

  if (filterLevel.value !== 'all') {
    filtered = filtered.filter(a => a.level === filterLevel.value);
  }

  return filtered;
});

// Methods
onMounted(async () => {
  await loadAllActivities();
});

const getStudentName = (studentId) => {
  const student = props.students.find(s => s.id === studentId);
  return student?.full_name || 'Unknown Student';
};

const toggleActivity = (activityId) => {
  if (selectedActivities.value.has(activityId)) {
    selectedActivities.value.delete(activityId);
  } else {
    selectedActivities.value.add(activityId);
  }
};

const clearSelection = () => {
  selectedActivities.value.clear();
};

const confirmBulkAssignment = async () => {
  if (selectedActivities.value.size === 0) return;

  if (!confirm(`Assign ${selectedActivities.value.size} activities to ${props.selectedStudents.length} students?`)) {
    return;
  }

  isAssigning.value = true;

  try {
    const staffEmail = getStaffEmail();
    const activityIds = Array.from(selectedActivities.value);
    const studentEmails = props.selectedStudents.map(id => {
      const student = props.students.find(s => s.id === id);
      return student?.email;
    }).filter(Boolean);

    await bulkAssignActivities(studentEmails, activityIds, staffEmail, props.staffContext.schoolId);

    alert(`Successfully assigned ${activityIds.length} activities to ${studentEmails.length} students!`);
    emit('assigned');

  } catch (error) {
    console.error('Failed to bulk assign:', error);
    alert('Failed to assign activities. Please try again.');
  } finally {
    isAssigning.value = false;
  }
};
</script>

<style scoped>
/* Inherits styles from AssignModal */
.selected-students-list {
  background: #f8f9fa;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 20px;
}

.selected-students-list h4 {
  margin: 0 0 12px 0;
  font-size: 14px;
  font-weight: 600;
  color: #495057;
}

.student-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.student-chip {
  padding: 4px 12px;
  background: white;
  border: 1px solid #dee2e6;
  border-radius: 16px;
  font-size: 12px;
  color: #495057;
}
</style>

