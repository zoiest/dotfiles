;;; delete-no-kill-ring.el --- Delete without touching the kill ring -*- lexical-binding: t; -*-

;;; Copied from http://xahlee.info/emacs/emacs/emacs_kill-ring.html
;;; Modify behaviors of delete
(defun my-delete-word (arg)
  "Delete characters forward until encountering the end of a word.
With argument, do this that many times.
This command does not push erased text to kill-ring."
  (interactive "p")
  (delete-region (point) (progn (forward-word arg) (point))))

(defun my-backward-delete-word (arg)
  "Delete characters backward until encountering the beginning of a word.
With argument, do this that many times.
This command does not push erased text to kill-ring."
  (interactive "p")
  (my-delete-word (- arg)))

(defun my-delete-line ()
  "Delete text from current position to end of line char.
If at end of line, delete the newline character."
  (interactive)
  (if (eolp)
      (delete-char 1)
    (delete-region
     (point)
     (save-excursion (move-end-of-line 1) (point)))))

(defun my-delete-line-backward ()
  "Delete text between the beginning of the line to the cursor position."
  (interactive)
  (let (x1 x2)
    (setq x1 (point))
    (move-beginning-of-line 1)
    (setq x2 (point))
    (delete-region x1 x2)))

;;; Here's the code to bind them emacs's default shortcut keys:
(global-set-key (kbd "M-d") 'my-delete-word)
(global-set-key (kbd "<M-backspace>") 'my-backward-delete-word)
(global-set-key (kbd "C-k") 'my-delete-line)
(global-set-key (kbd "C-S-k") 'my-delete-line-backward)

;;; Read keysequence with the command below in terminal
;;; (format-kbd-macro (read-key-sequence "Key? " nil t))
(global-set-key (kbd "ESC d") 'my-delete-word)
(global-set-key (kbd "ESC DEL") 'my-backward-delete-word)

(provide 'delete-no-kill-ring)
