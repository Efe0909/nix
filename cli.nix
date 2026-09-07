{ config, pkgs, lib, ... }:

# Shell (bash), vim, tmux ve debug araclari.
# Dosya adi cli.nix — shell.nix DEGIL, cunku o ad Nix'te nix-shell'in dev
# ortamina ayrilmis, karisirdi.
#
# Bu makine daily driver DEGIL — konfor konfigurasyonu minimum, debug
# kabiliyeti maksimum. Ayrim onemli: bugun lsof/dig/nettop olmasa failure
# debug edilemezdi, ama zsh eklenti yoneticisi tam da sistem bozukken
# girisi yavaslattigi icin zarar verdi.
#
# Home Manager YOK: nadiren giris yapilan bir makineye bir input ve bir
# degerlendirme katmani daha eklemek kazandirdigindan fazlasini goturur.

let
  # Mac'teki .vimrc — 207 satir, eklentisiz, tasinabilir.
  # Pi'dekinden (42 satir) kopyalanmadi; modern olan bu.
  vimrc = ''
    set nocompatible
    syntax enable
    filetype plugin indent on

    " --- UI ---
    set ruler showcmd showmatch noshowmode noerrorbells visualbell
    set number relativenumber numberwidth=4
    set title laststatus=2 showtabline=2 signcolumn=yes
    set scrolloff=8 sidescrolloff=8
    set nowrap linebreak breakindent
    set splitbelow splitright
    set pumheight=10 conceallevel=0 cmdheight=1
    set statusline=%f%=%l/%L

    " --- Girinti ---
    set tabstop=4 shiftwidth=4 softtabstop=4 expandtab
    set autoindent smartindent

    " --- Arama ---
    set hlsearch incsearch ignorecase smartcase

    " --- Dosya / gecmis ---
    set encoding=UTF-8 fileencoding=utf-8
    set history=1000
    set nobackup nowritebackup noswapfile
    set backspace=indent,eol,start
    set updatetime=250 timeoutlen=300
    set completeopt=menuone,noselect
    set whichwrap+=<,>,[,],h,l
    set iskeyword+=-
    set mouse=a

    " Kalici undo: vim kapansa bile geri alma gecmisi durur.
    set undofile
    set undodir=~/.local/state/vim/undo
    if !isdirectory(&undodir) | call mkdir(&undodir, "p", 0700) | endif

    " --- Kisayollar ---
    let mapleader = " "
    let maplocalleader = " "
    nnoremap <Space> <Nop>
    vnoremap <Space> <Nop>

    " ; -> :  (Shift'e basmadan komut)
    nnoremap ; :
    vnoremap ; :

    " Kaydirirken imleci ortala
    nnoremap <C-d> <C-d>zz
    nnoremap <C-u> <C-u>zz
    nnoremap n nzzzv
    nnoremap N Nzzzv

    " Buffer
    nnoremap <Tab> :bnext<CR>
    nnoremap <S-Tab> :bprevious<CR>

    " Pencere (split/pane)
    nnoremap <leader>v <C-w>v
    nnoremap <leader>h <C-w>s
    nnoremap <leader>se <C-w>=
    nnoremap <leader>xs :close<CR>
    nnoremap <C-k> :wincmd k<CR>
    nnoremap <C-j> :wincmd j<CR>
    nnoremap <C-h> :wincmd h<CR>
    nnoremap <C-l> :wincmd l<CR>

    " Sekme
    nnoremap <leader>to :tabnew<CR>
    nnoremap <leader>tx :tabclose<CR>
    nnoremap <leader>tn :tabn<CR>
    nnoremap <leader>tp :tabp<CR>

    " Sistem panosu
    noremap <leader>y "+y
    noremap <leader>Y "+Y

    " netrw
    nnoremap <silent> <leader>e :Lex<CR>
    let g:netrw_banner = 0
    let g:netrw_liststyle = 3
    let g:netrw_browse_split = 4
    let g:netrw_altv = 1
    let g:netrw_winsize = 25
    augroup netrw_setup
      autocmd!
      autocmd FileType netrw nmap <buffer> l <CR>
    augroup END

    " --- Gorunum ---
    colorscheme wildcharm
    set background=dark
    set termguicolors
    set clipboard=unnamedplus
    highlight ExtraWhitespace ctermbg=red guibg=red
    match ExtraWhitespace /\s\+$/

    " Insert modda cizgi imleci, digerlerinde blok
    let &t_SI = "\e[6 q"
    let &t_EI = "\e[2 q"

    " --- Dosya turune ozel ---
    autocmd FileType python   setlocal expandtab shiftwidth=4 softtabstop=4
    autocmd FileType rust     setlocal shiftwidth=4 softtabstop=4 noexpandtab
    autocmd FileType markdown setlocal wrap spell
    set spelllang=en
    set nospell

    " Dosyayi acinca en son kalinan satira don
    autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
      \ | exe "normal! g`\"" | endif

    " ==========================================================
    " Splash ekrani
    " ==========================================================
    " Vim'in yerlesik :intro metnine EKLEME YAPILAMAZ (derlenmis).
    " Yontem: yerlesigi kapat (shortmess+=I), aynisini yeniden ciz,
    " altina kendi kisayollarini ekle.
    set shortmess+=I

    function! s:Karsilama() abort
      if argc() != 0 || line2byte('$') != -1 || &insertmode | return | endif
      let l:satirlar = [
        \ "", "", "", "", "",
        \ "                    VIM - Vi IMproved",
        \ "",
        \ "                     " . v:version / 100 . "." . v:version % 100,
        \ "               by Bram Moolenaar et al.",
        \ "        Vim is open source and freely distributable",
        \ "",
        \ "     type  :q<Enter>               to exit",
        \ "     type  :help<Enter>  or  <F1>  for on-line help",
        \ "",
        \ "  ─────────────────  evsunucu  ─────────────────",
        \ "",
        \ "     ;              yerine :        (komut modu)",
        \ "     <Space>e       netrw dosya gezgini",
        \ "     <Space>v       dikey split       (yan yana)",
        \ "     <Space>h       yatay split       (alt alta)",
        \ "     <Space>se      split'leri esitle",
        \ "     <Space>xs      split'i kapat",
        \ "     <C-h/j/k/l>    split'ler arasi gecis",
        \ "     <Tab>/<S-Tab>  buffer ileri/geri",
        \ "     <Space>y       sistem panosuna kopyala",
        \ "",
        \ "     netrw icinde:  l  dosyayi ac,  -  ust dizin",
        \ ]
      call append(0, l:satirlar)
      normal! gg
      setlocal buftype=nofile bufhidden=wipe noswapfile nomodified
      setlocal nonumber norelativenumber nolist
      " Ilk tusa basinca normal bos buffer'a don
      nnoremap <buffer><silent> <Esc> :enew<CR>
    endfunction

    autocmd VimEnter * call s:Karsilama()
  '';

