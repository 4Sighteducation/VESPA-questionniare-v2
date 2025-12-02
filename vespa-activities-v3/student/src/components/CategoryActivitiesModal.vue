<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal modal-large">
      <div class="modal-header" :style="{ background: categoryGradient }">
        <div class="header-content">
          <span class="category-emoji">{{ categoryEmoji }}</span>
          <div class="header-text">
            <h2 class="modal-title">{{ categoryName }} Activities</h2>
            <p class="modal-subtitle">
              Improve your {{ categoryName }} score with these activities
            </p>
          </div>
        </div>
        <button class="modal-close" @click="$emit('close')">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="modal-body">
        <div v-if="loading" class="loading">
          <div class="spinner"></div>
          <p>Loading activities...</p>
        </div>
        
        <div v-else-if="activities.length === 0" class="empty-state">
          <span class="empty-icon">📭</span>
          <h3>No activities available</h3>
          <p>There are no {{ categoryName }} activities to show right now.</p>
        </div>
        
        <div v-else class="activities-grid">
          <div
            v-for="activity in activities"
            :key="activity.id"
            :class="['activity-item', { selected: selectedActivities.has(activity.id), completed: isCompleted(activity.id) }]"
            @click="toggleActivity(activity)"
          >
            <div class="activity-checkbox">
              <input 
                type="checkbox" 
                :checked="selectedActivities.has(activity.id)"
                @click.stop
                :disabled="isCompleted(activity.id)"
              />
            </div>
            <div class="activity-info">
              <h4 class="activity-name">{{ activity.name }}</h4>
              <div class="activity-meta">
                <span class="meta-badge level">{{ activity.level }}</span>
                <span class="meta-badge time">⏱️ {{ activity.time_minutes || 30 }} min</span>
                <span class="meta-badge points">+{{ activity.level === 'Level 3' ? 15 : 10 }} pts</span>
              </div>
            </div>
            <div v-if="isCompleted(activity.id)" class="completed-badge">
              ✓ Done
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <div class="footer-left">
          <span class="selection-count">
            {{ selectedActivities.size }} activit{{ selectedActivities.size === 1 ? 'y' : 'ies' }} selected
          </span>
        </div>
        <div class="footer-right">
          <button class="btn btn-secondary" @click="$emit('close')">
            Cancel
          </button>
          <button 
            class="btn btn-primary" 
            :style="{ background: categoryColor }"
            @click="addSelectedToMyActivities"
            :disabled="selectedActivities.size === 0"
          >
            <i class="fas fa-plus"></i>
            Add {{ selectedActivities.size || '' }} to My Activities
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import supabase from '../../shared/supabaseClient';
import { CATEGORY_COLORS } from '../../shared/constants';

const props = defineProps({
  category: {
    type: String,
    required: true
  },
  completedActivityIds: {
    type: Array,
    default: () => []
  },
  assignedActivityIds: {
    type: Array,
    default: () => []
  }
});

const emit = defineEmits(['close', 'add-activities']);

const loading = ref(false);
const activities = ref([]);
const selectedActivities = ref(new Set());

const categoryName = computed(() => {
  return props.category.charAt(0).toUpperCase() + props.category.slice(1);
});

const categoryColor = computed(() => {
  return CATEGORY_COLORS[categoryName.value] || '#079baa';
});

const categoryGradient = computed(() => {
  const color = categoryColor.value;
  return `linear-gradient(135deg, ${color}, ${adjustColor(color, -20)})`;
});

const categoryEmojis = {
  'Vision': '👁️',
  'Effort': '💪',
  'Systems': '⚙️',
  'Practice': '🎯',
  'Attitude': '🧠'
};

const categoryEmoji = computed(() => {
  return categoryEmojis[categoryName.value] || '📚';
});

// Helper to darken color
const adjustColor = (color, amount) => {
  const clamp = (val) => Math.min(255, Math.max(0, val));
  const hex = color.replace('#', '');
  const r = clamp(parseInt(hex.slice(0, 2), 16) + amount);
  const g = clamp(parseInt(hex.slice(2, 4), 16) + amount);
  const b = clamp(parseInt(hex.slice(4, 6), 16) + amount);
  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
};

const isCompleted = (activityId) => {
  return props.completedActivityIds.includes(activityId);
};

const isAssigned = (activityId) => {
  return props.assignedActivityIds.includes(activityId);
};

