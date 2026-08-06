import QtQml
import qs.services
import "../../logic/EvaluationProfiles.js" as EvalProfiles

QtObject {
    readonly property var tracer: Logger.scope("backend.actions.audio", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.actions.audio", { category: "backend" })

    function roots(context) {
        tracer.trace("roots", function() { return { count: 2 }; });
        return [audioTree(), brightnessTree()];
    }

    function audioTree() {
        return {
            id: "audio",
            display: {
                title: qsTr("Audio"),
                icon: AudioService.outputIconName,
                iconColor: AudioService.outputMuted ? Config.styling.critical : Config.styling.secondaryAccent
            },
            match: {
                aliases: ["audio", "sound", "volume", "mute"],
                evaluationProfile: EvalProfiles.groupProfile()
            },
            template: "flat-action-group",
            behavior: { filterChildren: true, selectable: false },
            children: AudioService.outputDeviceEntries().map(function(entry) {
                return {
                    id: "sink-" + entry.id,
                    display: {
                        title: entry.name,
                        subtitle: entry.default ? qsTr("Default output") : qsTr("Output"),
                        icon: entry.iconName,
                        iconColor: entry.muted ? Config.styling.critical : Config.styling.secondaryAccent
                    },
                    match: {
                        aliases: ["sink", "output", "speaker", entry.name],
                        evaluationProfile: EvalProfiles.groupProfile()
                    },
                    template: "flat-action-group",
                    behavior: { filterChildren: true },
                    switchState: entry.muted,
                    control: entry.control,
                    switchActions: entry.switchActions,
                    children: streamChildren(entry.id)
                };
            })
        };
    }

    function streamChildren(outputId) {
        var streams = AudioService.streamEntriesForOutput(outputId);
        return streams.length > 0 ? [{
            id: "streams",
            display: {
                title: qsTr("Streams"),
                subtitle: streams.length + " " + qsTr("active"),
                icon: "audio-x-generic-symbolic",
                iconColor: Config.styling.text1
            },
            match: {
                aliases: ["streams", "apps", "applications"],
                fields: { subtitle: false },
                evaluationProfile: EvalProfiles.groupProfile()
            },
            template: "flat-action-group",
            behavior: { filterChildren: true },
            children: streams.map(function(stream) {
                return {
                    id: "stream-" + stream.id,
                    display: {
                        title: stream.name,
                        subtitle: stream.volume + "%",
                        icon: stream.iconName,
                        iconColor: stream.muted ? Config.styling.critical : Config.styling.secondaryAccent
                    },
                    match: {
                        aliases: ["stream", "volume", stream.name],
                        fields: { subtitle: false }
                    },
                    switchState: stream.muted,
                    control: stream.control,
                    switchActions: stream.switchActions
                };
            })
        }] : [];
    }

    function brightnessTree() {
        return {
            id: "brightness",
            display: {
                title: qsTr("Brightness"),
                subtitle: Brightness.available ? qsTr("Screen brightness") : qsTr("Backlight unavailable"),
                icon: Brightness.iconName,
                iconColor: Brightness.available ? Config.styling.primaryAccent : Config.styling.text2
            },
            match: {
                aliases: ["brightness", "backlight", "screen"],
                evaluationProfile: EvalProfiles.groupProfile()
            },
            template: "flat-action-group",
            behavior: { filterChildren: true },
            children: [{
                id: "brightness-volume",
                display: {
                    title: qsTr("Brightness"),
                    subtitle: Brightness.available ? (Brightness.percent + "%") : qsTr("Unavailable"),
                    icon: Brightness.iconName,
                    iconColor: Brightness.available ? Config.styling.primaryAccent : Config.styling.text2
                },
                match: {
                    aliases: ["brightness", "level", "slider"],
                    fields: { subtitle: false }
                },
                control: {
                    kind: "slider",
                    target: "brightness",
                    from: 0,
                    to: 100,
                    step: 5,
                    value: Brightness.percent
                }
            }]
        };
    }
}
