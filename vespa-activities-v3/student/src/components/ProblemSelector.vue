<template>
  <div class="problem-selector">
    <p class="selector-description">
      Select a problem you're facing, and we'll recommend activities to help:
    </p>
    
    <div v-if="loading" class="loading">
      <div class="spinner"></div>
      <p>Loading problems...</p>
    </div>
    
    <div v-else-if="error" class="error">
      <p>{{ error }}</p>
      <button @click="loadProblemMappings" class="btn btn-outline">Retry</button>
    </div>
    
    <div v-else class="problems-grid">
      <div
        v-for="category in categories"
        :key="category"
        class="category-group"
      >
        <h4 class="category-title" :style="{ color: categoryColors[category] }">
          {{ category }}
        </h4>
        <div class="problems-list">
          <button
            v-for="problem in getProblemsForCategory(category)"
            :key="problem.id"
            @click="selectProblem(problem)"
            class="problem-btn"
          >
            {{ problem.label }}
          </button>
        </div>
      </div>
    </div>
    
    <div v-if="selectedProblemActivities.length > 0" class="selected-activities">
      <h4>Recommended Activities:</h4>
      <div class="activities-list">
        <div
          v-for="activity in selectedProblemActivities"
          :key="activity.id"
          class="activity-item"
        >
          <span class="activity-name">{{ activity.name }}</span>
          <button @click="addActivity(activity)" class="btn btn-sm btn-primary">
            Add to Dashboard
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { VESPA_CATEGORIES, CATEGORY_COLORS, API_BASE_URL, API_ENDPOINTS } from '../../shared/constants';

const emit = defineEmits(['select-activity']);

const loading = ref(false);
const error = ref(null);
const problemMappings = ref(null);
const selectedProblemActivities = ref([]);

const categories = VESPA_CATEGORIES;
const categoryColors = CATEGORY_COLORS;

// Problem definitions (from vespa-problem-activity-mappings1a.json structure)
const problemDefinitions = {
  Vision: [
    { id: 'svision_1', label: "I can't see how school connects to my future" },
    { id: 'svision_2', label: "I don't know what I want to do after school" },
    { id: 'svision_3', label: "I struggle to set goals" },
    { id: 'svision_4', label: "I lack motivation" }
  ],
  Effort: [
    { id: 'seffort_1', label: "I struggle to stay focused" },
    { id: 'seffort_2', label: "I get distracted easily" },
    { id: 'seffort_3', label: "I find it hard to concentrate" }
  ],
  Systems: [
    { id: 'ssystems_1', label: "I'm disorganized" },
    { id: 'ssystems_2', label: "I struggle with time management" },
    { id: 'ssystems_3', label: "I forget deadlines" }
  ],
  Practice: [
    { id: 'spractice_1', label: "I don't know how to revise effectively" },
    { id: 'spractice_2', label: "I struggle with exam preparation" }
  ],
  Attitude: [
    { id: 'sattitude_1', label: "I have negative thoughts about school" },
    { id: 'sattitude_2', label: "I lack confidence" }
  ]
};

const getProblemsForCategory = (category) => {
  return problemDefinitions[category] || [];
};

const selectProblem = async (problem) => {
  try {
    loading.value = true;
    error.value = null;
    
    const response = await fetch(
      `${API_BASE_URL}${API_ENDPOINTS.ACTIVITIES_BY_PROBLEM}?problem_id=${problem.id}`
    );
    
    if (!response.ok) {
      throw new Error('Failed to fetch activities for problem');
    }
    
    const data = await response.json();
    selectedProblemActivities.value = data.activities || [];
    
    console.log(`[ProblemSelector] Found ${selectedProblemActivities.value.length} activities for problem ${problem.id}`);
  } catch (err) {
    console.error('[ProblemSelector] Error:', err);
    error.value = err.message;
  } finally {
    loading.value = false;
  }
};

const addActivity = (activity) => {
  emit('select-activity', activity);
  selectedProblemActivities.value = []; // Clear selection after adding
};

const loadProblemMappings = async () => {
  // This would load from CDN in production
  // For now, we use the hardcoded problem definitions
  problemMappings.value = problemDefinitions;
};
</script>

<style scoped>
.problem-selector {
  padding: var(--spacing-md);
}

.selector-description {
  margin-bottom: var(--spacing-lg);
  color: var(--dark-gray);
}

.loading,
.error {
  text-align: center;
  padding: var(--spacing-xl);
}

.problems-grid {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.category-group {
  background: white;
  padding: var(--spacing-md);
  border-radius: var(--radius-lg);
  border-left: 4px solid var(--primary);
}

.category-title {
  font-size: 1.125rem;
  margin-bottom: var(--spacing-md);
  font-weight: 600;
}

.problems-list {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
}

.problem-btn {
  padding: var(--spacing-sm) var(--spacing-md);
  background: var(--light-gray);
  border: 1px solid var(--gray);
  border-radius: var(--radius-md);
  color: var(--text);
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.problem-btn:hover {
  background: var(--primary);
  color: white;
  border-color: var(--primary);
  transform: translateY(-1px);
}

.selected-activities {
  margin-top: var(--spacing-xl);
  padding: var(--spacing-md);
  background: white;
  border-radius: var(--radius-lg);
}

.activities-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
  margin-top: var(--spacing-md);
}

.activity-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-sm);
  background: var(--light-gray);
  border-radius: var(--radius-md);
}

.activity-name {
  font-weight: 500;
  color: var(--dark-blue);
}
</style>

