#!/usr/bin/env bash
# ==============================================================================
# Module: 12-clipboard-preview
# Description: Cấu hình phím tắt Super + V mở lịch sử clipboard QuickShell với
#              bố cục chia đôi 6/4:
#              - 60% bên trái: Danh sách lịch sử + tìm kiếm, hiển thị ảnh thumbnail mini.
#              - 40% bên phải: Khung xem trước (preview) ảnh lớn / toàn bộ văn bản.
#              - Cơ chế cuộn: Chuẩn (non-infinite, dừng ở biên trên/dưới, không vòng lặp).
# ==============================================================================

MODULE_NAME="clipboard-preview"
MODULE_DESC="Lịch sử clipboard Super + V QuickShell chia 6/4, ảnh mini và preview ảnh to, cuộn chuẩn"

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. CÀI ĐẶT CÁC CÔNG CỤ CẦN THIẾT
    info "1/5. Kiểm tra các gói phụ thuộc: cliphist, python, wl-clipboard..."
    pkg_install cliphist python wl-clipboard

    # 2. THIẾT LẬP SCRIPT TRÍCH XUẤT CLIPBOARD CHO QUICKSHELL
    info "2/5. Thiết lập script clipboard-list.py cho QuickShell..."
    local QS_SCRIPTS_DIR="$HOME/.dotfiles/.config/quickshell/scripts"
    mkdir -p "$QS_SCRIPTS_DIR"
    mkdir -p "$HOME/.config/quickshell/scripts"

    cat << 'EOF' > "$QS_SCRIPTS_DIR/clipboard-list.py"
#!/usr/bin/env python3
# ==============================================================================
# Script: clipboard-list.py
# Description: Trích xuất danh sách clipboard từ cliphist định dạng JSON cho QuickShell.
#              Tự động giải mã thumbnail hình ảnh vào ~/.cache/cliphist/thumbnails/.
# ==============================================================================

import os
import re
import subprocess
import sys
import json

