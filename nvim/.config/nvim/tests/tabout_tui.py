# Run with the installed configuration and plugins: python3 tests/tabout_tui.py
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
root = pathlib.Path(tempfile.mkdtemp(prefix='nvim-tabout-tui-'))
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

def prepare(line, column, filetype='typescript'):
    # Stop through RPC so an already-Normal buffer cannot leave a queued Esc
    # that exits Insert after the next preparation has finished.
    mode=rpc('require("copilot.suggestion").dismiss(); require("blink.cmp").hide(); vim.cmd("stopinsert"); return vim.api.nvim_get_mode().mode')
    if mode in ('s','S','\x13','v','V','\x16'):
        os.write(master,b'\x1b')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='n')
    code='local ls=require("luasnip"); pcall(ls.unlink_current); require("blink.cmp").hide(); require("copilot.suggestion").dismiss(); local b=vim.api.nvim_create_buf(true,false); vim.api.nvim_set_current_buf(b); vim.api.nvim_buf_set_lines(b,0,-1,false,{'+json.dumps(line)+'}); vim.bo[b].filetype='+json.dumps(filetype)+'; vim.b[b].copilot_suggestion_auto_trigger=false; vim.api.nvim_win_set_cursor(0,{1,'+str(column)+'}); vim.cmd('+json.dumps('startinsert!' if column>=len(line) else 'startinsert')+'); return b'
    rpc(code)
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='i')
    rpc('require("blink.cmp").hide(); return true')

def press_and_expect(key,line,column,label):
    os.write(master,key)
    try:
        until(lambda: rpc('return {vim.api.nvim_get_current_line(),vim.api.nvim_win_get_cursor(0)[2]}')==[line,column])
    except RuntimeError:
        detail=rpc('local ok,p=pcall(vim.treesitter.get_parser,0);return {line=vim.api.nvim_get_current_line(),cursor=vim.api.nvim_win_get_cursor(0),mode=vim.api.nvim_get_mode().mode,menu=require("blink.cmp").is_menu_visible(),suggestion=require("copilot.suggestion").is_visible() or false,parser=ok and p~=nil,tabout=require("tabout").is_enabled(),mapping=vim.fn.maparg("<Tab>","i",false,true).desc}')
        raise RuntimeError(label+': '+repr(detail))
    print('PASS',label)

def prepare_insert_snippet():
    prepare('',0)
    rpc('local ls=require("luasnip"); ls.snip_expand(ls.parser.parse_snippet("audit", "fn(${1:d}, ${2:second})$0")); return true')
    os.write(master,b'\x1b')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='n')
    rpc('vim.api.nvim_win_set_cursor(0,{1,3}); vim.cmd("startinsert"); return true')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='i')
    until(lambda: rpc('return require("luasnip").locally_jumpable(1)'))

def suggest_copilot(text):
    rpc('local sg=require("copilot.suggestion"); require("copilot.client").get=function() return nil end; local get; for i=1,30 do local name,v=debug.getupvalue(sg.update_preview,i); if name=="get_ctx" then get=v;break end end; assert(get); local ctx=get(); ctx.suggestions={{uuid="deterministic-audit",text='+json.dumps(text)+',displayText="done",range={start={line=0,character=0},["end"]={line=0,character=#vim.api.nvim_get_current_line()}}}};ctx.choice=1;ctx.shown_choices={};sg.set_keymap(vim.api.nvim_get_current_buf());vim.b.copilot_suggestion_hidden=false;sg.update_preview(ctx);assert(sg.is_visible());return true')

