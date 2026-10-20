;;; some-configurations.el --- Assorted keybindings and tweaks -*- lexical-binding: t; -*-

;;; Faster move around
(global-set-key (kbd "C-x <right>") 'windmove-right)
(global-set-key (kbd "C-x <left>") 'windmove-left)
(global-set-key (kbd "C-x <down>") 'windmove-down)
(global-set-key (kbd "C-x <up>") 'windmove-up)

;; M-<arrow> navigation (M-<up>/M-<down> by lines, M-<left>/M-<right> by
;; word) lives in global-key-overrides.el, where it overrides every mode.
;; M-n / M-p are left to each mode's own meaning.

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
