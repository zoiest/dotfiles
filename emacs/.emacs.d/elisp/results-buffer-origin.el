;;; results-buffer-origin.el --- Jump to quickfix-like target window -*- lexical-binding: t; -*-

;; Vim-quickfix-like behavior: selecting a match in *xref*, *grep*,
;; *rg*, or *compilation* buffers displays the target in the last
;; "normal" editing window you focused (not a results buffer, not
;; the minibuffer) — kept continuously up to date, not just the
;; window the search was started from. Switch to a different edit
;; window before picking the next match, and results now land there
;; instead. If that window is no longer live, falls back to normal
;; `display-buffer' behavior (free to pick or create a new pane).

(defvar my-results-target-window nil
  "Most recently focused \"normal\" editing window (quickfix target).")

(defvar my-results-buffer-names '("*xref*" "*grep*" "*rg*" "*compilation*" "*rustic-compilation*")
  "Buffer names that should never be recorded as the quickfix target window.")

(defun my-results-buffer--results-window-p (window)
  "Non-nil if WINDOW is showing a results buffer or the minibuffer."
  (let* ((buf (window-buffer window))
         (name (buffer-name buf)))
    (or (window-minibuffer-p window)
        (member name my-results-buffer-names)
        (string-match-p "^\\*\\(cargo-[^*]+\\|Flymake diagnostics[^*]*\\)\\*$" name)
        (with-current-buffer buf
          (derived-mode-p 'compilation-mode 'flymake-diagnostics-buffer-mode)))))

(defun my-results-buffer--track-target (&optional frame)
  "Update `my-results-target-window' with the current window, if it
is a normal editing window (not a results buffer / minibuffer)."
  (let ((win (frame-selected-window frame)))
    (unless (my-results-buffer--results-window-p win)
      (setq my-results-target-window win))))

;; Keep the target window up to date as focus moves around, covering
;; both mouse/keyboard window switches and buffers changing within a window.
(add-hook 'window-selection-change-functions #'my-results-buffer--track-target)
(add-hook 'window-buffer-change-functions #'my-results-buffer--track-target)

(defun my-results-buffer--reuse-target-action (fn &rest args)
  "Run FN with `display-buffer-overriding-action' set to reuse the
quickfix target window, when it is still live. Uses Emacs' normal
display-buffer action mechanism (no redefinition of `display-buffer'),
so it composes safely and cannot recurse."
  (if (window-live-p my-results-target-window)
      (let ((display-buffer-overriding-action
             (list (lambda (buffer _alist)
                     (when (window-live-p my-results-target-window)
                       (window--display-buffer
                        buffer my-results-target-window 'reuse))))))
        (apply fn args))
    (apply fn args)))

;; `xref-goto-xref' (RET / n / p with `xref-show-definitions-function')
;; ultimately calls `xref-pop-to-location-buffer' -> `pop-to-buffer'.
;; Advise the low-level location display so all xref selection commands
;; (RET, TAB, n, p, xref-quit-and-goto-xref, etc.) are covered.
(with-eval-after-load 'xref
  (advice-add 'xref-pop-to-location-buffer :around #'my-results-buffer--reuse-target-action))

;; grep-mode / rg-mode / compilation-mode (compile.el) all funnel
;; through `compilation-goto-locus', which chooses a window for the
;; source buffer. Advise it the same way.
(with-eval-after-load 'compile
  (advice-add 'compilation-goto-locus :around #'my-results-buffer--reuse-target-action))

;; `rustic-compile-goto-error-hook' handles clicking/RET on line-number
;; gutters inside `rustic-compilation-mode' via `find-file-other-window'.
(with-eval-after-load 'rustic-compile
  (advice-add 'rustic-compile-goto-error-hook :around #'my-results-buffer--reuse-target-action))

(provide 'results-buffer-origin)
