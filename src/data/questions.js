/**
 * VESPA Questionnaire Questions
 * All 32 questions with field mappings for Knack dual-write
 * Based on Object_29 mapping and psychometric_question_details.json
 */

export const questions = [
  // 29 VESPA Questions (q1-q28 + q29)
  {
    id: 'q1',
    text: "I've worked out the next steps I need to take to reach my career goals",
    category: 'VISION',
    order: 1,
    knackFields: {
      current: 'field_794',
      cycle1: 'field_1953',
      cycle2: 'field_1955',
      cycle3: 'field_1956'
    }
  },
  {
    id: 'q2',
    text: "I plan and organise my time so that I can fit in all my school work as well as other activities",
    category: 'SYSTEMS',
    order: 2,
    knackFields: {
      current: 'field_795',
      cycle1: 'field_1954',
      cycle2: 'field_1957',
      cycle3: 'field_1958'
    }
  },
  {
    id: 'q3',
    text: "I give a lot of attention to my career planning",
    category: 'VISION',
    order: 3,
    knackFields: {
      current: 'field_796',
      cycle1: 'field_1959',
      cycle2: 'field_1960',
      cycle3: 'field_1961'
    }
  },
  {
    id: 'q4',
    text: "I complete all my homework on time",
    category: 'SYSTEMS',
    order: 4,
    knackFields: {
      current: 'field_797',
      cycle1: 'field_1962',
      cycle2: 'field_1963',
      cycle3: 'field_1964'
    }
  },
  {
    id: 'q5',
    text: "No matter who you are, you can change your intelligence a lot",
    category: 'ATTITUDE',
    order: 5,
    knackFields: {
      current: 'field_798',
      cycle1: 'field_1965',
      cycle2: 'field_1966',
      cycle3: 'field_1967'
    }
  },
  {
    id: 'q6',
    text: "I use all my independent study time effectively",
    category: 'EFFORT',
    order: 6,
    knackFields: {
      current: 'field_799',
      cycle1: 'field_1968',
      cycle2: 'field_1969',
      cycle3: 'field_1970'
    }
  },
  {
    id: 'q7',
    text: "I test myself on important topics until I remember them",
    category: 'PRACTICE',
    order: 7,
    knackFields: {
      current: 'field_800',
      cycle1: 'field_1971',
      cycle2: 'field_1972',
      cycle3: 'field_1973'
    }
  },
  {
    id: 'q8',
    text: "I have a positive view of myself",
    category: 'ATTITUDE',
    order: 8,
    knackFields: {
      current: 'field_801',
      cycle1: 'field_1974',
      cycle2: 'field_1975',
      cycle3: 'field_1976'
    }
  },
  {
    id: 'q9',
    text: "I am a hard working student",
    category: 'EFFORT',
    order: 9,
    knackFields: {
      current: 'field_802',
      cycle1: 'field_1977',
      cycle2: 'field_1978',
      cycle3: 'field_1979'
    }
  },
  {
    id: 'q10',
    text: "I am confident in my academic ability",
    category: 'ATTITUDE',
    order: 10,
    knackFields: {
      current: 'field_803',
      cycle1: 'field_1980',
      cycle2: 'field_1981',
      cycle3: 'field_1982'
    }
  },
  {
    id: 'q11',
    text: "I always meet deadlines",
    category: 'SYSTEMS',
    order: 11,
    knackFields: {
      current: 'field_804',
      cycle1: 'field_1983',
      cycle2: 'field_1984',
      cycle3: 'field_1985'
    }
  },
  {
    id: 'q12',
    text: "I spread out my revision, rather than cramming at the last minute",
    category: 'PRACTICE',
    order: 12,
    knackFields: {
      current: 'field_805',
      cycle1: 'field_1986',
      cycle2: 'field_1987',
      cycle3: 'field_1988'
    }
  },
  {
    id: 'q13',
    text: "I don't let a poor test/assessment result get me down for too long",
    category: 'ATTITUDE',
    order: 13,
    knackFields: {
      current: 'field_806',
      cycle1: 'field_1989',
      cycle2: 'field_1990',
      cycle3: 'field_1991'
    }
  },
  {
    id: 'q14',
    text: "I strive to achieve the goals I set for myself",
    category: 'VISION',
    order: 14,
    knackFields: {
      current: 'field_807',
      cycle1: 'field_1992',
      cycle2: 'field_1993',
      cycle3: 'field_1994'
    }
  },
  {
    id: 'q15',
    text: "I summarise important information in diagrams, tables or lists",
    category: 'PRACTICE',
    order: 15,
    knackFields: {
      current: 'field_808',
      cycle1: 'field_1995',
      cycle2: 'field_1996',
      cycle3: 'field_1997'
    }
  },
  {
    id: 'q16',
    text: "I enjoy learning new things",
    category: 'VISION',
    order: 16,
    knackFields: {
      current: 'field_809',
      cycle1: 'field_1998',
      cycle2: 'field_1999',
      cycle3: 'field_2000'
    }
  },
  {
    id: 'q17',
    text: "I'm not happy unless my work is the best it can be",
    category: 'EFFORT',
    order: 17,
    knackFields: {
      current: 'field_810',
      cycle1: 'field_2001',
      cycle2: 'field_2002',
      cycle3: 'field_2003'
    }
  },
  {
    id: 'q18',
    text: "I take good notes in class which are useful for revision",
    category: 'SYSTEMS',
    order: 18,
    knackFields: {
      current: 'field_811',
      cycle1: 'field_2004',
      cycle2: 'field_2005',
      cycle3: 'field_2006'
    }
  },
  {
    id: 'q19',
    text: "When revising I mix different kinds of topics/subjects in one study session",
    category: 'PRACTICE',
    order: 19,
    knackFields: {
      current: 'field_812',
      cycle1: 'field_2007',
      cycle2: 'field_2008',
      cycle3: 'field_2009'
    }
  },
  {
    id: 'q20',
    text: "I feel I can cope with the pressure at school/college/University",
    category: 'ATTITUDE',
    order: 20,
    knackFields: {
      current: 'field_813',
      cycle1: 'field_2010',
      cycle2: 'field_2011',
      cycle3: 'field_2012'
    }
  },
  {
    id: 'q21',
    text: "I work as hard as I can in most classes",
    category: 'EFFORT',
    order: 21,
    knackFields: {
      current: 'field_814',
      cycle1: 'field_2013',
      cycle2: 'field_2014',
      cycle3: 'field_2015'
    }
  },
  {
    id: 'q22',
    text: "My books/files are organised",
    category: 'SYSTEMS',
    order: 22,
    knackFields: {
      current: 'field_815',
      cycle1: 'field_2016',
      cycle2: 'field_2017',
      cycle3: 'field_2018'
    }
  },
  {
    id: 'q23',
    text: "I study by explaining difficult topics out loud",
    category: 'PRACTICE',
    order: 23,
    knackFields: {
      current: 'field_816',
      cycle1: 'field_2019',
      cycle2: 'field_2020',
      cycle3: 'field_2021'
    }
  },
  {
    id: 'q24',
    text: "I'm happy to ask questions in front of a group",
    category: 'ATTITUDE',
    order: 24,
    knackFields: {
      current: 'field_817',
      cycle1: 'field_2022',
      cycle2: 'field_2023',
      cycle3: 'field_2024'
    }
  },
  {
    id: 'q25',
    text: "When revising, I work under timed conditions answering exam-style questions",
    category: 'PRACTICE',
    order: 25,
    knackFields: {
      current: 'field_818',
      cycle1: 'field_2025',
      cycle2: 'field_2026',
      cycle3: 'field_2027'
    }
  },
  {
    id: 'q26',
    text: "Your intelligence is something about you that you can change very much",
    category: 'ATTITUDE',
    order: 26,
    knackFields: {
      current: 'field_819',
      cycle1: 'field_2028',
      cycle2: 'field_2029',
      cycle3: 'field_2030'
    }
  },
  {
    id: 'q27',
    text: "I like hearing feedback about how I can improve",
    category: 'ATTITUDE',
    order: 27,
    knackFields: {
      current: 'field_820',
      cycle1: 'field_2031',
      cycle2: 'field_2032',
      cycle3: 'field_2033'
    }
  },
  {
    id: 'q28',
    text: "I can control my nerves in tests/practical assessments",
    category: 'ATTITUDE',
    order: 28,
    knackFields: {
      current: 'field_821',
      cycle1: 'field_2034',
      cycle2: 'field_2035',
      cycle3: 'field_2036'
    }
  },
  {
    id: 'q29',
    text: "I know what grades I want to achieve",
    category: 'VISION',
    order: 29,
    knackFields: {
      current: 'field_2317',
      cycle1: 'field_2927',
      cycle2: 'field_2928',
      cycle3: 'field_2929'
    }
  },
  
  // 3 Outcome Questions (don't affect VESPA scores but are collected)
  {
    id: 'q30',
    text: "I have the support I need to achieve this year",
    category: 'OUTCOME',
    order: 30,
    knackFields: {
      current: 'field_1816',
      cycle1: 'field_2037',
      cycle2: 'field_2038',
      cycle3: 'field_2039'
    }
  },
  {
    id: 'q31',
    text: "I feel equipped to face the study and revision challenges this year",
    category: 'OUTCOME',
    order: 31,
    knackFields: {
      current: 'field_1817',
      cycle1: 'field_2040',
      cycle2: 'field_2041',
      cycle3: 'field_2042'
    }
  },
  {
    id: 'q32',
    text: "I am confident I will achieve my potential in my final exams",
    category: 'OUTCOME',
    order: 32,
    knackFields: {
      current: 'field_1818',
      cycle1: 'field_2043',
      cycle2: 'field_2044',
      cycle3: 'field_2045'
    }
  }
]

