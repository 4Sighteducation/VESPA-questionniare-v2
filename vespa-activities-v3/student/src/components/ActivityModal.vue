<template>
  <div class="activity-modal-fullpage">
    <div class="activity-modal-container">
      <!-- Review Mode Banner -->
      <div v-if="isReviewMode" class="review-mode-banner">
        <span class="review-icon">👁️</span>
        <span class="review-text">You've completed this activity! Reviewing your previous work.</span>
      </div>

      <!-- Beautiful Colored Header -->
      <header class="activity-header" :style="{ background: `linear-gradient(135deg, ${categoryColor.primary}, ${categoryColor.light})` }">
        <div class="activity-header-content">
          <div class="activity-title-section">
            <h1 class="activity-title">{{ activity.name }}</h1>
            <span class="activity-category-badge">
              {{ getCategoryEmoji() }} {{ activity.vespa_category }}
            </span>
            <span class="activity-level-badge">{{ activity.level }}</span>
            <span v-if="isReviewMode" class="completed-badge">✓ Completed</span>
          </div>
          <button @click="handleClose" class="activity-exit-btn">
            <span class="exit-icon">✕</span>
            <span class="exit-text">{{ isReviewMode ? 'Close' : 'Save & Exit' }}</span>
          </button>
        </div>
        <div class="activity-progress-bar">
          <div class="progress-fill" :style="{ width: isReviewMode ? '100%' : progressPercentage + '%' }"></div>
        </div>
      </header>

      <!-- Stage Navigation Tabs -->
      <div class="activity-stages-nav">
        <button 
          v-for="stage in stages" 
          :key="stage.id"
          class="stage-nav-item"
          :class="{ 
            active: currentStage === stage.id, 
            completed: isStageCompleted(stage.id),
            locked: !canAccessStage(stage.id)
          }"
          @click="navigateToStage(stage.id)"
          :disabled="!canAccessStage(stage.id)"
        >
          <span class="stage-icon">{{ stage.icon }}</span>
          <span class="stage-label">{{ stage.label }}</span>
          <span v-if="isStageCompleted(stage.id)" class="stage-check">✓</span>
        </button>
      </div>

      <!-- Content Area -->
      <div class="activity-content-wrapper">
        <div class="activity-content">
          <!-- INTRODUCTION STAGE -->
          <div v-if="currentStage === 'intro'" class="stage-content intro-content">
            <div class="stage-header">
              <h2>Welcome to {{ activity.name }}!</h2>
              <p class="stage-description">Let's explore this activity together.</p>
            </div>
            
            <div class="activity-overview">
              <div class="overview-card">
                <span class="overview-icon">⏱️</span>
                <h3>Time Needed</h3>
                <p>Approximately {{ activity.time_minutes || 30 }} minutes</p>
              </div>
              <div class="overview-card">
                <span class="overview-icon">🎯</span>
                <h3>What You'll Learn</h3>
                <p>Develop key skills in {{ activity.vespa_category }}</p>
              </div>
              <div class="overview-card">
                <span class="overview-icon">⭐</span>
                <h3>Points Available</h3>
                <p>{{ basePoints }} points</p>
              </div>
            </div>
            
            <div class="stage-navigation">
              <button class="primary-btn next-stage-btn" @click="navigateToStage('learn')">
                Let's Begin! <span class="btn-arrow">→</span>
              </button>
            </div>
          </div>

          <!-- LEARN STAGE -->
          <div v-if="currentStage === 'learn'" class="stage-content learn-content">
            <div class="stage-header">
              <h2>Learn & Explore</h2>
              <p class="stage-description">Review the materials below to understand the activity.</p>
            </div>
            
            <!-- THINK Section (Videos/Slides) -->
            <div v-if="activity.think_section_html" class="learn-video-section">
              <h3 class="section-heading">WATCH 📺</h3>
              <div class="section-content" v-html="activity.think_section_html"></div>
            </div>
            
            <!-- LEARN Section (Background Info) -->
            <div v-if="activity.learn_section_html" class="learn-background-section">
              <h3 class="section-heading">THINK 🧠</h3>
              <div class="background-info-content" v-html="activity.learn_section_html"></div>
            </div>
            
            <!-- Confirmation Checkbox (not shown in review mode) -->
            <div v-if="!isReviewMode" class="learn-confirmation">
              <label class="confirmation-checkbox">
                <input 
                  type="checkbox" 
                  v-model="hasConfirmedLearnContent"
                  class="confirmation-input"
                />
                <span class="confirmation-checkmark"></span>
                <span class="confirmation-text">
                  ✓ I've reviewed the content above and I'm ready to practice!
                </span>
              </label>
            </div>
            
            <div class="stage-navigation">
              <button class="secondary-btn prev-stage-btn" @click="navigateToStage('intro')">
                <span class="btn-arrow">←</span> Back
              </button>
              <button 
                class="primary-btn next-stage-btn" 
                @click="navigateToStage('do')"
                :disabled="!hasConfirmedLearnContent && !isReviewMode"
                :class="{ 'btn-disabled': !hasConfirmedLearnContent && !isReviewMode }"
              >
                Ready to Practice! <span class="btn-arrow">→</span>
              </button>
            </div>
          </div>

          <!-- DO STAGE -->
          <div v-if="currentStage === 'do'" class="stage-content do-content">
            <div class="stage-header">
              <h2>Your Turn!</h2>
              <p class="stage-description">Complete the following activities.</p>
              <!-- Progress indicator for minimum responses (not in review mode) -->
              <div v-if="!isReviewMode && doQuestions.length > 0" class="response-progress">
                <div class="progress-info">
                  <span class="progress-count">
                    {{ answeredDoQuestionsCount }} / {{ minRequiredResponses }} 
                  </span>
                  <span class="progress-label">responses to unlock Reflect</span>
                </div>
                <div class="progress-bar-mini">
                  <div 
                    class="progress-fill-mini" 
                    :style="{ width: `${Math.min(100, (answeredDoQuestionsCount / minRequiredResponses) * 100)}%` }"
                    :class="{ 'complete': answeredDoQuestionsCount >= minRequiredResponses }"
                  ></div>
                </div>
              </div>
            </div>
            
            <!-- DO Section HTML -->
            <div v-if="activity.do_section_html" class="do-instructions">
              <div v-html="activity.do_section_html"></div>
            </div>
            
            <!-- Questions (non-reflection) -->
            <div v-if="doQuestions.length > 0" class="activity-questions" :class="{ 'review-mode': isReviewMode }">
              <div 
                v-for="(question, index) in paginatedDoQuestions" 
                :key="question.id"
                class="question-block"
                :class="{ required: question.answer_required }"
              >
                <QuestionRenderer
                  :question="question"
                  :model-value="responses[question.id] || getExistingResponse(question.id)"
                  :readonly="isReviewMode"
                  @update:model-value="updateResponse(question.id, $event)"
                />
              </div>
            </div>
            
            <!-- Pagination for questions -->
            <div v-if="doQuestions.length > questionsPerPage" class="question-pagination-new">
              <div class="pagination-info">
                <span class="pagination-text">Question {{ currentQuestionPage * questionsPerPage + 1}}-{{ Math.min((currentQuestionPage + 1) * questionsPerPage, doQuestions.length) }} of {{ doQuestions.length }}</span>
              </div>
              <div class="progress-bar-mini">
                <div 
                  class="progress-fill-mini" 
                  :style="{ width: `${((currentQuestionPage + 1) / totalQuestionPages) * 100}%` }"
                ></div>
              </div>
            </div>
            
            <div class="stage-navigation">
              <button 
                v-if="currentQuestionPage > 0"
                class="secondary-btn prev-questions-btn" 
                @click="previousQuestions"
              >
                <span class="btn-arrow">←</span> Previous
              </button>
              <button 
                v-else
                class="secondary-btn prev-stage-btn" 
                @click="navigateToStage('learn')"
              >
                <span class="btn-arrow">←</span> Review Materials
              </button>
              
              <button 
                v-if="currentQuestionPage < totalQuestionPages - 1"
                class="primary-btn next-questions-btn" 
                @click="nextQuestions"
                :disabled="!canProceedToNextQuestions"
              >
                Next <span class="btn-arrow">→</span>
              </button>
              <button 
                v-else
                class="primary-btn next-stage-btn reflect-btn" 
                @click="navigateToStage('reflect')"
                :disabled="!canProceedFromDo"
                :class="{ 'btn-disabled': !canProceedFromDo }"
                :title="!canProceedFromDo ? `Answer at least ${minRequiredResponses} questions to continue` : ''"
              >
                <template v-if="canProceedFromDo">
                  Continue to Reflection <span class="btn-arrow">→</span>
                </template>
                <template v-else>
                  🔒 {{ answeredDoQuestionsCount }}/{{ minRequiredResponses }} answered
                </template>
              </button>
            </div>
          </div>

          <!-- REFLECT STAGE -->
          <div v-if="currentStage === 'reflect'" class="stage-content reflect-content">
            <div class="stage-header">
              <h2>Reflection Time</h2>
              <p class="stage-description">Take a moment to reflect on what you've learned.</p>
              <!-- Rating requirement indicator (not in review mode) -->
              <div v-if="!isReviewMode && !hasSelectedRating" class="rating-required-hint">
                <span class="hint-icon">💡</span>
                <span class="hint-text">Please select a rating below to complete the activity</span>
              </div>
            </div>
            
            <!-- REFLECT Section HTML -->
            <div v-if="activity.reflect_section_html" class="reflect-instructions">
              <div v-html="activity.reflect_section_html"></div>
            </div>
            
            <!-- Reflection Questions (show_in_final_questions) -->
            <div v-if="reflectionQuestions.length > 0" class="reflection-questions" :class="{ 'review-mode': isReviewMode }">
              <div 
                v-for="question in reflectionQuestions" 
                :key="question.id"
                class="question-block"
                :class="{ required: question.answer_required }"
              >
                <QuestionRenderer
                  :question="question"
                  :model-value="responses[question.id] || getExistingResponse(question.id)"
                  :readonly="isReviewMode"
                  @update:model-value="updateResponse(question.id, $event)"
                />
              </div>
            </div>
            
            <div class="stage-navigation">
              <button class="secondary-btn prev-stage-btn" @click="navigateToStage('do')">
                <span class="btn-arrow">←</span> Back to Activities
              </button>
              <button 
                v-if="!isReviewMode"
                class="primary-btn complete-btn" 
                @click="handleComplete"
                :disabled="!canComplete"
                :class="{ 'btn-disabled': !canComplete }"
                :title="!hasSelectedRating ? 'Please select a rating first' : ''"
              >
                <template v-if="canComplete">
                  Complete Activity! <span class="btn-arrow">🎉</span>
                </template>
                <template v-else>
                  🔒 Select a rating to complete
                </template>
              </button>
              <button 
                v-else
                class="secondary-btn close-review-btn" 
                @click="handleClose"
              >
                Close Review <span class="btn-arrow">✕</span>
              </button>
            </div>
          </div>

          <!-- COMPLETE STAGE -->
          <div v-if="currentStage === 'complete'" class="stage-content complete-content">
            <div class="completion-celebration">
              <div class="celebration-icon">🎉</div>
              <h2>Congratulations!</h2>
              <p>You've completed "{{ activity.name }}"</p>
              
              <div class="points-earned">
                <span class="points-value">+{{ basePoints }}</span>
                <span class="points-label">Points Earned!</span>
              </div>
              
              <div class="completion-actions">
                <p style="color: #666; font-size: 14px; margin-bottom: 15px;">Returning to dashboard in 5 seconds...</p>
                <button class="secondary-btn" @click="handleClose">
                  Return Now
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import QuestionRenderer from './QuestionRenderer.vue';
import { CATEGORY_COLORS, AUTO_SAVE_INTERVAL } from '../../shared/constants';

