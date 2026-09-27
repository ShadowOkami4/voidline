import QtQuick
import "../../components"
import "../../core"
import "../../services"

SettingsMasonry {
    id: root
    width: parent ? parent.width : 0
    spacing: 18

    // "devices" lists hardware; "input" is the Mouse & keyboard page.
    property string page: "devices"
    property string selectedKind: ""
    property var selectedDevice: null

    readonly property var categories: [
        { kind: "bluetooth", title: I18n.tr("devices.bluetooth.title"), singular: I18n.tr("devices.bluetooth.singular"),
            icon: "bluetooth", capability: "bluetooth", description: I18n.tr("devices.bluetooth.description") },
        { kind: "printscan", title: I18n.tr("devices.printscan.title"), singular: I18n.tr("devices.printscan.singular"),
            icon: "print", capability: "printscan", description: I18n.tr("devices.printscan.description") },
        { kind: "camera", title: I18n.tr("devices.camera.title"), singular: I18n.tr("devices.camera.singular"),
            icon: "photo_camera", capability: "cameras", description: I18n.tr("devices.camera.description") },
        { kind: "usb", title: I18n.tr("devices.usb.title"), singular: I18n.tr("devices.usb.singular"),
            icon: "usb", capability: "", description: I18n.tr("devices.usb.description") },
        { kind: "storage", title: I18n.tr("devices.storage.title"), singular: I18n.tr("devices.storage.singular"),
            icon: "hard_drive", capability: "", description: I18n.tr("devices.storage.description") },
        { kind: "audio", title: I18n.tr("devices.audio.title"), singular: I18n.tr("devices.audio.singular"),
            icon: "speaker", capability: "audio", description: I18n.tr("devices.audio.description") },
        { kind: "keyboard", title: I18n.tr("devices.keyboard.title"), singular: I18n.tr("devices.keyboard.singular"),
            icon: "keyboard", capability: "", description: I18n.tr("devices.keyboard.description") },
        { kind: "mouse", title: I18n.tr("devices.mouse.title"), singular: I18n.tr("devices.mouse.singular"),
            icon: "mouse", capability: "", description: I18n.tr("devices.mouse.description") },
        { kind: "touchpad", title: I18n.tr("devices.touchpad.title"), singular: I18n.tr("devices.touchpad.singular"),
            icon: "touchpad_mouse", capability: "", description: I18n.tr("devices.touchpad.description") },
        { kind: "touchscreen", title: I18n.tr("devices.touchscreen.title"), singular: I18n.tr("devices.touchscreen.singular"),
            icon: "touch_app", capability: "", description: I18n.tr("devices.touchscreen.description") },
        { kind: "tablet", title: I18n.tr("devices.tablet.title"), singular: I18n.tr("devices.tablet.singular"),
            icon: "draw", capability: "", description: I18n.tr("devices.tablet.description") },
        { kind: "controller", title: I18n.tr("devices.controller.title"), singular: I18n.tr("devices.controller.singular"),
            icon: "sports_esports", capability: "", description: I18n.tr("devices.controller.description") }
    ]

    readonly property var selectedCategory: {
        for (let index = 0; index < categories.length; ++index) {
            if (categories[index].kind === selectedKind)
                return categories[index]
        }
        return categories[0]
    }
    readonly property var selectedList: selectedKind.length > 0
        ? SystemSettingsService.list(selectedKind) : []
    readonly property var printerList: SystemSettingsService.list("printer")
    readonly property var scannerList: SystemSettingsService.list("scanner")
    readonly property string selectedDeviceKind: selectedDevice
        ? String(selectedDevice.kind || selectedKind) : selectedKind
    readonly property int totalDeviceCount: {
        let total = 0
        for (let index = 0; index < categories.length; ++index)
            total += count(categories[index].kind)
        return total
    }

    function count(kind) {
        return SystemSettingsService.list(kind).length
    }

    function categoryAvailable(category) {
        if (category.kind === "printscan")
            return SystemSettingsService.available("cups")
                || SystemSettingsService.available("scanners")
        return category.capability.length === 0
            || SystemSettingsService.available(category.capability)
    }

    function iconForDevice(device) {
        const kind = device ? String(device.kind || selectedKind) : selectedKind
        if (kind === "printer")
            return "print"
        if (kind === "scanner")
            return "scanner"
        return selectedCategory.icon
    }

    function scannerEmptyMessage() {
        if (!SystemSettingsService.available("scanners"))
            return "Install SANE to enable scanner discovery"
        if (!SystemSettingsService.available("airscan"))
            return "Install sane-airscan for driverless network scanners"
        if (!SystemSettingsService.available("mdns-active"))
            return "Start Avahi to discover scanners advertised on the network"
        return "No physical scanner is currently advertised or configured"
    }

    function printerEmptyMessage() {
        if (!SystemSettingsService.available("cups"))
            return "Install and start CUPS to manage printers"
        if (!SystemSettingsService.available("mdns-active"))
            return "Start Avahi to discover printers advertised on the network"
        return "No saved or discoverable printer is currently available"
    }

    function openCategory(kind) {
        selectedKind = kind
        selectedDevice = null
        SystemSettingsService.discover(kind)
    }

    Component.onCompleted: {
        if (ShellState.settingsDeviceCategory.length > 0) {
            openCategory(ShellState.settingsDeviceCategory)
            ShellState.settingsDeviceCategory = ""
        }
    }

    // Devices and Mouse & keyboard share one page instance.
    onPageChanged: closeCategory()

    function closeCategory() {
        selectedKind = ""
        selectedDevice = null
    }

    // Pixel-style overview: pairing destinations first, then only the
    // device types that currently have something connected.
    SettingsSection {
        visible: root.page === "devices" && root.selectedKind.length === 0
        fullWidth: true
        title: "Pair new devices"
        icon: "add_link"

        Repeater {
            model: root.categories.filter(item => item.kind === "bluetooth" || item.kind === "printscan")

            SettingsAction {
                required property var modelData
                width: parent.width
                icon: modelData.icon
                title: modelData.title
                subtitle: root.categoryAvailable(modelData)
                    ? modelData.description : "Required service is not installed"
                enabled: root.categoryAvailable(modelData)
                value: root.count(modelData.kind) > 0 ? String(root.count(modelData.kind)) : ""
                onClicked: root.openCategory(modelData.kind)
            }
        }
    }

    SettingsSection {
        visible: root.page === "devices" && root.selectedKind.length === 0
        fullWidth: true
        title: "Connected now"
        icon: "devices_other"

        Repeater {
            model: root.categories.filter(item => item.kind !== "bluetooth" && item.kind !== "printscan")

            SettingsAction {
                required property var modelData
                visible: root.categoryAvailable(modelData) && root.count(modelData.kind) > 0
                width: parent.width
                icon: modelData.icon
                title: modelData.title
                subtitle: root.count(modelData.kind) === 1
                    ? "1 " + modelData.singular.toLowerCase()
                    : root.count(modelData.kind) + " " + modelData.title.toLowerCase()
                onClicked: root.openCategory(modelData.kind)
            }
        }
        SettingsAction {
            width: parent.width
            visible: root.totalDeviceCount === 0
            icon: "search"
            title: "No devices detected"
            subtitle: "Plug in or pair a device and it appears here"
            enabled: false
        }
    }

    SettingsSection {
        visible: root.selectedKind.length > 0
            && root.selectedKind !== "printscan"
            && root.selectedDevice === null
        fullWidth: true
        title: root.selectedCategory.title
        subtitle: root.selectedList.length > 0
            ? root.selectedList.length + " devices found"
            : "No devices are currently reported"
        icon: root.selectedCategory.icon

        SettingsAction {
            width: parent.width
            icon: "arrow_back"
            title: "Connected devices"
            subtitle: "Return to all device categories"
            onClicked: root.closeCategory()
        }
        SettingsAction {
            width: parent.width
            icon: SystemSettingsService.devicesLoading ? "progress_activity" : "refresh"
            title: "Search again"
            subtitle: root.selectedKind === "bluetooth"
                ? "Make nearby Bluetooth devices discoverable for six seconds"
                : "Refresh this category using its Linux discovery service"
            enabled: !SystemSettingsService.loading
            onClicked: SystemSettingsService.discover(root.selectedKind)
        }
        Repeater {
            model: root.selectedList

            SettingsAction {
                required property var modelData
                width: parent.width
                icon: root.selectedCategory.icon
                title: modelData.name
                subtitle: modelData.connection.length > 0
                    ? modelData.status + " · " + modelData.connection
                    : modelData.status
                value: "Details"
                active: modelData.status === "Connected"
                onClicked: root.selectedDevice = modelData
            }
        }
        SettingsAction {
            visible: root.selectedList.length === 0
            width: parent.width
            icon: "search_off"
            title: "No " + root.selectedCategory.title.toLowerCase() + " found"
            subtitle: root.categoryAvailable(root.selectedCategory)
                ? "Connect a device or run another search"
                : "Install the required system service to enable discovery"
            enabled: false
        }
    }

    SettingsSection {
        visible: root.selectedKind === "printscan"
            && root.selectedDevice === null
        fullWidth: true
        title: "Printers & scanners"
        subtitle: "One place for CUPS queues and genuine SANE scan devices"
        icon: "print"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsAction {
            width: parent.width
            icon: "arrow_back"
            title: "Connected devices"
            subtitle: "Return to all device categories"
            onClicked: root.closeCategory()
        }
        SettingsAction {
            width: parent.width
            icon: SystemSettingsService.devicesLoading ? "progress_activity" : "refresh"
            title: "Search for devices"
            subtitle: "Refresh saved queues and discover network printers and scanners"
            enabled: !SystemSettingsService.loading
            onClicked: SystemSettingsService.discover("printscan")
        }
    }

    SettingsSection {
        visible: root.selectedKind === "printscan"
            && root.selectedDevice === null
        title: "Printers"
        subtitle: root.printerList.length > 0
            ? root.printerList.length + " saved or available"
            : root.printerEmptyMessage()
        icon: "print"

        Repeater {
            model: root.printerList

            SettingsAction {
                required property var modelData
                width: parent.width
                icon: "print"
                title: modelData.name
                subtitle: modelData.status + (modelData.connection.length > 0
                    ? " · " + modelData.connection : "")
                value: modelData.status === "Saved" ? "Ready" : "Add"
                active: modelData.status === "Saved"
                onClicked: root.selectedDevice = modelData
            }
        }
        SettingsAction {
            visible: root.printerList.length === 0
            width: parent.width
            icon: SystemSettingsService.available("mdns-active")
                ? "print_disabled" : "wifi_off"
            title: "No printers found"
            subtitle: root.printerEmptyMessage()
            enabled: false
        }
    }

    SettingsSection {
        visible: root.selectedKind === "printscan"
            && root.selectedDevice === null
        title: "Scanners"
        subtitle: root.scannerList.length > 0
            ? root.scannerList.length + " physical scanners available"
            : root.scannerEmptyMessage()
        icon: "scanner"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        Repeater {
            model: root.scannerList

            SettingsAction {
                required property var modelData
                width: parent.width
                icon: "scanner"
                title: modelData.name
                subtitle: modelData.status + (modelData.connection.length > 0
                    ? " · " + modelData.connection : "")
                value: "Details"
                onClicked: root.selectedDevice = modelData
            }
        }
        SettingsAction {
            visible: root.scannerList.length === 0
            width: parent.width
            icon: SystemSettingsService.available("airscan")
                ? "scanner" : "download"
            title: "No scanners found"
            subtitle: root.scannerEmptyMessage()
            enabled: false
        }
    }

    SettingsSection {
        visible: root.selectedDevice !== null
        fullWidth: true
        title: root.selectedDevice ? root.selectedDevice.name : "Device"
        subtitle: root.selectedDeviceKind === "printer"
            ? "Printer properties"
            : (root.selectedDeviceKind === "scanner"
                ? "Scanner properties" : root.selectedCategory.singular + " properties")
        icon: root.iconForDevice(root.selectedDevice)

        SettingsAction {
            width: parent.width
            icon: "arrow_back"
            title: root.selectedCategory.title
            subtitle: root.selectedKind === "printscan"
                ? "Return to printers and scanners"
                : "Return to discovered devices"
            onClicked: root.selectedDevice = null
        }
        SettingsAction {
            width: parent.width
            icon: root.selectedDevice && root.selectedDevice.status === "Connected"
                ? "check_circle" : "info"
            title: "Connection status"
            subtitle: root.selectedDevice ? root.selectedDevice.connection : ""
            value: root.selectedDevice ? root.selectedDevice.status : ""
            active: root.selectedDevice && root.selectedDevice.status === "Connected"
            interactive: false
        }
        SettingsAction {
            width: parent.width
            icon: "fingerprint"
            title: "Hardware or device ID"
            subtitle: "Identifier reported by the system"
            value: root.selectedDevice ? root.selectedDevice.id : ""
            interactive: false
        }
        SettingsAction {
            visible: root.selectedDevice && root.selectedDevice.manufacturer.length > 0
            width: parent.width
            icon: "factory"
            title: "Manufacturer"
            value: root.selectedDevice ? root.selectedDevice.manufacturer : ""
            interactive: false
        }
        SettingsAction {
            visible: root.selectedDevice && root.selectedDevice.model.length > 0
            width: parent.width
            icon: "category"
            title: "Model"
            value: root.selectedDevice ? root.selectedDevice.model : ""
            interactive: false
        }
        SettingsAction {
            visible: root.selectedDevice && root.selectedDevice.driver.length > 0
            width: parent.width
            icon: "memory"
            title: "Driver"
            subtitle: "Linux backend handling this device"
            value: root.selectedDevice ? root.selectedDevice.driver : ""
            interactive: false
        }
        SettingsAction {
            visible: root.selectedDevice && root.selectedDevice.battery.length > 0
            width: parent.width
            icon: "battery_5_bar"
            title: "Battery level"
            value: root.selectedDevice ? root.selectedDevice.battery : ""
            interactive: false
        }
    }

    SettingsSection {
        visible: root.selectedDevice !== null
            && (root.selectedDeviceKind === "bluetooth"
                || root.selectedDeviceKind === "printer"
                || root.selectedDeviceKind === "scanner"
                || (root.selectedDeviceKind === "storage"
                    && root.selectedDevice
                    && root.selectedDevice.driver === "block-partition"))
        fullWidth: true
        title: "Available actions"
        subtitle: "Only actions supported by the selected device are shown"
        icon: "tune"

        SettingsAction {
            visible: root.selectedDeviceKind === "bluetooth"
                && root.selectedDevice && root.selectedDevice.status === "Discovered"
            width: parent.width
            icon: "add_link"
            title: "Pair"
            subtitle: "Create a trusted Bluetooth pairing"
            value: "Pair"
            onClicked: SystemSettingsService.deviceAction(
                "bluetooth", "pair", root.selectedDevice.id)
        }
        SettingsAction {
            visible: root.selectedDeviceKind === "bluetooth"
                && root.selectedDevice && root.selectedDevice.status === "Paired"
            width: parent.width
            icon: "link"
            title: "Connect"
            value: "Connect"
            onClicked: SystemSettingsService.deviceAction(
                "bluetooth", "connect", root.selectedDevice.id)
        }
        SettingsAction {
            visible: root.selectedDeviceKind === "bluetooth"
                && root.selectedDevice && root.selectedDevice.status === "Connected"
            width: parent.width
            icon: "link_off"
            title: "Disconnect"
            value: "Disconnect"
            onClicked: SystemSettingsService.deviceAction(
                "bluetooth", "disconnect", root.selectedDevice.id)
        }
        SettingsAction {
            visible: root.selectedDeviceKind === "bluetooth"
                && root.selectedDevice && root.selectedDevice.status !== "Discovered"
            width: parent.width
            icon: "delete"
            title: "Remove pairing"
            subtitle: "Forget this Bluetooth device"
            value: "Remove"
            onClicked: SystemSettingsService.deviceAction(
                "bluetooth", "remove", root.selectedDevice.id)
        }
        SettingsAction {
            visible: root.selectedDeviceKind === "printer"
                && root.selectedDevice && root.selectedDevice.status === "Saved"
            width: parent.width
            icon: "print"
            title: "Print test page"
            subtitle: "Send the standard CUPS test page"
            value: "Test"
            onClicked: SystemSettingsService.deviceAction(
                "printer", "test", root.selectedDevice.id)
        }
        SettingsAction {
            visible: root.selectedDeviceKind === "printer"
                && root.selectedDevice && root.selectedDevice.status === "Available"
            width: parent.width
            icon: "add"
            title: "Add printer"
            subtitle: "Create a driverless CUPS queue for this device"
            value: "Add"
            onClicked: SystemSettingsService.deviceAction(
                "printer", "add", root.selectedDevice.id)
        }
        SettingsAction {
            visible: root.selectedDeviceKind === "printer"
                && root.selectedDevice && root.selectedDevice.status === "Saved"
            width: parent.width
            icon: "delete"
            title: "Remove printer"
            subtitle: "Delete this saved CUPS queue"
            value: "Remove"
            onClicked: SystemSettingsService.deviceAction(
                "printer", "remove", root.selectedDevice.id)
        }
        SettingsAction {
            visible: root.selectedDeviceKind === "scanner"
            width: parent.width
            icon: "diagnosis"
            title: "Check scanner capabilities"
            subtitle: "Ask the SANE backend for supported modes and resolutions"
            value: "Check"
            onClicked: SystemSettingsService.deviceAction(
                "scanner", "probe", root.selectedDevice.id)
        }
        SettingsAction {
            visible: root.selectedDeviceKind === "storage"
                && root.selectedDevice
                && root.selectedDevice.driver === "block-partition"
            width: parent.width
            icon: "drive_file_move"
            title: root.selectedDevice && root.selectedDevice.status === "Mounted"
                ? "Unmount storage" : "Mount storage"
            subtitle: "Use the desktop storage service with normal user authorization"
            value: root.selectedDevice && root.selectedDevice.status === "Mounted"
                ? "Unmount" : "Mount"
            onClicked: SystemSettingsService.deviceAction(
                "storage",
                root.selectedDevice.status === "Mounted" ? "unmount" : "mount",
                root.selectedDevice.id)
        }
    }

    // ---------------- Mouse & keyboard ----------------
    SettingsSection {
        visible: root.page === "input"
        title: "Mouse"
        icon: "mouse"

        SettingsSlider {
            width: parent.width
            title: "Pointer speed"
            icon: "speed"
            from: -1; to: 1; step: 0.05
            value: SystemSettingsService.pointerSpeed
            onChanged: value => SystemSettingsService.updateValue(
                "pointerSpeed", value, "input:sensitivity")
        }
    }

    SettingsSection {
        visible: root.page === "input"
        title: "Touchpad"
        icon: "touchpad_mouse"

        SettingsToggle {
            width: parent.width
            icon: "touch_app"
            title: "Tap to click"
            checked: SystemSettingsService.tapToClick
            onToggled: value => SystemSettingsService.updateValue(
                "tapToClick", value, "input:touchpad:tap-to-click")
        }
        SettingsToggle {
            width: parent.width
            icon: "swap_vert"
            title: "Natural scrolling"
            subtitle: "Content follows your fingers"
            checked: SystemSettingsService.naturalScroll
            onToggled: value => SystemSettingsService.updateValue(
                "naturalScroll", value, "input:touchpad:natural_scroll")
        }
        SettingsToggle {
            width: parent.width
            icon: "swipe"
            title: "Swipe between workspaces"
            checked: SystemSettingsService.workspaceGestures
            onToggled: value => SystemSettingsService.updateValue(
                "workspaceGestures", value, "gestures:workspace_swipe")
        }
        SettingsChoice {
            width: parent.width
            title: "Scrolling"
            options: ["2fg", "edge", "on_button_down"]
            optionLabels: ["Two fingers", "Edge", "Button + move"]
            value: SystemSettingsService.scrollMethod
            onSelected: value => SystemSettingsService.updateValue(
                "scrollMethod", value, "input:scroll_method")
        }
    }

    SettingsSection {
        visible: root.page === "input"
        title: "Keyboard"
        icon: "keyboard"

        SettingsField {
            width: parent.width
            title: "Layouts"
            subtitle: "XKB layout names, comma-separated (for example de,us)"
            icon: "language"
            value: SystemSettingsService.keyboardLayout
            onAccepted: value => SystemSettingsService.updateValue(
                "keyboardLayout", value, "input:kb_layout")
        }
        SettingsSlider {
            width: parent.width
            title: "Repeat delay"
            icon: "timer"
            from: 150; to: 1200; step: 50
            value: SystemSettingsService.repeatDelay; suffix: " ms"
            onChanged: value => SystemSettingsService.updateValue(
                "repeatDelay", value, "input:repeat_delay")
        }
        SettingsSlider {
            width: parent.width
            title: "Repeat rate"
            icon: "keyboard"
            from: 5; to: 60
            value: SystemSettingsService.repeatRate; suffix: " /s"
            onChanged: value => SystemSettingsService.updateValue(
                "repeatRate", value, "input:repeat_rate")
        }
    }
}
