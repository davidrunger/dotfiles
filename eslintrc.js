const { env } = require('process');

module.exports = {
  env: {
    browser: true,
  },
  globals: {
    chrome: false, // globally available in browser extensions (?)
  },
  extends: [
    'eslint:recommended',
  ],
  parserOptions: {
    ecmaVersion: "latest",
    parser: '@typescript-eslint/parser',
    sourceType: 'module',
  },
  settings: {
    'import/parsers': {
      '@typescript-eslint/parser': ['.ts'],
    },
    'import/resolver': {
      typescript: {
        alwaysTryTypes: true,
      },
    },
  },
  rules: {
    '@typescript-eslint/no-empty-function': 'off',
    'arrow-parens': 'off',
    'function-paren-newline': 'off',
    'import/no-extraneous-dependencies': 'off',
    'import/prefer-default-export': 'off',
    'max-len': ['warn', { code: 100, ignoreUrls: true }],
    'newline-per-chained-call': 'off',
    'no-alert': 'off',
    'no-console': env.NODE_ENV === 'production' ? 'error' : 'warn',
    'no-debugger': env.NODE_ENV === 'production' ? 'error' : 'warn',
    'no-else-return': 'off',
    'no-new': 'off',
    'no-param-reassign': 'off',
    'no-plusplus': 'off',
    'no-restricted-imports': [
      'error',
      {
        paths: [
          {
            name: 'lodash',
            message: 'Use lodash-es.',
          },
        ],
      },
    ],
    'no-restricted-syntax': [
      'error',
      'ForInStatement',
      'LabeledStatement',
      'WithStatement',
    ],
    'no-underscore-dangle': 'off',
    'no-unreachable': env.NODE_ENV === 'production' ? 'error' : 'warn',
    'no-use-before-define': ['error', { functions: false }],
    // https://stackoverflow.com/a/64067915/4009384
    'no-unused-vars': 'off',
    'operator-linebreak': 'off',
    quotes: ['warn', 'single', { avoidEscape: true }],
    'require-await': 'error',
  },
};
