;;; some-configurations.el --- Assorted keybindings and tweaks -*- lexical-binding: t; -*-

;;; Faster move around
(global-set-key (kbd "C-x <right>") 'windmove-right)
(global-set-key (kbd "C-x <left>") 'windmove-left)
(global-set-key (kbd "C-x <down>") 'windmove-down)
(global-set-key (kbd "C-x <up>") 'windmove-up)

;; M-n / M-p / M-<down> / M-<up> fast motion lives in
;; global-key-overrides.el, which binds them in a keymap that overrides
;; every major and minor mode (plain `global-set-key' loses to comint,
;; compilation, diff-mode, Info, ...).

;; Rebinding the transpose keybindings because Ctrl-t is tmux prefix
(global-set-key (kbd "C-ö") #'transpose-chars)

;;; Confirm before exit
(setq confirm-kill-emacs 'yes-or-no-p)

;;; no backup files
(setq make-backup-files nil)

;;; no autosave
(setq auto-save-default nil)

;;; display fill column
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)

;;; whitespace-mode
;; (add-hook 'prog-mode-hook #'whitespace-mode)

;; disable indent
(setq-default indent-tabs-mode nil)

;; dired less verbose
;; https://emacs.stackexchange.com/questions/45383/dired-hide-details-show-size-and-date
(require 'ls-lisp)
(setq ls-lisp-use-insert-directory-program nil)
(setq ls-lisp-verbosity nil)

(provide 'some-configurations)
