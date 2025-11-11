<template>
  <div class="category-filter">
    <button
      v-for="category in categories"
      :key="category"
      @click="selectCategory(category)"
      class="filter-btn"
      :class="{ active: modelValue === category }"
      :style="{ 
        borderColor: modelValue === category ? categoryColors[category] : 'transparent',
        backgroundColor: modelValue === category ? categoryColors[category] + '20' : 'transparent'
      }"
    >
      {{ category }}
    </button>
    <button
      v-if="modelValue"
      @click="clearFilter"
      class="filter-btn clear"
    >
      Clear Filter
    </button>
  </div>
</template>

<script setup>
import { VESPA_CATEGORIES, CATEGORY_COLORS } from '../../shared/constants';

const props = defineProps({
  modelValue: {
    type: String,
    default: null
  }
});

const emit = defineEmits(['update:modelValue']);

const categories = VESPA_CATEGORIES;
const categoryColors = CATEGORY_COLORS;

const selectCategory = (category) => {
  emit('update:modelValue', props.modelValue === category ? null : category);
};

const clearFilter = () => {
  emit('update:modelValue', null);
};
</script>

<style scoped>
.category-filter {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
}

.filter-btn {
  padding: var(--spacing-xs) var(--spacing-md);
  border: 2px solid transparent;
  border-radius: var(--radius-md);
  background: white;
  color: var(--text);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.filter-btn:hover {
  transform: translateY(-1px);
  box-shadow: var(--shadow-sm);
}

.filter-btn.active {
  color: var(--dark-blue);
  font-weight: 600;
}

.filter-btn.clear {
  border-color: var(--dark-gray);
  color: var(--dark-gray);
}
</style>

