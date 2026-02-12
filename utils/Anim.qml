import QtQuick

QtObject {
    id: root

    readonly property int micro: 30

    readonly property int standard: 65

    readonly property int entry: 50

    readonly property int easingMicro: Easing.OutCubic

    readonly property int easingStandard: Easing.InOutCubic

    readonly property int easingEntry: Easing.OutCubic

    
    

    function createNumberAnimation(target, property, tier, from, to) {
        var duration = root.standard
        var easing = root.easingStandard
        
        if (tier === "micro") {
            duration = root.micro
            easing = root.easingMicro
        } else if (tier === "entry") {
            duration = root.entry
            easing = root.easingEntry
        }
        
        return Qt.createQmlObject(
            `import QtQuick
             NumberAnimation {
                 target: ${target}
                 property: "${property}"
                 duration: ${duration}
                 easing.type: ${easing}
                 ${from !== undefined ? `from: ${from}` : ''}
                 ${to !== undefined ? `to: ${to}` : ''}
             }`,
            target
        )
    }
    
    

    function createColorAnimation(tier) {
        var duration = root.standard
        var easing = root.easingStandard
        
        if (tier === "micro") {
            duration = root.micro
            easing = root.easingMicro
        } else if (tier === "entry") {
            duration = root.entry
            easing = root.easingEntry
        }
        
        return Qt.createQmlObject(
            `import QtQuick
             ColorAnimation {
                 duration: ${duration}
                 easing.type: ${easing}
             }`,
            root
        )
    }
    
    

    component NumberBehavior: Behavior {
        id: behavior
        property string tier: "standard"
        
        NumberAnimation {
            duration: (behavior.tier === "micro") ? root.micro 
                    : (behavior.tier === "entry") ? root.entry 
                    : root.standard
            easing.type: (behavior.tier === "micro") ? root.easingMicro
                      : (behavior.tier === "entry") ? root.easingEntry
                      : root.easingStandard
        }
    }
    
    

    component ColorBehavior: Behavior {
        id: behavior
        property string tier: "standard"
        
        ColorAnimation {
            duration: (behavior.tier === "micro") ? root.micro 
                    : (behavior.tier === "entry") ? root.entry 
                    : root.standard
            easing.type: (behavior.tier === "micro") ? root.easingMicro
                      : (behavior.tier === "entry") ? root.easingEntry
                      : root.easingStandard
        }
    }
}

