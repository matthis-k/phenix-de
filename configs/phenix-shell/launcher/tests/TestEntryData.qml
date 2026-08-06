// Entry display/match layering invariants.
//
// Usage from a launcher debug surface:
//   var component = Qt.createComponent("../tests/TestEntryData.qml")
//   var test = component.createObject(parent)
//   var report = test.runAll()

import QtQml
import Quickshell
import qs.services
import "../logic/EntryData.js" as EntryData
import "../logic/IndexBuilder.qml"

QtObject {
    readonly property var tracer: Logger.scope("test.entryData", { category: "test" })

    function testResult(ok, label, detail) {
        return { ok: ok, label: label, detail: detail || "" };
    }

    function runAll() {
        return {
            name: "EntryData",
            results: [
                testCanonicalDisplayOverridesLegacy(),
                testLegacyDataNormalizes(),
                testDisplayFieldsMatchByDefault(),
                testAliasesSupplementDisplay(),
                testSubtitleCanBeExcluded(),
                testFieldWeightOverride(),
                testLegacyLabelWeightOverride()
            ]
        };
    }

    function testCanonicalDisplayOverridesLegacy() {
        var display = EntryData.displayFor({
            title: "Legacy title",
            subtitle: "Legacy subtitle",
            display: { title: "Canonical title", subtitle: "Canonical subtitle" }
        });
        var ok = display.title === "Canonical title" && display.subtitle === "Canonical subtitle";
        return testResult(ok, "canonical-display-overrides-legacy", JSON.stringify(display));
    }

    function testLegacyDataNormalizes() {
        var source = {
            title: "Wi-Fi",
            subtitle: "Connected",
            aliases: ["wifi", "wireless"]
        };
        var display = EntryData.displayFor(source);
        var match = EntryData.matchFor(source);
        var ok = display.title === "Wi-Fi"
            && display.subtitle === "Connected"
            && match.aliases.length === 2
            && match.aliases[0] === "wifi";
        return testResult(ok, "legacy-data-normalizes", JSON.stringify({ display: display, match: match }));
    }

    function testDisplayFieldsMatchByDefault() {
        var fields = fieldsFor({
            display: { title: "Wi-Fi", subtitle: "Connected to Home" },
            match: {}
        });
        var ok = hasField(fields, "label", "Wi-Fi")
            && hasField(fields, "subtitle", "Connected to Home");
        return testResult(ok, "display-fields-match-by-default", fieldSummary(fields));
    }

    function testAliasesSupplementDisplay() {
        var fields = fieldsFor({
            display: { title: "Do Not Disturb" },
            match: { aliases: ["dnd", "focus mode"] }
        });
        var ok = hasField(fields, "label", "Do Not Disturb")
            && hasField(fields, "aliases", "dnd focus mode");
        return testResult(ok, "aliases-supplement-display", fieldSummary(fields));
    }

    function testSubtitleCanBeExcluded() {
        var fields = fieldsFor({
            display: { title: "Brightness", subtitle: "47%" },
            match: { fields: { subtitle: false } }
        });
        var ok = hasField(fields, "label", "Brightness")
            && !hasFieldName(fields, "subtitle");
        return testResult(ok, "subtitle-can-be-excluded", fieldSummary(fields));
    }

    function testFieldWeightOverride() {
        var fields = fieldsFor({
            display: { title: "Power Mode" },
            match: { fields: { title: { weight: 1.4 } } }
        });
        var titleField = fieldByName(fields, "label");
        var ok = !!titleField && Math.abs(titleField.weight - 1.4) < 0.0001;
        return testResult(ok, "field-weight-override", fieldSummary(fields));
    }

    function testLegacyLabelWeightOverride() {
        var fields = fieldsFor({
            display: { title: "Legacy weighted title" },
            fieldWeights: { label: 1.25 }
        });
        var titleField = fieldByName(fields, "label");
        var ok = !!titleField && Math.abs(titleField.weight - 1.25) < 0.0001;
        return testResult(ok, "legacy-label-weight-override", fieldSummary(fields));
    }

    function fieldsFor(entry) {
        var node = Object.assign({
            id: "test-entry",
            kind: "desktop-action"
        }, entry || {});
        return IndexBuilder.searchableFields(node);
    }

    function fieldByName(fields, name) {
        for (var i = 0; i < (fields || []).length; i += 1) {
            if (fields[i].field === name)
                return fields[i];
        }
        return null;
    }

    function hasFieldName(fields, name) {
        return !!fieldByName(fields, name);
    }

    function hasField(fields, name, text) {
        var field = fieldByName(fields, name);
        return !!field && field.text === text;
    }

    function fieldSummary(fields) {
        return JSON.stringify((fields || []).map(function(field) {
            return { field: field.field, text: field.text, weight: field.weight };
        }));
    }
}
