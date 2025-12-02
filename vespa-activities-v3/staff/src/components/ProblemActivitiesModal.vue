<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal modal-large">
      <div class="modal-header">
        <div>
          <h2 class="modal-title">
            <i class="fas fa-lightbulb"></i>
            Recommended Activities
          </h2>
          <p class="problem-context">
            For: <strong>"{{ problem.text }}"</strong>
          </p>
        </div>
        <button class="modal-close" @click="$emit('close')">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="modal-body">
        <div v-if="activities.length > 0" class="activities-selection">
          <div class="selection-header">
            <p>Select activities to assign to {{ student.full_name }}:</p>
            <button class="btn btn-sm" @click="toggleSelectAll">
              {{ allSelected ? 'Deselect All' : 'Select All' }}
            </button>
          </div>

          <div class="activities-grid">
            <div
              v-for="activity in activities"
              :key="activity.id"
              :class="['activity-card-select', (activity.vespa_category || '').toLowerCase(), { 'selected': selectedIds.has(activity.id) }]"
              @click="toggleActivity(activity.id)"
            >
              <input
                type="checkbox"
                :checked="selectedIds.has(activity.id)"
                @click.stop="toggleActivity(activity.id)"
              />
              <div class="activity-info">
                <div class="activity-name">{{ activity.name }}</div>
                <div class="activity-meta">
                  <span :class="['category-badge', (activity.vespa_category || '').toLowerCase()]">
                    {{ activity.vespa_category || 'General' }}
                  </span>
                  <span class="level-badge">{{ activity.level || 'Level 2' }}</span>
                  <span v-if="activity.time_minutes" class="time-badge">
                    {{ activity.time_minutes }} min
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div v-else class="empty-state">
          <i class="fas fa-inbox"></i>
          <p>No activities found for this problem</p>
        </div>
      </div>

      <div class="modal-footer">
        <div class="footer-left">
          <span class="selection-count">{{ selectedIds.size }} activities selected</span>
        </div>
        <div class="footer-right">
          <button class="btn btn-secondary" @click="$emit('close')">
            Cancel
          </button>
          <button
            class="btn btn-success"
            @click="assignActivities('add')"
            :disabled="selectedIds.size === 0 || isAssigning"
            title="Add to existing activities"
          >
            <i class="fas fa-plus"></i>
            {{ isAssigning ? 'Adding...' : 'Add to Current' }}
          </button>
          <button
            class="btn btn-warning"
            @click="assignActivities('replace')"
            :disabled="selectedIds.size === 0 || isAssigning"
            title="Replace all existing activities"
          >
            <i class="fas fa-sync"></i>
            {{ isAssigning ? 'Replacing...' : 'Replace All' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useActivities } from '../composables/useActivities';
import { useAuth } from '../composables/useAuth';

const props = defineProps({
  problem: {
    type: Object,
    required: true
  },
  activities: {
    type: Array,
    required: true
  },
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

const { assignActivity } = useActivities();
const { getStaffEmail } = useAuth();

const selectedIds = ref(new Set(props.activities.map(a => a.id))); // Select all by default
const isAssigning = ref(false);

const allSelected = computed(() => {
  return props.activities.length > 0 && selectedIds.value.size === props.activities.length;
});

const toggleActivity = (activityId) => {
  if (selectedIds.value.has(activityId)) {
    selectedIds.value.delete(activityId);
  } else {
    selectedIds.value.add(activityId);
  }
  // Force reactivity
  selectedIds.value = new Set(selectedIds.value);
};

const toggleSelectAll = () => {
  if (allSelected.value) {
    selectedIds.value.clear();
  } else {
    selectedIds.value = new Set(props.activities.map(a => a.id));
  }
  selectedIds.value = new Set(selectedIds.value);
};

const assignActivities = async (mode = 'add') => {
  if (selectedIds.value.size === 0) return;

  // Confirm if replacing all
  if (mode === 'replace') {
    const confirmed = confirm(
      `⚠️ Replace ALL current activities?\n\n` +
      `This will remove all ${props.student.full_name}'s existing activities\n` +
      `and assign ${selectedIds.value.size} new ones.\n\n` +
      `Current activities will be marked as 'removed' (data preserved).\n\n` +
      `Continue?`
    );
    if (!confirmed) return;
  }

  isAssigning.value = true;

  try {
    console.log(`${mode === 'replace' ? '🔄 Replacing' : '➕ Adding'} ${selectedIds.value.size} activities`);
    
    let assigned = 0;
    for (const activityId of selectedIds.value) {
      try {
        await assignActivity(
          props.student.email,
          activityId,
          getStaffEmail(),
          props.student.current_cycle || 1,
          props.staffContext.schoolId
        );
        assigned++;
        console.log(`✅ Assigned activity ${assigned}/${selectedIds.value.size}`);
      } catch (error) {
        console.error('❌ Failed to assign activity:', activityId, error);
      }
    }

    const message = mode === 'replace' ? 
      `Replaced all activities with ${assigned} new activities` :
      `Added ${assigned} activities to current assignments`;
    
    alert(`✅ Success!\n\n${message}`);
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
.modal-large {
  max-width: 1100px;
  width: 95%;
  max-height: 90vh;
}

.problem-context {
  margin: 8px 0 0 0;
  font-size: 14px;
  color: #495057;
  font-weight: normal;
}

.problem-context strong {
  color: #079baa;
}

.selection-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 12px 16px;
  background: #f8f9fa;
  border-radius: 8px;
}

.selection-header p {
  margin: 0;
  font-size: 14px;
  color: #495057;
}

.activities-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 12px;
  max-height: 500px;
  overflow-y: auto;
  padding: 4px;
}

.activity-card-select {
  background: white;
  border: 2px solid #dee2e6;
  border-radius: 8px;
  padding: 12px;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.activity-card-select:hover {
  border-color: #079baa;
  box-shadow: 0 4px 8px rgba(7, 155, 170, 0.15);
  transform: translateY(-2px);
}

.activity-card-select.selected {
  border-color: #079baa;
  background: #e0f7fa;
}

.activity-card-select input[type="checkbox"] {
  margin-top: 2px;
  cursor: pointer;
}

.activity-info {
  flex: 1;
}

.activity-name {
  font-weight: 600;
  font-size: 14px;
  color: #212529;
  margin-bottom: 6px;
}

.activity-meta {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.category-badge,
.level-badge,
.time-badge {
  font-size: 11px;
  padding: 3px 8px;
  border-radius: 12px;
  font-weight: 600;
}

.category-badge {
  color: white;
}

.category-badge.vision { background: #ff8f00; }
.category-badge.effort { background: #86b4f0; }
.category-badge.systems { background: #84cc16; }
.category-badge.practice { background: #7f31a4; }
.category-badge.attitude { background: #f032e6; }

.level-badge {
  background: #e9ecef;
  color: #495057;
}

.time-badge {
  background: #fff3cd;
  color: #856404;
}

.footer-left {
  display: flex;
  align-items: center;
}

.selection-count {
  font-size: 14px;
  color: #495057;
  font-weight: 600;
}

.footer-right {
  display: flex;
  gap: 10px;
}

.btn-success {
  background: #28a745;
  color: white;
}

.btn-success:hover:not(:disabled) {
  background: #218838;
}

.btn-success:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-warning:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #6c757d;
}

.empty-state i {
  font-size: 48px;
  margin-bottom: 16px;
  opacity: 0.3;
}
</style>

