/**
 * Activity Service - Handles all activity-related API calls
 */

import supabase from '../../shared/supabaseClient';
import { API_BASE_URL, API_ENDPOINTS } from '../../shared/constants';

export class ActivityService {
  /**
   * Fetch recommended activities based on VESPA scores
   */
  static async getRecommendedActivities(studentEmail, cycle = 1) {
    const response = await fetch(
      `${API_BASE_URL}${API_ENDPOINTS.RECOMMENDED_ACTIVITIES}?email=${studentEmail}&cycle=${cycle}`
    );
    
    if (!response.ok) {
      throw new Error('Failed to fetch recommended activities');
    }
    
    const data = await response.json();
    return data;
  }
  
  /**
   * Fetch activities by problem ID
   */
  static async getActivitiesByProblem(problemId) {
    const response = await fetch(
      `${API_BASE_URL}${API_ENDPOINTS.ACTIVITIES_BY_PROBLEM}?problem_id=${problemId}`
    );
    
    if (!response.ok) {
      throw new Error('Failed to fetch activities by problem');
    }
    
    const data = await response.json();
    return data.activities;
  }
  
  /**
   * Fetch student's assigned activities
   */
  static async getMyActivities(studentEmail, cycle = 1) {
    const response = await fetch(
      `${API_BASE_URL}${API_ENDPOINTS.ASSIGNED_ACTIVITIES}?email=${studentEmail}&cycle=${cycle}`
    );
    
    if (!response.ok) {
      throw new Error('Failed to fetch assigned activities');
    }
    
    const data = await response.json();
    return data.assignments;
  }
  
  /**
   * Fetch questions for an activity
   */
  static async getActivityQuestions(activityId) {
    const { data, error } = await supabase
      .from('activity_questions')
      .select('*')
      .eq('activity_id', activityId)
      .eq('is_active', true)
      .order('display_order');
    
    if (error) throw error;
    return data;
  }
  
  /**
   * Start an activity
   */
  static async startActivity(studentEmail, activityId, selectedVia = 'student_choice', cycle = 1) {
    const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.START_ACTIVITY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        studentEmail,
        activityId,
        selectedVia,
        cycle
      })
    });
    
    if (!response.ok) {
      throw new Error('Failed to start activity');
    }
    
    return await response.json();
  }
  
  /**
   * Auto-save activity progress
   */
  static async saveProgress(studentEmail, activityId, responses, timeMinutes, cycle = 1) {
    const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.SAVE_PROGRESS}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        studentEmail,
        activityId,
        responses,
        timeMinutes,
        cycle
      })
    });
    
    if (!response.ok) {
      throw new Error('Failed to save progress');
    }
    
    return await response.json();
  }
  
  /**
   * Complete an activity
   */
  static async completeActivity(studentEmail, activityId, responses, reflection, timeMinutes, wordCount, cycle = 1) {
    const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.COMPLETE_ACTIVITY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        studentEmail,
        activityId,
        responses,
        reflection,
        timeMinutes,
        wordCount,
        cycle
      })
    });
    
    if (!response.ok) {
      throw new Error('Failed to complete activity');
    }
    
    return await response.json();
  }
  
  /**
   * Get existing response for an activity
   */
  static async getExistingResponse(studentEmail, activityId, cycle = 1) {
    const { data, error } = await supabase
      .from('activity_responses')
      .select('*')
      .eq('student_email', studentEmail)
      .eq('activity_id', activityId)
      .eq('cycle_number', cycle)
      .single();
    
    if (error && error.code !== 'PGRST116') {  // PGRST116 = not found, which is OK
      throw error;
    }
    
    return data;
  }
  
  /**
   * Fetch all activities (for browse/search)
   */
  static async getAllActivities(filters = {}) {
    let query = supabase
      .from('activities')
      .select('*')
      .eq('is_active', true);
    
    if (filters.category) {
      query = query.eq('vespa_category', filters.category);
    }
    
    if (filters.level) {
      query = query.eq('level', filters.level);
    }
    
    query = query.order('display_order');
    
    const { data, error } = await query;
    
    if (error) throw error;
    return data;
  }
}

export default ActivityService;


