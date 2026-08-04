import QtQml

QtObject {
    id: root

    readonly property string overviewMode: "overview"
    readonly property string detailedMode: "detailed"

    function normalizeMode(mode) {
        return String(mode || "").toLowerCase() === root.detailedMode
            ? root.detailedMode
            : root.overviewMode;
    }

    function isDetailed(mode) {
        return root.normalizeMode(mode) === root.detailedMode;
    }

    function percentSeverity(value, warningThreshold, criticalThreshold) {
        const normalized = Number(value || 0);
        const warning = Number(warningThreshold || 75);
        const critical = Number(criticalThreshold || 90);
        if (normalized >= critical)
            return "critical";
        if (normalized >= warning)
            return "warning";
        return "normal";
    }

    function isPercentOutlier(value, average, options) {
        const opts = options || {};
        const normalized = Number(value || 0);
        const baseline = Number(average || 0);
        const warning = Number(opts.warningThreshold !== undefined ? opts.warningThreshold : 75);
        const critical = Number(opts.criticalThreshold !== undefined ? opts.criticalThreshold : 90);
        const deviation = Number(opts.deviationThreshold !== undefined ? opts.deviationThreshold : 25);

        return normalized >= critical
            || (normalized >= warning && normalized - baseline >= deviation);
    }

    function cpuCoreOutliers(corePercents, average, limit) {
        const values = Array.isArray(corePercents) ? corePercents : [];
        const rows = [];
        for (let index = 0; index < values.length; index += 1) {
            const percent = Number(values[index] || 0);
            if (!root.isPercentOutlier(percent, average, {
                    warningThreshold: 75,
                    criticalThreshold: 90,
                    deviationThreshold: 25
                }))
                continue;

            rows.push({
                index: index,
                key: `core${index}`,
                percent: percent,
                severity: root.percentSeverity(percent, 75, 90),
                promoted: true
            });
        }

        rows.sort(function(left, right) {
            if (right.percent !== left.percent)
                return right.percent - left.percent;
            return left.index - right.index;
        });

        return rows.slice(0, Math.max(1, Number(limit || 4)));
    }

    function allCpuCoreRows(corePercents) {
        const values = Array.isArray(corePercents) ? corePercents : [];
        return values.map(function(percent, index) {
            const normalized = Number(percent || 0);
            return {
                index: index,
                key: `core${index}`,
                percent: normalized,
                severity: root.percentSeverity(normalized, 75, 90),
                promoted: false
            };
        });
    }

    function cpuRows(corePercents, average, mode) {
        return root.isDetailed(mode)
            ? root.allCpuCoreRows(corePercents)
            : root.cpuCoreOutliers(corePercents, average, 4);
    }

    function partitionRows(partitions, mode) {
        const values = Array.isArray(partitions) ? partitions : [];
        if (root.isDetailed(mode))
            return values.slice();

        const result = [];
        const seen = {};

        function append(partition) {
            if (!partition)
                return;
            const key = String(partition.mount || partition.device || result.length);
            if (seen[key])
                return;
            seen[key] = true;
            result.push(partition);
        }

        for (const partition of values) {
            if (String(partition.mount || "") === "/")
                append(partition);
        }
        for (const partition of values) {
            if (Number(partition.percent || 0) >= 85)
                append(partition);
        }

        return result;
    }

    function audioEntries(entries, mode) {
        const values = Array.isArray(entries) ? entries : [];
        if (root.isDetailed(mode))
            return values.slice();

        const promoted = values.filter(function(entry) {
            return !!entry && (entry.default === true
                || (Array.isArray(entry.streams) && entry.streams.length > 0)
                || Number(entry.volume || 0) >= 100);
        });
        return promoted.length > 0 ? promoted : values.slice(0, 1);
    }

    function showDetail(mode, promoted) {
        return root.isDetailed(mode) || promoted === true;
    }
}
