<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal">
      <div class="modal-header">
        <h3 class="modal-title">
          <i class="fas fa-plus-circle"></i>
          Assign Activities to {{ student.full_name }}
        </h3>
        <button class="modal-close" @click="$emit('close')">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="modal-body">
        <!-- Filters -->
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

          <button class="btn btn-sm btn-secondary" @click="clearActivityFilters">
            <i class="fas fa-times"></i> Clear
          </button>
        </div>

        <!-- Selection Summary -->
        <div v-if="selectedActivities.size > 0" class="selection-summary">
          <span>{{ selectedActivities.size }} activity(ies) selected</span>
          <button class="btn btn-sm btn-secondary" @click="clearSelection">
            Clear Selection
          </button>
        </div>

        <!-- Loading -->
        <div v-if="isLoadingActivities" class="loading-state">
          <div class="spinner"></div>
          <p>Loading activities...</p>
        </div>

        <!-- Compact Activities Grid (4 columns, very compact like v2) -->
        <div v-else class="activities-compact-grid">
          <div
            v-for="activity in filteredActivities"
            :key="activity.id"
            :class="['compact-activity-card-selectable', activity.vespa_category.toLowerCase(), { 
              'selected': selectedActivities.has(activity.id),
              'already-assigned': isAlreadyAssigned(activity.id)
            }]"
            @click="toggleActivity(activity.id)"
            :title="activity.name"
          >
            <div class="card-check">
              <input
                type="checkbox"
                :checked="selectedActivities.has(activity.id)"
                :disabled="isAlreadyAssigned(activity.id)"
                @click.stop
                @change="toggleActivity(activity.id)"
              />
            </div>
            <div class="card-content-compact">
              <div class="activity-name-compact">{{ activity.name }}</div>
              <div class="activity-meta-compact">
                <span class="level-mini">{{ activity.level?.replace('Level ', 'L') }}</span>
                <span v-if="activity.time_minutes" class="time-mini">{{ activity.time_minutes }}m</span>
              </div>
            </div>
            <button
              v-if="!isAlreadyAssigned(activity.id)"
              class="btn-preview-mini"
              @click.stop="previewActivity(activity)"
              title="Preview activity"
            >
              <i class="fas fa-eye"></i>
            </button>
            <span v-else class="assigned-check">✓</span>
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
          @click="confirmAssignment"
          :disabled="selectedActivities.size === 0 || isAssigning"
        >
          <i class="fas fa-check"></i>
          {{ isAssigning ? 'Assigning...' : `Assign ${selectedActivities.size} Activity(ies)` }}
        </button>
      </div>
    </div>

    <!-- Activity Preview Modal -->
    <ActivityPreviewModal
      v-if="previewingActivity"
      :activity="previewingActivity"
      @close="previewingActivity = null"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useActivities } from '../composables/useActivities';
import { useAuth } from '../composables/useAuth';
import ActivityPreviewModal from './ActivityPreviewModal.vue';

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

const emit = defineEmits(['close', 'assigned']);

// Composables
const { allActivities, isLoadingActivities, loadAllActivities, assignActivity } = useActivities();
const { getStaffEmail } = useAuth();

// State
const searchTerm = ref('');
const filterCategory = ref('all');
const filterLevel = ref('all');
const selectedActivities = ref(new Set());
const isAssigning = ref(false);
const previewingActivity = ref(null);

// Constants
const categories = ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude'];

// Computed
const assignedActivityIds = computed(() => {
  return new Set(
    (props.student.activity_responses || [])
      .filter(r => r.status !== 'removed')
      .map(r => r.activity_id)
  );
});

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

const isAlreadyAssigned = (activityId) => {
  return assignedActivityIds.value.has(activityId);
};

const toggleActivity = (activityId) => {
  if (isAlreadyAssigned(activityId)) return;

  if (selectedActivities.value.has(activityId)) {
    selectedActivities.value.delete(activityId);
  } else {
    selectedActivities.value.add(activityId);
  }
};

const clearSelection = () => {
  selectedActivities.value.clear();
};

const clearActivityFilters = () => {
  searchTerm.value = '';
  filterCategory.value = 'all';
  filterLevel.value = 'all';
};

const previewActivity = (activity) => {
  previewingActivity.value = activity;
};

const confirmAssignment = async () => {
  if (selectedActivities.value.size === 0) return;

  isAssigning.value = true;

  try {
    const staffEmail = getStaffEmail();
    const activityIds = Array.from(selectedActivities.value);

    // Assign each activity
    for (const activityId of activityIds) {
      await assignActivity(
        props.student.email,
        activityId,
        staffEmail,
        props.student.current_cycle || 1,
        props.staffContext.schoolId
      );
    }

    alert(`Successfully assigned ${activityIds.length} activity(ies) to ${props.student.full_name}`);
    emit('assigned');

  } catch (error) {
    console.error('Failed to assign activities:', error);
    alert('Failed to assign activities. Please try again.');
  } finally {
    isAssigning.value = false;
  }
};
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal {
  background: white;
  border-radius: 12px;
  width: 90%;
  max-width: 900px;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
}

