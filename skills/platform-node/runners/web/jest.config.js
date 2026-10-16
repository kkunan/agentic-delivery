const path = require('path');
const nextJest = require(path.join(process.cwd(), 'node_modules/next/jest'));

const createJestConfig = nextJest({ dir: process.cwd() });

module.exports = createJestConfig({
  rootDir: process.cwd(),
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['@testing-library/jest-dom', path.join(__dirname, 'jest.setup.js')],
  testMatch: ['<rootDir>/**/*.test.ts', '<rootDir>/**/*.test.tsx'],
  testPathIgnorePatterns: ['/node_modules/', '/.next/', '<rootDir>/.worktrees/'],
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' },
});