in {
  # ================================================================== VIM ====
  environment.systemPackages = [
    (pkgs.vim-full.customize {
      name = "vim";
      vimrcConfig.customRC = vimrc;
    })
  ] ++ (with pkgs; [
    # --- debug: bunlar konfor degil, ihtiyac ---
    htop ncdu lsof dnsutils tcpdump iotop jq ripgrep tree rsync curl wget
    smartmontools          # 458GB backup diskinin SMART izlemesi
    pciutils usbutils file
    # --- shell yardimcilari ---
    fzf bash-completion git tmux
  ]);

  environment.variables.EDITOR = "vim";
  environment.variables.VISUAL = "vim";

  # ================================================================= BASH ====
  programs.bash.completion.enable = true;

  programs.bash.interactiveShellInit = ''
    # --- Gecmis: "ne yapmistim" sorusunun ikinci cevabi ---
    # Birincisi git'teki bu konfigurasyon; bu onun tamamlayicisi.
    HISTSIZE=-1                 # sinirsiz
    HISTFILESIZE=-1
    HISTCONTROL=ignoreboth      # tekrarlari ve bosluk baslayanlari atla
    HISTTIMEFORMAT='%F %T  '    # her komutun ne zaman calistigi
    shopt -s histappend         # oturumlar birbirinin gecmisini EZMESIN
    PROMPT_COMMAND="history -a''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

    # --- Prompt: KIRMIZI ve hostname'li ---
    # Mac terminaliyle karistirip yanlis makinede yikici komut calistirma
    # riskini kesiyor. Bugun iki makinede paralel calisirken gerceklesti.
    PS1='\[\e[1;31m\][\h]\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\] \$ '

    # --- Renkler ---
    alias ls='ls --color=auto'
    alias ll='ls -alh --color=auto'
    alias grep='grep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip -c'

    # --- fzf: Ctrl-R gecmis, Ctrl-T dosya, Alt-C dizin ---
    source ${pkgs.fzf}/share/fzf/key-bindings.bash
    source ${pkgs.fzf}/share/fzf/completion.bash
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

    # Sistem durumu tek komutta — SSH atmak zorunda kalinan nadir anlar icin
    alias durum='systemctl --failed --no-pager; echo; \
                 systemctl is-active nginx tailscaled docker sshd; echo; \
                 df -h / /home/efe/sata | tail -2'
  '';

  # ================================================================= TMUX ====
  programs.tmux = {
    enable = true;
    shortcut = "a";              # prefix: Ctrl-A
    baseIndex = 1;                # pencereler 1'den baslasin
    escapeTime = 10;
    historyLimit = 50000;
    terminal = "screen-256color";

    extraConfig = ''
      # Pencere kapaninca numaralar kaymasin — base-index 1 ile tutarli
      set -g renumber-windows on
      setw -g pane-base-index 1

      set -g mouse on

      # Split: v = dikey (yan yana), h = yatay (alt alta)
      # vim'deki <leader>v / <leader>h ile ayni mantik
      bind v split-window -h -c "#{pane_current_path}"
      bind h split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Pane'ler arasi gecis — vim ile ayni tuslar
      bind -n C-Left  select-pane -L
      bind -n C-Right select-pane -R
      bind -n C-Up    select-pane -U
      bind -n C-Down  select-pane -D

      bind r source-file /etc/tmux.conf \; display "tmux.conf yeniden yuklendi"

      # Status bar: solda hostname (yanlis makine korumasi, kirmizi prompt
      # ile ayni gerekce)
      set -g status-style 'bg=colour234 fg=colour250'
      set -g status-left  '#[bg=colour160,fg=colour255,bold] #H #[default] '
      set -g status-left-length 20
      set -g status-right '#[fg=colour245]%d.%m %H:%M '
      setw -g window-status-current-style 'fg=colour255,bg=colour238,bold'
    '';
  };
}
