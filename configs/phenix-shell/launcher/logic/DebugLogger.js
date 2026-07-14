.pragma library

function log(category, message, data) {
  console.warn("[SEARCH:" + category + "]", message, data ? JSON.stringify(data).slice(0, 500) : "");
}

function logExecute(candidateId, actionId, dryRun, safe) {
  log("execute", "Execution attempt", {
    candidateId: candidateId,
    actionId: actionId,
    dryRun: dryRun,
    safe: safe
  });
}

function logError(message, error) {
  log("error", message, {
    error: error ? error.toString() : null
  });
}
