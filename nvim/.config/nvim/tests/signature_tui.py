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

def signature_win():
    return rpc('local w=vim.b.lsp_floating_preview;return w and vim.api.nvim_win_is_valid(w) and w or false')

def signature_open():
    return bool(signature_win())

def blink_win():
    return rpc('for _,w in ipairs(vim.api.nvim_list_wins()) do local b=vim.api.nvim_win_get_buf(w);if vim.bo[b].filetype=="blink-cmp-menu" then return w end end;return false')

def blink_open():
    return bool(blink_win())

def layer_state():
    return rpc('local s=vim.b.lsp_floating_preview;local b=nil;for _,w in ipairs(vim.api.nvim_list_wins()) do local buf=vim.api.nvim_win_get_buf(w);if vim.bo[buf].filetype=="blink-cmp-menu" then b=w end end;if not s or not vim.api.nvim_win_is_valid(s) or not b then return false end;local sc=vim.api.nvim_win_get_config(s);local bc=vim.api.nvim_win_get_config(b);return {signature=s,blink=b,signature_zindex=sc.zindex or 0,blink_zindex=bc.zindex or 0}')

def both_open():
    return bool(layer_state())

def until_front(layer, timeout=10):
    def matches():
        state = layer_state()
        if not state:
            return False
        if layer == 'signature' and state['signature_zindex'] > state['blink_zindex']:
            return state
        if layer == 'blink' and state['blink_zindex'] > state['signature_zindex']:
            return state
        return False
    return until(matches, timeout)

def overlap_snapshot():
    return rpc('local s=vim.b.lsp_floating_preview;local b=nil;for _,w in ipairs(vim.api.nvim_list_wins()) do local buf=vim.api.nvim_win_get_buf(w);if vim.bo[buf].filetype=="blink-cmp-menu" then b=w end end;if not s or not b then return false end;vim.cmd("redraw");local sp=vim.api.nvim_win_get_position(s);local bp=vim.api.nvim_win_get_position(b);local sc=vim.api.nvim_win_get_config(s);local bc=vim.api.nvim_win_get_config(b);local h=math.min(sc.height,bc.height);local width=math.min(sc.width,bc.width);local out={signature=s,blink=b,srow=sp[1],scol=sp[2],brow=bp[1],bcol=bp[2],screen={}};for row=bp[1],bp[1]+h-1 do local line={};for col=bp[2],bp[2]+width-1 do table.insert(line,vim.fn.screenstring(row+1,col+1)) end;table.insert(out.screen,table.concat(line)) end;return out')

