<template>
  <div id="vespa-questionnaire-app">
    <!-- Loading/Checking State -->
    <LoadingCheck 
      v-if="state === 'checking'"
      loading-text="Checking your questionnaire access..."
      sub-text="This will just take a moment"
    />

    <!-- Instructions State -->
    <InstructionsScreen
      v-else-if="state === 'instructions'"
      :student-name="userData.name"
      :cycle-info="{ cycle: validationResult.cycle }"
      @start="startQuestionnaire"
    />

    <!-- Not Available State -->
    <NotAvailable
      v-else-if="state === 'not-available'"
      :reason="validationResult.reason"
      :message="validationResult.message"
      :next-start-date="validationResult.nextStartDate"
    />

    <!-- Questionnaire State -->
    <div v-else-if="state === 'questionnaire'" class="questionnaire-container">
      <ProgressIndicator
        :current-question="currentQuestionIndex + 1"
        :total-questions="questions.length"
        :category-name="currentQuestion?.category"
        :category-color="currentCategoryColor"
      />
      
      <div class="questionnaire-content">
        <transition name="slide" mode="out-in">
          <QuestionCard
            :key="currentQuestion.id"
            :question="currentQuestion"
            v-model="responses[currentQuestion.id]"
          />
        </transition>

        <!-- Navigation Buttons -->
        <div class="navigation-buttons">
          <button 
            class="btn btn-secondary"
            @click="previousQuestion"
            :disabled="currentQuestionIndex === 0"
          >
            <i class="fa fa-arrow-left"></i>
            Previous
          </button>

          <button 
            class="btn btn-primary"
            @click="nextQuestion"
            :disabled="!responses[currentQuestion.id]"
          >
            {{ isLastQuestion ? 'Submit' : 'Next' }}
            <i :class="['fa', isLastQuestion ? 'fa-check' : 'fa-arrow-right']"></i>
          </button>
        </div>
      </div>
    </div>

    <!-- Submitting State -->
    <LoadingCheck 
      v-else-if="state === 'submitting'"
      loading-text="Saving your responses..."
      sub-text="Calculating your VESPA scores"
    />

    <!-- Success State -->
    <SuccessMessage
      v-else-if="state === 'success'"
      :scores="calculatedScores"
    />

    <!-- Error State -->
    <NotAvailable
      v-else-if="state === 'error'"
      reason="error"
      :message="errorMessage"
    />
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import LoadingCheck from './components/LoadingCheck.vue'
import InstructionsScreen from './components/InstructionsScreen.vue'
import NotAvailable from './components/NotAvailable.vue'
import ProgressIndicator from './components/ProgressIndicator.vue'
import QuestionCard from './components/QuestionCard.vue'
import SuccessMessage from './components/SuccessMessage.vue'

import { getKnackUser } from './services/knackAuth.js'
import { validateQuestionnaireAccess, submitQuestionnaire } from './services/api.js'
import { questions, categories } from './data/questions.js'
import { calculateVespaScores, validateResponses } from './services/vespaCalculator.js'

