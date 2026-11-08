#!/usr/bin/env python3
# AI-DLC kit: the files a shell command would write, for the shell gate (shell-gate.sh).
#   printf '%s' "<command>" | python3 -I shell-targets.py <folder the command runs in>
# Prints one absolute path per line (a folder ends with "/"): files the command would create, change or delete.
# Finds redirects, tee, sed -i, perl -i, cp, mv, rm, touch, truncate, ln, dd of=, git checkout/restore/rm/mv,
# git reset --hard, git clean -f, formatters that write, package commands that change a manifest, cd, bash -c.
# Variables the command sets itself (D=lib; … "$D/a.dart") and $HOME are filled in.
# Fails open: a target it can't read (another $VAR, $(...), a parse error) is left out; unknown commands write nothing.

import glob
import os
import re
import shlex
import sys

SEPARATORS = set(";&|()\n")
ASSIGNMENT = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.S)
DECLARE = {"export", "readonly", "declare", "local", "typeset"}
REDIRECTS = {">", ">>", ">|", "&>", "&>>"}
SKIP_NEXT = {"<", "<<", "<<<", "<<-", "<&", "<>", ">&"}
WRAPPERS = {"sudo", "command", "builtin", "exec", "nohup", "time", "nice", "env", "xargs", "npx", "bunx", "pnpx"}
MANIFESTS = {  # package command → (subcommands that change the manifest, the manifest, needs a package name)
    "npm": ({"install", "i", "add", "uninstall", "remove", "rm", "un", "update", "up"}, "package.json", True),
    "yarn": ({"add", "remove", "upgrade"}, "package.json", False),
    "pnpm": ({"add", "remove", "rm", "update", "up"}, "package.json", False),
    "bun": ({"add", "remove", "rm"}, "package.json", False),
    "composer": ({"require", "remove"}, "composer.json", False),
    "poetry": ({"add", "remove"}, "pyproject.toml", False),
    "uv": ({"add", "remove"}, "pyproject.toml", False),
    "cargo": ({"add", "remove"}, "Cargo.toml", False),
    "go": ({"get"}, "go.mod", False),
}


def strip_heredocs(cmd):
    """Drops the body of every heredoc (its text is data, not commands) and joins continued lines."""
    lines, out, i = cmd.replace("\\\n", " ").split("\n"), [], 0
    while i < len(lines):
        out.append(lines[i])
        words = re.findall(r"(?<!<)<<-?(?!<)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", lines[i])
        i += 1
        for _quote, word in words:
            while i < len(lines) and lines[i].strip() != word:
                i += 1
            i += 1
    return "\n".join(out)


def tokens(cmd):
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=";&|()<>\n")
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    return list(lex)


def simple_commands(toks):
    """Splits the tokens at ; && || | & ( ) and new lines; leaves out arithmetic, (( … )) and $(( … ))."""
    cmd, arithmetic = [], False
    for t in toks:
        if t and set(t) <= SEPARATORS:
            if cmd and not arithmetic:
                yield cmd
            cmd, arithmetic = [], "((" in t
        else:
            cmd.append(t)
    if cmd and not arithmetic:
        yield cmd


class Targets:
    def __init__(self):
        self.paths = []

    def add(self, path, cwd):
        """One target, relative to cwd; left out when it can't be known or is a device."""
        if not path or cwd is None or any(c in path for c in "$`") or path == "-":
            return
        path = os.path.expanduser(path)
        if path.startswith("/dev/"):
            return
        full = os.path.normpath(os.path.join(cwd, path))
        if any(c in path for c in "*?["):
            for match in sorted(glob.glob(full)):
                self.paths.append(match + ("/" if os.path.isdir(match) else ""))
            return
        self.paths.append(full + ("/" if os.path.isdir(full) or path in (".", "./") else ""))


def positional(args):
    return [a for a in args if not a.startswith("-") or a == "-"]


def expand(tok, env, cwd):
    """Fills in $NAME and ${NAME} when the value is known; anything else stays, and an unknown target is left out."""
    def value(m):
        name = m.group(1) or m.group(2)
        if name == "PWD" and cwd:
            return cwd
        return env.get(name, m.group(0))
    return re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)", value, tok)


