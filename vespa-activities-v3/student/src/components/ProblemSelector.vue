<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal modal-large">
      <div class="modal-header">
        <h2 class="modal-title">
          <i class="fas fa-hand-pointer"></i>
          Choose Activities by Problem
        </h2>
        <p class="modal-subtitle">
          Select up to 3 challenges you're facing ({{ selectedProblems.size }}/3 selected)
        </p>
        <button class="modal-close" @click="$emit('close')">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <div class="modal-body">
        <div v-if="loading" class="loading">
          <div class="spinner"></div>
          <p>Loading problems...</p>
        </div>
        
        <div v-else class="problems-categories">
          <div
            v-for="category in categories"
            :key="category"
            class="problem-category"
          >
            <h4 :class="['category-header', category.toLowerCase()]">
              <span class="category-icon">{{ getCategoryIcon(category) }}</span>
              {{ category }}
            </h4>
            <div class="problems-list">
              <div
                v-for="problem in getProblemsForCategory(category)"
                :key="problem.id"
                :class="['problem-item', { selected: selectedProblems.has(problem.id) }]"
                @click="toggleProblem(problem)"
                @mouseenter="showPreview(problem)"
                @mouseleave="hidePreview"
              >
                <input 
                  type="checkbox" 
                  :checked="selectedProblems.has(problem.id)"
                  @click.stop
                  class="problem-checkbox"
                />
                <span class="problem-text">{{ problem.text }}</span>
                <span class="problem-count">({{ problem.activityCount }} activities)</span>
                <span class="problem-arrow">→</span>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Hover Preview Panel -->
        <div v-if="hoveredProblem" class="preview-panel">
          <h5>
            <i class="fas fa-eye"></i>
            Activities Preview
          </h5>
          <p class="preview-problem">"{{ hoveredProblem.text }}"</p>
          <div class="preview-activities">
            <div 
              v-for="activityName in hoveredProblem.recommendedActivityNames.slice(0, 6)"
              :key="activityName"
              class="preview-activity-chip"
            >
              {{ activityName }}
            </div>
            <span v-if="hoveredProblem.recommendedActivityNames.length > 6" class="preview-more">
              +{{ hoveredProblem.recommendedActivityNames.length - 6 }} more
            </span>
          </div>
        </div>
      </div>
      
      <div v-if="selectedProblems.size > 0" class="modal-footer">
        <div class="footer-left">
          <span class="selection-summary">
            {{ selectedProblems.size }} problem{{ selectedProblems.size > 1 ? 's' : '' }} selected
          </span>
        </div>
        <div class="footer-right">
          <button class="btn btn-secondary" @click="clearSelection">
            Clear Selection
          </button>
          <button 
            class="btn btn-primary" 
            @click="loadActivitiesForSelectedProblems"
            :disabled="isLoadingActivities"
          >
            <i class="fas fa-arrow-right"></i>
            {{ isLoadingActivities ? 'Loading...' : 'View Activities' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, watch } from 'vue';
import supabase from '../../shared/supabaseClient';

const props = defineProps({
  preSelectedCategory: {
    type: String,
    default: null
  }
});

const emit = defineEmits(['close', 'problem-selected']);

const loading = ref(false);
const isLoadingActivities = ref(false);
const problemMappings = ref({});
const selectedProblems = ref(new Set());
const hoveredProblem = ref(null);

// Expand the pre-selected category by default
const expandedCategories = ref(new Set());

const categories = ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude'];

onMounted(async () => {
  // Load problem mappings from CDN
  try {
    const response = await fetch('https://cdn.jsdelivr.net/gh/4Sighteducation/vespa-activities-v2@main/shared/vespa-problem-activity-mappings1a.json');
    const data = await response.json();
    problemMappings.value = data.problemMappings;
    console.log('📋 Loaded problem mappings from CDN:', problemMappings.value);
  } catch (error) {
    console.error('Failed to load problem mappings from CDN:', error);
    // Fallback to embedded mappings if fetch fails
    problemMappings.value = getEmbeddedProblemMappings();
    console.log('📋 Using embedded problem mappings fallback');
  }
});

const getEmbeddedProblemMappings = () => {
  // Fallback problem mappings embedded in code (complete list)
  return {
    "Vision": [
      { "id": "svision_1", "text": "I'm unsure about my future goals", "recommendedActivities": ["21st Birthday", "Roadmap", "Personal Compass", "Perfect Day"] },
      { "id": "svision_2", "text": "I'm not feeling motivated for my studies", "recommendedActivities": ["Motivation Diamond", "Five Roads", "Mission & Medal", "What's Stopping You"] },
      { "id": "svision_3", "text": "I can't see how school connects to my future", "recommendedActivities": ["Success Leaves Clues", "There and Back", "20 Questions", "SMART Goals"] },
      { "id": "svision_4", "text": "I don't really know what success looks like for me", "recommendedActivities": ["Perfect Day", "Fix your dashboard", "Getting Dreams Done", "Personal Compass"] },
      { "id": "svision_5", "text": "I haven't thought about what I want to achieve this year", "recommendedActivities": ["SMART Goals", "Roadmap", "Mental Contrasting", "21st Birthday"] },
      { "id": "svision_6", "text": "I find it hard to picture myself doing well", "recommendedActivities": ["Fake It!", "Perfect Day", "Inner Story Telling", "Force Field"] },
      { "id": "svision_7", "text": "I rarely think about where I'm heading or why I'm here", "recommendedActivities": ["Personal Compass", "Five Roads", "One to Ten", "20 Questions"] }
    ],
    "Effort": [
      { "id": "seffort_1", "text": "I struggle to complete my homework on time", "recommendedActivities": ["Weekly Planner", "25min Sprints", "Priority Matrix", "Now vs Most"] },
      { "id": "seffort_2", "text": "I find it hard to keep trying when things get difficult", "recommendedActivities": ["Will vs Skill", "Effort Thermometer", "Looking under Rocks", "Kill Your Critic"] },
      { "id": "seffort_3", "text": "I often give up if I don't get things right straight away", "recommendedActivities": ["Failing Forwards", "Growth Mindset", "2 Slow, 1 Fast", "Learn from Mistakes"] },
      { "id": "seffort_4", "text": "I do the bare minimum just to get by", "recommendedActivities": ["Effort Thermometer", "Mission & Medal", "Working Weeks", "The Bottom Left"] },
      { "id": "seffort_5", "text": "I get distracted really easily when I try to study", "recommendedActivities": ["High Flow Spaces", "Types of Attention", "Pre-Made Decisions", "Chunking Steps"] },
      { "id": "seffort_6", "text": "I avoid topics or tasks that feel too hard", "recommendedActivities": ["Will vs Skill", "Looking under Rocks", "2 Slow, 1 Fast", "The Lead Domino"] },
      { "id": "seffort_7", "text": "I put things off until I'm under pressure", "recommendedActivities": ["10min Rule", "Frogs & Bannisters", "Now vs Most", "25min Sprints"] }
    ],
    "Systems": [
      { "id": "ssystems_1", "text": "I'm not very organized with my notes and deadlines", "recommendedActivities": ["Weekly Planner", "Priority Matrix", "STQR", "Graphic Organisers"] },
      { "id": "ssystems_2", "text": "I don't have a good revision plan", "recommendedActivities": ["Leitner Box", "Revision Questionnaire", "Spaced Practice", "2-4-8 Rule"] },
      { "id": "ssystems_3", "text": "I keep forgetting what homework I have", "recommendedActivities": ["Weekly Planner", "Rule of 3", "Project Progress Chart", "Packing Bags"] },
      { "id": "ssystems_4", "text": "I leave everything to the last minute", "recommendedActivities": ["Eisenhower Matrix", "Priority Matrix", "The Lead Domino", "10min Rule"] },
      { "id": "ssystems_5", "text": "I don't use a planner or calendar to track my work", "recommendedActivities": ["Weekly Planner", "Project Progress Chart", "Working Weeks", "Rule of 3"] },
      { "id": "ssystems_6", "text": "My notes are all over the place and hard to follow", "recommendedActivities": ["Graphic Organisers", "STQR", "Right-Wrong-Right", "Chunking Steps"] },
      { "id": "ssystems_7", "text": "I struggle to prioritise what to do first", "recommendedActivities": ["Priority Matrix", "Eisenhower Matrix", "The Lead Domino", "Now vs Most"] }
    ],
    "Practice": [
      { "id": "spractice_1", "text": "I don't review my work regularly", "recommendedActivities": ["Test Yourself", "Spaced Practice", "Leitner Box", "2-4-8 Rule"] },
      { "id": "spractice_2", "text": "I tend to cram before tests", "recommendedActivities": ["Revision Questionnaire", "Spaced Practice", "Snack Don't Binge", "2-4-8 Rule"] },
      { "id": "spractice_3", "text": "I avoid practising topics I find hard", "recommendedActivities": ["Will vs Skill", "2 Slow, 1 Fast", "Looking under Rocks", "The Bottom Left"] },
      { "id": "spractice_4", "text": "I'm not sure how to revise effectively", "recommendedActivities": ["Time to Teach", "9 Box Grid", "Practice Questionnaire", "Test Yourself"] },
      { "id": "spractice_5", "text": "I don't practise exam-style questions enough", "recommendedActivities": ["Test Yourself", "Know the Skills", "Mechanical vs Flexible", "Right-Wrong-Right"] },
      { "id": "spractice_6", "text": "I don't really learn from the mistakes I make", "recommendedActivities": ["Failing Forwards", "Learn from Mistakes", "Right-Wrong-Right", "Problem Solving"] },
      { "id": "spractice_7", "text": "I rarely check my understanding before moving on", "recommendedActivities": ["Test Yourself", "Independent Learning", "9 Box Grid", "Time to Teach"] }
    ],
    "Attitude": [
      { "id": "sattitude_1", "text": "I worry I'm not smart enough", "recommendedActivities": ["Growth Mindset", "The Battery", "Managing Reactions", "Stopping Negative Thoughts"] },
      { "id": "sattitude_2", "text": "I get easily discouraged by setbacks", "recommendedActivities": ["Failing Forwards", "Benefit Finding", "Change Curve", "The First Aid Kit"] },
      { "id": "sattitude_3", "text": "I often compare myself to others and feel behind", "recommendedActivities": ["The Battery", "Network Audits", "Vampire Test", "One to Ten"] },
      { "id": "sattitude_4", "text": "I don't believe my effort really makes a difference", "recommendedActivities": ["Growth Mindset", "Effort Thermometer", "Force Field", "Will vs Skill"] },
      { "id": "sattitude_5", "text": "I feel overwhelmed when I don't get something straight away", "recommendedActivities": ["The First Aid Kit", "Stand Tall", "Managing Reactions", "Power of If"] },
      { "id": "sattitude_6", "text": "I tell myself I'm just not good at certain subjects", "recommendedActivities": ["Growth Mindset", "Stopping Negative Thoughts", "Kill Your Critic", "Fake It!"] },
      { "id": "sattitude_7", "text": "I find it hard to stay positive about school", "recommendedActivities": ["Network Audits", "The Battery", "Vampire Test", "Benefit Finding"] }
    ]
  };
};

const getCategoryIcon = (category) => {
  const icons = {
    'Vision': '👁️',
    'Effort': '💪',
    'Systems': '⚙️',
    'Practice': '🎯',
    'Attitude': '❤️'
  };
  return icons[category] || '📚';
};

const getProblemsForCategory = (category) => {
  const problems = problemMappings.value[category] || [];
  return problems.map(p => ({
    id: p.id,
    text: p.text,  // Keep first person for students
    activityCount: p.recommendedActivities?.length || 0,
    recommendedActivityNames: p.recommendedActivities || []
  }));
};

// Toggle problem selection (max 3)
const toggleProblem = (problem) => {
  if (selectedProblems.value.has(problem.id)) {
    selectedProblems.value.delete(problem.id);
    selectedProblems.value = new Set(selectedProblems.value); // Trigger reactivity
  } else if (selectedProblems.value.size < 3) {
    selectedProblems.value.add(problem.id);
    selectedProblems.value = new Set(selectedProblems.value); // Trigger reactivity
  } else {
    // Already at max - give feedback
    alert('You can select up to 3 problems. Please deselect one before adding another.');
  }
};

const clearSelection = () => {
  selectedProblems.value = new Set();
};

const showPreview = (problem) => {
  hoveredProblem.value = problem;
};

const hidePreview = () => {
  hoveredProblem.value = null;
};

// Get selected problems as objects
const getSelectedProblems = () => {
  const allProblems = [];
  Object.values(problemMappings.value).forEach(categoryProblems => {
    allProblems.push(...categoryProblems);
  });
  return allProblems.filter(p => selectedProblems.value.has(p.id));
};

// Load activities for all selected problems
const loadActivitiesForSelectedProblems = async () => {
  if (selectedProblems.value.size === 0) return;
  
  console.log('🎯 Loading activities for selected problems:', Array.from(selectedProblems.value));
  
  try {
    isLoadingActivities.value = true;
    
    // Get all selected problem IDs
    const problemIds = Array.from(selectedProblems.value);
    
    // Query for activities that match ANY of the selected problems
    // Using OR logic with array overlap
    const { data: activities, error: queryError } = await supabase
      .from('activities')
      .select('*')
      .overlaps('problem_mappings', problemIds)
      .eq('is_active', true)
      .order('vespa_category, level, display_order');

    if (queryError) throw queryError;

    console.log(`✅ Found ${activities?.length || 0} activities for ${problemIds.length} problems`);
    
    // Emit event with all selected problems and matching activities
    emit('problem-selected', {
      problem: getSelectedProblems()[0], // Primary problem for display
      problems: getSelectedProblems(),   // All selected problems
      activities: activities || []
    });

  } catch (err) {
    console.error('❌ Failed to load activities for problems:', err);
    alert('Failed to load activities. Please try again.');
  } finally {
    isLoadingActivities.value = false;
  }
};

// Legacy single-select function (keeping for backward compatibility)
const selectProblem = async (problem) => {
  console.log('🎯 Problem selected:', problem);
  
  // Query Supabase for activities with this problem ID in problem_mappings array
  try {
    loading.value = true;
    const { data: activities, error: queryError } = await supabase
      .from('activities')
      .select('*')
      .contains('problem_mappings', [problem.id])
      .eq('is_active', true)
      .order('vespa_category, level, display_order');

    if (queryError) throw queryError;

    console.log(`✅ Found ${activities?.length || 0} activities for problem:`, problem.id);
    
    // Emit event with problem and activities
    emit('problem-selected', {
      problem,
      activities: activities || []
    });

  } catch (err) {
    console.error('❌ Failed to load activities for problem:', err);
    alert('Failed to load activities. Please try again.');
  } finally {
    loading.value = false;
  }
};

// Watch for pre-selected category
watch(() => props.preSelectedCategory, (newCat) => {
  if (newCat) {
    // Expand this category
    const categoryName = newCat.charAt(0).toUpperCase() + newCat.slice(1);
    expandedCategories.value.add(categoryName);
  }
}, { immediate: true });
</script>

<style scoped>
.modal-large {
  max-width: 1000px;
  width: 95%;
  max-height: 90vh;
}

.modal-subtitle {
  margin: 8px 0 0 0;
  font-size: 14px;
  color: rgba(255, 255, 255, 0.9);
  font-weight: normal;
}

.loading {
  text-align: center;
  padding: 3rem;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #e0e0e0;
  border-top-color: #079baa;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 1rem;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.problems-categories {
  display: grid;
  grid-template-columns: 1fr;
  gap: 24px;
}

.problem-category {
  background: white;
  border-radius: 12px;
  padding: 20px;
  border: 2px solid #e9ecef;
  transition: all 0.2s;
}

.problem-category:hover {
  border-color: #079baa;
  box-shadow: 0 4px 12px rgba(7, 155, 170, 0.1);
}

.category-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 0 16px 0;
  font-size: 18px;
  font-weight: 600;
  padding-bottom: 12px;
  border-bottom: 2px solid #e9ecef;
}