.modal-header {
  padding: 20px 24px;
  border-bottom: 1px solid #dee2e6;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-title {
  font-size: 20px;
  font-weight: 600;
  color: #212529;
  margin: 0;
  display: flex;
  align-items: center;
  gap: 10px;
}

.modal-close {
  background: none;
  border: none;
  font-size: 24px;
  color: #6c757d;
  cursor: pointer;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  transition: background 0.2s;
}

.modal-close:hover {
  background: #f8f9fa;
}

.modal-body {
  padding: 24px;
  overflow-y: auto;
  flex: 1;
}

.activity-filters {
  display: flex;
  gap: 12px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}

.search-input,
.filter-select {
  padding: 8px 12px;
  border: 1px solid #dee2e6;
  border-radius: 6px;
  font-size: 14px;
}

.search-input {
  flex: 1;
  min-width: 200px;
}

.selection-summary {
  background: #e3f2fd;
  border: 1px solid #90caf9;
  border-radius: 6px;
  padding: 12px;
  margin-bottom: 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  color: #0d47a1;
  font-weight: 500;
}

/* Compact Activity Grid - 4 columns, very small cards */
.activities-compact-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  max-height: 500px;
  overflow-y: auto;
}

@media (max-width: 1200px) {
  .activities-compact-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

@media (max-width: 768px) {
  .activities-compact-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

/* Compact Activity Card - Selectable */
.compact-activity-card-selectable {
  background: white;
  border: 2px solid #dee2e6;
  border-radius: 8px;
  padding: 8px;
  cursor: pointer;
  transition: all 0.2s;
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-height: 100px;
  max-height: 120px;
}

.compact-activity-card-selectable:hover:not(.already-assigned) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  border-color: #079baa;
}

.compact-activity-card-selectable.selected {
  border-color: #079baa;
  background: #e0f2fe;
  box-shadow: 0 2px 8px rgba(7, 155, 170, 0.2);
}

.compact-activity-card-selectable.already-assigned {
  opacity: 0.6;
  cursor: not-allowed;
  background: #f8f9fa;
  border-color: #e9ecef;
}

/* Category-specific border colors */
.compact-activity-card-selectable.vision {
  border-left: 4px solid #ff8f00;
}

.compact-activity-card-selectable.effort {
  border-left: 4px solid #86b4f0;
}

.compact-activity-card-selectable.systems {
  border-left: 4px solid #84cc16;
}

.compact-activity-card-selectable.practice {
  border-left: 4px solid #7f31a4;
}

.compact-activity-card-selectable.attitude {
  border-left: 4px solid #f032e6;
}

.card-check {
  position: absolute;
  top: 6px;
  left: 6px;
  z-index: 2;
}

.card-check input[type="checkbox"] {
  width: 16px;
  height: 16px;
  cursor: pointer;
}

.compact-activity-card-selectable.already-assigned .card-check input {
  cursor: not-allowed;
}

.card-content-compact {
  flex: 1;
  padding-left: 20px;
  overflow: hidden;
}

.activity-name-compact {
  font-size: 12px;
  font-weight: 600;
  color: #212529;
  line-height: 1.3;
  margin-bottom: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.activity-meta-compact {
  display: flex;
  gap: 4px;
  font-size: 10px;
}

.level-mini,
.time-mini {
  padding: 2px 6px;
  border-radius: 8px;
  background: #e9ecef;
  color: #495057;
  font-weight: 600;
}

.btn-preview-mini {
  position: absolute;
  bottom: 6px;
  right: 6px;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  border: 1px solid #079baa;
  background: white;
  color: #079baa;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  font-size: 11px;
}

.btn-preview-mini:hover {
  background: #079baa;
  color: white;
  transform: scale(1.1);
}

.assigned-check {
  position: absolute;
  bottom: 6px;
  right: 6px;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: #28a745;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: bold;
}

/* Scrollbar */
.activities-compact-grid::-webkit-scrollbar {
  width: 8px;
}

.activities-compact-grid::-webkit-scrollbar-track {
  background: #f1f5f9;
}

.activities-compact-grid::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 4px;
}

.activities-compact-grid::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

.modal-footer {
  padding: 16px 24px;
  border-top: 1px solid #dee2e6;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  color: #6c757d;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #f3f3f3;
  border-top: 3px solid #079baa;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.empty-state {
  text-align: center;
  padding: 40px;
  color: #6c757d;
}

.empty-icon {
  font-size: 48px;
  color: #cbd5e1;
  margin-bottom: 16px;
}

/* Button Styles */
.btn {
  padding: 10px 16px;
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

.btn-primary:hover:not(:disabled) {
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

.btn-sm {
  padding: 6px 12px;
  font-size: 13px;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>

