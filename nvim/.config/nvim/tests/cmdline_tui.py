# Run with the installed configuration: python3 tests/cmdline_tui.py
import fcntl
import json
import os
import pathlib
import pty
import select
import struct
import subprocess
import tempfile
import termios
import threading
import time

config = pathlib.Path(__file__).resolve().parents[1]


def run():
    with tempfile.TemporaryDirectory(prefix='nvim-cmdline-tui-') as directory:
        root = pathlib.Path(directory)
        socket = root / 'nvim.sock'
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))
        environment = dict(os.environ, TERM='xterm-256color', NVIM_LOG_FILE=str(root / 'nvim.log'),
                           XDG_STATE_HOME=str(root / 'state'), XDG_CACHE_HOME=str(root / 'cache'))
        process = subprocess.Popen(['nvim', '-i', 'NONE', '--listen', str(socket)], cwd=config,
                                   env=environment, stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)

        def drain():
            while process.poll() is None:
                if select.select([master], [], [], 0.2)[0]:
                    try:
                        os.read(master, 65536)
                    except OSError:
                        return

        threading.Thread(target=drain, daemon=True).start()

        def rpc(lua):
            expression = 'json_encode(luaeval(' + json.dumps('(function() ' + lua + ' end)()') + '))'
            result = subprocess.run(['nvim', '-u', 'NONE', '-i', 'NONE', '--server', str(socket),
                                     '--remote-expr', expression], env=environment,
                                    capture_output=True, text=True, timeout=10)
            if result.returncode:
                raise RuntimeError(result.stderr)
            return json.loads(result.stdout)

        def state():
            return rpc('return {mode=vim.api.nvim_get_mode().mode,line=vim.fn.getcmdline(),'
                       'pos=vim.fn.getcmdpos(),native=vim.fn.wildmenumode()==1,'
                       'completion=vim.fn.cmdcomplete_info(),blink=require("blink.cmp").is_menu_visible()}')

        def until(callback, label, timeout=8):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                try:
                    result = callback()
                    if result:
                        return result
                except (RuntimeError, json.JSONDecodeError):
                    pass
                if process.poll() is not None:
                    raise RuntimeError('Neovim exited: ' + label)
                time.sleep(0.05)
            raise AssertionError(label + ': ' + repr(state()))

        def press(keys):
            os.write(master, keys)

        def open_cmdline(prefix):
            press(b'\x1b')
            until(lambda: rpc('return vim.api.nvim_get_mode().mode') == 'n', 'normal mode')
            press(prefix[:1])
            until(lambda: state()['mode'] == 'c', 'command-line mode')
            time.sleep(0.05)
            for character in prefix[1:]:
                press(bytes([character]))
                time.sleep(0.02)
            until(lambda: state()['native'], 'native autocomplete for ' + repr(prefix))

        def selected(index):
            current = state()
            return current['native'] and not current['blink'] and current['completion']['selected'] == index

        try:
            until(lambda: socket.exists(), 'RPC socket')
            until(lambda: rpc('return package.loaded["blink.cmp.fuzzy"] ~= nil and MiniCmdline ~= nil'), 'plugins ready')
            rpc('vim.api.nvim_create_user_command("CmdlineAudit",function(o) vim.g.cmdline_audit=o.args end,'
                '{nargs=1,complete=function() return {"Alpha","Beta","Gamma"} end});'
                'vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true,false));'
                'vim.api.nvim_buf_set_lines(0,0,-1,false,{"CmdlineSearchAlpha CmdlineSearchBeta"}); return true')

            open_cmdline(b':CmdlineAudit ')
            until(lambda: selected(-1), 'initial menu without insertion')
            for key, index, label in [(b'\x1b[B', 0, 'Down selects first native item'),
                                      (b'\x1b[B', 1, 'Down selects next native item'),
                                      (b'\x1b[A', 0, 'Up selects previous native item'),
                                      (b'\x1bj', 1, 'Alt-j selects next native item'),
                                      (b'\x1bk', 0, 'Alt-k selects previous native item'),
                                      (b'\x0e', 1, 'Ctrl-n selects next native item'),
                                      (b'\x10', 0, 'Ctrl-p selects previous native item')]:
                press(key)
                until(lambda: selected(index), label)
                print('PASS', label)
            open_cmdline(b':CmdlineAudit ')
            until(lambda: selected(-1), 'fresh menu without insertion')
            for key, index, label in [(b'\t', 0, 'Tab selects first native item'),
                                      (b'\t', 1, 'Tab selects next native item'),
                                      (b'\x1b[Z', 0, 'Shift-Tab selects previous native item'),
                                      (b'\x0e', 1, 'Ctrl-n selects next native item'),
                                      (b'\x10', 0, 'Ctrl-p selects previous native item')]:
                press(key)
                until(lambda: selected(index), label)
                print('PASS', label)
            press(b'\r')
            until(lambda: rpc('return vim.g.cmdline_audit') == 'Alpha', 'Enter executes selected command')
            print('PASS Enter executes selected command')

            open_cmdline(b':CmdlineAudit ')
            original_pos = state()['pos']
            press(b'\x1b[D')
            until(lambda: state()['pos'] == original_pos - 1 and not state()['blink'], 'Left moves cursor')
            press(b'\x1b[C')
            until(lambda: state()['pos'] == original_pos and not state()['blink'], 'Right moves cursor')
            print('PASS Left/Right edit command instead of selecting Blink items')
            rpc('vim.fn.histadd("cmd", "CmdlineAudit Gamma"); return true')
            press(b'\x05')
            until(lambda: not state()['native'], 'cancel menu before history navigation')
            press(b'\x1b[A')
            until(lambda: state()['line'] == 'CmdlineAudit Gamma', 'Up recalls command history')
            if state()['native']:
                press(b'\x05')
                until(lambda: not state()['native'], 'cancel recalled command menu')
            press(b'\x1b[B')
            until(lambda: state()['line'] == 'CmdlineAudit ', 'Down restores current command')
            print('PASS Up/Down navigate history')

            for delimiter in (b'/', b'?'):
                open_cmdline(delimiter + b'CmdlineSearch')
                press(b'\x1b[B')
                until(lambda: selected(0), 'native search selection ' + repr(delimiter))
                press(b'\x1b[B')
                until(lambda: selected(1), 'native search next item ' + repr(delimiter))
                press(b'\x1b[A')
                until(lambda: selected(0), 'native search previous item ' + repr(delimiter))
                pattern = state()['line']
                press(b'\r')
                until(lambda: rpc('return vim.fn.getreg("/")') == pattern, 'search confirmation')
                print('PASS search', delimiter.decode(), 'completes and confirms')

            press(b'\x1b')
            rpc('local b=vim.api.nvim_create_buf(true,false); vim.api.nvim_set_current_buf(b);'
                'vim.api.nvim_buf_set_lines(b,0,-1,false,vim.fn.readfile("lua/plugin/editor.lua"));'
                'vim.bo[b].filetype="lua"; return true')
            for delimiter in (b'/', b'?'):
                open_cmdline(delimiter + b'comm')
                until(lambda: selected(-1), 'Lua search initially unselected')
                matches = state()['completion']['matches']
                assert len(matches) >= 3, repr(matches)
                for key, index, label in [(b'\x1b[B', 0, 'Down'), (b'\x1b[B', 1, 'Down'),
                                          (b'\x1b[A', 0, 'Up'), (b'\t', 1, 'Tab'),
                                          (b'\x1b[Z', 0, 'Shift-Tab'), (b'\x1bj', 1, 'Alt-j'),
                                          (b'\x1bk', 0, 'Alt-k'), (b'\x0e', 1, 'Ctrl-n'),
                                          (b'\x10', 0, 'Ctrl-p')]:
                    press(key)
                    until(lambda: selected(index), 'Lua ' + delimiter.decode() + 'comm ' + label)
                    assert state()['line'] == matches[index], repr(state())
                pattern = state()['line']
                press(b'\r')
                until(lambda: rpc('return vim.fn.getreg("/")') == pattern, 'Lua search confirmation')
                print('PASS Lua', delimiter.decode() + 'comm', 'all navigation keys and Enter')
            print('CMDLINE_TUI_OK')
        finally:
            try:
                rpc('vim.cmd("qa!"); return true')
            except Exception:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait(timeout=5)
            os.close(master)


if __name__ == '__main__':
    run()