const toggleActivity = (activity) => {
  if (isCompleted(activity.id)) return; // Don't toggle completed activities
  
  if (selectedActivities.value.has(activity.id)) {
    selectedActivities.value.delete(activity.id);
  } else {
    selectedActivities.value.add(activity.id);
  }
  // Trigger reactivity
  selectedActivities.value = new Set(selectedActivities.value);
};

const addSelectedToMyActivities = () => {
  const selected = activities.value.filter(a => selectedActivities.value.has(a.id));
  emit('add-activities', selected);
};

onMounted(async () => {
  loading.value = true;
  try {
    console.log(`📚 Loading ${categoryName.value} activities...`);
    
    // Query activities for this category only
    const { data, error } = await supabase
      .from('activities')
      .select('*')
      .eq('vespa_category', categoryName.value)
      .eq('is_active', true)
      .order('level, display_order, name');
    
    if (error) throw error;
    
    activities.value = data || [];
    console.log(`✅ Loaded ${activities.value.length} ${categoryName.value} activities`);
    
  } catch (err) {
    console.error('Failed to load category activities:', err);
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.modal-large {
  max-width: 800px;
  width: 95%;
  max-height: 85vh;
  display: flex;
  flex-direction: column;
}

.modal-header {
  padding: 24px;
  color: white;
  border-radius: 12px 12px 0 0;
  position: relative;
}

.header-content {
  display: flex;
  align-items: center;
  gap: 16px;
}

.category-emoji {
  font-size: 48px;
  filter: drop-shadow(0 2px 4px rgba(0,0,0,0.2));
}

.header-text {
  flex: 1;
}

.modal-title {
  margin: 0 0 4px 0;
  font-size: 24px;
  font-weight: 700;
}

.modal-subtitle {
  margin: 0;
  opacity: 0.9;
  font-size: 14px;
}

.modal-close {
  position: absolute;
  top: 16px;
  right: 16px;
  background: rgba(255,255,255,0.2);
  border: none;
  color: white;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  transition: all 0.2s;
}

.modal-close:hover {
  background: rgba(255,255,255,0.3);
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
}

.loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 48px;
  color: #6c757d;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #e9ecef;
  border-top-color: #079baa;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.empty-state {
  text-align: center;
  padding: 48px;
  color: #6c757d;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
  display: block;
}

.activities-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.activity-item {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  background: white;
  border: 2px solid #e9ecef;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.activity-item:hover:not(.completed) {
  border-color: #079baa;
  background: #f8f9fa;
}

.activity-item.selected {
  border-color: #079baa;
  background: rgba(7, 155, 170, 0.05);
}

.activity-item.completed {
  opacity: 0.6;
  cursor: not-allowed;
  background: #f8f9fa;
}

.activity-checkbox input {
  width: 20px;
  height: 20px;
  cursor: pointer;
}

.activity-checkbox input:disabled {
  cursor: not-allowed;
}

.activity-info {
  flex: 1;
}

.activity-name {
  margin: 0 0 8px 0;
  font-size: 16px;
  font-weight: 600;
  color: #23356f;
}

.activity-meta {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.meta-badge {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;
}

.meta-badge.level {
  background: #e9ecef;
  color: #495057;
}

.meta-badge.time {
  background: #e3f2fd;
  color: #1565c0;
}

.meta-badge.points {
  background: #e8f5e9;
  color: #2e7d32;
}

.completed-badge {
  background: #72cb44;
  color: white;
  padding: 6px 12px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
}

.modal-footer {
  padding: 16px 24px;
  border-top: 1px solid #e9ecef;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
}

.selection-count {
  color: #6c757d;
  font-size: 14px;
}

.footer-right {
  display: flex;
  gap: 12px;
}

.btn {
  padding: 10px 20px;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 8px;
}

.btn-secondary {
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
  color: #475569;
}

.btn-secondary:hover {
  background: #e2e8f0;
}

.btn-primary {
  background: #079baa;
  border: none;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  filter: brightness(1.1);
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .modal-large {
    max-width: 100%;
    width: 100%;
    height: 100%;
    max-height: 100vh;
    border-radius: 0;
  }
  
  .modal-header {
    border-radius: 0;
  }
  
  .category-emoji {
    font-size: 36px;
  }
  
  .modal-title {
    font-size: 20px;
  }
  
  .activity-item {
    padding: 12px;
  }
  
  .modal-footer {
    flex-direction: column;
  }
  
  .footer-right {
    width: 100%;
    flex-direction: column;
  }
  
  .btn {
    width: 100%;
    justify-content: center;
  }
}
</style>

