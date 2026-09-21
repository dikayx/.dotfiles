" --- Plugins ---
call plug#begin()
Plug 'cocopon/iceberg.vim'
Plug 'sheerun/vim-polyglot'         " May cause issues with neovim
Plug 'luochen1990/rainbow'
Plug 'itchyny/lightline.vim'
Plug 'vim-syntastic/syntastic'
Plug 'airblade/vim-gitgutter'
call plug#end()                     " Also runs 'syntax enable' and 'filetype plugin indent on'

" --- Theme ---
set background=dark
colorscheme iceberg
let g:lightline = {'colorscheme': 'wombat'}

" --- Visuals ---
set visualbell
set laststatus=2                    " Always show the statusbar
set hlsearch incsearch
set cursorline
hi clear CursorLine                 " Underline instead of highlight
hi CursorLine gui=underline cterm=underline

" --- Editing ---
set number signcolumn=yes
set encoding=utf-8
set autoindent
set tabstop=4 shiftwidth=4

set mouse=a
set mousemodel=extend               " Right-click extends selection by default; we override it below
if !has('nvim') && has('mouse_sgr')
  set ttymouse=sgr                  " Reliable mouse reporting through tmux
endif

" Right-click in visual mode: copy to macOS clipboard, then the selection disappears
xnoremap <silent> <RightMouse> y:call system('pbcopy', @")<CR>
nnoremap <RightMouse> <Nop>

" --- Misc ---
set nobackup nowritebackup          " Disable backup files
set updatetime=300                  " Reduce delay

" --- Commands ---
command! -nargs=1 SetTab setlocal expandtab tabstop=<args> shiftwidth=0 softtabstop=-1

function! Trim()                    " Trim trailing whitespace in the whole file
  let l:save = winsaveview()
  keeppatterns %s/\s\+$//e
  call winrestview(l:save)
endfunction
command! Trim call Trim()