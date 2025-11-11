<template>
  <div class="question-renderer">
    <div v-if="question.text_above_question" 
         class="text-above" 
         v-html="question.text_above_question">
    </div>
    
    <label class="question-label">
      {{ question.question_title }}
      <span v-if="question.answer_required" class="required">*</span>
    </label>
    
    <!-- Short Text -->
    <input
      v-if="question.question_type === 'Short Text'"
      type="text"
      :value="modelValue"
      @input="updateValue($event.target.value)"
      class="input-text"
      :required="question.answer_required"
    />
    
    <!-- Paragraph Text -->
    <textarea
      v-else-if="question.question_type === 'Paragraph Text'"
      :value="modelValue"
      @input="updateValue($event.target.value)"
      class="input-textarea"
      rows="5"
      :required="question.answer_required"
    ></textarea>
    
    <!-- Dropdown -->
    <select
      v-else-if="question.question_type === 'Dropdown'"
      :value="modelValue"
      @change="updateValue($event.target.value)"
      class="input-select"
      :required="question.answer_required"
    >
      <option value="">Select an option...</option>
      <option
        v-for="option in dropdownOptions"
        :key="option"
        :value="option"
      >
        {{ option }}
      </option>
    </select>
    
    <!-- Checkboxes -->
    <div
      v-else-if="question.question_type === 'Checkboxes'"
      class="checkbox-group"
    >
      <label
        v-for="option in dropdownOptions"
        :key="option"
        class="checkbox-label"
      >
        <input
          type="checkbox"
          :value="option"
          :checked="isChecked(option)"
          @change="toggleCheckbox(option)"
        />
        <span>{{ option }}</span>
      </label>
    </div>
    
    <!-- Single Checkbox -->
    <label
      v-else-if="question.question_type === 'Single Checkbox'"
      class="checkbox-label"
    >
      <input
        type="checkbox"
        :checked="modelValue === true || modelValue === 'true'"
        @change="updateValue($event.target.checked)"
      />
      <span>{{ question.question_title }}</span>
    </label>
    
    <!-- Date -->
    <input
      v-else-if="question.question_type === 'Date'"
      type="date"
      :value="modelValue"
      @input="updateValue($event.target.value)"
      class="input-date"
      :required="question.answer_required"
    />
  </div>
</template>

<script setup>
import { computed, ref } from 'vue';

const props = defineProps({
  question: {
    type: Object,
    required: true
  },
  modelValue: {
    type: [String, Number, Boolean, Array],
    default: null
  }
});

const emit = defineEmits(['update:modelValue']);

const dropdownOptions = computed(() => {
  if (!props.question.dropdown_options) return [];
  if (Array.isArray(props.question.dropdown_options)) {
    return props.question.dropdown_options;
  }
  // Handle CSV string
  if (typeof props.question.dropdown_options === 'string') {
    return props.question.dropdown_options.split(',').map(s => s.trim());
  }
  return [];
});

const updateValue = (value) => {
  emit('update:modelValue', value);
};

const isChecked = (option) => {
  if (!props.modelValue) return false;
  if (Array.isArray(props.modelValue)) {
    return props.modelValue.includes(option);
  }
  return props.modelValue === option;
};

const toggleCheckbox = (option) => {
  let newValue = props.modelValue || [];
  if (!Array.isArray(newValue)) {
    newValue = [];
  }
  
  if (newValue.includes(option)) {
    newValue = newValue.filter(v => v !== option);
  } else {
    newValue = [...newValue, option];
  }
  
  emit('update:modelValue', newValue);
};
</script>

<style scoped>
.question-renderer {
  margin-bottom: var(--spacing-lg);
}

.text-above {
  margin-bottom: var(--spacing-md);
  color: var(--dark-gray);
  font-size: 0.875rem;
  line-height: 1.6;
}

.question-label {
  display: block;
  font-weight: 600;
  margin-bottom: var(--spacing-sm);
  color: var(--dark-blue);
}

.required {
  color: #dc3545;
}

.input-text,
.input-textarea,
.input-select,
.input-date {
  width: 100%;
  padding: var(--spacing-sm) var(--spacing-md);
  border: 2px solid var(--gray);
  border-radius: var(--radius-md);
  font-size: 1rem;
  font-family: inherit;
  transition: border-color 0.2s;
}

.input-text:focus,
.input-textarea:focus,
.input-select:focus,
.input-date:focus {
  outline: none;
  border-color: var(--primary);
}

.input-textarea {
  resize: vertical;
  min-height: 100px;
}

.checkbox-group {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  cursor: pointer;
  padding: var(--spacing-sm);
  border-radius: var(--radius-sm);
  transition: background 0.2s;
}

.checkbox-label:hover {
  background: var(--light-gray);
}

.checkbox-label input[type="checkbox"] {
  width: 18px;
  height: 18px;
  cursor: pointer;
}
</style>

