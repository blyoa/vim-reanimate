let s:save_cpo = &cpo
set cpo&vim
scriptencoding utf-8


function! reanimate#hook(event, ...)
	call call(s:events.add, [a:event] + a:000, s:events)
endfunction

function! reanimate#point_to_path(point)
	return s:save_dir()."/".(a:point)
endfunction

function! reanimate#path_to_point(path)
	return fnamemodify(a:path, ":t:r")
endfunction

function! reanimate#save_points_path()
	return split(globpath(s:save_dir(), "/*"), "\n")
endfunction

function! reanimate#save_points()
	return map(reanimate#save_points_path(), "reanimate#path_to_point(v:val)")
endfunction


function! reanimate#save(...)
	let new_point = a:0 && !empty(a:1) ? a:1 : s:last_point()

	" 新しい名前が既に存在時し、
	" 新しい名前と現在の保存名が違っている場合に確認する
	if count(reanimate#save_points(), new_point) && new_point != s:last_point()
		if input("Overwrite the ".new_point."? [y/n]:") != "y"
			return
		endif
	endif
	call s:save(s:context(new_point))
	let s:last_point = new_point
endfunction

function! reanimate#load(...)
	let new_point = a:0 && !empty(a:1) ? a:1 : s:last_point()
	
	" すでに保存されており
	" 今の名前と違う場合に保存を行う
	if s:is_saved() && new_point != s:last_point
		if input("Do you want to save the ".s:last_point."? [y/n]:") == "y"
			call reanimate#save(s:last_point)
		endif
	endif
	call s:load(s:context(new_point))
	let s:last_point = new_point
endfunction

function! reanimate#is_saved()
	return s:is_saved()
endfunction

function! reanimate#last_point()
	return s:last_point
endfunction




let s:last_point = ""

function! s:save_dir()
	return substitute(get(g:, "reanimate_save_dir", "~/reanimate/save_dir"), "\\", "/", "g")
endfunction

function! s:default_point()
	return get(g:, "reanimate_default_save_name", "latest")
endfunction

function! s:sessionoptions()
	return get(g:, "reanimate_sessionoptions", &sessionoptions)
endfunction

function! s:is_saved()
	return !empty(s:last_point)
endfunction

function! s:last_point()
	return empty(s:last_point) ? s:default_point() : s:last_point
endfunction

function! s:disables()
	return get(g:, "reanimate_disables", [])
endfunction

function! s:is_disable(event)
	return type(a:event) == type({}) && has_key(a:event, "name") ? count(s:disables(), a:event.name)
\		 : 0
endfunction


" event
function! s:eventable(name, func)
	let self = {}
	let self[a:name] = a:func
	return self
endfunction

function! s:events()
	let self = {}
	let self.list = []

	function! self.add(event, ...)
		return a:0 == 0 ? add(self.list, a:event) : add(self.list, s:eventable(a:event, a:1))
	endfunction

	function! self.clear()
		let self.list = []
	endfunction

	function! self.call(event, context)
		let context = extend(a:context, {"event" : a:event})
		for var in filter(copy(self.list), "has_key(v:val, a:event) && !s:is_disable(v:val)")
			if type(var[a:event]) == type({}) && has_key(var[a:event], "apply")
				call var[a:event].apply(context)
			else
				call var[a:event](context)
			endif
		endfor
	endfunction
	
	return self
endfunction

let s:events = s:events()


function! s:reanimate_hook(event, ...)
	call call(s:events.add, [a:event] + a:000, s:events)
endfunction


function! s:context(point)
	let self = {}
	let self.point = a:point
	let self.path  = reanimate#point_to_path(a:point)
	return self
endfunction


function! s:make_event(name)
	return {"name" : a:name}
endfunction

function! s:mkdir()
	let self = s:make_event("mkdir")
	function! self.save_pre(context)
		if !isdirectory(a:context.path)
			call mkdir(a:context.path)
		endif
	endfunction
	return self
endfunction

call s:reanimate_hook(s:mkdir())


function! s:session()
	let self = s:make_event("reanimate_session")

	function! self.load(context)
		let dir = a:context.path
		let tmp = &sessionoptions
		execute "set sessionoptions=".s:sessionoptions()
		if filereadable(dir."/session.vim")
			execute "source ".dir."/session.vim"
		endif
		execute "set sessionoptions=".tmp
	endfunction

	function! self.save(context)
		let dir = a:context.path
		if !filereadable(dir.'/session.vim') || filewritable(dir.'/session.vim')
			execute "mksession! ".dir."/session.vim"
		endif
	endfunction
	return self
endfunction

call s:reanimate_hook(s:session())


function! s:viminfo()
	let self = s:make_event("reanimate_viminfo")

	function! self.load(context)
		let dir = a:context.path
		if filereadable(dir."/viminfo.vim")
			execute "rviminfo ".dir."/viminfo.vim"
		endif
	endfunction

	function! self.save(context)
		let dir = a:context.path
		if !filereadable(dir.'/viminfo.vim') || filewritable(dir.'/viminfo.vim')
			execute "wviminfo!  ".dir."/viminfo.vim"
		endif
	endfunction
	return self
endfunction

call s:reanimate_hook(s:viminfo())


function! s:window()
	let self = s:make_event("reanimate_window")

	function! self.load(context)
		let dir = a:context.path
		if filereadable(dir."/vimwinpos.vim") && has("gui")
			execute "source ".dir."/vimwinpos.vim"
		endif
	endfunction

	function! self.save(context)
		let dir = a:context.path
		if !filereadable(dir.'/vimwinpos.vim') || filewritable(dir.'/vimwinpos.vim')
			if has("gui")
				let options = [
				\ 'set columns=' . &columns,
				\ 'set lines=' . &lines,
				\ 'winpos ' . getwinposx() . ' ' . getwinposy(),
				\ ]
				call writefile(options, dir.'/vimwinpos.vim')
			endif
		endif
	endfunction
	return self
endfunction

call s:reanimate_hook(s:window())



" Save
function! s:save(context)
	call s:events.call("save_pre",  a:context)
	call s:events.call("save",      a:context)
	call s:events.call("save_post", a:context)
endfunction


" Load
function! s:load(context)
	call s:events.call("load_pre",  a:context)
	call s:events.call("load",      a:context)
	call s:events.call("load_post", a:context)
endfunction





let &cpo = s:save_cpo
unlet s:save_cpo
