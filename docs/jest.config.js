module.exports = {
  rootDir: __dirname,
  displayName: 'docs',
  testEnvironment: 'jsdom',
  testMatch: ['**/*.test.(js|ts|tsx)'],
  setupFilesAfterEnv: ['@testing-library/jest-dom/extend-expect'],
  clearMocks: true,
  coverageDirectory: '<rootDir>/coverage',
  moduleNameMapper: {
    '^~(.*)$': '<rootDir>/$1',
  },
};