def overlap_signature_with_blink():
    return rpc('local s=vim.b.lsp_floating_preview;local b=nil;for _,w in ipairs(vim.api.nvim_list_wins()) do local buf=vim.api.nvim_win_get_buf(w);if vim.bo[buf].filetype=="blink-cmp-menu" then b=w end end;if not s or not b then return false end;local p=vim.api.nvim_win_get_position(b);local c=vim.api.nvim_win_get_config(s);c.relative="editor";c.row=p[1];c.col=p[2];c.anchor="NW";c.win=nil;c.bufpos=nil;vim.api.nvim_win_set_config(s,c);return true')


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
    assert rpc('return vim.fn.maparg("<A-k>","i",false,true).desc') == 'LSP: Toggle completion/signature layer'
    rpc('vim.api.nvim_win_set_cursor(0,{7,12});vim.cmd("startinsert!");return true')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode=="i"'))
    os.write(master,b'(')
    until(signature_open, 30)
    print('PASS auto opens in call')
    os.write(master,b'\x1bk')
    until(lambda: not signature_open())
    time.sleep(1.2)
    assert not signature_open()
    print('PASS Alt-K closes; CursorHoldI does not reopen')
    os.write(master,b'1')
    until(lambda: rpc('return vim.api.nvim_get_current_line():find("Call%(1%)")~=nil'))
    assert not signature_open()
    print('PASS typing preserves manual close')
    os.write(master,b'\x1bk')
    until(signature_open, 30)
    print('PASS Alt-K reopens in first parameter')
    os.write(master,b'\x1bk')
    until(lambda: not signature_open())
    os.write(master,b', tes')
    until(blink_open,30)
    assert not signature_open()
    print('PASS Blink alone stays open after typing a completion trigger')
    os.write(master,b'\x1bk')
    state=until_front('signature',30)
    assert state['signature'] and state['blink']
    print('PASS Alt-K opens signature from Blink without hiding either window')

    old_updatetime=rpc('local old=vim.o.updatetime;vim.o.updatetime=60000;return old')
    overlap_signature_with_blink()
    state=until_front('signature')
    snapshot_signature=overlap_snapshot()
    assert snapshot_signature['signature']==state['signature'] and snapshot_signature['blink']==state['blink']
    assert snapshot_signature['srow']==snapshot_signature['brow'] and snapshot_signature['scol']==snapshot_signature['bcol']
    os.write(master,b'\x1bk')
    until_front('blink')
    snapshot_blink=until(lambda: (lambda x: x if x and x['screen']!=snapshot_signature['screen'] else False)(overlap_snapshot()))
    assert snapshot_blink['signature']==state['signature'] and snapshot_blink['blink']==state['blink']
    os.write(master,b'\x1bk')
    until_front('signature')
    until(lambda: (lambda x: x if x and x['screen']==snapshot_signature['screen'] else False)(overlap_snapshot()))
    rpc('vim.o.updatetime='+str(old_updatetime)+';return true')
    print('PASS Alt-K changes the rendered top layer with both windows overlapped')

    old_signature=state['signature']
    rpc('vim.lsp.buf.signature_help({focusable=false,close_events={"InsertLeave"},border="rounded"});return true')
    state=until(lambda: (lambda x: x if x and x['signature']!=old_signature and x['signature_zindex']>x['blink_zindex'] else False)(layer_state()),30)
    print('PASS signature remains in front after a new LSP response recreates its window')

    os.write(master,b'\x1bk')
    until_front('blink')
    os.write(master,b'\x0b')
    time.sleep(0.3)
    state=layer_state()
    assert state and state['blink_zindex']>state['signature_zindex']
    print('PASS Ctrl-K navigates Blink while the signature remains visible')
    rpc('local c=vim.lsp.get_clients({bufnr=0,method="textDocument/signatureHelp"})[1];vim.api.nvim_exec_autocmds("LspAttach",{buffer=0,data={client_id=c.id}});return true')
    os.write(master,b'\x0b')
    time.sleep(0.3)
    state=layer_state()
    assert state and state['blink_zindex']>state['signature_zindex']
    print('PASS late LspAttach preserves both layers and Ctrl-K navigation')
    os.write(master,b'\x1bk')
    until_front('signature',30)
    print('PASS Alt-K brings the signature forward after late LspAttach')
    os.write(master,b'\x1bk')
    until_front('blink',30)
    assert blink_open() and signature_open()
    print('PASS Alt-K switches back to Blink without closing either window')
    os.write(master,b'\x1bk')
    until_front('signature',30)
    assert blink_open() and signature_open()
    print('PASS Alt-K switches to signature layer with Blink still open')

    active=until(lambda: rpc('local w=vim.b.lsp_floating_preview;if not w or not vim.api.nvim_win_is_valid(w) then return false end;local b=vim.api.nvim_win_get_buf(w);local marks=vim.api.nvim_buf_get_extmarks(b,vim.api.nvim_get_namespaces()["nvim.lsp.signature_help"],0,-1,{details=true});if #marks==0 then return false end;return {lines=vim.api.nvim_buf_get_lines(b,0,-1,false),marks=marks}'))
    assert active['marks'][0][2] == active['lines'][1].index('text')
    assert active['marks'][0][3]['end_col'] == active['lines'][1].index('text') + len('text')
    print('PASS active-parameter highlight remains correct above Blink')

    cursor=rpc('return vim.api.nvim_win_get_cursor(0)')
    os.write(master,b'\x1b')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')!='i' or not blink_open())
    if rpc('return vim.api.nvim_get_mode().mode')=='i':
        os.write(master,b'\x1b')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='n')
    rpc('vim.api.nvim_win_set_cursor(0,{'+str(cursor[0])+','+str(cursor[1])+'});vim.cmd("startinsert");return true')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='i')
    until(signature_open,30)
    rpc('require("blink.cmp").show();return true')
    until(blink_open,30)
    state=until_front('blink',30)
    print('PASS InsertLeave and a new Insert session reset the default layer to Blink')

    os.write(master,b'\x1bk')
    until_front('signature',30)
    before=rpc('return vim.api.nvim_get_current_line()')
    os.write(master,b'\t')
    line=until(lambda: (lambda value: value if 'Call(1, testing' in value else False)(rpc('return vim.api.nvim_get_current_line()')),30)
    assert line != before
    print('PASS Tab accepts Blink completion while the signature is in front')

    if blink_open():
        rpc('require("blink.cmp").hide();return true')
        until(lambda: not blink_open())
    assert signature_open()
    os.write(master,b'\x1bk')
    until(lambda: not signature_open())
    assert rpc('return vim.api.nvim_get_mode().mode')=='i'
    print('PASS Alt-K toggles the signature when it is the only open menu')
    os.write(master,b'\x1bk')
    until(signature_open,30)
    assert not blink_open()
    assert rpc('return vim.api.nvim_get_mode().mode')=='i'
    print('PASS Alt-K reopens a signature alone without leaving Insert')
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
