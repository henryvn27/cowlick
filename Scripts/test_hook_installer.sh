#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
temporary_directory="$(mktemp -d "${TMPDIR%/}/cowlick-hook-tests.XXXXXX")"
chmod 700 "$temporary_directory"
trap 'rm -rf "$temporary_directory"' EXIT

test_home="$temporary_directory/home"
hooks_directory="$test_home/.codex"
helper="$temporary_directory/cowlick-hook"
mkdir -p "$hooks_directory"
mkdir -p "$test_home/.local/bin"
chmod 755 "$test_home/.local/bin"
print -n -- '#!/bin/zsh\nexit 0\n' > "$helper"
chmod 755 "$helper"

COWLICK_TEST_HOME="$test_home" COWLICK_TEST_HOOKS="$hooks_directory/hooks.json" swift -e '
  import Foundation

  let environment = ProcessInfo.processInfo.environment
  let home = environment["COWLICK_TEST_HOME"]!
  let destination = URL(fileURLWithPath: environment["COWLICK_TEST_HOOKS"]!)
  let root: [String: Any] = [
    "future": ["preserve": true],
    "hooks": [
      "Stop": [[
        "hooks": [
          ["type": "command", "command": "/usr/local/bin/unrelated"],
          [
            "type": "command",
            "command": "\(home)/.local/bin/notchrelay-hook hook",
            "notchRelay": ["product": "NotchRelay", "protocol": 1],
          ],
        ]
      ]]
    ],
  ]
  try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    .write(to: destination, options: .atomic)
'
chmod 600 "$hooks_directory/hooks.json"

COWLICK_HOME="$test_home" swift "$script_dir/install_hooks.swift" install --helper "$helper" >/dev/null
[[ "$(stat -f '%Lp' "$test_home/.local/bin")" == "755" ]] \
  || { print -u2 "installer changed shared ~/.local/bin permissions"; exit 1; }
first_hash="$(shasum -a 256 "$hooks_directory/hooks.json" | awk '{print $1}')"
COWLICK_HOME="$test_home" swift "$script_dir/install_hooks.swift" install --helper "$helper" >/dev/null
second_hash="$(shasum -a 256 "$hooks_directory/hooks.json" | awk '{print $1}')"
[[ "$first_hash" == "$second_hash" ]] || { print -u2 "hook installation is not idempotent"; exit 1; }

COWLICK_TEST_HOOKS="$hooks_directory/hooks.json" swift -e '
  import Foundation

  let path = ProcessInfo.processInfo.environment["COWLICK_TEST_HOOKS"]!
  let root = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
  let future = root["future"] as! [String: Any]
  precondition(future["preserve"] as? Bool == true)
  let hooks = root["hooks"] as! [String: Any]
  for event in ["SessionStart", "UserPromptSubmit", "PermissionRequest", "Stop"] {
    let groups = hooks[event] as! [[String: Any]]
    let handlers = groups.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
    let owned = handlers.filter { ($0["cowlick"] as? [String: Any])?["product"] as? String == "Cowlick" }
    precondition(owned.count == 1)
    precondition(!handlers.contains { ($0["command"] as? String)?.contains("notchrelay-hook") == true })
  }
'

COWLICK_HOME="$test_home" swift "$script_dir/install_hooks.swift" remove >/dev/null
COWLICK_TEST_HOOKS="$hooks_directory/hooks.json" swift -e '
  import Foundation

  let path = ProcessInfo.processInfo.environment["COWLICK_TEST_HOOKS"]!
  let root = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
  precondition((root["future"] as? [String: Any])?["preserve"] as? Bool == true)
  let hooks = root["hooks"] as! [String: Any]
  let stop = hooks["Stop"] as! [[String: Any]]
  let handlers = stop.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
  precondition(handlers.count == 1)
  precondition(handlers[0]["command"] as? String == "/usr/local/bin/unrelated")
  for event in ["SessionStart", "UserPromptSubmit", "PermissionRequest"] {
    precondition(hooks[event] == nil)
  }
'

foreign_home="$temporary_directory/foreign-home"
foreign_hooks="$foreign_home/.codex/hooks.json"
foreign_installed_helper="$foreign_home/Library/Application Support/Cowlick/bin/cowlick-hook"
mkdir -p "${foreign_hooks:h}" "${foreign_installed_helper:h}"
print -n -- '{"custom":"preserve","hooks":{}}' > "$foreign_hooks"
print -n -- 'foreign-helper' > "$foreign_installed_helper"
foreign_hooks_hash="$(shasum -a 256 "$foreign_hooks" | awk '{print $1}')"
foreign_helper_hash="$(shasum -a 256 "$foreign_installed_helper" | awk '{print $1}')"

if COWLICK_HOME="$foreign_home" swift "$script_dir/install_hooks.swift" \
  install --helper "$helper" >/dev/null 2>&1; then
  print -u2 "installer replaced a foreign helper without an owned shim"
  exit 1
fi
if COWLICK_HOME="$foreign_home" swift "$script_dir/install_hooks.swift" remove \
  >/dev/null 2>&1; then
  print -u2 "remover deleted a foreign helper without an owned shim"
  exit 1
fi
[[ "$(shasum -a 256 "$foreign_hooks" | awk '{print $1}')" == "$foreign_hooks_hash" ]]
[[ "$(shasum -a 256 "$foreign_installed_helper" | awk '{print $1}')" \
    == "$foreign_helper_hash" ]]

print "Hook installer smoke tests passed."
