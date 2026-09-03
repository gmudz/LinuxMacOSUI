pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Variants {
    id: dockVariants
    model: {
        Quickshell.screens;
        return SettingsData.getFilteredScreens("dock");
    }

    property var contextMenu
    property var trashContextMenu

    delegate: PanelWindow {
        id: dock

        WindowBlur {
            targetWindow: dock
            blurEnabled: !dock.usesConnectedFrameChrome && dock.hasApps
            blurX: dockBackground.x + dockContainer.x + dockMouseArea.x + dockCore.x + dockSlide.x
            blurY: dockBackground.y + dockContainer.y + dockMouseArea.y + dockCore.y + dockSlide.y
            blurWidth: dock.hasApps ? dockBackground.width : 0
            blurHeight: dock.hasApps ? dockBackground.height : 0
            blurRadius: 20
        }

        WlrLayershell.namespace: "dms:dock"
        WlrLayershell.layer: dock.usesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top

        readonly property bool isVertical: SettingsData.dockPosition === SettingsData.Position.Left || SettingsData.dockPosition === SettingsData.Position.Right

        anchors {
            top: !isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top) : true
            bottom: !isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom) : true
            left: !isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Left)
            right: !isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Right)
        }

        property var modelData: item
        property bool autoHide: SettingsData.dockAutoHide || SettingsData.dockSmartAutoHide
        property real backgroundTransparency: SettingsData.dockTransparency
        property bool groupByApp: SettingsData.dockGroupByApp
        readonly property int borderThickness: SettingsData.dockBorderEnabled ? SettingsData.dockBorderThickness : 0
        readonly property string connectedBarSide: SettingsData.dockPosition === SettingsData.Position.Top ? "top" : SettingsData.dockPosition === SettingsData.Position.Bottom ? "bottom" : SettingsData.dockPosition === SettingsData.Position.Left ? "left" : "right"
        readonly property bool frameDockExclusionActive: dockGeometry.frameExclusionActive
        readonly property bool connectedBarActiveOnEdge: dockGeometry.connectedBarActiveOnEdge
        readonly property real connectedJoinInset: dockGeometry.connectedJoinInset
        readonly property real dockFrameInset: dockGeometry.frameInset
        readonly property real surfaceRadius: usesConnectedFrameChrome ? Theme.connectedSurfaceRadius : 20
        readonly property color surfaceColor: usesConnectedFrameChrome ? Theme.connectedSurfaceColor : Theme.withAlpha(Theme.surfaceContainer, 0.20)
        readonly property color surfaceBorderColor: usesConnectedFrameChrome ? Theme.withAlpha(BlurService.borderColor, 0) : Theme.withAlpha("white", 0.10)
        readonly property real surfaceBorderWidth: usesConnectedFrameChrome ? 0 : 1
        readonly property real surfaceTopLeftRadius: usesConnectedFrameChrome && (SettingsData.dockPosition === SettingsData.Position.Top || SettingsData.dockPosition === SettingsData.Position.Left) ? 0 : surfaceRadius
        readonly property real surfaceTopRightRadius: usesConnectedFrameChrome && (SettingsData.dockPosition === SettingsData.Position.Top || SettingsData.dockPosition === SettingsData.Position.Right) ? 0 : surfaceRadius
        readonly property real surfaceBottomLeftRadius: usesConnectedFrameChrome && (SettingsData.dockPosition === SettingsData.Position.Bottom || SettingsData.dockPosition === SettingsData.Position.Left) ? 0 : surfaceRadius
        readonly property real surfaceBottomRightRadius: usesConnectedFrameChrome && (SettingsData.dockPosition === SettingsData.Position.Bottom || SettingsData.dockPosition === SettingsData.Position.Right) ? 0 : surfaceRadius
        readonly property real horizontalConnectorExtent: usesConnectedFrameChrome && !isVertical ? Theme.connectedCornerRadius : 0
        readonly property real verticalConnectorExtent: usesConnectedFrameChrome && isVertical ? Theme.connectedCornerRadius : 0

        readonly property int hasApps: dockApps.implicitWidth > 0 || dockApps.implicitHeight > 0

        readonly property real widgetHeight: SettingsData.dockIconSize
        readonly property real effectiveBarHeight: dockGeometry.visualThickness
        function getBarHeight(barConfig) {
            if (!barConfig)
                return 0;
            const innerPadding = barConfig.innerPadding ?? 4;
            const widgetThickness = Math.max(20, 26 + innerPadding * 0.6);
            const barThickness = Math.max(widgetThickness + innerPadding + 4, Theme.barHeight - 4 - (8 - innerPadding));
            const spacing = barConfig.spacing ?? 4;
            const bottomGap = barConfig.bottomGap ?? 0;
            return barThickness + spacing + bottomGap;
        }

        readonly property real barSpacing: {
            const defaultBar = SettingsData.barConfigs[0] || SettingsData.getBarConfig("default");
            if (!defaultBar)
                return 0;

            const barPos = defaultBar.position ?? SettingsData.Position.Top;
            const barIsHorizontal = (barPos === SettingsData.Position.Top || barPos === SettingsData.Position.Bottom);
            const barIsVertical = (barPos === SettingsData.Position.Left || barPos === SettingsData.Position.Right);
            const samePosition = (SettingsData.dockPosition === barPos);
            const dockIsHorizontal = !isVertical;
            const dockIsVertical = isVertical;

            if (!(defaultBar.visible ?? true))
                return 0;
            const spacing = defaultBar.spacing ?? 4;
            const bottomGap = defaultBar.bottomGap ?? 0;
            if (dockIsHorizontal && barIsHorizontal && samePosition) {
                return spacing + effectiveBarHeight + bottomGap;
            }
            if (dockIsVertical && barIsVertical && samePosition) {
                return spacing + effectiveBarHeight + bottomGap;
            }
            return 0;
        }

        readonly property real adjacentTopBarHeight: {
            if (!isVertical || autoHide)
                return 0;
            const screenName = dock.modelData?.name ?? "";
            const topBar = SettingsData.barConfigs.find(bc => {
                if (!bc.enabled || bc.autoHide || !(bc.visible ?? true))
                    return false;
                if (bc.position !== SettingsData.Position.Top && bc.position !== 0)
                    return false;
                const onThisScreen = bc.screenPreferences.length === 0 || bc.screenPreferences.includes("all") || bc.screenPreferences.includes(screenName);
                return onThisScreen;
            });
            return getBarHeight(topBar);
        }

        readonly property real adjacentLeftBarWidth: {
            if (isVertical || autoHide)
                return 0;
            const screenName = dock.modelData?.name ?? "";
            const leftBar = SettingsData.barConfigs.find(bc => {
                if (!bc.enabled || bc.autoHide || !(bc.visible ?? true))
                    return false;
                if (bc.position !== SettingsData.Position.Left && bc.position !== 2)
                    return false;
                const onThisScreen = bc.screenPreferences.length === 0 || bc.screenPreferences.includes("all") || bc.screenPreferences.includes(screenName);
                return onThisScreen;
            });
            return getBarHeight(leftBar);
        }

        readonly property real dockMargin: SettingsData.dockMargin
        readonly property bool effectiveBlurEnabled: Theme.connectedSurfaceBlurEnabled
        readonly property real effectiveDockBottomGap: dockGeometry.visualOffset
        readonly property real effectiveDockMargin: dockGeometry.effectiveMargin
        readonly property real positionSpacing: barSpacing + effectiveDockBottomGap + effectiveDockMargin
        readonly property real joinedEdgeMargin: dockGeometry.joinedEdgeMargin
        readonly property real _dpr: (dock.screen && dock.screen.devicePixelRatio) ? dock.screen.devicePixelRatio : 1
        function px(v) {
            return Math.round(v * _dpr) / _dpr;
        }

        DockGeometry {
            id: dockGeometry

            screen: dock.screen || dock.modelData
            edge: dock.connectedBarSide
            dockVisible: dock.visible
            autoHide: dock.autoHide
            iconSize: dock.widgetHeight
            spacing: SettingsData.dockSpacing
            borderThickness: dock.borderThickness
            offset: SettingsData.dockBottomGap
            margin: SettingsData.dockMargin
            barSpacing: dock.barSpacing
            dpr: dock._dpr
        }

        // Dock window origin in screen-relative coordinates (FrameWindow space).
        function _dockWindowOriginX() {
            if (!dock.isVertical)
                return 0;
            if (SettingsData.dockPosition === SettingsData.Position.Right)
                return (dock.screen ? dock.screen.width : 0) - dock.width;
            return 0;
        }
        function _dockWindowOriginY() {
            if (dock.isVertical)
                return 0;
            if (SettingsData.dockPosition === SettingsData.Position.Bottom)
                return (dock.screen ? dock.screen.height : 0) - dock.height;
            return 0;
        }

        readonly property string _dockScreenName: dock.modelData ? dock.modelData.name : (dock.screen ? dock.screen.name : "")
        readonly property bool usesConnectedFrameChrome: CompositorService.usesConnectedFrameChromeForScreen(dock._dockScreenName)
        readonly property bool usesOverlayLayer: CompositorService.framePeerSurfacesUseOverlayForScreen(dock._dockScreenName) || SettingsData.dockUseOverlayLayer

        function _syncDockChromeState() {
            if (!dock._dockScreenName)
                return;
            if (!dock.usesConnectedFrameChrome) {
                ConnectedModeState.clearDockState(dock._dockScreenName);
                return;
            }

            const presented = dock.visible && (dock.reveal || slideXAnimation.running || slideYAnimation.running) && dock.hasApps;
            const phase = !presented ? "hidden" : ((!dock.reveal && (slideXAnimation.running || slideYAnimation.running)) ? "closing" : ((slideXAnimation.running || slideYAnimation.running) ? "opening" : "open"));
            const bodyX = dock._dockWindowOriginX() + dockBackground.x + dockContainer.x + dockMouseArea.x + dockCore.x;
            const bodyY = dock._dockWindowOriginY() + dockBackground.y + dockContainer.y + dockMouseArea.y + dockCore.y;
            const bodyW = dock.hasApps ? dockBackground.width : 0;
            const bodyH = dock.hasApps ? dockBackground.height : 0;
            ConnectedModeState.setDockState(dock._dockScreenName, {
                "kind": "dock",
                "screenName": dock._dockScreenName,
                "phase": phase,
                "visible": presented,
                "presented": presented,
                "reveal": presented,
                "barSide": dock.connectedBarSide,
                "bodyRect": {
                    "x": bodyX,
                    "y": bodyY,
                    "width": bodyW,
                    "height": bodyH
                },
                "animationOffset": {
                    "x": dockSlide.x,
                    "y": dockSlide.y
                },
                "scale": 1,
                "opacity": Theme.connectedSurfaceColor.a,
                "bodyX": bodyX,
                "bodyY": bodyY,
                "bodyW": bodyW,
                "bodyH": bodyH,
                "slideX": dockSlide.x,
                "slideY": dockSlide.y
            });
        }

        function _syncDockSlide() {
            if (!dock._dockScreenName || !dock.usesConnectedFrameChrome)
                return;
            ConnectedModeState.setDockSlide(dock._dockScreenName, dockSlide.x, dockSlide.y);
        }

        DeferredAction {
            id: dockSlideSync
            enabled: dock.usesConnectedFrameChrome
            onTriggered: dock._syncDockSlide()
        }

        function _queueSlideSync() {
            if (!dock.usesConnectedFrameChrome)
                return;
            dockSlideSync.schedule();
        }

        DeferredAction {
            id: dockChromeSync
            onTriggered: dock._syncDockChromeState()
        }

        property bool contextMenuOpen: (dockVariants.contextMenu && dockVariants.contextMenu.visible && dockVariants.contextMenu.screen === modelData) ? true : false
        property bool revealSticky: false

        readonly property bool hasFullscreenOrMaximizedWindow: {
            if (!CompositorService.isNiri && !CompositorService.isHyprland && !CompositorService.isMango)
                return false;

            if (CompositorService.isNiri) {
                if (NiriService.inOverview)
                    return false;

                NiriService.windows;
                NiriService.allWorkspaces;

                const screenName = dock.modelData?.name ?? "";
                const screenHeight = (dock.screen && dock.screen.height > 0) ? dock.screen.height : 1080;
                const screenWidth = (dock.screen && dock.screen.width > 0) ? dock.screen.width : 1920;

                let currentWorkspaceId = null;
                for (let i = 0; i < NiriService.allWorkspaces.length; i++) {
                    const ws = NiriService.allWorkspaces[i];
                    if ((ws.output === screenName || NiriService.allWorkspaces.length <= 1 || !screenName) && (ws.is_active || ws.is_focused)) {
                        currentWorkspaceId = ws.id;
                        break;
                    }
                }

                if (currentWorkspaceId === null && NiriService.allWorkspaces.length > 0) {
                    currentWorkspaceId = NiriService.allWorkspaces[0].id;
                }

                if (currentWorkspaceId === null)
                    return false;

                for (let i = 0; i < NiriService.windows.length; i++) {
                    const win = NiriService.windows[i];
                    if (win.workspace_id !== currentWorkspaceId)
                        continue;

                    if (!win.is_focused)
                        continue;

                    // True fullscreen
                    if (win.is_fullscreen)
                        return true;

                    // Maximized window (Mod+M, Mod+F maximize-column, or fullscreen)
                    if (win.layout) {
                        const winW = (win.layout.window_size && win.layout.window_size[0]) || (win.layout.tile_size && win.layout.tile_size[0]) || 0;
                        const winH = (win.layout.window_size && win.layout.window_size[1]) || (win.layout.tile_size && win.layout.tile_size[1]) || 0;
                        if (winW >= (screenWidth - 40) && winH >= (screenHeight - 140)) {
                            return true;
                        }
                    }
                }

                return false;
            }

            if (CompositorService.isHyprland) {
                const sorted = CompositorService.sortedToplevels || [];
                return sorted.some(t => t?.fullscreen || t?.maximized);
            }

            if (CompositorService.isMango) {
                const wins = MangoService.windows || [];
                return wins.some(w => w?.is_fullscreen || w?.is_maximized);
            }

            return false;
        }

        readonly property bool shouldHideForWindows: {
            if (!SettingsData.dockSmartAutoHide)
                return false;
            if (!CompositorService.isNiri && !CompositorService.isHyprland && !CompositorService.isMango)
                return false;

            const screenName = dock.modelData?.name ?? "";
            const dockThickness = dockGeometry.motionThickness;
            const screenWidth = (dock.screen && dock.screen.width > 0) ? dock.screen.width : 1920;
            const screenHeight = (dock.screen && dock.screen.height > 0) ? dock.screen.height : 1080;

            if (CompositorService.isNiri) {
                NiriService.windows;
                NiriService.allWorkspaces;
                NiriService.focusedWorkspaceId;

                let currentWorkspaceId = null;
                for (let i = 0; i < NiriService.allWorkspaces.length; i++) {
                    const ws = NiriService.allWorkspaces[i];
                    if ((ws.output === screenName || NiriService.allWorkspaces.length <= 1 || !screenName) && ws.is_active) {
                        currentWorkspaceId = ws.id;
                        break;
                    }
                }

                if (currentWorkspaceId === null)
                    return false;

                for (let i = 0; i < NiriService.windows.length; i++) {
                    const win = NiriService.windows[i];
                    if (win.workspace_id !== currentWorkspaceId)
                        continue;

                    // True fullscreen
                    if (win.is_fullscreen)
                        return true;

                    // Maximized window (Mod+M, Mod+F maximize-column, or fullscreen)
                    if (win.is_focused && win.layout) {
                        const winH = (win.layout.window_size && win.layout.window_size[1]) || (win.layout.tile_size && win.layout.tile_size[1]) || 0;
                        const winW = (win.layout.window_size && win.layout.window_size[0]) || (win.layout.tile_size && win.layout.tile_size[0]) || 0;
                        if (winW >= (screenWidth - 40) && winH >= (screenHeight - 140)) {
                            return true;
                        }
                    }
                }

                return false;
            }

            if (CompositorService.isMango) {
                MangoService.windows;
                MangoService.outputs;
                return CompositorService.mangoDockOverlapForSmartAutoHide(screenName, SettingsData.dockPosition, dockThickness, screenWidth, screenHeight);
            }

            // Hyprland implementation (current workspace + visible special workspaces)
            Hyprland.focusedWorkspace;
            Hyprland.toplevels;
            return CompositorService.hyprlandDockOverlapForSmartAutoHide(screenName, SettingsData.dockPosition, dockThickness, screenWidth, screenHeight);
        }

        Timer {
            id: revealHold
            interval: 250
            repeat: false
            onTriggered: dock.revealSticky = false
        }

        // Flip `reveal` false when a modal claims this edge; reuses the slide animation
        readonly property bool _modalRetractActive: {
            if (!dock._dockScreenName)
                return false;
            return ConnectedModeState.dockRetractActiveForSide(dock._dockScreenName, dock.connectedBarSide);
        }

        property bool startupRevealDone: true

        property bool reveal: {
            if (!startupRevealDone)
                return false;

            if (_modalRetractActive)
                return false;

            if (CompositorService.isNiri && NiriService.inOverview && SettingsData.dockOpenOnOverview) {
                return true;
            }

            // When a window is fullscreen or maximized (Win+M), auto-hide dock so it doesn't cover the window
            if (hasFullscreenOrMaximizedWindow) {
                return dockMouseArea.containsMouse || dockApps.requestDockShow || contextMenuOpen || revealSticky;
            }

            // Smart auto-hide: show dock when no windows overlap, hide when they do
            if (SettingsData.dockSmartAutoHide) {
                if (shouldHideForWindows)
                    return dockMouseArea.containsMouse || dockApps.requestDockShow || contextMenuOpen || revealSticky;
                return true;  // No overlapping windows - show dock
            }

            // Regular auto-hide: always hide unless hovering
            return !autoHide || dockMouseArea.containsMouse || dockApps.requestDockShow || contextMenuOpen || revealSticky;
        }

        onContextMenuOpenChanged: {
            if (!contextMenuOpen && autoHide && !dockMouseArea.containsMouse) {
                revealSticky = true;
                revealHold.restart();
            }
        }

        Component.onCompleted: dockChromeSync.schedule()
        Component.onDestruction: {
            dockChromeSync.cancel();
            dockSlideSync.cancel();
            ConnectedModeState.clearDockState(dock._dockScreenName);
        }

        onRevealChanged: dock._syncDockChromeState()
        onWidthChanged: dock._syncDockChromeState()
        onHeightChanged: dock._syncDockChromeState()
        onVisibleChanged: dock._syncDockChromeState()
        onHasAppsChanged: dock._syncDockChromeState()
        onConnectedBarSideChanged: dock._syncDockChromeState()
        onUsesConnectedFrameChromeChanged: dock._syncDockChromeState()

        Connections {
            target: SettingsData
            function onConnectedFrameModeActiveChanged() {
                dockSlideSync.cancel();
                dock._syncDockChromeState();
            }
        }

        Connections {
            target: SettingsData
            function onDockTransparencyChanged() {
                dock.backgroundTransparency = SettingsData.dockTransparency;
            }
        }

        screen: modelData
        visible: {
            if (CompositorService.isNiri && NiriService.inOverview) {
                return SettingsData.dockOpenOnOverview;
            }
            return SettingsData.showDock;
        }
        color: "transparent"

        readonly property real dockReserveZone: dockGeometry.reserveZone
        readonly property bool shouldReserveDockSpace: dockGeometry.shouldReserveSpace

        exclusiveZone: -1

        property real animationHeadroom: Math.ceil(SettingsData.dockIconSize * 2.0 + 80)

        implicitWidth: isVertical ? (px(dockGeometry.surfaceThickness) + animationHeadroom) : 0
        implicitHeight: !isVertical ? (px(dockGeometry.surfaceThickness) + animationHeadroom) : 0

        Item {
            id: maskItem
            parent: dock.contentItem
            visible: false
            x: isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? Math.max(0, dock.width - width) : 0) : Math.max(0, (dock.width - width) / 2)
            y: {
                if (SettingsData.dockPosition === SettingsData.Position.Top)
                    return 0;
                return Math.max(0, dock.height - height);
            }
            width: {
                if (isVertical) {
                    return dock.reveal ? (dockBackground.width + dockGeometry.bodyEdgeMargin + 12) : 4;
                }
                return Math.min(dock.width, dockBackground.width + 16);
            }
            height: {
                if (isVertical) {
                    return Math.min(dock.height, dockBackground.height + 16);
                }
                return dock.reveal ? (dockBackground.height + dockGeometry.bodyEdgeMargin + 12) : 4;
            }
        }

        mask: Region {
            item: maskItem
        }



        readonly property var hoveredButton: {
            if (!dockApps.isDockHovered || dockApps.activeHoveredIndex < 0)
                return null;
            const repeater = dockApps.repeaterItem;
            if (!repeater || typeof repeater.itemAt !== "function")
                return null;
            const item = repeater.itemAt(dockApps.activeHoveredIndex);
            return (item && item.dockButton) ? item.dockButton : null;
        }

        Connections {
            target: dock
            function onRevealChanged() {
                // reveal state handler
            }
        }

        Item {
            id: dockCore
            anchors.fill: parent
            x: isVertical && SettingsData.dockPosition === SettingsData.Position.Right ? animationHeadroom : 0
            y: !isVertical && SettingsData.dockPosition === SettingsData.Position.Bottom ? animationHeadroom : 0

            Connections {
                target: dockMouseArea
                function onContainsMouseChanged() {
                    if (dockMouseArea.containsMouse) {
                        dock.revealSticky = true;
                        revealHold.stop();
                    } else {
                        if (!dock.contextMenuOpen) {
                            revealHold.restart();
                        }
                    }
                }
            }

            MouseArea {
                id: dockMouseArea
                property var currentScreen: modelData ? modelData : dock.screen
                property real screenWidth: currentScreen ? (currentScreen.geometry ? currentScreen.geometry.width : (currentScreen.width || 1920)) : 1920
                property real screenHeight: currentScreen ? (currentScreen.geometry ? currentScreen.geometry.height : (currentScreen.height || 1080)) : 1080
                property real maxDockWidth: screenWidth * 0.98
                property real maxDockHeight: screenHeight * 0.98

                height: {
                    if (dock.isVertical) {
                        return Math.min(dockBackground.height + 16, maxDockHeight);
                    }
                    return dock.reveal ? (dockBackground.height + dockGeometry.bodyEdgeMargin + 12) : 4;
                }
                width: {
                    if (dock.isVertical) {
                        return dock.reveal ? (dockBackground.width + dockGeometry.bodyEdgeMargin + 12) : 4;
                    }
                    return Math.min(dockBackground.width + 16, maxDockWidth);
                }
                anchors {
                    top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? undefined : parent.top) : undefined
                    bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined) : undefined
                    horizontalCenter: !dock.isVertical ? parent.horizontalCenter : undefined
                    left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? undefined : parent.left) : undefined
                    right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined) : undefined
                    verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
                }
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: dockContainer
                    anchors.fill: parent
                    clip: false
                    opacity: dock.startupRevealDone ? 1 : 0

                    transform: Translate {
                        id: dockSlide
                        x: {
                            if (!dock.isVertical)
                                return 0;
                            if (dock.reveal)
                                return 0;
                            if (dock.usesConnectedFrameChrome) {
                                const retractDist = dockBackground.width + SettingsData.dockSpacing + 10;
                                return SettingsData.dockPosition === SettingsData.Position.Right ? retractDist : -retractDist;
                            }
                            const hideDistance = dockGeometry.motionThickness + 10;
                            if (SettingsData.dockPosition === SettingsData.Position.Right) {
                                return hideDistance;
                            } else {
                                return -hideDistance;
                            }
                        }
                        y: {
                            if (dock.isVertical)
                                return 0;
                            if (dock.reveal)
                                return 0;
                            if (dock.usesConnectedFrameChrome) {
                                const retractDist = dockBackground.height + SettingsData.dockSpacing + 10;
                                return SettingsData.dockPosition === SettingsData.Position.Bottom ? retractDist : -retractDist;
                            }
                            const hideDistance = dockGeometry.motionThickness + 10;
                            if (SettingsData.dockPosition === SettingsData.Position.Bottom) {
                                return hideDistance;
                            } else {
                                return -hideDistance;
                            }
                        }

                        Behavior on x {
                            NumberAnimation {
                                id: slideXAnimation
                                duration: dock.usesConnectedFrameChrome ? Theme.variantDuration(Theme.popoutAnimationDuration, dock.reveal) : Theme.shortDuration
                                easing.type: dock.usesConnectedFrameChrome ? Easing.BezierSpline : Easing.OutCubic
                                easing.bezierCurve: dock.usesConnectedFrameChrome ? (dock.reveal ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve) : []
                                onRunningChanged: if (!running)
                                    dock._syncDockChromeState()
                            }
                        }

                        Behavior on y {
                            NumberAnimation {
                                id: slideYAnimation
                                duration: dock.usesConnectedFrameChrome ? Theme.variantDuration(Theme.popoutAnimationDuration, dock.reveal) : Theme.shortDuration
                                easing.type: dock.usesConnectedFrameChrome ? Easing.BezierSpline : Easing.OutCubic
                                easing.bezierCurve: dock.usesConnectedFrameChrome ? (dock.reveal ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve) : []
                                onRunningChanged: if (!running)
                                    dock._syncDockChromeState()
                            }
                        }

                        onXChanged: dock._queueSlideSync()
                        onYChanged: dock._queueSlideSync()
                    }

                    Item {
                        id: dockBackground
                        objectName: "dockBackground"
                        visible: dock.hasApps
                        anchors {
                            top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top ? parent.top : undefined) : undefined
                            bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? parent.bottom : undefined) : undefined
                            horizontalCenter: !dock.isVertical ? parent.horizontalCenter : undefined
                            left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Left ? parent.left : undefined) : undefined
                            right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? parent.right : undefined) : undefined
                            verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
                        }
                        anchors.topMargin: !dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Top ? dockGeometry.bodyEdgeMargin : 0
                        anchors.bottomMargin: !dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Bottom ? dockGeometry.bodyEdgeMargin : 0
                        anchors.leftMargin: dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Left ? dockGeometry.bodyEdgeMargin : 0
                        anchors.rightMargin: dock.isVertical && SettingsData.dockPosition === SettingsData.Position.Right ? dockGeometry.bodyEdgeMargin : 0

                        implicitWidth: dock.isVertical ? (dockApps.implicitHeight + SettingsData.dockSpacing * 2) : (dockApps.implicitWidth + SettingsData.dockSpacing * 2)
                        implicitHeight: dock.isVertical ? (dockApps.implicitWidth + SettingsData.dockSpacing * 2) : (dockApps.implicitHeight + SettingsData.dockSpacing * 2)
                        width: implicitWidth
                        height: implicitHeight

                        // Avoid an offscreen texture seam where the connected dock meets the frame.
                        layer.enabled: false
                        clip: false

                        Rectangle {
                            anchors.fill: parent
                            visible: !usesConnectedFrameChrome && (!FrameTransitionState.effectiveConnectedFrameModeActive || dock.reveal)
                            color: dock.surfaceColor
                            topLeftRadius: dock.surfaceTopLeftRadius
                            topRightRadius: dock.surfaceTopRightRadius
                            bottomLeftRadius: dock.surfaceBottomLeftRadius
                            bottomRightRadius: dock.surfaceBottomRightRadius
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !usesConnectedFrameChrome && (!FrameTransitionState.effectiveConnectedFrameModeActive || dock.reveal)
                            color: "transparent"
                            topLeftRadius: dock.surfaceTopLeftRadius
                            topRightRadius: dock.surfaceTopRightRadius
                            bottomLeftRadius: dock.surfaceBottomLeftRadius
                            bottomRightRadius: dock.surfaceBottomRightRadius
                            border.color: dock.surfaceBorderColor
                            border.width: dock.surfaceBorderWidth
                            z: 100
                        }

                        // Sync dockBackground geometry to ConnectedModeState
                        onXChanged: dock._syncDockChromeState()
                        onYChanged: dock._syncDockChromeState()
                        onWidthChanged: dock._syncDockChromeState()
                        onHeightChanged: dock._syncDockChromeState()
                    }

                    Item {
                        id: dockConnectedChrome
                        visible: Theme.isConnectedEffect && dock.reveal && dock.hasApps && !FrameTransitionState.effectiveConnectedFrameModeActive
                        readonly property real extraLeft: dock.isVertical ? 0 : Theme.connectedCornerRadius
                        readonly property real extraTop: dock.isVertical ? Theme.connectedCornerRadius : 0
                        readonly property real bodyRadius: dock.surfaceRadius
                        readonly property bool barTop: dock.connectedBarSide === "top"
                        readonly property bool barBottom: dock.connectedBarSide === "bottom"
                        readonly property bool barLeft: dock.connectedBarSide === "left"
                        readonly property bool barRight: dock.connectedBarSide === "right"

                        x: dockBackground.x - extraLeft
                        y: dockBackground.y - extraTop
                        width: dockBackground.width + extraLeft * 2
                        height: dockBackground.height + extraTop * 2

                        ShaderEffect {
                            anchors.fill: parent
                            fragmentShader: Qt.resolvedUrl("../../Shaders/qsb/connected_chrome.frag.qsb")

                            property real widthPx: width
                            property real heightPx: height
                            property vector4d surfaceColor: Qt.vector4d(dock.surfaceColor.r, dock.surfaceColor.g, dock.surfaceColor.b, dock.surfaceColor.a)
                            property vector4d shadowColor: Qt.vector4d(0, 0, 0, 0)
                            property vector4d shadowParam: Qt.vector4d(0, 0, 0, 0)
                            property vector4d ambientParam: Qt.vector4d(0, 0, 0, 0)
                            property vector4d bodyRect: Qt.vector4d(dockConnectedChrome.extraLeft, dockConnectedChrome.extraTop, dockBackground.width, dockBackground.height)
                            property vector4d cornerRadius: Qt.vector4d(dockConnectedChrome.barTop || dockConnectedChrome.barLeft ? 0 : dockConnectedChrome.bodyRadius, dockConnectedChrome.barTop || dockConnectedChrome.barRight ? 0 : dockConnectedChrome.bodyRadius, dockConnectedChrome.barBottom || dockConnectedChrome.barRight ? 0 : dockConnectedChrome.bodyRadius, dockConnectedChrome.barBottom || dockConnectedChrome.barLeft ? 0 : dockConnectedChrome.bodyRadius)
                            property vector4d edgeParam: Qt.vector4d(dockConnectedChrome.barTop ? 0 : (dockConnectedChrome.barBottom ? 1 : (dockConnectedChrome.barLeft ? 2 : 3)), Theme.connectedCornerRadius, 0, 0)
                        }
                    }

                    Shape {
                        id: dockBorderShape
                        x: dockBackground.x - borderThickness
                        y: dockBackground.y - borderThickness
                        width: dockBackground.width + borderThickness * 2
                        height: dockBackground.height + borderThickness * 2
                        visible: SettingsData.dockBorderEnabled && dock.hasApps && !usesConnectedFrameChrome
                        preferredRendererType: Shape.CurveRenderer

                        readonly property real borderThickness: Math.max(1, dock.borderThickness)
                        readonly property real i: borderThickness / 2
                        readonly property real cr: dock.surfaceRadius
                        readonly property real w: dockBackground.width
                        readonly property real h: dockBackground.height

                        readonly property color borderColor: {
                            const opacity = SettingsData.dockBorderOpacity;
                            switch (SettingsData.dockBorderColor) {
                            case "secondary":
                                return Theme.withAlpha(Theme.secondary, opacity);
                            case "primary":
                                return Theme.withAlpha(Theme.primary, opacity);
                            default:
                                return Theme.withAlpha(Theme.surfaceText, opacity);
                            }
                        }

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: dockBorderShape.borderColor
                            strokeWidth: dockBorderShape.borderThickness
                            joinStyle: ShapePath.RoundJoin
                            capStyle: ShapePath.FlatCap

                            PathSvg {
                                path: {
                                    const bt = dockBorderShape.borderThickness;
                                    const i = dockBorderShape.i;
                                    const cr = dockBorderShape.cr + bt - i;
                                    const w = dockBorderShape.w;
                                    const h = dockBorderShape.h;

                                    let d = `M ${i + cr} ${i}`;
                                    d += ` L ${i + w + 2 * (bt - i) - cr} ${i}`;
                                    if (cr > 0)
                                        d += ` A ${cr} ${cr} 0 0 1 ${i + w + 2 * (bt - i)} ${i + cr}`;
                                    d += ` L ${i + w + 2 * (bt - i)} ${i + h + 2 * (bt - i) - cr}`;
                                    if (cr > 0)
                                        d += ` A ${cr} ${cr} 0 0 1 ${i + w + 2 * (bt - i) - cr} ${i + h + 2 * (bt - i)}`;
                                    d += ` L ${i + cr} ${i + h + 2 * (bt - i)}`;
                                    if (cr > 0)
                                        d += ` A ${cr} ${cr} 0 0 1 ${i} ${i + h + 2 * (bt - i) - cr}`;
                                    d += ` L ${i} ${i + cr}`;
                                    if (cr > 0)
                                        d += ` A ${cr} ${cr} 0 0 1 ${i + cr} ${i}`;
                                    d += " Z";
                                    return d;
                                }
                            }
                        }
                    }

                    DockApps {
                        id: dockApps

                        anchors.top: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top ? dockBackground.top : undefined) : undefined
                        anchors.bottom: !dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom ? dockBackground.bottom : undefined) : undefined
                        anchors.horizontalCenter: !dock.isVertical ? dockBackground.horizontalCenter : undefined
                        anchors.left: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Left ? dockBackground.left : undefined) : undefined
                        anchors.right: dock.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Right ? dockBackground.right : undefined) : undefined
                        anchors.verticalCenter: dock.isVertical ? dockBackground.verticalCenter : undefined
                        anchors.topMargin: !dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.bottomMargin: !dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.leftMargin: dock.isVertical ? SettingsData.dockSpacing : 0
                        anchors.rightMargin: dock.isVertical ? SettingsData.dockSpacing : 0

                        contextMenu: dockVariants.contextMenu
                        trashContextMenu: dockVariants.trashContextMenu
                        groupByApp: dock.groupByApp
                        isVertical: dock.isVertical
                        dockScreen: dock.screen
                        iconSize: dock.widgetHeight
                        usesOverlayLayer: dock.usesOverlayLayer
                    }
                }
            }
        }
    }
}
