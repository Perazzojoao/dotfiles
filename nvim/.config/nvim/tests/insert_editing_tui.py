# Run with the installed configuration: python3 tests/insert_editing_tui.py
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
root = pathlib.Path(tempfile.mkdtemp(prefix='nvim-insert-editing-tui-'))
socket = root / 'nvim.sock'
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))
environment = dict(os.environ, TERM='xterm-256color', NVIM_LOG_FILE=str(root / 'nvim.log'), XDG_STATE_HOME=str(root / 'state'), XDG_CACHE_HOME=str(root / 'cache'))
process = subprocess.Popen(['nvim', '-i', 'NONE', '--listen', str(socket)], cwd=config, env=environment, stdin=slave, stdout=slave, stderr=slave)
os.close(slave)
terminal = bytearray()


def drain():
    while process.poll() is None:
        if select.select([master], [], [], 0.2)[0]:
            try:
                terminal.extend(os.read(master, 65536))
            except OSError:
                return


threading.Thread(target=drain, daemon=True).start()


def rpc(lua):
    expression = 'json_encode(luaeval(' + json.dumps('(function() ' + lua + ' end)()', ensure_ascii=False) + '))'
    result = subprocess.run(['nvim', '-u', 'NONE', '-i', 'NONE', '--server', str(socket), '--remote-expr', expression], env=environment, capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)


