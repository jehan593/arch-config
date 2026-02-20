" --- Basic Setup ---
let mapleader = " "
syntax on
set termguicolors
colorscheme nord

" --- General Settings ---
set number
set relativenumber
set mouse=a
set clipboard=unnamedplus
set cursorline
set scrolloff=8
set signcolumn=yes

" --- Undo & Backup (The Safety Net) ---
set noswapfile
set nobackup
set undofile
set undodir=~/.vim/undodir

" Auto-create undodir if it doesn't exist
if !isdirectory($HOME."/.vim/undodir")
    call mkdir($HOME."/.vim/undodir", "p")
endif

" --- Search & Tabs ---
set ignorecase smartcase
set hlsearch
set incsearch
set expandtab
set shiftwidth=4
set tabstop=4
set softtabstop=4
set autoindent

" --- Windows & Splits ---
set splitright
set splitbelow

" Fast split navigation (Ctrl + h/j/k/l)
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" --- Custom Logic & Keybindings ---

" jk in insert mode acts as Escape
inoremap jk <Esc>

" Space + w: Save only
nnoremap <leader>w :w<CR>

" Space + wq: Save and Quit
nnoremap <leader>wq :wq<CR>

" Space + q: Quit WITHOUT saving (forced)
nnoremap <leader>q :q!<CR>

" Space + Enter: Clear search highlights
nnoremap <leader><CR> :noh<CR>

" Stay in visual mode after indenting left
vnoremap < <gv

" Stay in visual mode after indenting right
vnoremap > >gv

" Space + d: True delete (Black Hole register)
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" x key: Delete char without overwriting clipboard
nnoremap x "_x