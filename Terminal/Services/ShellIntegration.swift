// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Minimal shell integration: environment variables and bundled scripts.
///
/// Full prompt marking (OSC 133) requires the shell to emit sequences. When
/// `enableShellIntegration` is on, this layer sets `TERM_PROGRAM` and
/// `TERMINAL_SHELL_INTEGRATION` so a sourced integration script can detect
/// it. Auto-injection via ZDOTDIR/BASH_ENV shims is a planned follow-up;
/// for now users can source the bundled scripts manually.
enum ShellIntegration {
    /// Environment for a new terminal process.
    ///
    /// `base` is typically `TerminalType.processEnvironment` (now a full
    /// passthrough of the parent environment with TERM/COLORTERM/LANG overrides).
    /// Extra keys are only added — never removed.
    static func environment(base: [String], enableShellIntegration: Bool) -> [String] {
        var env = base
        if !env.contains(where: { $0.hasPrefix("TERM_PROGRAM=") }) {
            env.append("TERM_PROGRAM=Terminal")
        }
        if !env.contains(where: { $0.hasPrefix("TERM_PROGRAM_VERSION=") }),
           let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            env.append("TERM_PROGRAM_VERSION=\(version)")
        }
        if !env.contains(where: { $0.hasPrefix("COLORTERM=") }) {
            env.append("COLORTERM=truecolor")
        }
        if enableShellIntegration {
            if !env.contains(where: { $0.hasPrefix("TERMINAL_SHELL_INTEGRATION=") }) {
                env.append("TERMINAL_SHELL_INTEGRATION=1")
            }
        }
        return env
    }

    // MARK: - Bundled integration scripts (for manual sourcing)

    /// Zsh integration: emits OSC 7 (cwd) and OSC 133 (semantic prompts).
    static let zshScript = #"""
        # Terminal shell integration — zsh
        # Emits OSC 7 (cwd) and OSC 133 (semantic prompts) for reliable
        # current-directory tracking and prompt navigation.
        if [[ -n "$TERMINAL_SHELL_INTEGRATION" ]]; then
          terminal_zsh_cwd() {
            local url_path=''
            {
              local i ch hexch LC_CTYPE=C LC_COLLATE=C LC_ALL= LANG=
              for ((i = 1; i <= ${#PWD}; ++i)); do
                ch="$PWD[i]"
                if [[ "$ch" =~ [/._~A-Za-z0-9-] ]]; then
                  url_path+="$ch"
                else
                  printf -v hexch "%02X" "'$ch"
                  url_path+="%$hexch"
                fi
              done
            }
            printf '\033]7;%s\007' "file://$HOST$url_path"
          }
          terminal_zsh_prompt_start() {
            printf '\033]133;A\007'
          }
          terminal_zsh_prompt_end() {
            printf '\033]133;B\007'
          }
          terminal_zsh_preexec() {
            printf '\033]133;C\007'
          }
          terminal_zsh_precmd() {
            local ret=$?
            printf '\033]133;D;%s\007' "$ret"
            terminal_zsh_cwd
          }
          autoload -Uz add-zsh-hook
          add-zsh-hook precmd terminal_zsh_precmd
          add-zsh-hook preexec terminal_zsh_preexec
          if [[ -o interactive ]]; then
            precmd_functions=(terminal_zsh_prompt_start $precmd_functions)
          fi
        fi
        """#

    /// Bash integration: emits OSC 7 and OSC 133 via PROMPT_COMMAND and DEBUG trap.
    static let bashScript = #"""
        # Terminal shell integration — bash
        if [[ -n "$TERMINAL_SHELL_INTEGRATION" ]]; then
          terminal_bash_cwd() {
            local url_path=""
            local i ch hexch
            for ((i=0; i<${#PWD}; ++i)); do
              ch="${PWD:i:1}"
              if [[ "$ch" =~ [/._~A-Za-z0-9-] ]]; then
                url_path+="$ch"
              else
                printf -v hexch "%02X" "'$ch"
                url_path+="%$hexch"
              fi
            done
            printf '\033]7;%s\007' "file://$HOSTNAME$url_path"
          }
          __terminal_bash_precmd() {
            local ret=$?
            printf '\033]133;D;%s\007' "$ret"
            terminal_bash_cwd
          }
          __terminal_bash_preexec() {
            printf '\033]133;C\007'
          }
          if [[ -z "$PROMPT_COMMAND" ]]; then
            PROMPT_COMMAND="__terminal_bash_precmd"
          else
            PROMPT_COMMAND="__terminal_bash_precmd; $PROMPT_COMMAND"
          fi
          trap '__terminal_bash_preexec' DEBUG
        fi
        """#
}