const props = defineProps({
  activity: {
    type: Object,
    required: true
  },
  questions: {
    type: Array,
    default: () => []
  },
  existingResponses: {
    type: Object,
    default: null
  }
});

const emit = defineEmits(['close', 'save', 'complete']);

// State
const currentStage = ref('intro');
const responses = ref({});
const autoSaveStatus = ref('');
const timeSpent = ref(0);
const startTime = ref(Date.now());
const currentQuestionPage = ref(0);
const questionsPerPage = 2;
let autoSaveIntervalId = null;
let timeInterval = null;

// Engagement tracking - ensure students actually view content
const hasConfirmedLearnContent = ref(false);  // Checkbox: "I've reviewed this content"

// Check if this is a completed activity being reviewed (read-only mode)
const isReviewMode = computed(() => {
  return props.existingResponses?.status === 'completed';
});

// Stages
const stages = [
  { id: 'intro', icon: '📖', label: 'Introduction' },
  { id: 'learn', icon: '🎯', label: 'Learn' },
  { id: 'do', icon: '✏️', label: 'Do' },
  { id: 'reflect', icon: '💭', label: 'Reflect' },
  { id: 'complete', icon: '🏆', label: 'Complete' }
];

// Category colors with light variant
const categoryColors = {
  'Vision': { primary: '#fc8900', light: '#ffa940' },
  'Effort': { primary: '#78aced', light: '#a3c4f3' },
  'Systems': { primary: '#7bc114', light: '#9ad43a' },
  'Practice': { primary: '#792e9c', light: '#9c4fc6' },
  'Attitude': { primary: '#eb2de3', light: '#f460ea' }
};