def analyze(cmd, cwd, out, env, exported):
    """Adds the targets of one simple command; returns the folder for the next command (cd)."""
    if cmd[0] == "[[":
        return cwd   # a test: "[[ a > b ]]" compares, it doesn't redirect
    args, i = [], 0
    while i < len(cmd):
        t = cmd[i]
        if t in REDIRECTS:
            if t in (">", ">>", ">|") and args and re.fullmatch(r"\d{1,2}", args[-1]):
                args.pop()   # the file descriptor of "2>"
            if i + 1 < len(cmd):
                out.add(cmd[i + 1], cwd)
            i += 2
            continue
        if t in SKIP_NEXT or (t and set(t) <= set("<>&")):
            if t == ">&" and args and re.fullmatch(r"\d{1,2}", args[-1]):
                args.pop()
            i += 2
            continue
        args.append(t)
        i += 1
    while args and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", args[0]):
        args.pop(0)   # VAR=value before the command
    while args and os.path.basename(args[0]) in WRAPPERS:
        args.pop(0)
        while args and (args[0].startswith("-") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", args[0])):
            args.pop(0)
            if args and args[0].isdigit():
                args.pop(0)   # nice -n 10, xargs -n 1
    if not args:
        return cwd
    name, rest = os.path.basename(args[0]), args[1:]
    pos = positional(rest)

    if name in ("cd", "pushd"):
        if not pos:
            return os.path.expanduser("~")
        if any(c in pos[0] for c in "$`") or pos[0] == "-":
            return None
        return os.path.normpath(os.path.join(cwd, os.path.expanduser(pos[0]))) if cwd else None
    if name in ("bash", "sh", "zsh", "eval"):
        code = rest[rest.index("-c") + 1] if name != "eval" and "-c" in rest[:-1] else (" ".join(rest) if name == "eval" else None)
        if code:   # a child shell sees only the exported variables
            collect(code, cwd, out, {k: v for k, v in env.items() if k in exported or k == "HOME"}, set(exported))
        return cwd
    if name == "tee":
        for a in pos:
            out.add(a, cwd)
    elif name == "sed":
        inplace, script_given, files, j = False, False, [], 0
        while j < len(rest):
            a = rest[j]
            if a in ("-e", "--expression", "-f", "--file"):
                script_given, j = True, j + 2
                continue
            if a.startswith(("--expression=", "--file=")):
                script_given = True
            elif a == "-i":
                inplace = True
                if j + 1 < len(rest) and (rest[j + 1] == "" or rest[j + 1].startswith(".")):
                    j += 1   # the backup suffix (BSD: -i '')
            elif a.startswith("--in-place"):
                inplace = True
            elif a.startswith("-") and len(a) > 1 and not a.startswith("--"):
                if "i" in a[1:]:
                    inplace = True
                if a[-1] in "ef":
                    script_given, j = True, j + 2
                    continue
            elif a:
                files.append(a)
            j += 1
        if inplace:
            for f in (files if script_given else files[1:]):
                out.add(f, cwd)
    elif name == "perl":
        inplace = any(a.startswith("-") and not a.startswith("--") and "i" in a[1:] for a in rest)
        files, j, code_given = [], 0, False
        while j < len(rest):
            a = rest[j]
            if a.startswith("-") and not a.startswith("--") and a[-1] in "eE":
                code_given, j = True, j + 2
                continue
            if not a.startswith("-"):
                files.append(a)
            j += 1
        if inplace:
            for f in (files if code_given else files[1:]):
                out.add(f, cwd)
    elif name in ("cp", "install", "rsync", "ln", "mv"):
        if len(pos) >= 2:
            *srcs, dest = pos
            if ":" in dest and name == "rsync":
                return cwd
            if name == "mv":
                for s in srcs:
                    out.add(s, cwd)
            dest_dir = dest.endswith("/") or (cwd is not None and os.path.isdir(os.path.join(cwd, os.path.expanduser(dest))))
            if dest_dir and name != "ln":
                for s in srcs:
                    if not any(c in s for c in "$`"):
                        out.add(os.path.join(dest, os.path.basename(s.rstrip("/"))), cwd)
            else:
                out.add(dest, cwd)
    elif name in ("rm", "rmdir", "unlink", "shred"):
        for a in pos:
            out.add(a, cwd)
    elif name in ("touch", "truncate"):
        j = 0
        while j < len(rest):
            if rest[j] in ("-s", "--size", "-r", "--reference", "-t", "-d", "--date"):
                j += 2
                continue
            if not rest[j].startswith("-"):
                out.add(rest[j], cwd)
            j += 1
    elif name == "dd":
        for a in rest:
            if a.startswith("of="):
                out.add(a[3:], cwd)
    elif name == "git":
        git(rest, cwd, out)
    elif name in ("dart", "flutter") and rest[:1] == ["format"]:
        if not any(a in ("--output=none", "-onone") for a in rest) and "none" not in rest:
            for a in positional(rest[1:]):
                out.add(a, cwd)
    elif name == "dart" and rest[:1] == ["fix"] and "--apply" in rest:
        for a in positional(rest[1:]) or ["."]:
            out.add(a, cwd)
    elif name in ("dart", "flutter") and rest[:1] == ["pub"] and len(rest) > 1 and rest[1] in ("add", "remove", "upgrade", "downgrade"):
        out.add("pubspec.yaml", cwd)
    elif name == "prettier" and ("--write" in rest or "-w" in rest):
        for a in pos:
            out.add(a, cwd)
    elif name == "eslint" and "--fix" in rest:
        for a in pos:
            out.add(a, cwd)
    elif name in ("black", "isort") and not any(a in ("--check", "--diff", "--check-only") for a in rest):
        for a in pos:
            out.add(a, cwd)
    elif name == "ruff" and rest[:1] in (["format"], ["check"]):
        writes = rest[0] == "format" and not any(a in ("--check", "--diff") for a in rest) or rest[0] == "check" and "--fix" in rest
        if writes:
            for a in positional(rest[1:]) or ["."]:
                out.add(a, cwd)
    elif name == "gofmt" and "-w" in rest:
        for a in pos:
            out.add(a, cwd)
    elif name in MANIFESTS and not any(a in ("-g", "--global") for a in rest):   # global installs change no project file
        subs, manifest, needs_package = MANIFESTS[name]
        if pos and pos[0] in subs and (not needs_package or len(pos) > 1 or pos[0] in ("uninstall", "remove", "rm", "un")):
            out.add(manifest, cwd)
    return cwd


def git(rest, cwd, out):
    while rest and rest[0] in ("-C", "-c"):
        if rest[0] == "-C" and len(rest) > 1:
            cwd = os.path.normpath(os.path.join(cwd, rest[1])) if cwd else None
        rest = rest[2:]
    if not rest:
        return
    sub, args = rest[0], rest[1:]
    if sub == "checkout":
        if "--" in args:
            paths = args[args.index("--") + 1:]
        elif any(a in ("-b", "-B", "--orphan") for a in args):
            paths = []
        else:
            paths = [a for a in positional(args) if cwd and (a == "." or os.path.exists(os.path.join(cwd, a)))]
        for p in paths:
            out.add(p, cwd)
    elif sub == "restore":
        if "--staged" in args and "--worktree" not in args and "-W" not in args:
            return
        for p in positional([a for a in args if not a.startswith("--source")]):
            out.add(p, cwd)
    elif sub in ("rm", "mv"):
        if sub == "rm" and "--cached" in args:
            return
        for p in positional(args):
            out.add(p, cwd)
    elif sub == "reset" and "--hard" in args:
        out.add(".", cwd)
    elif sub == "clean" and any(a == "--force" or (a.startswith("-") and not a.startswith("--") and "f" in a) for a in args):
        out.add(".", cwd)


def collect(cmd, cwd, out, env=None, exported=None):
    env = dict(env) if env else {"HOME": os.path.expanduser("~")}
    exported = set(exported or ())
    try:
        toks = tokens(strip_heredocs(cmd))
    except ValueError:
        return   # unbalanced quotes: the shell would refuse it too
    for simple in simple_commands(toks):
        code_at = simple.index("-c") + 1 if os.path.basename(simple[0]) in ("bash", "sh", "zsh") and "-c" in simple[:-1] else -1
        simple = [t if i == code_at else expand(t, env, cwd) for i, t in enumerate(simple)]   # bash -c code: its own shell
        words = simple[1:] if simple[0] in DECLARE else simple
        if words and all(ASSIGNMENT.match(w) or (simple[0] in DECLARE and w.startswith("-")) for w in words):
            for w in words:   # D=lib · export D=lib: remembered for the commands after it
                m = ASSIGNMENT.match(w)
                if m:
                    env[m.group(1)] = m.group(2)
                    if simple[0] == "export":
                        exported.add(m.group(1))
            continue
        if simple[0] == "export":
            exported.update(w for w in simple[1:] if not w.startswith("-"))
            continue
        cwd = analyze(simple, cwd, out, env, exported)


def main():
    cwd = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
    out = Targets()
    collect(sys.stdin.read(), cwd, out)
    seen = set()
    for p in out.paths:
        if p not in seen:
            seen.add(p)
            print(p)


if __name__ == "__main__":
    main()