// Category metadata
export const categories = {
  VISION: {
    name: 'Vision',
    description: 'Your goals and future planning',
    color: '#ff8f00',
    icon: 'fa-eye',
    letter: 'V'
  },
  EFFORT: {
    name: 'Effort',
    description: 'Your work ethic and perseverance',
    color: '#86b4f0',
    icon: 'fa-dumbbell',
    letter: 'E'
  },
  SYSTEMS: {
    name: 'Systems',
    description: 'Your organization and time management',
    color: '#72cb44',
    icon: 'fa-cogs',
    letter: 'S'
  },
  PRACTICE: {
    name: 'Practice',
    description: 'Your study techniques and methods',
    color: '#7f31a4',
    icon: 'fa-book',
    letter: 'P'
  },
  ATTITUDE: {
    name: 'Attitude',
    description: 'Your mindset and resilience',
    color: '#f032e6',
    icon: 'fa-smile',
    letter: 'A'
  },
  OUTCOME: {
    name: 'Outcome',
    description: 'Your confidence and preparedness',
    color: '#2196f3',
    icon: 'fa-flag-checkered',
    letter: 'O'
  }
}

// Likert scale options
export const likertScale = [
  { value: 1, label: 'Strongly Disagree', shortLabel: 'Strongly\nDisagree' },
  { value: 2, label: 'Disagree', shortLabel: 'Disagree' },
  { value: 3, label: 'Neutral', shortLabel: 'Neutral' },
  { value: 4, label: 'Agree', shortLabel: 'Agree' },
  { value: 5, label: 'Strongly Agree', shortLabel: 'Strongly\nAgree' }
]