export default {
  name: 'App',
  components: {
    LoadingCheck,
    InstructionsScreen,
    NotAvailable,
    ProgressIndicator,
    QuestionCard,
    SuccessMessage
  },
  setup() {
    // State machine
    const state = ref('checking') // checking | instructions | not-available | questionnaire | submitting | success | error
    
    // User data
    const userData = ref({
      email: '',
      name: '',
      accountId: '',
      knackRecordId: ''
    })
    
    // Validation result
    const validationResult = ref({
      allowed: false,
      cycle: 1,
      reason: '',
      message: '',
      nextStartDate: '',
      userRecord: null,
      academicYear: ''
    })
    
    // Questionnaire data
    const currentQuestionIndex = ref(0)
    const responses = ref({})
    const calculatedScores = ref(null)
    const errorMessage = ref('')

    // Computed
    const currentQuestion = computed(() => questions[currentQuestionIndex.value])
    const isLastQuestion = computed(() => currentQuestionIndex.value === questions.length - 1)
    const currentCategoryColor = computed(() => {
      const category = currentQuestion.value?.category
      return categories[category]?.color || '#079baa'
    })

    // Methods
    async function initialize() {
      try {
        // Get Knack user
        const user = getKnackUser()
        userData.value = user

        console.log('[Questionnaire V2] User:', user.email)

        // TEMPORARY: Always bypass for initial styling testing
        // TODO: Remove this and use backend validation once endpoints are deployed
        console.log('[Questionnaire V2] DEVELOPMENT MODE - Bypassing validation for styling test')
        validationResult.value = {
          allowed: true,
          cycle: 1,
          reason: 'dev_mode',
          message: 'Development mode enabled',
          academicYear: '2025/2026',
          userRecord: { id: user.accountId || 'test_user', email: user.email }
        }
        state.value = 'instructions'
        return
        
        // COMMENTED OUT FOR NOW - Uncomment when backend is ready:
        /*
        // Validate questionnaire access
        const validation = await validateQuestionnaireAccess(user.email, user.accountId)
        validationResult.value = validation

        console.log('[Questionnaire V2] Validation:', validation)

        if (validation.allowed) {
          // Show instructions
          state.value = 'instructions'
        } else {
          // Show not available message
          state.value = 'not-available'
        }
        */

        // Validate questionnaire access
        const validation = await validateQuestionnaireAccess(user.email, user.accountId)
        validationResult.value = validation

        console.log('[Questionnaire V2] Validation:', validation)

        if (validation.allowed) {
          // Show instructions
          state.value = 'instructions'
        } else {
          // Show not available message
          state.value = 'not-available'
        }
      } catch (error) {
        console.error('[Questionnaire V2] Initialization error:', error)
        errorMessage.value = error.message || 'Unable to load questionnaire. Please try again later.'
        state.value = 'error'
      }
    }

    function startQuestionnaire() {
      state.value = 'questionnaire'
      currentQuestionIndex.value = 0
      responses.value = {}
      
      // Shuffle questions for randomization
      shuffleQuestions()
    }
    
    function shuffleQuestions() {
      // Fisher-Yates shuffle algorithm
      const shuffled = [...questions]
      for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]]
      }
      
      // Replace questions array with shuffled version
      // Note: We need to modify the reactive questions reference
      questions.length = 0
      shuffled.forEach(q => questions.push(q))
      
      console.log('[Questionnaire V2] Questions shuffled for randomization')
    }

    function nextQuestion() {
      // Validate current response
      if (!responses.value[currentQuestion.value.id]) {
        return
      }

      if (isLastQuestion.value) {
        submitResponses()
      } else {
        currentQuestionIndex.value++
      }
    }

    function previousQuestion() {
      if (currentQuestionIndex.value > 0) {
        currentQuestionIndex.value--
      }
    }

    async function submitResponses() {
      try {
        // Validate all responses
        const validation = validateResponses(responses.value, questions)
        
        if (!validation.valid) {
          alert('Please answer all questions before submitting:\n' + validation.errors.join('\n'))
          return
        }

        state.value = 'submitting'

        // Calculate VESPA scores
        const calculation = calculateVespaScores(responses.value, questions)
        calculatedScores.value = calculation.vespaScores

        console.log('[Questionnaire V2] Calculated scores:', calculation)

        // Prepare submission data
        const submissionData = {
          studentEmail: userData.value.email,
          studentName: userData.value.name,
          cycle: validationResult.value.cycle,
          responses: responses.value,
          vespaScores: calculation.vespaScores,
          categoryAverages: calculation.categoryAverages,
          outcomeAverage: calculation.outcomeAverage,
          knackRecordId: validationResult.value.userRecord?.id,
          academicYear: validationResult.value.academicYear
        }

        // Submit to backend
        const result = await submitQuestionnaire(submissionData)

        console.log('[Questionnaire V2] Submission result:', result)

        // Show success
        state.value = 'success'

      } catch (error) {
        console.error('[Questionnaire V2] Submission error:', error)
        errorMessage.value = error.message || 'Failed to save your responses. Please try again.'
        state.value = 'error'
      }
    }

    // Initialize on mount
    onMounted(() => {
      initialize()
    })

    return {
      state,
      userData,
      validationResult,
      currentQuestionIndex,
      responses,
      calculatedScores,
      errorMessage,
      questions,
      currentQuestion,
      isLastQuestion,
      currentCategoryColor,
      startQuestionnaire,
      nextQuestion,
      previousQuestion
    }
  }
}
</script>

<style scoped>
#vespa-questionnaire-app {
  min-height: 100vh;
  background: linear-gradient(135deg, var(--vespa-dark) 0%, var(--vespa-primary) 100%);
}

.questionnaire-container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.questionnaire-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  background: white;
  border-radius: 0 0 20px 20px;
  padding: 0;
  margin: 0 20px 20px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
  max-height: calc(100vh - 120px);
  overflow: hidden;
}

.navigation-buttons {
  display: flex;
  justify-content: space-between;
  gap: 15px;
  padding: 15px 20px;
  border-top: 1px solid #e0e0e0;
  flex-shrink: 0;
}

.navigation-buttons .btn {
  min-width: 140px;
}

/* Slide transition for questions */
.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease;
}

.slide-enter-from {
  opacity: 0;
  transform: translateX(30px);
}

.slide-leave-to {
  opacity: 0;
  transform: translateX(-30px);
}

@media (max-width: 768px) {
  .questionnaire-content {
    margin: 0;
    border-radius: 0;
  }

  .navigation-buttons {
    padding: 15px 20px;
    gap: 10px;
  }

  .navigation-buttons .btn {
    min-width: 120px;
    padding: 12px 20px;
    font-size: 15px;
  }
}
</style>
