#!/bin/bash

if [ $# != 1 ] ; then 
echo "Usage: $0 DaemonVersion"
exit 1; 
fi 

# 1
BVER="${1}"

# 2
find . -name "*.plist" -exec plutil -lint {} \; > /dev/null

# 3
plutil -replace "DAEMON_VERSION" -string "${BVER}" "XXTExplorer/Defines/XXTEAppDefines.plist"
plutil -replace "DAEMON_VERSION" -string "${BVER}" "XXTExplorer/Defines/XXTEAppDefines.AppStore.plist"

# 4
plutil -remove "items.1" "XXTExplorer/Supporting Files/Settings.bundle/About.plist"
plutil -remove "items.1" "XXTExplorer/Supporting Files/Settings.Pro.bundle/About.plist"
plutil -insert "items.1" -xml "<dict><key>cell</key><string>About</string><key>label</key><string>XXTouch Editor
v${BVER}</string><key>value</key><string>https://www.xxtouch.com
2016-2017 © XXTouch Team.
All Rights Reserved.</string></dict>" "XXTExplorer/Supporting Files/Settings.bundle/About.plist"
plutil -insert "items.1" -xml "<dict><key>cell</key><string>About</string><key>label</key><string>XXTouch
v${BVER}</string><key>value</key><string>https://www.xxtouch.com
2016-2017 © XXTouch Team.
All Rights Reserved.</string></dict>" "XXTExplorer/Supporting Files/Settings.Pro.bundle/About.plist"

# 5
plutil -remove "items.6" "XXTExplorer/Supporting Files/Settings.bundle/About.plist"
plutil -remove "items.6" "XXTExplorer/Supporting Files/Settings.Pro.bundle/About.plist"
plutil -insert "items.6" -xml "<dict><key>cell</key><string>Button</string><key>label</key><string>Mail Feedback</string><key>action</key><string>SendMail:</string><key>args</key><dict><key>subject</key><string>[Feedback] XXTouch Editor v${BVER}</string><key>toRecipients</key><array><string>bug@xxtouch.com</string></array><key>ccRecipients</key><array><string>i.82@qq.com</string></array></dict></dict>" "XXTExplorer/Supporting Files/Settings.bundle/About.plist"
plutil -insert "items.6" -xml "<dict><key>cell</key><string>Button</string><key>label</key><string>Mail Feedback</string><key>action</key><string>SendMail:</string><key>args</key><dict><key>subject</key><string>[Feedback] XXTouch v${BVER}</string><key>toRecipients</key><array><string>bug@xxtouch.com</string></array><key>ccRecipients</key><array><string>i.82@qq.com</string></array></dict></dict>" "XXTExplorer/Supporting Files/Settings.Pro.bundle/About.plist"

# 6
plutil -remove "PreferenceSpecifiers.3" "XXTExplorer/Supporting Files/Settings.bundle/Root.plist"
plutil -remove "PreferenceSpecifiers.3" "XXTExplorer/Supporting Files/Settings.Pro.bundle/Root.plist"
plutil -insert "PreferenceSpecifiers.3" -xml "<dict><key>Type</key><string>PSTitleValueSpecifier</string><key>DefaultValue</key><string>${BVER}</string><key>Title</key><string>Version</string><key>Key</key><string>sbVersion</string></dict>" "XXTExplorer/Supporting Files/Settings.bundle/Root.plist"
plutil -insert "PreferenceSpecifiers.3" -xml "<dict><key>Type</key><string>PSTitleValueSpecifier</string><key>DefaultValue</key><string>${BVER}</string><key>Title</key><string>Version</string><key>Key</key><string>sbVersion</string></dict>" "XXTExplorer/Supporting Files/Settings.Pro.bundle/Root.plist"