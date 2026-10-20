;;; flash-jump-line.el --- Briefly flash the line you jump to -*- lexical-binding: t; -*-

;; Flashes the destination line after a jump, so it is obvious where
;; point landed. Covered jumps:
;;
;;   - leaving isearch on a match
;;   - selecting a match in *xref*
;;   - selecting a match in *compilation*, *grep*, or *rg*
;;   - `next-error' / `previous-error', plus other next-error sources
;;     such as *Occur* and flymake
;;
;; Emacs' built-in `pulse' is deliberately not used for the highlight.
;; In a terminal frame (face-background 'default) is "unspecified-bg",
;; so `color-values' returns nil, which makes `pulse-available-p' and
;; therefore `pulse-flag' nil. With pulsing unavailable,
;; `pulse-momentary-highlight-one-line' does not flash: it holds the
;; highlight until the next key press. A plain overlay plus a timer
;; behaves identically in GUI and terminal frames.

(require 'isearch)

(declare-function xref-pulse-momentarily "xref" ())

(defgroup my-flash-line nil
  "Briefly highlight the line jumped to."
  :group 'convenience)

(defcustom my-flash-line-duration 0.25
  "Seconds the destination line stays highlighted."
  :type 'number
  :group 'my-flash-line)

(defface my-flash-line-face
  '((t :inherit isearch :extend t))
  "Face for the momentary jump-destination highlight.
Inherits `isearch' because themes make that face deliberately
conspicuous; many themes' `highlight' is nearly invisible (on
monokai-pro it is #353236 against a #2d2a2e background).
`:extend' makes the highlight span the full window width."
  :group 'my-flash-line)

(defvar my-flash-line--overlay nil
  "Overlay currently showing the flash, if any.")

(defvar my-flash-line--timer nil
  "Timer that will remove `my-flash-line--overlay'.")

(defun my-flash-line--clear ()
  "Remove the flash overlay and cancel its timer."
  (when (timerp my-flash-line--timer)
    (cancel-timer my-flash-line--timer))
  (setq my-flash-line--timer nil)
  (when (overlayp my-flash-line--overlay)
    (delete-overlay my-flash-line--overlay))
  (setq my-flash-line--overlay nil))

(defun my-flash-line (&rest _args)
  "Briefly highlight the line around point in the current buffer.
Accepts and ignores arguments so it can be used directly as a hook
function.  Only one flash is ever active: a new jump replaces the
highlight from the previous one."
  (my-flash-line--clear)
  (let ((ov (make-overlay (line-beginning-position)
                          (min (point-max) (1+ (line-end-position))))))
    (overlay-put ov 'face 'my-flash-line-face)
    ;; Sit above hl-line, region, and friends for the duration.
    (overlay-put ov 'priority 100)
    (setq my-flash-line--overlay ov)
    (setq my-flash-line--timer
          (run-with-timer my-flash-line-duration nil #'my-flash-line--clear))))

(defun my-flash-line-at-marker (marker)
  "Flash the line MARKER points at, in MARKER's own buffer."
  (let ((buffer (and (markerp marker) (marker-buffer marker))))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (save-excursion
          (goto-char marker)
          (my-flash-line))))))

;; --- isearch ---

(defun my-flash-line--after-isearch ()
  "Flash the match isearch finished on, unless the search was aborted."
  (unless isearch-mode-end-hook-quit
    (my-flash-line)))

(add-hook 'isearch-mode-end-hook #'my-flash-line--after-isearch)

(defun my-flash-line--after-isearch-repeat (&rest _args)
  "Flash the new match after C-s / C-r steps to another one.
`isearch-repeat' is the shared helper behind `isearch-repeat-forward'
and `isearch-repeat-backward', so advising it covers both directions
and wrap-around.  Nothing is flashed on a failed search, where point
has not moved.

The flash does not hide the match itself: isearch's own overlay has
priority 1001 against this overlay's 100, so the matched text keeps
its highlight on top of the flashed line."
  (when isearch-success
    (my-flash-line)))

(advice-add 'isearch-repeat :after #'my-flash-line--after-isearch-repeat)

;; --- xref ---

;; `xref-after-jump-hook' defaults to (recenter xref-pulse-momentarily)
;; and `xref-after-return-hook' to (xref-pulse-momentarily). Drop the
;; pulse, which lingers until the next keypress in a terminal, and keep
;; `recenter'.
(with-eval-after-load 'xref
  (remove-hook 'xref-after-jump-hook #'xref-pulse-momentarily)
  (remove-hook 'xref-after-return-hook #'xref-pulse-momentarily)
  (add-hook 'xref-after-jump-hook #'my-flash-line)
  (add-hook 'xref-after-return-hook #'my-flash-line))

;; --- compilation / grep / rg ---

(defun my-flash-line--after-goto-locus (_msg mk _end-mk)
  "Flash the source line a compilation-style match jumped to.
MK is the target marker passed to `compilation-goto-locus'."
  (my-flash-line-at-marker mk))

;; RET, mouse clicks, and next-error in compilation-derived modes all
;; funnel through `compilation-goto-locus'. Flashing from the marker
;; rather than point means the correct line is highlighted no matter
;; which window ends up selected.
(with-eval-after-load 'compile
  (advice-add 'compilation-goto-locus :after #'my-flash-line--after-goto-locus))

;; --- everything else that uses the next-error protocol ---

(add-hook 'next-error-hook #'my-flash-line)

(provide 'flash-jump-line)
