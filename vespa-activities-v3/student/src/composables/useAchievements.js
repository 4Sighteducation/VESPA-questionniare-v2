/**
 * useAchievements Composable
 * Manages student achievements and gamification
 */

import { ref, computed } from 'vue';
import supabase from '../../shared/supabaseClient';
import { API_BASE_URL, API_ENDPOINTS } from '../../shared/constants';

export function useAchievements(studentEmail) {
  // State
  const achievements = ref([]);
  const totalPoints = ref(0);
  const loading = ref(false);
  const error = ref(null);
  
  // Computed
  const pinnedAchievements = computed(() => {
    return achievements.value.filter(a => a.is_pinned);
  });
  
  const recentAchievements = computed(() => {
    return [...achievements.value]
      .sort((a, b) => new Date(b.date_earned) - new Date(a.date_earned))
      .slice(0, 5);
  });
  
  const achievementsByType = computed(() => {
    const grouped = {};
    achievements.value.forEach(achievement => {
      const type = achievement.achievement_type;
      if (!grouped[type]) {
        grouped[type] = [];
      }
      grouped[type].push(achievement);
    });
    return grouped;
  });
  
  // Methods
  const fetchAchievements = async () => {
    try {
      loading.value = true;
      error.value = null;
      
      console.log('[useAchievements] Fetching achievements for:', studentEmail);
      
      // Fetch achievements
      const { data: achievementsData, error: achievementsError } = await supabase
        .from('student_achievements')
        .select('*')
        .eq('student_email', studentEmail)
        .order('date_earned', { ascending: false });
      
      if (achievementsError) throw achievementsError;
      
      achievements.value = achievementsData || [];
      
      // Calculate total points from achievements
      totalPoints.value = achievements.value.reduce((sum, a) => sum + (a.points_value || 0), 0);
      
      console.log('[useAchievements] ✅ Loaded achievements:', achievements.value.length, 'Total points:', totalPoints.value);
      
      // Fetch from API endpoint (cached totals from vespa_students table)
      try {
        const response = await fetch(
          `${API_BASE_URL}/api/students/stats?email=${studentEmail}`
        );
        
        if (response.ok) {
          const data = await response.json();
          if (data.total_points !== undefined) {
            // Use API value if available (more accurate, includes all sources)
            totalPoints.value = data.total_points || totalPoints.value;
            console.log('[useAchievements] ✅ Updated total_points from API:', totalPoints.value);
          }
        } else {
          console.warn('[useAchievements] Could not fetch student stats from API, using calculated total');
        }
      } catch (err) {
        console.warn('[useAchievements] Error fetching student stats:', err);
        // Continue with calculated totalPoints from achievements
      }
      
    } catch (err) {
      console.error('[useAchievements] Error fetching achievements:', err);
      error.value = err.message;
    } finally {
      loading.value = false;
    }
  };
  
  const checkNewAchievements = async () => {
    try {
      console.log('[useAchievements] Checking for new achievements...');
      
      const response = await fetch(
        `${API_BASE_URL}${API_ENDPOINTS.CHECK_ACHIEVEMENTS}?email=${studentEmail}`
      );
      
      if (!response.ok) {
        throw new Error('Failed to check achievements');
      }
      
      const data = await response.json();
      const newAchievements = data.newAchievements || [];
      
      if (newAchievements.length > 0) {
        console.log('[useAchievements] 🏆 New achievements earned:', newAchievements.length);
        
        // Add to local state
        achievements.value.unshift(...newAchievements);
        
        // Recalculate total points
        totalPoints.value = achievements.value.reduce((sum, a) => sum + (a.points_value || 0), 0);
        
        // Show celebration modal/animation
        showAchievementCelebration(newAchievements);
        
        return newAchievements;
      }
      
      return [];
      
    } catch (err) {
      console.error('[useAchievements] Error checking achievements:', err);
      return [];
    }
  };
  
  const showAchievementCelebration = (newAchievements) => {
    // Create celebratory overlay
    newAchievements.forEach((achievement, index) => {
      setTimeout(() => {
        const overlay = document.createElement('div');
        overlay.className = 'achievement-celebration';
        overlay.style.cssText = `
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0,0,0,0.7);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 99999;
          animation: fadeIn 0.3s ease-out;
        `;
        
        overlay.innerHTML = `
          <div style="background: white; padding: 40px; border-radius: 16px; text-align: center; max-width: 400px; animation: bounceIn 0.5s ease-out;">
            <div style="font-size: 64px; margin-bottom: 20px;">${achievement.icon_emoji}</div>
            <h2 style="margin: 0 0 12px 0; color: #079baa;">Achievement Unlocked!</h2>
            <h3 style="margin: 0 0 12px 0; font-size: 24px;">${achievement.achievement_name}</h3>
            <p style="color: #666; margin-bottom: 20px;">${achievement.achievement_description}</p>
            <div style="font-size: 20px; font-weight: 600; color: #ff8f00;">+${achievement.points_value} points</div>
            <button onclick="this.parentElement.parentElement.remove()" 
                    style="margin-top: 24px; padding: 12px 32px; background: #079baa; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer;">
              Awesome!
            </button>
          </div>
        `;
        
        document.body.appendChild(overlay);
        
        // Auto-remove after 10 seconds
        setTimeout(() => {
          overlay.style.animation = 'fadeOut 0.3s ease-in';
          setTimeout(() => overlay.remove(), 300);
        }, 10000);
        
      }, index * 500);  // Stagger if multiple achievements
    });
  };
  
  return {
    // State
    achievements,
    totalPoints,
    loading,
    error,
    
    // Computed
    pinnedAchievements,
    recentAchievements,
    achievementsByType,
    
    // Methods
    fetchAchievements,
    checkNewAchievements
  };
}

export default useAchievements;