const categoryColor = computed(() => {
  return categoryColors[props.activity.vespa_category] || { primary: '#079baa', light: '#00e5db' };
});

const getCategoryEmoji = () => {
  const emojis = {
    'Vision': '👁️',
    'Effort': '💪',
    'Systems': '⚙️',
    'Practice': '🎯',
    'Attitude': '🧠'
  };
  return emojis[props.activity.vespa_category] || '📚';
};

const basePoints = computed(() => {
  return props.activity.level === 'Level 3' ? 15 : 10;
});

// Split questions into Do vs Reflect
const doQuestions = computed(() => {
  return props.questions.filter(q => !q.show_in_final_questions);
});

const reflectionQuestions = computed(() => {
  return props.questions.filter(q => q.show_in_final_questions);
});

// Pagination for Do questions
const totalQuestionPages = computed(() => {
  return Math.ceil(doQuestions.value.length / questionsPerPage);
});

const paginatedDoQuestions = computed(() => {
  const start = currentQuestionPage.value * questionsPerPage;
  const end = start + questionsPerPage;
  return doQuestions.value.slice(start, end);
});

// Progress calculation
const progressPercentage = computed(() => {
  const stageIndex = stages.findIndex(s => s.id === currentStage.value);
  return Math.round((stageIndex / (stages.length - 1)) * 100);
});

