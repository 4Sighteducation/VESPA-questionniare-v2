<template>
  <div class="question-card">
    <!-- Category Badge - HIDDEN FOR NOW -->
    <!-- 
    <div class="category-badge">
      <div 
        class="category-icon"
        :style="{ backgroundColor: categoryColor }"
      >
        {{ categoryLetter }}
      </div>
      <span class="category-name" :style="{ color: categoryColor }">
        {{ categoryName }}
      </span>
    </div>
    -->

    <!-- Question Text -->
    <h3 class="question-text">{{ question.text }}</h3>

    <!-- Likert Scale -->
    <div class="likert-scale">
      <label 
        v-for="option in likertOptions" 
        :key="option.value"
        class="likert-option"
        :class="{ 'selected': modelValue === option.value }"
      >
        <input 
          type="radio" 
          :name="`question-${question.id}`"
          :value="option.value"
          :checked="modelValue === option.value"
          @change="selectOption(option.value)"
          class="likert-input"
        >
        <div class="likert-circle">
          {{ option.value }}
        </div>
        <p class="likert-label" v-html="option.shortLabel"></p>
      </label>
    </div>

    <!-- Helper text for outcome questions -->
    <p v-if="question.category === 'OUTCOME'" class="helper-text">
      <i class="fa fa-info-circle"></i>
      This question helps us understand your overall confidence and doesn't affect your VESPA scores.
    </p>
  </div>
</template>

<script>
import { categories, likertScale } from '../data/questions.js'

export default {
  name: 'QuestionCard',
  props: {
    question: {
      type: Object,
      required: true
    },
    modelValue: {
      type: Number,
      default: null
    }
  },
  emits: ['update:modelValue'],
  data() {
    return {
      likertOptions: likertScale
    }
  },
  computed: {
    categoryData() {
      return categories[this.question.category] || {}
    },
    categoryName() {
      return this.categoryData.name || this.question.category
    },
    categoryColor() {
      return this.categoryData.color || '#079baa'
    },
    categoryLetter() {
      return this.categoryData.letter || this.question.category.charAt(0)
    }
  },
  methods: {
    selectOption(value) {
      this.$emit('update:modelValue', value)
    }
  }
}
</script>

<style scoped>
.question-card {
  text-align: center;
  padding: 10px 20px 5px 20px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  animation: fadeIn 0.4s ease-out;
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

.category-badge {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  padding: 12px 20px;
  background: #f5f5f5;
  border-radius: 25px;
  margin-bottom: 30px;
}

.category-icon {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: bold;
  font-size: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

.category-name {
  font-weight: 600;
  font-size: 18px;
}

.question-text {
  font-size: 20px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.2;
  margin: 0 0 15px 0;
  max-width: 800px;
  margin-left: auto;
  margin-right: auto;
}

.likert-scale {
  display: flex;
  justify-content: center;
  align-items: flex-start;
  gap: 20px;
  max-width: 800px;
  margin: 0 auto;
}

/* Wider on larger screens */
@media (min-width: 1200px) {
  .likert-scale {
    gap: 30px;
    max-width: 900px;
  }
  
  .likert-circle {
    width: 80px;
    height: 80px;
    font-size: 28px;
  }
  
  .likert-label {
    font-size: 14px;
  }
}

.likert-option {
  flex: 1;
  cursor: pointer;
  transition: all 0.3s ease;
}

.likert-option:hover {
  transform: translateY(-3px);
}

.likert-input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.likert-circle {
  width: 70px;
  height: 70px;
  border-radius: 50%;
  border: 3px solid #d0d0d0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  font-weight: 700;
  color: #999;
  background: white;
  transition: all 0.3s ease;
  margin: 0 auto 8px;
}

.likert-option.selected .likert-circle {
  background: linear-gradient(135deg, var(--vespa-secondary) 0%, var(--vespa-primary) 100%);
  border-color: var(--vespa-primary);
  color: white;
  transform: scale(1.1);
  box-shadow: 0 6px 20px rgba(7, 155, 170, 0.4);
}

.likert-option:hover .likert-circle {
  border-color: var(--vespa-primary);
  background: rgba(7, 155, 170, 0.05);
}

.likert-label {
  font-size: 13px;
  color: var(--text-secondary);
  line-height: 1.3;
  margin: 0;
  white-space: pre-line;
}

.likert-option.selected .likert-label {
  color: var(--vespa-primary);
  font-weight: 600;
}

.helper-text {
  color: var(--text-secondary);
  font-size: 14px;
  font-style: italic;
  margin: 20px 0 0 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.helper-text i {
  color: var(--vespa-primary);
}

@media (max-width: 768px) {
  .question-card {
    padding: 12px 15px;
  }

  .question-text {
    font-size: 18px;
    margin-bottom: 20px;
  }

  .likert-scale {
    gap: 8px;
  }

  .likert-circle {
    width: 56px;
    height: 56px;
    font-size: 20px;
  }

  .likert-label {
    font-size: 11px;
  }
}

@media (max-width: 480px) {
  .question-card {
    padding: 10px 12px;
  }

  .question-text {
    font-size: 16px;
    margin-bottom: 15px;
  }

  .likert-scale {
    gap: 6px;
  }

  .likert-circle {
    width: 50px;
    height: 50px;
    font-size: 18px;
  }

  .likert-label {
    font-size: 10px;
  }
}
</style>