def until(callback, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            value = callback()
            if value:
                return value
        except (RuntimeError, json.JSONDecodeError):
            pass
        if process.poll() is not None:
            raise RuntimeError('Neovim exited before verification')
        time.sleep(0.05)
    raise RuntimeError('Timed out waiting for UI state')


def prepare(line, column, lines=None, row=1):
    lines = lines or [line]
    line = lines[row - 1]
    rpc('vim.cmd("stopinsert"); return true')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode') == 'n')
    start = 'startinsert!' if column >= len(line.encode('utf-8')) else 'startinsert'
    lua_lines = '{' + ','.join(json.dumps(value, ensure_ascii=False) for value in lines) + '}'
    rpc('local b=vim.api.nvim_create_buf(true,false); vim.api.nvim_set_current_buf(b); vim.api.nvim_buf_set_lines(b,0,-1,false,'+lua_lines+'); vim.bo[b].filetype="text"; vim.b[b].copilot_suggestion_auto_trigger=false; vim.api.nvim_win_set_cursor(0,{'+str(row)+','+str(column)+'}); vim.cmd('+json.dumps(start)+'); return true')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode') == 'i')


def press_and_expect(key, line, column, label):
    os.write(master, key)
    try:
        until(lambda: rpc('return {vim.api.nvim_get_current_line(),vim.api.nvim_win_get_cursor(0)[2],vim.api.nvim_get_mode().mode}') == [line, column, 'i'])
    except RuntimeError as error:
        actual = rpc('return {vim.api.nvim_get_current_line(),vim.api.nvim_win_get_cursor(0)[2],vim.api.nvim_get_mode().mode}')
        raise RuntimeError(label + ': observed ' + repr(actual)) from error
    print('PASS', label)


def press_and_expect_buffer(key, lines, row, column, label):
    os.write(master, key)
    expected = [lines, row, column, 'i']
    try:
        until(lambda: rpc('return {vim.api.nvim_buf_get_lines(0,0,-1,false),vim.api.nvim_win_get_cursor(0)[1],vim.api.nvim_win_get_cursor(0)[2],vim.api.nvim_get_mode().mode}') == expected)
    except RuntimeError as error:
        actual = rpc('return {vim.api.nvim_buf_get_lines(0,0,-1,false),vim.api.nvim_win_get_cursor(0)[1],vim.api.nvim_win_get_cursor(0)[2],vim.api.nvim_get_mode().mode}')
        raise RuntimeError(label + ': observed ' + repr(actual)) from error
    print('PASS', label)


try:
    until(lambda: socket.exists())
    until(lambda: rpc('return vim.fn.maparg("<C-BS>","i",false,true).desc == "Delete word backward" and vim.fn.maparg("<C-Delete>","i",false,true).desc == "Delete word forward"'))
    # Stop completion UI from intercepting keys while keeping the real keymaps active.
    rpc('if package.loaded["blink.cmp"] then require("blink.cmp.config").completion.menu.auto_show=false; require("blink.cmp").hide() end; return true')

    prepare('alpha beta', 8)
    press_and_expect(b'\x1b[127;5u', 'alpha ta', 6, 'Ctrl+Backspace deletes the preceding part of an ASCII word')
    prepare('αβγ tail', 4)
    press_and_expect(b'\x1b[127;5u', 'γ tail', 0, 'Ctrl+Backspace handles UTF-8 word characters')
    prepare('one, two', 4)
    press_and_expect(b'\x1b[127;5u', 'one two', 3, 'Ctrl+Backspace removes punctuation at a word boundary')
    prepare('one   two', 6)
    press_and_expect(b'\x1b[127;5u', 'two', 0, 'Ctrl+Backspace removes preceding whitespace and word')
    prepare('alpha beta', 6)
    press_and_expect(b'\x1b[127;5u', 'beta', 0, 'Ctrl+Backspace at a word start deletes the prior word')

    prepare('alpha beta', 2)
    press_and_expect(b'\x1b[3;5~', 'albeta', 2, 'Ctrl+Delete deletes forward from the middle of a word')
    prepare('alpha beta', 0)
    press_and_expect(b'\x1b[3;5~', 'beta', 0, 'Ctrl+Delete at a word start deletes the whole word')
    prepare('αβγ tail', 2)
    press_and_expect(b'\x1b[3;5~', 'αtail', 2, 'Ctrl+Delete handles UTF-8 word characters')
    prepare('one   two', 3)
    press_and_expect(b'\x1b[3;5~', 'onetwo', 3, 'Ctrl+Delete removes forward whitespace')
    prepare('alpha', 5)
    press_and_expect(b'\x1b[3;5~', 'alpha', 5, 'Ctrl+Delete at end of line preserves the preceding character')
    prepare('second', 0, ['first', 'second'], 2)
    press_and_expect_buffer(b'\x1b[127;5u', ['first', 'second'], 2, 0, 'Ctrl+Backspace at start of a line preserves the previous line')
    prepare('    second', 4, ['first', '    second'], 2)
    press_and_expect_buffer(b'\x1b[127;5u', ['first', 'second'], 2, 0, 'Ctrl+Backspace removes indentation without joining the previous line')
    prepare('first', 5, ['first', 'second'])
    press_and_expect_buffer(b'\x1b[3;5~', ['first', 'second'], 1, 5, 'Ctrl+Delete at end of a line preserves the next line')
    prepare('first', 0, ['first', 'second'])
    press_and_expect_buffer(b'\x1b[3;5~', ['', 'second'], 1, 0, 'Ctrl+Delete removes the last word without joining the next line')
    prepare('first  ', 5, ['first  ', 'second'])
    press_and_expect_buffer(b'\x1b[3;5~', ['first', 'second'], 1, 5, 'Ctrl+Delete removes trailing spaces without joining the next line')
    prepare('', 0)
    press_and_expect(b'\x1b[3;5~', '', 0, 'Ctrl+Delete on an empty line is a no-op')

    prepare('abc', 2)
    press_and_expect(b'\x08', 'ac', 1, 'Ctrl+H keeps single-character Backspace behavior')
    prepare('abc', 2)
    press_and_expect(b'\x7f', 'ac', 1, 'Backspace keeps single-character deletion for DEL input')
    prepare('abc', 1)
    press_and_expect(b'\x1b[3~', 'ac', 1, 'Delete keeps single-character forward deletion')
    print('INSERT_EDITING_TUI_OK')
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
    (root / 'terminal.raw').write_bytes(terminal)