// Navigation checks
const isStageCompleted = (stageId) => {
  const currentIndex = stages.findIndex(s => s.id === currentStage.value);
  const stageIndex = stages.findIndex(s => s.id === stageId);
  return stageIndex < currentIndex;
};

const canAccessStage = (stageId) => {
  // In review mode, allow access to all stages
  if (isReviewMode.value) return true;
  
  const stageIndex = stages.findIndex(s => s.id === stageId);
  const currentIndex = stages.findIndex(s => s.id === currentStage.value);
  
  // Can always go back
  if (stageIndex <= currentIndex) return true;
  
  // Forward navigation requires meeting requirements
  switch (stageId) {
    case 'intro':
      return true;
    case 'learn':
      return true; // Can always access Learn from Intro
    case 'do':
      return hasConfirmedLearnContent.value; // Must confirm Learn content
    case 'reflect':
      return canProceedFromDo.value; // Must answer min questions in Do
    case 'complete':
      return canComplete.value; // Must have rating selected
    default:
      return true;
  }
};

// Count how many Do questions have been answered
const answeredDoQuestionsCount = computed(() => {
  return doQuestions.value.filter(q => {
    const value = responses.value[q.id] || getExistingResponse(q.id);
    return value !== null && value !== undefined && value !== '' && String(value).trim().length > 0;
  }).length;
});

// Require ALL Do questions to be answered (force full completion)
const minRequiredResponses = computed(() => {
  return doQuestions.value.length; // ALL questions required!
});

const canProceedFromDo = computed(() => {
  // In review mode, always allow navigation
  if (isReviewMode.value) return true;
  
  // Must answer ALL Do questions before proceeding to Reflect
  return answeredDoQuestionsCount.value >= minRequiredResponses.value;
});

const canProceedToNextQuestions = computed(() => {
  // In review mode, always allow navigation
  if (isReviewMode.value) return true;
  
  // Check current page questions - at least try to answer them
  const answeredOnPage = paginatedDoQuestions.value.filter(q => {
    const value = responses.value[q.id] || getExistingResponse(q.id);
    return value !== null && value !== undefined && value !== '' && String(value).trim().length > 0;
  }).length;
  
  // Must answer at least 1 question on current page to proceed
  return answeredOnPage > 0 || paginatedDoQuestions.value.length === 0;
});

// Check if rating question has been answered in Reflect section
const hasSelectedRating = computed(() => {
  // Find the rating question (usually a dropdown asking to rate the activity)
  const ratingQuestion = reflectionQuestions.value.find(q => 
    q.question_type === 'Dropdown' && 
    (q.question_title?.toLowerCase().includes('rating') || 
     q.question_title?.toLowerCase().includes('rate'))
  );
  
  if (!ratingQuestion) return true; // No rating question, allow completion
  
  const value = responses.value[ratingQuestion.id] || getExistingResponse(ratingQuestion.id);
  return value !== null && value !== undefined && value !== '';
});

const canComplete = computed(() => {
  // In review mode, don't show complete button anyway
  if (isReviewMode.value) return false;
  
  // Must have:
  // 1. Answered minimum required Do questions
  // 2. Selected a rating in Reflect section
  return canProceedFromDo.value && hasSelectedRating.value;
});

// Methods
const getExistingResponse = (questionId) => {
  if (!props.existingResponses?.responses) return null;
  return props.existingResponses.responses[questionId] || null;
};

