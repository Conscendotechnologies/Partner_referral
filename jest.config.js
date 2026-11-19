const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
    // automation-testing/ holds Playwright specs (*.spec.ts) run by @playwright/test, not by LWC Jest.
    testPathIgnorePatterns: [...(jestConfig.testPathIgnorePatterns || ['<rootDir>/node_modules/']), '<rootDir>/automation-testing/']
};
