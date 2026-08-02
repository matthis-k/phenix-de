.pragma library

function highestPriority(votes, tieBreak) {
    if (!votes || votes.length === 0)
        return null;

    var best = votes[0];
    for (var i = 1; i < votes.length; i += 1) {
        var vote = votes[i];
        if (vote.priority > best.priority ||
            (vote.priority === best.priority && tieBreak === "last"))
            best = vote;
    }
    return best;
}

function best(votes, tieBreak) {
    if (!votes || votes.length === 0)
        return null;

    var selected = votes[0];
    for (var i = 1; i < votes.length; i += 1) {
        var vote = votes[i];
        var voteNumeric = typeof vote.decision === "number";
        var selectedNumeric = typeof selected.decision === "number";

        if (voteNumeric && selectedNumeric) {
            if (vote.priority > selected.priority ||
                (vote.priority === selected.priority && vote.decision > selected.decision))
                selected = vote;
        } else if (vote.priority > selected.priority ||
                   (vote.priority === selected.priority && tieBreak === "last")) {
            selected = vote;
        }
    }
    return selected;
}