const updateResponse = (questionId, value) => {
  responses.value[questionId] = value;
  scheduleAutoSave();
};

const navigateToStage = (stageId) => {
  // Block navigation if stage is locked
  if (!canAccessStage(stageId)) {
    console.log('[ActivityModal] 🔒 Stage locked:', stageId);
    return;
  }
  
  console.log('[ActivityModal] ✅ Navigating to stage:', stageId);
  currentStage.value = stageId;
  currentQuestionPage.value = 0; // Reset pagination
};

const nextQuestions = () => {
  if (currentQuestionPage.value < totalQuestionPages.value - 1) {
    currentQuestionPage.value++;
  }
};

const previousQuestions = () => {
  if (currentQuestionPage.value > 0) {
    currentQuestionPage.value--;
  }
};

const scheduleAutoSave = () => {
  if (autoSaveIntervalId) {
    clearTimeout(autoSaveIntervalId);
  }
  
  autoSaveIntervalId = setTimeout(async () => {
    await handleSave(true);
    autoSaveIntervalId = null;
  }, AUTO_SAVE_INTERVAL);
};

const handleSave = async (isAutoSave = false) => {
  try {
    autoSaveStatus.value = isAutoSave ? '💾 Saving...' : '';
    
    // CRITICAL: Merge existing + new responses for saves too
    const mergedResponses = {
      ...(props.existingResponses?.responses || {}),
      ...responses.value
    };
    
    const saveData = {
      responses: mergedResponses,  // Send all responses
      timeMinutes: Math.floor(timeSpent.value / 60)
    };
    
    emit('save', saveData);
    
    if (isAutoSave) {
      autoSaveStatus.value = '✓ Saved';
      setTimeout(() => {
        autoSaveStatus.value = '';
      }, 2000);
    }
  } catch (err) {
    console.error('[ActivityModal] Save error:', err);
    autoSaveStatus.value = '✕ Save failed';
  }
};

const handleComplete = async () => {
  console.log('[ActivityModal] 🎉 handleComplete called');
  console.log('[ActivityModal] canComplete:', canComplete.value);
  console.log('[ActivityModal] responses.value:', Object.keys(responses.value).length, 'answers');
  
  if (!canComplete.value) {
    console.log('[ActivityModal] ❌ Cannot complete - required questions not answered');
    alert('Please answer all required questions before completing.');
    return;
  }
  
  // CRITICAL: Merge existing responses with new responses
  // This ensures we send ALL responses (old + new), not just new ones
  const mergedResponses = {
    ...(props.existingResponses?.responses || {}),  // Start with old responses
    ...responses.value  // Override with new responses
  };
  
  console.log('[ActivityModal] 📦 Merged responses:', Object.keys(mergedResponses).length, 'total answers');
  
  // Calculate word count from ALL text responses (old + new)
  let totalWords = 0;
  Object.values(mergedResponses).forEach(response => {
    if (typeof response === 'string') {
      totalWords += response.trim().split(/\s+/).filter(w => w.length > 0).length;
    }
  });
  
  const completeData = {
    responses: mergedResponses,  // Send merged responses!
    timeMinutes: Math.floor(timeSpent.value / 60),
    wordCount: totalWords
  };
  
  // Show completion stage first
  currentStage.value = 'complete';
  
  console.log('[ActivityModal] ✅ Emitting complete event with data:', {
    responseCount: Object.keys(completeData.responses).length,
    wordCount: completeData.wordCount,
    timeMinutes: completeData.timeMinutes
  });
  
  // Emit complete after showing celebration
  setTimeout(() => {
    emit('complete', completeData);
    console.log('[ActivityModal] ✅ Complete event emitted');
  }, 500);
  
  // Auto-close after 5 seconds
  setTimeout(() => {
    handleClose();
  }, 5000);
};

const handleClose = async () => {
  // Auto-save before closing
  if (Object.keys(responses.value).length > 0) {
    await handleSave(false);
  }
  emit('close');
};

// Load existing responses
onMounted(() => {
  if (props.existingResponses?.responses) {
    responses.value = { ...props.existingResponses.responses };
  }
  
  // Start time tracking
  if (props.existingResponses?.time_spent_minutes) {
    timeSpent.value = props.existingResponses.time_spent_minutes * 60;
  }
  
  timeInterval = setInterval(() => {
    timeSpent.value++;
  }, 1000);
  
  // Prevent body scroll
  document.body.style.overflow = 'hidden';
  
  // Hide broken images after mount
  setTimeout(() => {
    const images = document.querySelectorAll('.activity-modal-fullpage img');
    images.forEach(img => {
      img.addEventListener('error', function() {
        console.log('[ActivityModal] 🚫 Hiding broken image:', this.src);
        this.style.display = 'none';
        // Also hide parent if it's an empty container
        if (this.parentElement && this.parentElement.children.length === 1) {
          this.parentElement.style.display = 'none';
        }
      });
    });
  }, 500);
});

