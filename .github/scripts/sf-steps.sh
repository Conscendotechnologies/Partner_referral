#!/usr/bin/env bash
# Shared steps for the Salesforce workflows.
#   sf-steps.sh delta <from-ref> <to-ref>     build the changed-metadata package in ./delta (sfdx-git-delta)
#   sf-steps.sh deploy <validate|deploy>      check-only or real deploy of ./delta, running every Apex test class
#   sf-steps.sh tests                         run every Apex test class in the repo against the org
set -euo pipefail

TESTS="$(node .github/scripts/apex-test-classes.js force-app)"
summary() { echo "$*" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"; }

# A change set counts when either manifest has types: a deletion-only change has an empty package.xml and
# everything in destructiveChanges.xml, and must still be deployed.
has_changes() {
  grep -q '<types>' delta/package/package.xml 2>/dev/null ||
    grep -q '<types>' delta/destructiveChanges/destructiveChanges.xml 2>/dev/null
}

case "${1:-}" in
  delta)
    rm -rf delta && mkdir -p delta
    sf sgd source delta --from "$2" --to "$3" --output-dir delta --generate-delta --source-dir force-app
    echo "---- package.xml ----"; cat delta/package/package.xml
    echo "---- destructiveChanges.xml ----"; cat delta/destructiveChanges/destructiveChanges.xml
    ;;

  deploy)
    mode="$2"
    if ! has_changes; then
      echo "No Salesforce metadata changed: nothing to ${mode}."
      summary "### ${mode}: no Salesforce metadata changed"
      exit 0
    fi
    args=(--manifest delta/package/package.xml --wait 120 --json)
    if grep -q '<types>' delta/destructiveChanges/destructiveChanges.xml; then
      args+=(--post-destructive-changes delta/destructiveChanges/destructiveChanges.xml)
    fi
    if [ -n "$TESTS" ]; then
      args+=(--test-level RunSpecifiedTests)
      IFS=',' read -ra names <<< "$TESTS"
      for t in "${names[@]}"; do args+=(--tests "$t"); done
    else
      args+=(--test-level RunLocalTests)
    fi
    set +e
    if [ "$mode" = "validate" ]; then
      sf project deploy validate "${args[@]}" > deploy-result.json
    else
      sf project deploy start "${args[@]}" > deploy-result.json
    fi
    code=$?
    set -e
    node -e '
      const j = JSON.parse(require("fs").readFileSync("deploy-result.json", "utf8"));
      const r = j.result || {}, d = r.details || {}, mode = process.argv[1];
      const lines = [`### ${mode === "validate" ? "Check-only deploy (dry run)" : "Deploy"}: ${r.status || j.name || "Failed"}`,
        `Components: ${r.numberComponentsDeployed ?? 0}/${r.numberComponentsTotal ?? 0} · Tests run by the deploy: ${r.numberTestsCompleted ?? 0}/${r.numberTestsTotal ?? 0}`];
      for (const f of [].concat(d.componentFailures || [])) lines.push(`- ❌ ${f.componentType} ${f.fullName}: ${f.problem}`);
      for (const f of [].concat((d.runTestResult || {}).failures || [])) lines.push(`- ❌ ${f.name}.${f.methodName}: ${f.message}`);
      if (j.message && !r.status) lines.push(`- ${j.message}`);
      if (r.success && !r.numberTestsTotal) lines.push("> The org ran no tests during the deploy, so the next step runs every Apex test class explicitly.");
      console.log(lines.join("\n"));
      require("fs").appendFileSync(process.env.GITHUB_STEP_SUMMARY || "/dev/null", lines.join("\n") + "\n");
    ' "$mode"
    exit $code
    ;;

  tests)
    if [ -z "$TESTS" ]; then
      echo "No Apex test classes in the repo."; summary "### Apex tests: none in the repo"; exit 0
    fi
    echo "Running: $TESTS"
    mkdir -p test-results
    set +e
    sf apex run test --class-names "$TESTS" --code-coverage --wait 60 --output-dir test-results --result-format json > test-results/run.json
    code=$?
    set -e
    node -e '
      const j = JSON.parse(require("fs").readFileSync("test-results/run.json", "utf8"));
      const r = j.result || {}, s = r.summary || {};
      const lines = [`### Apex tests: ${s.outcome || "Failed"} (${s.passing ?? 0} passed, ${s.failing ?? 0} failed, org coverage ${s.orgWideCoverage || "n/a"})`];
      for (const t of (r.tests || []).filter((t) => t.Outcome !== "Pass")) lines.push(`- ❌ ${t.FullName}: ${t.Message}`);
      const low = ((r.coverage || {}).coverage || []).filter((c) => c.coveredPercent < 75);
      if (low.length) lines.push("", "Classes under 75% coverage: " + low.map((c) => `${c.name} ${c.coveredPercent}%`).join(", "));
      if (j.message && !s.outcome) lines.push(`- ${j.message}`);
      console.log(lines.join("\n"));
      require("fs").appendFileSync(process.env.GITHUB_STEP_SUMMARY || "/dev/null", lines.join("\n") + "\n");
    '
    exit $code
    ;;

  *)
    echo "usage: sf-steps.sh delta <from> <to> | deploy <validate|deploy> | tests" >&2
    exit 2
    ;;
esac
