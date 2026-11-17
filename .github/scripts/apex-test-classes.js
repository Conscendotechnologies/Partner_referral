#!/usr/bin/env node
// Prints the Apex classes under force-app that contain test methods, comma-separated.
// A class counts when it has an @IsTest-annotated void method or a testMethod; @IsTest helper classes
// with no test methods (for example PR_TestFactory) are left out, because they cannot be run as tests.
const fs = require('fs');
const path = require('path');

const root = process.argv[2] || 'force-app';
const TEST_METHOD = /@istest\b(\s*\([^)]*\))?\s+((public|private|global|protected)\s+)?(static\s+)?void\s+\w+\s*\(|\btestmethod\b/i;

function walk(dir, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.name.endsWith('.cls') && TEST_METHOD.test(fs.readFileSync(full, 'utf8'))) {
      out.push(entry.name.replace(/\.cls$/, ''));
    }
  }
  return out;
}

process.stdout.write(walk(root, []).sort().join(','));