onUnmounted(() => {
  if (autoSaveIntervalId) {
    clearTimeout(autoSaveIntervalId);
  }
  if (timeInterval) {
    clearInterval(timeInterval);
  }
  
  // Restore body scroll
  document.body.style.overflow = '';
});
</script>

<style scoped>
/* ===== Full Page Modal ===== */
.activity-modal-fullpage {
  position: fixed;
  inset: 0;
  z-index: 9999;
  background: var(--white, #ffffff);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.activity-modal-container {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
}

/* Desktop centered modal */
@media (min-width: 1024px) {
  .activity-modal-fullpage {
    background: rgba(0, 0, 0, 0.5);
    padding: 2rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .activity-modal-container {
    background: white;
    max-width: 1200px;
    width: 100%;
    height: calc(100vh - 4rem);
    max-height: 900px;
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 25px 50px rgba(0, 0, 0, 0.3);
  }
}

/* ===== Header ===== */
.activity-header {
  padding: 1rem;
  color: white;
  position: relative;
  overflow: hidden;
  flex-shrink: 0;
}

.activity-header::before {
  content: '';
  position: absolute;
  top: -50%;
  right: -50%;
  width: 200%;
  height: 200%;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
}

.activity-header-content {
  position: relative;
  z-index: 1;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
}

.activity-title-section {
  flex: 1;
  min-width: 0;
}

.activity-title {
  font-size: 1.5rem;
  font-weight: 700;
  margin: 0 0 0.5rem 0;
  line-height: 1.2;
  color: white;
}

.activity-category-badge,
.activity-level-badge {
  display: inline-block;
  background: rgba(255, 255, 255, 0.2);
  padding: 0.25rem 0.75rem;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 600;
  margin-right: 0.5rem;
  backdrop-filter: blur(10px);
}

.completed-badge {
  display: inline-block;
  background: rgba(114, 203, 68, 0.9);
  color: white;
  padding: 0.25rem 0.75rem;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 700;
  margin-left: 0.5rem;
  box-shadow: 0 2px 8px rgba(114, 203, 68, 0.4);
}

/* ===== Review Mode Banner ===== */
.review-mode-banner {
  background: linear-gradient(135deg, #72cb44 0%, #5cb030 100%);
  color: white;
  padding: 0.75rem 1.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  font-weight: 600;
  font-size: 0.95rem;
  box-shadow: 0 2px 8px rgba(114, 203, 68, 0.3);
}

.review-icon {
  font-size: 1.25rem;
}

/* Review mode styling for questions */
.activity-questions.review-mode,
.reflection-questions.review-mode {
  pointer-events: none;
  opacity: 0.9;
}

.activity-questions.review-mode .question-block,
.reflection-questions.review-mode .question-block {
  background: #f8fff5;
  border: 1px solid #d4edc8;
}

.close-review-btn {
  background: linear-gradient(135deg, #72cb44 0%, #5cb030 100%);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.close-review-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(114, 203, 68, 0.3);
}

/* ===== Engagement & Validation Styles ===== */

/* Learn Confirmation Checkbox */
.learn-confirmation {
  margin: 2rem 0;
  padding: 1.5rem;
  background: linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%);
  border: 2px solid #14b8a6;
  border-radius: 12px;
}

.confirmation-checkbox {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  font-size: 1rem;
  font-weight: 500;
  color: #0f766e;
}

.confirmation-input {
  display: none;
}

.confirmation-checkmark {
  width: 28px;
  height: 28px;
  border: 3px solid #14b8a6;
  border-radius: 6px;
  background: white;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s;
  flex-shrink: 0;
}

.confirmation-input:checked + .confirmation-checkmark {
  background: linear-gradient(135deg, #14b8a6 0%, #0d9488 100%);
  border-color: #0d9488;
}

.confirmation-input:checked + .confirmation-checkmark::after {
  content: '✓';
  color: white;
  font-size: 18px;
  font-weight: bold;
}

.confirmation-text {
  line-height: 1.4;
}

/* Response Progress Bar in Do Section */
.response-progress {
  margin-top: 1rem;
  padding: 1rem;
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
  border-radius: 10px;
  border: 2px solid #f59e0b;
}

.progress-info {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: 8px;
}

.progress-count {
  font-size: 1.25rem;
  font-weight: 700;
  color: #b45309;
}

.progress-label {
  font-size: 0.875rem;
  color: #92400e;
}

.progress-bar-mini {
  height: 8px;
  background: rgba(255, 255, 255, 0.5);
  border-radius: 4px;
  overflow: hidden;
}

.progress-fill-mini {
  height: 100%;
  background: linear-gradient(90deg, #f59e0b 0%, #d97706 100%);
  border-radius: 4px;
  transition: width 0.3s ease;
}

.progress-fill-mini.complete {
  background: linear-gradient(90deg, #22c55e 0%, #16a34a 100%);
}

/* Rating Required Hint */
.rating-required-hint {
  margin-top: 1rem;
  padding: 1rem;
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
  border-radius: 10px;
  border: 2px solid #f59e0b;
  display: flex;
  align-items: center;
  gap: 10px;
}

.hint-icon {
  font-size: 1.5rem;
}

.hint-text {
  font-weight: 500;
  color: #92400e;
}

/* Disabled Button State */
.btn-disabled {
  opacity: 0.6;
  cursor: not-allowed !important;
  background: #94a3b8 !important;
}

.btn-disabled:hover {
  transform: none !important;
  box-shadow: none !important;
}

.activity-exit-btn {
  background: rgba(255, 255, 255, 0.2);
  border: 2px solid rgba(255, 255, 255, 0.4);
  color: white;
  padding: 0.5rem 1rem;
  border-radius: 25px;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  backdrop-filter: blur(10px);
}

.activity-exit-btn:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateY(-2px);
}

.exit-icon {
  font-size: 1.25rem;
}

.activity-progress-bar {
  height: 4px;
  background: rgba(0, 0, 0, 0.2);
  margin-top: 1rem;
  border-radius: 2px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: white;
  transition: width 0.5s ease;
}

/* ===== Stage Navigation ===== */
.activity-stages-nav {
  background: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
  display: flex;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  flex-shrink: 0;
}

.stage-nav-item {
  flex: 1;
  min-width: 0;
  padding: 0.75rem 0.5rem;
  background: none;
  border: none;
  border-bottom: 3px solid transparent;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
  cursor: pointer;
  transition: all 0.3s;
  position: relative;
  color: #6c757d;
}

.stage-nav-item:hover:not(.locked) {
  background: #f1f3f5;
}

.stage-nav-item.active {
  border-bottom-color: var(--primary, #079baa);
  background: white;
  color: var(--primary);
}

.stage-nav-item.completed {
  color: #72cb44;
}

.stage-nav-item.locked {
  opacity: 0.5;
  cursor: not-allowed;
}

.stage-icon {
  font-size: 1.5rem;
}

.stage-label {
  font-size: 0.75rem;
  font-weight: 600;
}

.stage-check {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  background: #72cb44;
  color: white;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
}

/* ===== Content Area ===== */
.activity-content-wrapper {
  flex: 1;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  background: #f8f9fa;
}

.activity-content {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem 1rem;
}

.stage-content {
  animation: fadeIn 0.3s ease;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.stage-header {
  text-align: center;
  margin-bottom: 2rem;
}

.stage-header h2 {
  font-size: 1.75rem;
  font-weight: 700;
  color: #343a40;
  margin: 0 0 0.5rem 0;
}

.stage-description {
  color: #6c757d;
  font-size: 1rem;
  margin: 0;
}

/* ===== Introduction Stage ===== */
.activity-overview {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
  margin-bottom: 2rem;
}

.overview-card {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  text-align: center;
  border: 2px solid #e9ecef;
  transition: all 0.3s;
}

.overview-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.overview-icon {
  font-size: 2.5rem;
  display: block;
  margin-bottom: 0.5rem;
}

.overview-card h3 {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 0 0 0.5rem 0;
  color: #343a40;
}

.overview-card p {
  margin: 0;
  color: #6c757d;
}

/* ===== Learn Stage ===== */
.section-heading {
  color: var(--primary);
  font-size: 1.5rem;
  font-weight: 700;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.learn-video-section {
  margin-bottom: 2rem;
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
}

.learn-background-section {
  margin-bottom: 2rem;
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
}

.background-info-content {
  line-height: 1.8;
  color: #333;
}

.background-info-content :deep(h2) {
  color: #a4c2f4;
  text-align: center;
  margin: 20px 0;
}

.background-info-content :deep(h3) {
  color: #2a3c7a;
  margin: 15px 0;
}

.background-info-content :deep(img) {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  margin: 20px auto;
  display: block;
}

.background-info-content :deep(iframe) {
  max-width: 100%;
  width: 100%;
  height: 500px;
  border: none;
  border-radius: 12px;
  margin: 20px 0;
}

/* ===== Do & Reflect Stages ===== */
.do-instructions,
.reflect-instructions {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  margin-bottom: 2rem;
  line-height: 1.8;
}

.activity-questions,
.reflection-questions {
  display: grid;
  gap: 2rem;
  margin-bottom: 2rem;
}

.question-block {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  border: 2px solid #e9ecef;
  transition: all 0.3s;
}

.question-block:hover {
  border-color: #dee2e6;
}

.question-block.required {
  border-color: var(--primary-light, #00e5db);
}

.question-pagination {
  margin-bottom: 2rem;
  text-align: center;
}

.progress-text {
  font-size: 0.875rem;
  color: #6c757d;
  margin-bottom: 0.5rem;
  font-weight: 600;
  display: block;
}

.progress-bar-wrapper {
  height: 8px;
  background: #e9ecef;
  border-radius: 4px;
  overflow: hidden;
  max-width: 300px;
  margin: 0 auto;
}

.progress-bar-fill {
  height: 100%;
  background: var(--primary);
  transition: width 0.3s;
}

/* New styled pagination */
.question-pagination-new {
  margin: 1.5rem 0;
  padding: 1rem;
  background: linear-gradient(135deg, #e0f2fe 0%, #bae6fd 100%);
  border-radius: 10px;
  border: 2px solid #0284c7;
  text-align: center;
}

.pagination-info {
  margin-bottom: 8px;
}

.pagination-text {
  font-size: 0.95rem;
  font-weight: 600;
  color: #0c4a6e;
}

/* ===== Complete Stage ===== */
.completion-celebration {
  text-align: center;
  padding: 2rem;
  background: white;
  border-radius: 20px;
  margin: 2rem auto;
  max-width: 600px;
}

.celebration-icon {
  font-size: 4rem;
  animation: bounce 1s ease infinite;
}

@keyframes bounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-20px); }
}

.completion-celebration h2 {
  font-size: 2rem;
  color: #343a40;
  margin: 1rem 0 0.5rem 0;
}

.completion-celebration p {
  color: #6c757d;
  margin-bottom: 2rem;
}

.points-earned {
  display: inline-flex;
  flex-direction: column;
  background: linear-gradient(135deg, #28a745 0%, #5cb85c 100%);
  color: white;
  padding: 1.5rem 3rem;
  border-radius: 20px;
  margin-bottom: 2rem;
  box-shadow: 0 8px 24px rgba(40, 167, 69, 0.3);
}

.points-value {
  font-size: 3rem;
  font-weight: 800;
}

.points-label {
  font-size: 1rem;
  font-weight: 600;
}

/* ===== Navigation Buttons ===== */
.stage-navigation {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  margin-top: 2rem;
}

.primary-btn,
.secondary-btn {
  padding: 0.75rem 1.5rem;
  border-radius: 25px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border: none;
  font-size: 1rem;
}

.primary-btn {
  background: var(--primary, #079baa);
  color: white;
}

.primary-btn:hover:not(:disabled) {
  background: var(--dark-blue, #23356f);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(7, 155, 170, 0.3);
}

.secondary-btn {
  background: #e9ecef;
  color: #495057;
}

.secondary-btn:hover {
  background: #dee2e6;
}

.primary-btn:disabled,
.secondary-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-arrow {
  transition: transform 0.3s;
}

.primary-btn:hover:not(:disabled) .btn-arrow {
  transform: translateX(3px);
}

.secondary-btn:hover .btn-arrow {
  transform: translateX(-3px);
}

/* ===== Responsive ===== */
@media (max-width: 768px) {
  .activity-title {
    font-size: 1.25rem;
  }
  
  .activity-overview {
    grid-template-columns: 1fr;
  }
  
  .activity-content {
    padding: 1rem;
  }
  
  .stage-nav-item {
    font-size: 0.75rem;
    padding: 0.5rem;
  }
  
  .stage-icon {
    font-size: 1rem;
  }
  
  .exit-text {
    display: none;
  }
  
  .stage-navigation {
    flex-direction: column;
  }
  
  .stage-navigation button {
    width: 100%;
  }
}

/* Section content styling */
.section-content :deep(iframe) {
  width: 100%;
  max-width: 100%;
  height: 400px;
  border: none;
  border-radius: 12px;
  margin: 1rem 0;
}

.section-content :deep(img) {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  margin: 1rem 0;
}

@media (max-width: 768px) {
  .section-content :deep(iframe) {
    height: 300px;
  }
}
</style>