try:
    until(lambda: socket.exists())
    until(lambda: rpc('return package.loaded["tabout"] ~= nil'))
    rpc('require("blink.cmp.config").completion.menu.auto_show=false; return true')
    examples=[('typescript','fn()',3,4),('typescript','fn("value")',5,10),('typescript',"fn('value')",5,10),('typescript','fn(`value`)',5,10),('typescript','const xs = [1]',12,14),('cs','class C { void M() { Call(); } }',26,27),('java','class C { void m() { call(); } }',26,27),('typescriptreact','const view = <div title="value" />;',25,31),('html','<div title="value"></div>',14,18),('yaml','key: "value"',8,12),('lua','print("value")',8,13)]
    for ft,line,start,end in examples:
        prepare(line,start,ft)
        press_and_expect(b'\t',line,end,'Tab '+ft+' '+line)
    prepare('fn("value")',10)
    press_and_expect(b'\x1b[Z','fn("value")',3,'Shift-Tab backwards out of string')
    prepare('fn()',3)
    press_and_expect(b'\tX','fn()X',5,'queued Tab then text preserves forward navigation')
    prepare('fn("value")',10)
    press_and_expect(b'\x1b[ZX','fn(X"value")',4,'queued Shift-Tab then text preserves backward navigation')
    prepare('fn("value")',5)
    press_and_expect(b'\t\tX','fn("value")X',12,'queued Tabs navigate in order before text')
    prepare('fn()',3)
    rpc('vim.keymap.del("i", "<Tab>", {buffer=0}); return true')
    press_and_expect(b'\tX','fn()X',5,'global fallback preserves queued Tab then text')
    prepare('',0)
    press_and_expect(b'\t','  ',2,'native indentation preserved')
    prepare('plain',5)
    os.write(master,b'\x0a')
    until(lambda: rpc('return vim.api.nvim_buf_get_lines(0,0,-1,false)')==['plain',''])
    assert not rpc('return require("blink.cmp").is_menu_visible()')
    print('PASS Ctrl-J with closed menu preserves native newline')
    prepare('',0,'tabout_missing_parser')
    press_and_expect(b'\x0ba:','ä',2,'Ctrl-K with closed menu and no LSP preserves native digraph')
    prepare('plain',5,'tabout_missing_parser')
    press_and_expect(b'\t','plain ',6,'missing parser preserves Tab')
    prepare('fn()',3)
    rpc('vim.cmd("TaboutToggle"); return true')
    press_and_expect(b'\t','fn( )',4,'disabled tabout preserves Tab')
    rpc('vim.cmd("TaboutToggle"); return true')
    prepare('fn()',3)
    press_and_expect(b'\t','fn()',4,'re-enabled tabout navigates again')
    prepare_insert_snippet()
    rpc('vim.api.nvim_buf_set_lines(0,-1,-1,false,{"fn()"}); vim.api.nvim_win_set_cursor(0,{2,3}); assert(not require("luasnip").locally_jumpable(1) and require("luasnip").jumpable(1)); return true')
    press_and_expect(b'\t','fn()',4,'stale LuaSnip state outside snippet yields to tabout')
    assert rpc('return vim.api.nvim_win_get_cursor(0)[1]')==2
    prepare_insert_snippet()
    rpc('vim.api.nvim_buf_set_lines(0,-1,-1,false,{"plain"}); vim.api.nvim_win_set_cursor(0,{2,5}); assert(not require("luasnip").locally_jumpable(1) and require("luasnip").jumpable(1)); return true')
    press_and_expect(b'\t','plain ',6,'stale LuaSnip state outside snippet preserves native Tab')
    assert rpc('return vim.api.nvim_win_get_cursor(0)[1]')==2
    prepare('',0)
    rpc('local ls=require("luasnip"); ls.snip_expand(ls.parser.parse_snippet("audit", "fn(${1:first}, ${2:second})$0")); return true')
    until(lambda: rpc('return require("luasnip").locally_jumpable(1)'))
    os.write(master,b'\t')
    until(lambda: rpc('return vim.api.nvim_win_get_cursor(0)[2]')==10)
    print('PASS LuaSnip Tab reaches next placeholder before tabout')
    os.write(master,b'\x1b[Z')
    until(lambda: rpc('return vim.api.nvim_win_get_cursor(0)[2]')==3)
    print('PASS LuaSnip Shift-Tab returns to previous placeholder')
    prepare('fn()',3)
    suggest_copilot('fn(done)')
    os.write(master,b'\t')
    until(lambda: rpc('return vim.api.nvim_get_current_line()')=='fn(done)')
    print('PASS real Copilot suggestion acceptance wins over tabout')
    prepare_insert_snippet()
    suggest_copilot('fn(done, second)')
    os.write(master,b'\t')
    until(lambda: rpc('return vim.api.nvim_get_current_line()')=='fn(done, second)')
    print('PASS real Copilot acceptance wins over local LuaSnip jump in Insert')
    prepare_insert_snippet()
    suggest_copilot('fn(done, second)')
    os.write(master,b'\x1b')
    until(lambda: rpc('return not require("copilot.suggestion").is_visible()'))
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='i')
    print('PASS Esc dismisses visible Copilot suggestion and retains Insert mode')
    os.write(master,b'\t')
    until(lambda: rpc('return vim.api.nvim_get_current_line()')=='fn(d, second)' and rpc('return vim.api.nvim_win_get_cursor(0)[2]')==6)
    print('PASS LuaSnip jump resumes after rejecting Copilot with Esc')
    prepare('fn()',3)
    os.write(master,b'\x1b')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='n')
    print('PASS Esc without Copilot exits Insert mode')
    prepare('fn(d)',4)
    rpc('package.loaded["audit_source"]={new=function()return {get_completions=function(_,context,callback)callback({items={{label="done",insertText="done",kind=6},{label="done_other",insertText="done_other",kind=6}},is_incomplete_forward=false,is_incomplete_backward=false})end}end}; local spec={name="Audit",module="audit_source"};require("blink.cmp.config").sources.providers.audit=spec;require("blink.cmp.sources.lib").providers.audit=require("blink.cmp.sources.lib.provider").new("audit",spec);require("blink.cmp").show({providers={"audit"}});return true')
    until(lambda: rpc('return require("blink.cmp").is_menu_visible()'))
    until(lambda: rpc('return require("blink.cmp").get_selected_item_idx()')==1)
    for key,index,label in [(b'\x0a',2,'Ctrl-J selects next Blink item'),(b'\x0b',1,'Ctrl-K selects previous Blink item'),(b'\x1bj',2,'Alt-J still selects next Blink item')]:
        os.write(master,key)
        until(lambda: rpc('return require("blink.cmp").get_selected_item_idx()')==index)
        assert rpc('return require("blink.cmp").is_menu_visible()')
        assert rpc('return vim.api.nvim_get_current_line()')=='fn(d)'
        print('PASS',label)
    os.write(master,b'\x0b')
    until(lambda: rpc('return require("blink.cmp").get_selected_item_idx()')==1)
    os.write(master,b'\t')
    until(lambda: rpc('return vim.api.nvim_get_current_line()')=='fn(done)')
    print('PASS real Blink menu acceptance wins over tabout')
    prepare_insert_snippet()
    rpc('require("blink.cmp.sources.lib").providers.audit.module.get_completions=function(_,context,callback) callback({items={{label="done",kind=6,textEdit={newText="done",range={start={line=0,character=3},["end"]={line=0,character=4}}}}},is_incomplete_forward=false,is_incomplete_backward=false}) end; require("blink.cmp").show({providers={"audit"}}); return true')
    until(lambda: rpc('return require("blink.cmp").is_menu_visible() and require("luasnip").locally_jumpable(1)'))
    press_and_expect(b'\t','fn(done, second)',7,'real Blink menu acceptance wins over local LuaSnip jump in Insert')
    until(lambda: rpc('return not require("blink.cmp").is_menu_visible() and require("luasnip").locally_jumpable(1)'))
    os.write(master,b'\t')
    until(lambda: rpc('return vim.api.nvim_win_get_cursor(0)[2]')==9)
    print('PASS LuaSnip jump resumes after Blink menu closes')
    prepare('fn(d)',4)
    rpc('require("blink.cmp").show({providers={"audit"}}); return true')
    until(lambda: rpc('return require("blink.cmp").is_menu_visible()'))
    os.write(master,b'\x1b')
    until(lambda: rpc('return vim.api.nvim_get_mode().mode')=='n')
    until(lambda: rpc('return not require("blink.cmp").is_menu_visible()'))
    print('PASS Esc with Blink menu and no Copilot closes menu and exits Insert mode')
    print('TABOUT_TUI_OK')

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
