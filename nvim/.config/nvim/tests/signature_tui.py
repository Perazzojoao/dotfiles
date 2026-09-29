# Run with the installed configuration, Roslyn, and .NET SDK: python3 tests/signature_tui.py
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
root = pathlib.Path(tempfile.mkdtemp(prefix='nvim-signature-tui-'))
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

def until(callback, timeout=10):
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

def signature_open():
    return rpc('local w=vim.b.lsp_floating_preview;return w and vim.api.nvim_win_is_valid(w) or false')


try:
    until(lambda: socket.exists())
    until(lambda: rpc('return package.loaded["blink.cmp"] ~= nil'))
    project = root / 'proj'
    project.mkdir()
    sdk_major = subprocess.check_output(['dotnet', '--version'], text=True).split('.')[0]
    (project / 'Probe.csproj').write_text(
        '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup>'
        f'<TargetFramework>net{sdk_major}.0</TargetFramework>'
        '</PropertyGroup></Project>'
    )
    target = project / 'Probe.cs'
    target.write_text('''public class Probe
{
    public void Call(int number, string text) { }
    public void Run()
    {
        string testing = "ok";
        Call
    }
}
''')
    rpc('vim.cmd("edit "..'+json.dumps(str(target))+');return true')
    until(lambda: rpc('return #vim.lsp.get_clients({bufnr=0,method="textDocument/signatureHelp"})>0'),60)
    assert rpc('return vim.fn.maparg("<C-k>","i",false,true).desc') == 'LSP: Toggle function signature'
    rpc('vim.api.nvim_win_set_cursor(0,{7,12});vim.cmd("startinsert!");return true')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode=="i"'))
    os.write(master,b'(')
    until(signature_open, 30)
    print('PASS auto opens in call')
    os.write(master,b'\x0b')
    until(lambda: not signature_open())
    time.sleep(1.2)
    assert not signature_open()
    print('PASS Ctrl-K closes; CursorHoldI does not reopen')
    os.write(master,b'1')
    until(lambda: rpc('return vim.api.nvim_get_current_line():find("Call%(1%)")~=nil'))
    assert not signature_open()
    print('PASS typing preserves manual close')
    os.write(master,b'\x0b')
    until(signature_open, 30)
    print('PASS Ctrl-K reopens in first parameter')
    os.write(master,b', tes')
    until(lambda: rpc('return require("blink.cmp").is_menu_visible()'),30)
    assert not signature_open()
    print('PASS Blink takes priority')
    os.write(master,b'\x0b')
    until(lambda: not rpc('return require("blink.cmp").is_menu_visible()') and signature_open(), 30)
    print('PASS Ctrl-K closes Blink before opening the signature')
    rpc('require("blink.cmp").show();return true')
    until(lambda: rpc('return require("blink.cmp").is_menu_visible()'), 30)
    assert not signature_open()
    rpc('require("blink.cmp").hide();return true')
    until(lambda: not rpc('return require("blink.cmp").is_menu_visible()') and signature_open(), 30)
    print('PASS auto reopens after Blink closes in second parameter')
    os.write(master,b'\x0b')
    until(lambda: not signature_open())
    rpc('require("blink.cmp").show();return true')
    until(lambda: rpc('return require("blink.cmp").is_menu_visible()'), 30)
    rpc('require("blink.cmp").hide();return true')
    until(lambda: not rpc('return require("blink.cmp").is_menu_visible()'))
    time.sleep(0.3)
    assert not signature_open()
    print('PASS Blink closing does not undo a manual close')
    os.write(master,b'\x0b')
    until(signature_open, 30)
    active = rpc('local w=vim.b.lsp_floating_preview;local b=vim.api.nvim_win_get_buf(w);return {lines=vim.api.nvim_buf_get_lines(b,0,-1,false),marks=vim.api.nvim_buf_get_extmarks(b,vim.api.nvim_get_namespaces()["nvim.lsp.signature_help"],0,-1,{details=true})}')
    assert active['marks'][0][2] == active['lines'][1].index('text')
    assert active['marks'][0][3]['end_col'] == active['lines'][1].index('text') + len('text')
    print('PASS Ctrl-K closes and reopens in current parameter')
    print('SIGNATURE_TOGGLE_OK')
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