def get_clipboard_items(max_items=120):
    thumb_dir = os.path.expanduser("~/.cache/cliphist/thumbnails")
    os.makedirs(thumb_dir, exist_ok=True)

    try:
        raw = subprocess.check_output(
            ["cliphist", "list"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8", errors="replace")
    except Exception:
        return []

    lines = raw.splitlines()[:max_items]
    img_re = re.compile(r"^(\d+)\t\[\[ binary data (.*?) (png|jpe?g|webp|bmp|gif) (\d+x\d+) \]\]", re.IGNORECASE)

    items = []
    for idx, line in enumerate(lines):
        m = img_re.match(line)
        if m:
            cid = m.group(1)
            size_str = m.group(2).strip()
            ext = m.group(3).lower()
            res = m.group(4)
            thumb_path = os.path.join(thumb_dir, f"{cid}.{ext}")

            if not os.path.exists(thumb_path) or os.path.getsize(thumb_path) == 0:
                try:
                    with open(thumb_path, "wb") as f:
                        subprocess.run(
                            ["cliphist", "decode", cid],
                            stdout=f,
                            stderr=subprocess.DEVNULL,
                            timeout=1,
                            check=True
                        )
                except Exception:
                    thumb_path = ""

            items.append({
                "id": str(cid),
                "isImage": True,
                "path": thumb_path,
                "title": f"{res}",
                "info": f"{ext.upper()} • {res} • {size_str}",
                "preview": f"Hình ảnh ({res}, {size_str})",
                "fullText": ""
            })
        else:
            parts = line.split("\t", 1)
            cid = parts[0] if parts else str(idx)
            snippet = parts[1] if len(parts) > 1 else ""
            
            # Pre-fetch fullText cho 15 mục đầu tiên để UI phản hồi tức thì
            full_text = ""
            if idx < 15:
                try:
                    p = subprocess.run(
                        ["cliphist", "decode", cid],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL,
                        timeout=0.3
                    )
                    full_text = p.stdout.decode("utf-8", errors="replace")
                    if len(full_text) > 3000:
                        full_text = full_text[:3000] + "\n... [Văn bản quá dài, đã rút gọn hiển thị]"
                except Exception:
                    full_text = snippet

            char_count = len(snippet)
            items.append({
                "id": str(cid),
                "isImage": False,
                "path": "",
                "title": "Văn bản",
                "info": f"Văn bản • {char_count} ký tự",
                "preview": snippet,
                "fullText": full_text
            })

    return items

def main():
    items = get_clipboard_items()
    sys.stdout.write(json.dumps(items, ensure_ascii=False))

if __name__ == "__main__":
    main()
EOF
    chmod +x "$QS_SCRIPTS_DIR/clipboard-list.py"
    ln -sfn "$QS_SCRIPTS_DIR/clipboard-list.py" "$HOME/.config/quickshell/scripts/clipboard-list.py"
    substep "Đã thiết lập: $QS_SCRIPTS_DIR/clipboard-list.py"

    # 3. THIẾT LẬP COMPONENT CLIPBOARD.QML TRONG QUICKSHELL
    info "3/5. Thiết lập giao diện QuickShell Clipboard.qml (layout 6/4, ảnh mini + ảnh to)..."
    local QS_DIR="$HOME/.dotfiles/.config/quickshell"
    mkdir -p "$QS_DIR"
    mkdir -p "$HOME/.config/quickshell"

    cat << 'EOF' > "$QS_DIR/Clipboard.qml"
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    property bool showing: false
    property var allItems: []
    property var filteredItems: []
    property string previewFullText: ""
    property int selectedIndex: 0
    readonly property var currentItem: (clipList.currentIndex >= 0 && clipList.currentIndex < clipModel.count) ? clipModel.get(clipList.currentIndex) : null

    Component.onCompleted: {
        fetcher.running = true;
    }

    visible: root.showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clipboard"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    ListModel {
        id: clipModel
    }

    Process {
        id: fetcher
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard-list.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.allItems = JSON.parse(text);
                    root.filterItems();
                } catch (e) {
                    console.warn("clipboard: failed to parse json:", e);
                }
            }
        }
    }

    Process {
        id: textDecoder
        stdout: StdioCollector {
            onStreamFinished: {
                root.previewFullText = text;
            }
        }
    }

    function getCurrentItem() {
        if (clipList.currentIndex >= 0 && clipList.currentIndex < clipModel.count) {
            return clipModel.get(clipList.currentIndex);
        }
        return null;
    }

    function updatePreview() {
        var cur = root.currentItem;
        if (!cur) {
            root.previewFullText = "";
            return;
        }
        if (cur.isImage) {
            root.previewFullText = "";
        } else if (cur.fullText && cur.fullText !== "") {
            root.previewFullText = cur.fullText;
        } else {
            root.previewFullText = cur.preview;
            if (cur.id) {
                textDecoder.command = ["cliphist", "decode", cur.id];
                textDecoder.running = true;
            }
        }
    }

    function filterItems() {
        var q = searchBox.text.trim().toLowerCase();
        clipModel.clear();
        var matches = [];
        for (var i = 0; i < root.allItems.length; i++) {
            var item = root.allItems[i];
            if (!item) continue;
            if (q === "") {
                matches.push(item);
            } else {
                var searchStr = ((item.preview || "") + " " + (item.title || "") + " " + (item.info || "")).toLowerCase();
                if (searchStr.indexOf(q) !== -1) {
                    matches.push(item);
                }
            }
        }
        root.filteredItems = matches;
        for (var j = 0; j < matches.length; j++) {
            clipModel.append(matches[j]);
        }
        if (clipModel.count > 0) {
            clipList.currentIndex = 0;
        } else {
            clipList.currentIndex = -1;
        }
        root.updatePreview();
    }

    function openMenu() {
        var mon = Hyprland.focusedMonitor;
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name; });
            if (scr) root.screen = scr;
        }
        root.showing = true;
        searchBox.text = "";
        fetcher.running = true;
        Qt.callLater(function () {
            if (root.showing) {
                searchBox.forceActiveFocus();
            }
        });
    }

    function closeMenu() {
        root.showing = false;
        searchBox.text = "";
        root.previewFullText = "";
    }

    function toggleMenu() {
        root.showing ? root.closeMenu() : root.openMenu();
    }

    function copyItem(id) {
        if (!id) return;
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + id + " | wl-copy"]);
        root.closeMenu();
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggleMenu(); }
        function show(): void { root.openMenu(); }
        function hide(): void { root.closeMenu(); }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.alpha("#000000", 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeMenu()
        }

        PerspectivePanel {
            id: card
            x: Math.round((root.width - width) / 2)
            y: Math.round((root.height - height) / 2)
            width: Math.min(960, Math.max(760, root.width - 48))
            height: Math.min(620, Math.max(480, root.height - 48))
            open: root.showing

            MouseArea {
                anchors.fill: parent
                onClicked: {} // Ngăn không cho click vào backdrop
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                radius: Theme.radius
                border.color: Theme.borderAccent
                border.width: 1

                // Viền sáng trang trí ở đỉnh
                Rectangle {
                    width: 60
                    height: 2
                    color: Theme.accent
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // 1. THANH HEADER
                    Item {
                        width: parent.width
                        height: 32

                        Row {
                            spacing: 8
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "󰅌"
                                font.family: Theme.iconFont
                                font.pixelSize: 18
                                color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Lịch sử Clipboard"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                                color: Theme.text
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                height: 20
                                width: countText.implicitWidth + 12
                                radius: 10
                                color: Theme.alpha(Theme.accent, 0.15)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: clipModel.count + " mục"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.accent
                                    font.bold: true
                                }
                            }
                        }

                        // Nút đóng
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            radius: 13
                            color: closeBtnArea.containsMouse ? Theme.alpha(Theme.danger, 0.25) : Theme.alpha(Theme.text, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: closeBtnArea.containsMouse ? Theme.danger : Theme.textDim
                            }

                            MouseArea {
                                id: closeBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.closeMenu()
                            }
                        }
                    }

                    // 2. KHU VỰC NỘI DUNG CHÍNH (CHIA TỈ LỆ 6 / 4)
                    Item {
                        width: parent.width
                        height: parent.height - 32 - 24 - 24 // Trừ header, footer và khoảng cách
                        readonly property int gap: 14
                        readonly property int leftW: Math.floor((width - gap) * 0.60)
                        readonly property int rightW: width - gap - leftW

                        // PHẦN TRÁI (60%): TÌM KIẾM & DANH SÁCH CLIPBOARD
                        Item {
                            id: leftPane
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.leftW

                            // Khung tìm kiếm
                            Rectangle {
                                id: searchContainer
                                width: parent.width
                                height: 38
                                radius: 8
                                color: Theme.bgCard
                                border.width: 1
                                border.color: searchBox.activeFocus ? Theme.accent : Theme.border

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: "󰍉"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 15
                                        color: searchBox.activeFocus ? Theme.accent : Theme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    TextInput {
                                        id: searchBox
                                        width: parent.width - 50
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        color: Theme.text
                                        selectionColor: Theme.accent
                                        selectedTextColor: Theme.bg
                                        clip: true

                                        onTextChanged: root.filterItems()

                                        Keys.onDownPressed: {
                                            if (clipList.currentIndex < clipModel.count - 1) {
                                                clipList.currentIndex++;
                                                clipList.positionViewAtIndex(clipList.currentIndex, ListView.Contain);
                                                root.updatePreview();
                                            }
                                        }

                                        Keys.onUpPressed: {
                                            if (clipList.currentIndex > 0) {
                                                clipList.currentIndex--;
                                                clipList.positionViewAtIndex(clipList.currentIndex, ListView.Contain);
                                                root.updatePreview();
                                            }
                                        }

                                        Keys.onReturnPressed: {
                                            var cur = root.getCurrentItem();
                                            if (cur) root.copyItem(cur.id);
                                        }

                                        Keys.onEnterPressed: {
                                            var cur = root.getCurrentItem();
                                            if (cur) root.copyItem(cur.id);
                                        }

                                        Keys.onEscapePressed: root.closeMenu()

                                        Text {
                                            anchors.fill: parent
                                            text: "Tìm kiếm văn bản hoặc kích thước hình ảnh..."
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            color: Theme.textDim
                                            visible: !searchBox.text && !searchBox.inputMethodComposing
                                        }
                                    }

                                    Text {
                                        visible: searchBox.text !== ""
                                        text: "✕"
                                        font.pixelSize: 11
                                        color: Theme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: { searchBox.text = ""; searchBox.forceActiveFocus(); }
                                        }
                                    }
                                }
                            }

                            // Danh sách Clipboard
                            ListView {
                                id: clipList
                                anchors.top: searchContainer.bottom
                                anchors.topMargin: 8
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                clip: true
                                spacing: 6
                                model: clipModel

                                // Cuộn thông thường (chặn infinity scroll và no wrap)
                                boundsBehavior: Flickable.StopAtBounds
                                keyNavigationWraps: false

                                onCurrentIndexChanged: root.updatePreview()

                                delegate: Rectangle {
                                    id: delegateItem
                                    required property int index
                                    required property string id
                                    required property bool isImage
                                    required property string path
                                    required property string title
                                    required property string info
                                    required property string preview
                                    required property string fullText

                                    width: clipList.width
                                    height: 52
                                    radius: 8

                                    readonly property bool isSelected: index === clipList.currentIndex

                                    color: isSelected ? Theme.alpha(Theme.accent, 0.2)
                                                      : (itemHoverArea.containsMouse ? Theme.alpha(Theme.text, 0.08) : Theme.bgCard)
                                    border.width: 1
                                    border.color: isSelected ? Theme.accent : Theme.border

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        // Icon hoặc Thumbnail ảnh mini trong danh sách (70%)
                                        Rectangle {
                                            id: thumbBox
                                            width: 40
                                            height: 40
                                            radius: 6
                                            color: delegateItem.isImage ? "#000000" : Theme.alpha(Theme.text, 0.07)
                                            clip: true
                                            anchors.verticalCenter: parent.verticalCenter

                                            // Ảnh mini
                                            Image {
                                                visible: delegateItem.isImage
                                                anchors.fill: parent
                                                fillMode: Image.PreserveAspectCrop
                                                source: delegateItem.isImage && delegateItem.path ? ("file://" + delegateItem.path) : ""
                                                asynchronous: true
                                                cache: true
                                                smooth: true
                                            }

                                            // Biểu tượng văn bản nếu không phải ảnh
                                            Text {
                                                visible: !delegateItem.isImage
                                                anchors.centerIn: parent
                                                text: "󰅍"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 16
                                                color: delegateItem.isSelected ? Theme.accent : Theme.textDim
                                            }
                                        }

                                        // Thông tin chi tiết
                                        Column {
                                            width: parent.width - 50
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                text: delegateItem.isImage ? ("🖼️ Hình ảnh (" + delegateItem.title + ")") : delegateItem.preview
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.bold: delegateItem.isSelected
                                                color: delegateItem.isSelected ? Theme.text : Theme.text
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: delegateItem.info
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: delegateItem.isSelected ? Theme.accent : Theme.textDim
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: itemHoverArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: {
                                            clipList.currentIndex = delegateItem.index;
                                        }
                                        onClicked: {
                                            root.copyItem(delegateItem.id);
                                        }
                                    }
                                }
                            }
                        }

                        // PHẦN PHẢI (30%): KHUNG PREVIEW ĐỘC LẬP HIỂN THỊ ẢNH TO / VĂN BẢN ĐẦY ĐỦ
                        Rectangle {
                            id: rightPane
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.rightW
                            radius: 8
                            color: Theme.bgCard
                            border.width: 1
                            border.color: Theme.border

                            // Header của khung preview
                            Item {
                                id: previewHeader
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                height: 22

                                Row {
                                    spacing: 6
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: "󰈈"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                        color: Theme.accent
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "XEM TRƯỚC"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Badge loại dữ liệu
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 18
                                    width: typeLabel.implicitWidth + 10
                                    radius: 4
                                    color: root.currentItem && root.currentItem.isImage ? Theme.alpha(Theme.ok, 0.2) : Theme.alpha(Theme.accent, 0.2)

                                    Text {
                                        id: typeLabel
                                        anchors.centerIn: parent
                                        text: root.currentItem ? (root.currentItem.isImage ? "ẢNH TO" : "VĂN BẢN") : "---"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: root.currentItem && root.currentItem.isImage ? Theme.ok : Theme.accent
                                    }
                                }
                            }

                            // Khu vực hiển thị: Ảnh to hoặc Toàn bộ văn bản (Tự động co giãn theo chiều dọc)
                            Rectangle {
                                id: previewContainer
                                anchors.top: previewHeader.bottom
                                anchors.topMargin: 8
                                anchors.bottom: previewBottomCol.top
                                anchors.bottomMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                radius: 6
                                color: Theme.bgPanel
                                border.width: 1
                                border.color: Theme.alpha(Theme.border, 0.5)
                                clip: true

                                // Preview Ảnh lớn
                                Image {
                                    id: largeImage
                                    visible: root.currentItem && root.currentItem.isImage
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    fillMode: Image.PreserveAspectFit
                                    source: (root.currentItem && root.currentItem.isImage && root.currentItem.path) ? ("file://" + root.currentItem.path) : ""
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    mipmap: true
                                }

                                // Preview Văn bản cuộn được
                                Flickable {
                                    id: textFlickable
                                    visible: root.currentItem && !root.currentItem.isImage
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    contentWidth: width
                                    contentHeight: fullTextContent.implicitHeight
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true

                                    Text {
                                        id: fullTextContent
                                        width: parent.width
                                        text: root.previewFullText !== "" ? root.previewFullText : (root.currentItem ? root.currentItem.preview : "")
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.text
                                        wrapMode: Text.WrapAnywhere
                                        lineHeight: 1.25
                                    }
                                }

                                // Placeholder khi trống
                                Text {
                                    visible: !root.currentItem
                                    anchors.centerIn: parent
                                    text: "Chưa chọn mục nào"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textDim
                                }
                            }

                            // Metadata & Nút Copy bên phải
                            Column {
                                id: previewBottomCol
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                height: 50
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.currentItem ? root.currentItem.info : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.textDim
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 32
                                    radius: 6
                                    color: copyBtnMouse.containsMouse ? Theme.accent : Theme.alpha(Theme.accent, 0.85)

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: "󰆏"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 13
                                            color: Theme._bgBase
                                        }

                                        Text {
                                            text: "Sao chép (Enter)"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Theme._bgBase
                                        }
                                    }

                                    MouseArea {
                                        id: copyBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            var cur = root.getCurrentItem();
                                            if (cur) root.copyItem(cur.id);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. THANH HƯỚNG DẪN DƯỚI ĐÁY
                    Row {
                        width: parent.width
                        height: 20
                        spacing: 16

                        Text {
                            text: "↵ Sao chép  •  ↑/↓ Di chuyển  •  Esc Đóng  •  Nhấp chuột để dán"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
EOF
    ln -sfn "$QS_DIR/Clipboard.qml" "$HOME/.config/quickshell/Clipboard.qml"
    substep "Đã thiết lập: $QS_DIR/Clipboard.qml"

    # 4. ĐĂNG KÝ CLIPBOARD TRONG SHELL.QML
    info "4/5. Đăng ký Clipboard component trong QuickShell shell.qml..."
    local SHELL_QML="$QS_DIR/shell.qml"
    if grep -q "Clipboard" "$SHELL_QML"; then
        substep "Đã đăng ký Clipboard trong shell.qml"
    else
        sed -i 's|}|    Clipboard {}\n}|' "$SHELL_QML"
        substep "Đã thêm Clipboard {} vào: $SHELL_QML"
    fi
    ln -sfn "$SHELL_QML" "$HOME/.config/quickshell/shell.qml"

    # 5. CẤU HÌNH PHÍM TẮT SUPER + V TRONG HYPRLAND
    info "5/5. Cập nhật phím tắt Super + V trong keybinds.lua..."
    local KEYBINDS_FILES=("$HOME/.config/hypr/keybinds.lua")
    [[ -f "$HOME/.dotfiles/.config/hypr/keybinds.lua" ]] && KEYBINDS_FILES+=("$HOME/.dotfiles/.config/hypr/keybinds.lua")

    for kfile in "${KEYBINDS_FILES[@]}"; do
        local real_kfile
        real_kfile="$(realpath "$kfile")"
        if grep -q "qs ipc call clipboard toggle" "$real_kfile"; then
            substep "Phím tắt Super + V đã cấu hình QuickShell trong: $(basename "$kfile")"
        else
            sed -i 's|.*cliphist.*|hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"))|' "$real_kfile"
            sed -i 's|.*scripts/clipboard\.sh.*|hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"))|' "$real_kfile"
            substep "Đã cập nhật phím tắt Super + V vào: $kfile"
        fi
    done

    # Cập nhật script clipboard.sh để tương thích ngược
    local SCRIPT_WRAPPER="$HOME/.dotfiles/.config/hypr/scripts/clipboard.sh"
    mkdir -p "$(dirname "$SCRIPT_WRAPPER")"
    cat << 'EOF' > "$SCRIPT_WRAPPER"
#!/usr/bin/env bash
qs ipc call clipboard toggle 2>/dev/null || true
EOF
    chmod +x "$SCRIPT_WRAPPER"
    ln -sfn "$SCRIPT_WRAPPER" "$HOME/.config/hypr/scripts/clipboard.sh"
    substep "Đã cập nhật script tương thích: $SCRIPT_WRAPPER"

    # Nạp lại cấu hình Hyprland
    if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
        hyprctl reload &>/dev/null || true
        substep "Đã nạp lại cấu hình Hyprland qua hyprctl reload"
    fi

    success "Hoàn tất module Clipboard Preview!"
}