.category-icon {
  font-size: 24px;
}

.category-header.vision { color: #ff8f00; border-bottom-color: #ff8f00; }
.category-header.effort { color: #86b4f0; border-bottom-color: #86b4f0; }
.category-header.systems { color: #84cc16; border-bottom-color: #84cc16; }
.category-header.practice { color: #7f31a4; border-bottom-color: #7f31a4; }
.category-header.attitude { color: #f032e6; border-bottom-color: #f032e6; }

.problems-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.problem-item {
  background: #f8f9fa;
  padding: 12px 16px;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 12px;
  border: 2px solid transparent;
}

.problem-item:hover {
  background: #079baa;
  color: white;
  border-color: #079baa;
  transform: translateX(4px);
}

.problem-text {
  flex: 1;
  font-size: 14px;
}

.problem-count {
  font-size: 12px;
  opacity: 0.7;
  font-weight: 600;
}

.problem-arrow {
  font-size: 18px;
  opacity: 0.5;
  transition: all 0.2s;
}

.problem-item:hover .problem-arrow {
  opacity: 1;
  transform: translateX(4px);
}

/* Selected State */
.problem-item.selected {
  background: #079baa;
  color: white;
  border-color: #079baa;
  transform: translateX(4px);
}

.problem-item.selected .problem-count {
  opacity: 1;
  color: rgba(255, 255, 255, 0.9);
}

.problem-checkbox {
  width: 18px;
  height: 18px;
  accent-color: #079baa;
  cursor: pointer;
}

/* Preview Panel */
.preview-panel {
  position: fixed;
  right: 30px;
  top: 50%;
  transform: translateY(-50%);
  background: white;
  border-radius: 12px;
  padding: 20px;
  width: 280px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  border: 2px solid #079baa;
  z-index: 1000;
}

.preview-panel h5 {
  margin: 0 0 12px 0;
  color: #079baa;
  font-size: 14px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.preview-problem {
  font-style: italic;
  color: #495057;
  margin: 0 0 12px 0;
  font-size: 13px;
  line-height: 1.4;
}

.preview-activities {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.preview-activity-chip {
  background: #f1f5f9;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 11px;
  color: #475569;
  font-weight: 500;
}

.preview-more {
  color: #079baa;
  font-size: 11px;
  font-weight: 600;
  padding: 4px;
}

/* Modal Footer */
.modal-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  background: #f8fafc;
  border-top: 1px solid #e2e8f0;
  border-radius: 0 0 16px 16px;
}

.footer-left {
  display: flex;
  align-items: center;
}

.selection-summary {
  font-weight: 600;
  color: #079baa;
  font-size: 14px;
}

.footer-right {
  display: flex;
  gap: 12px;
}

.btn {
  padding: 10px 20px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 6px;
}

.btn-primary {
  background: linear-gradient(135deg, #079baa 0%, #057a87 100%);
  color: white;
  border: none;
}

.btn-primary:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(7, 155, 170, 0.3);
}

.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-secondary {
  background: white;
  color: #079baa;
  border: 2px solid #079baa;
}

.btn-secondary:hover {
  background: #f0f9ff;
}

@media (max-width: 900px) {
  .problems-categories {
    grid-template-columns: 1fr;
  }
  
  .preview-panel {
    display: none;
  }
}
</style>

